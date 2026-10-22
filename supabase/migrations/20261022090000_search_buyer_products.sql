-- Relevance-ranked buyer product search for the app's Shop tab.
--
-- Replaces substring matching (title/description ilike '%term%', which made
-- "rings" match "earrings"/"strings" and listed results newest-first) with
-- word matching: a query word matches a product word when they are equal
-- (ignoring simple plurals: rings = ring) or when the product word starts
-- with it (neckla -> necklace). Every query word must match somewhere; each
-- scores by its best field: title > tags/category/subcategory > shop name >
-- description.
--
-- Mirrors lib/features/buyer/utils/product_search.dart (the app re-ranks with
-- it, and falls back to it entirely while this function is not deployed) and
-- landing/src/lib/marketplace/product-search.ts.
--
-- The function only matches and orders; it is SECURITY INVOKER so products
-- RLS applies, and the app chains its usual buyer-visibility filters
-- (published, active shop, available) and product embed on top of the RPC.

create or replace function public.search_words(p_text text)
returns text[]
language sql
immutable
parallel safe
set search_path = ''
as $$
  select coalesce(array_agg(w), '{}'::text[])
  from regexp_split_to_table(lower(coalesce(p_text, '')), '[^[:alnum:]]+') as w
  where w <> ''
$$;

create or replace function public.search_singular(p_word text)
returns text
language sql
immutable
parallel safe
set search_path = ''
as $$
  select case
    when length(p_word) > 4 and p_word like '%ies'
      then left(p_word, -3) || 'y'
    when length(p_word) > 4 and (
      p_word like '%sses' or p_word like '%xes' or p_word like '%ches'
      or p_word like '%shes' or p_word like '%zes'
    )
      then left(p_word, -2)
    when length(p_word) > 3 and p_word like '%s'
      and p_word not like '%ss' and p_word not like '%us' and p_word not like '%is'
      then left(p_word, -1)
    else p_word
  end
$$;

-- 2 = exact word (plural-insensitive), 1 = word starts with the query word,
-- 0 = no match. Never matches inside a word.
create or replace function public.search_word_grade(p_query_word text, p_words text[])
returns integer
language sql
immutable
parallel safe
set search_path = ''
as $$
  select coalesce(max(
    case
      when w = p_query_word
        or public.search_singular(w) = public.search_singular(p_query_word) then 2
      when length(p_query_word) >= 2 and left(w, length(p_query_word)) = p_query_word then 1
      else 0
    end
  ), 0)
  from unnest(p_words) as w
$$;

create or replace function public.search_buyer_products(p_query text, p_limit integer default 60)
returns setof public.products
language sql
stable
security invoker
set search_path = ''
as $$
  with query_words as (
    select distinct w
    from regexp_split_to_table(lower(coalesce(p_query, '')), '[^[:alnum:]]+') as w
    where w <> ''
    limit 8
  ),
  docs as (
    select
      p.id,
      p.created_at,
      public.search_words(p.title) as title_words,
      public.search_words(
        array_to_string(p.tags, ' ') || ' ' || coalesce(c.name, '') || ' ' || coalesce(sc.name, '')
      ) as meta_words,
      public.search_words(s.name) as shop_words,
      public.search_words(p.description) as description_words
    from public.products p
    join public.shops s on s.id = p.shop_id and s.is_active
    left join public.categories c on c.id = p.category_id
    left join public.subcategories sc on sc.id = p.subcategory_id
    where p.is_published
      and p.archived_at is null
      and (p.stock_qty > 0 or p.fulfillment_mode in ('made_to_order', 'stocked_with_mto'))
  ),
  scored as (
    select d.id, d.created_at, sum(best.score) as score, bool_and(best.score > 0) as all_matched
    from docs d
    cross join query_words q
    cross join lateral (
      select greatest(
        case public.search_word_grade(q.w, d.title_words) when 2 then 100 when 1 then 80 else 0 end,
        case public.search_word_grade(q.w, d.meta_words) when 2 then 60 when 1 then 50 else 0 end,
        case public.search_word_grade(q.w, d.shop_words) when 2 then 40 when 1 then 30 else 0 end,
        case public.search_word_grade(q.w, d.description_words) when 2 then 20 when 1 then 15 else 0 end
      ) as score
    ) best
    group by d.id, d.created_at
  )
  select p.*
  from scored
  join public.products p on p.id = scored.id
  where scored.all_matched
  order by scored.score desc, scored.created_at desc, p.id
  limit least(greatest(coalesce(p_limit, 60), 1), 300)
$$;

revoke all on function public.search_buyer_products(text, integer) from public;
grant execute on function public.search_words(text) to anon, authenticated;
grant execute on function public.search_singular(text) to anon, authenticated;
grant execute on function public.search_word_grade(text, text[]) to anon, authenticated;
grant execute on function public.search_buyer_products(text, integer) to anon, authenticated;

comment on function public.search_buyer_products(text, integer) is
  'Word/prefix-matched, relevance-ordered buyer product search (title > tags/category > shop > description).';
