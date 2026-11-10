-- Audit fixes, 10 Nov 2026.
--
-- 1. Trending only uses shops buyers can actually see. The first version
--    checked shops.is_active, which stays true for shops hidden because their
--    subscription lapsed (is_publicly_listed is the public-visibility flag).
-- 2. PayFast cancellation notices used to fail its payment validation and
--    leave "PayFast ITN server validation failed." on shops that had really
--    cancelled (PayFast's own notice said CANCELLED). payfast-itn now confirms
--    cancellations through PayFast's API; this corrects the old labels.

create or replace function public.refresh_trending_searches()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  next_terms text[];
  current_terms text[];
begin
  with available as (
    select p.id, btrim(p.title) as title, p.shop_id, p.created_at, p.is_featured
    from products p
    join shops s on s.id = p.shop_id and s.is_publicly_listed
    where p.is_published
      and p.title is not null and btrim(p.title) <> ''
      and (coalesce(p.stock_qty, 0) > 0
           or p.fulfillment_mode in ('made_to_order', 'stocked_with_mto'))
  ),
  scored as (
    select a.*,
      coalesce((select sum(oi.quantity) from order_items oi
                where oi.product_id = a.id and oi.created_at > now() - interval '30 days'), 0) * 5
    + coalesce((select count(*) from favourites f
                where f.product_id = a.id and f.created_at > now() - interval '30 days'), 0) * 3
    + coalesce((select count(*) from content_views v
                where v.kind = 'product' and v.target_id = a.id
                  and v.viewed_on > current_date - 30), 0) as score
    from available a
  ),
  per_shop as (
    -- At most two pieces per shop so one maker can't fill the list.
    select *, row_number() over (partition by shop_id order by score desc, created_at desc) as shop_rank
    from scored
  ),
  deduped as (
    select distinct on (lower(title)) title, score, is_featured, created_at
    from per_shop
    where shop_rank <= 2
    order by lower(title), score desc
  )
  select array_agg(title order by score desc, is_featured desc, created_at desc)
  into next_terms
  from (select * from deduped order by score desc, is_featured desc, created_at desc limit 8) top;

  select array_agg(term order by sort_order) into current_terms
  from trending_searches where is_active;

  -- Leave the table alone when nothing changed, so apps aren't pinged hourly.
  if next_terms is null or next_terms is not distinct from current_terms then
    return;
  end if;

  delete from trending_searches where true;
  insert into trending_searches (term, sort_order, is_active)
  select term, ord::integer, true
  from unnest(next_terms) with ordinality as t(term, ord);
end;
$$;

select public.refresh_trending_searches();

update public.vendor_subscriptions
set status_reason = 'PayFast marked the subscription as cancelled.'
where status = 'cancelled'
  and status_reason = 'PayFast ITN server validation failed.'
  and upper(coalesce(last_itn_payload -> 'body' ->> 'payment_status', '')) = 'CANCELLED';
