-- User-generated content safety (Apple App Review Guideline 1.2).
--
-- 1. Reports can now target product reviews, shop reviews and chat messages.
--    A chat message can only be reported by a participant of its thread.
-- 2. A server-side objectionable-language filter on user-visible UGC text.
-- 3. Community guidelines acceptance, recorded per profile through an RPC.
-- 4. The moderation log accepts the new review/message takedowns.
--
-- Additive. No existing rows are changed: the filter only checks a column on
-- INSERT or when an UPDATE changes that column, so old rows can still be
-- edited in unrelated ways.

-- ── 1. Reports on reviews and chat messages ───────────────────────────────
alter table public.creator_content_reports
  drop constraint creator_content_reports_target_type_check,
  add constraint creator_content_reports_target_type_check
    check (target_type in ('post', 'comment', 'story', 'shop',
                           'product_review', 'shop_review', 'message'));

-- Same as 20260929100000_report_reviewer_from_server.sql plus the three new
-- target types. Owner is the author of the reported text (the reviewer or the
-- message sender); shop is the shop the review or conversation belongs to.
create or replace function public.stamp_creator_content_report()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    new.reporter_id := (select auth.uid());
    new.created_at := statement_timestamp();
    new.details := btrim(new.details);
    new.resolution_notes := '';
    new.status := 'open';
    new.reviewed_by := null;
    new.reviewed_at := null;
    if new.reporter_id is null then
      raise exception 'Sign in to report content';
    end if;
    if exists (select 1 from public.creator_content_reports r
        where r.reporter_id = new.reporter_id and r.target_type = new.target_type
          and r.target_id = new.target_id) then
      return new;
    end if;
    perform pg_advisory_xact_lock(hashtext(new.reporter_id::text));
    if (select count(*) from public.creator_content_reports r
        where r.reporter_id = new.reporter_id
          and r.created_at > statement_timestamp() - interval '1 hour') >= 10 then
      raise exception 'Too many reports. Please try again later';
    end if;
    if new.target_type = 'post' then
      select left(coalesce(p.caption, ''), 4000), s.vendor_id, p.shop_id
        into new.target_text_snapshot, new.target_owner_id, new.target_shop_id
      from public.shop_posts p join public.shops s on s.id = p.shop_id
      where p.id = new.target_id and p.is_published;
    elsif new.target_type = 'comment' then
      select left(c.body, 4000), s.vendor_id, p.shop_id
        into new.target_text_snapshot, new.target_owner_id, new.target_shop_id
      from public.shop_post_comments c
      join public.shop_posts p on p.id = c.post_id
      join public.shops s on s.id = p.shop_id
      where c.id = new.target_id;
    elsif new.target_type = 'story' then
      select left(coalesce(st.caption, ''), 4000), s.vendor_id, st.shop_id
        into new.target_text_snapshot, new.target_owner_id, new.target_shop_id
      from public.shop_stories st join public.shops s on s.id = st.shop_id
      where st.id = new.target_id and st.expires_at > now();
    elsif new.target_type = 'shop' then
      select left(s.name || E'\n' || coalesce(s.bio, ''), 4000), s.vendor_id, s.id
        into new.target_text_snapshot, new.target_owner_id, new.target_shop_id
      from public.shops s where s.id = new.target_id and s.is_active;
    elsif new.target_type = 'product_review' then
      select left(r.rating || '/5' || E'\n' || coalesce(r.review_text, ''), 4000),
             r.buyer_id, r.shop_id
        into new.target_text_snapshot, new.target_owner_id, new.target_shop_id
      from public.product_reviews r where r.id = new.target_id;
    elsif new.target_type = 'shop_review' then
      select left(r.rating || '/5' || E'\n' || coalesce(r.review_text, ''), 4000),
             r.buyer_id, r.shop_id
        into new.target_text_snapshot, new.target_owner_id, new.target_shop_id
      from public.shop_reviews r where r.id = new.target_id;
    elsif new.target_type = 'message' then
      -- Only the buyer or vendor of the conversation may report a message.
      select left(coalesce(nullif(btrim(m.body), ''), m.attachment_name, 'Attachment'), 4000),
             m.sender_id, t.shop_id
        into new.target_text_snapshot, new.target_owner_id, new.target_shop_id
      from public.chat_messages m join public.chat_threads t on t.id = m.thread_id
      where m.id = new.target_id
        and new.reporter_id in (t.buyer_id, t.vendor_id);
    end if;
    if not found then
      raise exception 'Content is unavailable for reporting';
    end if;
  elsif new.reporter_id is distinct from old.reporter_id
     or new.target_type is distinct from old.target_type
     or new.target_id is distinct from old.target_id
     or new.reason is distinct from old.reason
     or new.details is distinct from old.details
     or new.target_text_snapshot is distinct from old.target_text_snapshot
     or new.target_owner_id is distinct from old.target_owner_id
     or new.target_shop_id is distinct from old.target_shop_id
     or new.created_at is distinct from old.created_at then
    raise exception 'Reports are immutable';
  end if;

  if new.status in ('resolved', 'dismissed') then
    -- The web admin acts through the service role and passes the admin's id.
    new.reviewed_by := case
      when current_user in ('postgres', 'service_role', 'supabase_admin')
        and new.reviewed_by is not null then new.reviewed_by
      else (select auth.uid()) end;
    new.reviewed_at := statement_timestamp();
  else
    new.reviewed_by := null;
    new.reviewed_at := null;
  end if;
  return new;
