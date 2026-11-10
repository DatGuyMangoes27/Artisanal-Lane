-- Trending searches were seeded once (migration 059) and never refreshed, so the
-- list kept showing pieces that had sold out or been removed. This rebuilds it
-- from the last 30 days of real activity on pieces that can still be bought,
-- and runs every hour.

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
    join shops s on s.id = p.shop_id and s.is_active
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

revoke all on function public.refresh_trending_searches() from public, anon, authenticated;

select cron.unschedule('refresh-trending-searches')
where exists (select 1 from cron.job where jobname = 'refresh-trending-searches');

select cron.schedule(
  'refresh-trending-searches',
  '7 * * * *',
  $$select public.refresh_trending_searches();$$
);

select public.refresh_trending_searches();