end;
$$;

drop policy creator_content_reports_insert_visible_target on public.creator_content_reports;
create policy creator_content_reports_insert_visible_target
on public.creator_content_reports for insert to authenticated
with check (
  reporter_id = (select auth.uid())
  and case target_type
    when 'post' then exists (select 1 from public.shop_posts p where p.id = target_id and p.is_published)
    when 'comment' then exists (select 1 from public.shop_post_comments c where c.id = target_id)
    when 'story' then exists (select 1 from public.shop_stories s where s.id = target_id and s.expires_at > now())
    when 'shop' then exists (select 1 from public.shops s where s.id = target_id and s.is_active)
    when 'product_review' then exists (select 1 from public.product_reviews r where r.id = target_id)
    when 'shop_review' then exists (select 1 from public.shop_reviews r where r.id = target_id)
    when 'message' then exists (
      select 1 from public.chat_messages m join public.chat_threads t on t.id = m.thread_id
      where m.id = target_id and (select auth.uid()) in (t.buyer_id, t.vendor_id))
    else false
  end
);

-- ── 2. Objectionable-language filter ──────────────────────────────────────
-- A deliberately moderate, curated list: racial/ethnic/homophobic/ableist
-- slurs (including South African ones), explicit sexual terms and severe
-- profanity. Everyday mild words (damn, hell, crap, bloody, shit) are allowed.
--
-- Every term is anchored with \m...\M (start/end of word, case-insensitive),
-- so words that merely contain a term are allowed: Scunthorpe, cocktail,
-- assassin, Hancock, Pakistan, spice, therapist, retardant, rapeseed.
--
-- Terms left out on purpose because they have common innocent meanings on a
-- craft marketplace: cock (rooster), pussy (pussy willow), dick (name),
-- cum (cum laude), coon (Maine Coon), chink (a gap), homo (homo sapiens),
-- fag (cigarette), dyke (embankment), bitch (female dog), nudes (colour),
-- xxx (kisses). Reports and admin review cover anything the list misses.
--
-- Keep lib/features/safety/content_filter.dart in sync with this list.
create or replace function public.contains_blocked_terms(input text)
returns boolean language sql immutable parallel safe set search_path = '' as $$
  select coalesce(input ~* ('\m(?:' || array_to_string(array[
    -- Severe profanity
    'f[u*@#]+c?k+(?:s|ed|er|ers|ing|in|face|faces|head|heads|wit|wits)?',
    'fck(?:s|ed|er|ers|ing)?',
    'motherf[u*@#]+c?k+(?:a|as|er|ers|ing|in)?',
    'cunts?',
    'twats?',
    'cocksuck(?:er|ers|ing)?',
    'dickheads?',
    'a(?:ss|rse)holes?',
    -- Explicit sexual terms
    'porn(?:o|os|ography|ographic|hub)?',
    'blowjobs?',
    'handjobs?',
    'cumshots?',
    'creampies?',
    'gangbang(?:s|ed|ing)?',
    'deepthroat(?:s|ed|ing)?',
    'dildos?',
    'masturbat(?:e|es|ed|ing|ion)',
    'jizz',
    'clits?',
    'hentai',
    'orgy|orgies',
    'whores?',
    'sluts?|slutty',
    'bestiality',
    'pa?edophil(?:e|es|ia)',
    -- Slurs
    'n[i1]gg(?:a|as|ah|az|er|ers)',
    'sandn[i1]gg(?:a|as|er|ers)',
    'k[a@]ff[i1]rs?',
    'kaffers?',
    'hotnots?',
    'coolies?',
    'faggots?',
    'retards?|retarded',
    'spics?',
    'kikes?',
    'gooks?',
    'pakis?',
    'wetbacks?',
    'trann(?:y|ies)',
    'ragheads?',
    'towelheads?',
    'jungle ?bunn(?:y|ies)'
  ], '|') || ')\M'), false);
$$;
revoke all on function public.contains_blocked_terms(text) from public;
grant execute on function public.contains_blocked_terms(text) to anon, authenticated, service_role;

-- Checks the named text (or jsonb) columns of NEW. On UPDATE a column is only
-- checked when its value changed. Applies to every role, including the
-- service role, because the website writes some member text server-side.
create or replace function public.enforce_ugc_text_filter() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare
  col text;
  new_value text;
begin
  foreach col in array tg_argv loop
    new_value := to_jsonb(new) ->> col;
    if new_value is null then continue; end if;
    if tg_op = 'UPDATE' and new_value is not distinct from (to_jsonb(old) ->> col) then
      continue;
    end if;
    if public.contains_blocked_terms(new_value) then
      raise exception 'This text contains language that isn''t allowed on Artisan Lane.'
        using errcode = 'P0001', hint = 'blocked_terms';
    end if;
  end loop;
  return new;
end;
$$;
revoke all on function public.enforce_ugc_text_filter() from public, anon, authenticated;

create trigger ugc_text_filter before insert or update on public.shop_posts
for each row execute function public.enforce_ugc_text_filter('caption', 'step_captions');
create trigger ugc_text_filter before insert or update on public.shop_post_comments
for each row execute function public.enforce_ugc_text_filter('body');
create trigger ugc_text_filter before insert or update on public.shop_stories
for each row execute function public.enforce_ugc_text_filter('caption');
create trigger ugc_text_filter before insert or update on public.post_polls
for each row execute function public.enforce_ugc_text_filter('question', 'options');
create trigger ugc_text_filter before insert or update on public.product_reviews
for each row execute function public.enforce_ugc_text_filter('review_text');
create trigger ugc_text_filter before insert or update on public.shop_reviews
for each row execute function public.enforce_ugc_text_filter('review_text');
create trigger ugc_text_filter before insert or update on public.chat_messages
for each row execute function public.enforce_ugc_text_filter('body', 'attachment_name');
create trigger ugc_text_filter before insert or update on public.shops
for each row execute function public.enforce_ugc_text_filter('name', 'bio', 'brand_story');
create trigger ugc_text_filter before insert or update on public.profiles
for each row execute function public.enforce_ugc_text_filter('display_name');
-- Seller listings are user content too (App Store guideline 1.2).
create trigger ugc_text_filter before insert or update on public.products
for each row execute function public.enforce_ugc_text_filter('title', 'description');

-- ── 3. Community guidelines acceptance ────────────────────────────────────
-- Not in the owner-editable profile columns (guard_profile_privileged_fields),
-- and not granted for direct reads: members set and read only their own
-- through these RPCs.
alter table public.profiles add column community_guidelines_accepted_at timestamptz;

create function public.accept_community_guidelines() returns timestamptz
language plpgsql volatile security definer set search_path = '' as $$
declare
  accepted timestamptz;
begin
  if (select auth.uid()) is null then
    raise exception 'Sign in to accept the community guidelines' using errcode = '42501';
  end if;
  update public.profiles
     set community_guidelines_accepted_at = coalesce(community_guidelines_accepted_at, now())
   where id = (select auth.uid())
  returning community_guidelines_accepted_at into accepted;
  if accepted is null then
    raise exception 'Profile not found' using errcode = 'P0002';
  end if;
  return accepted;
end;
$$;
revoke all on function public.accept_community_guidelines() from public, anon;
grant execute on function public.accept_community_guidelines() to authenticated;

create function public.get_my_community_guidelines_acceptance() returns timestamptz
language sql stable security definer set search_path = '' as $$
  select p.community_guidelines_accepted_at from public.profiles p
  where p.id = (select auth.uid());
$$;
revoke all on function public.get_my_community_guidelines_acceptance() from public, anon;
grant execute on function public.get_my_community_guidelines_acceptance() to authenticated;

-- ── 4. Moderation log: review and message takedowns ───────────────────────
alter table public.moderation_actions
  drop constraint moderation_actions_action_check,
  add constraint moderation_actions_action_check check (action in (
    'remove_post', 'restore_post', 'delete_comment', 'remove_story',
    'suspend_shop', 'restore_shop', 'suspend_user', 'restore_user',
    'resolve_report', 'dismiss_report',
    'delete_product_review', 'delete_shop_review', 'delete_message')),
  drop constraint moderation_actions_target_type_check,
  add constraint moderation_actions_target_type_check check (target_type in (
    'post', 'comment', 'story', 'shop', 'user', 'report',
    'product_review', 'shop_review', 'message'));
