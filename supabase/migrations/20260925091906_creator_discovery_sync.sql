-- Private per-account preferences. Decisions are separate rows so two devices
-- swiping different products never overwrite each other's history.
create table public.discovery_choices (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  category_ids uuid[] not null default '{}',
  max_budget numeric(12,2),
  constraint discovery_category_limit check(cardinality(category_ids)<=100),
  constraint discovery_budget_valid check(max_budget is null or (max_budget>0 and max_budget<=100000000))
);
create table public.discovery_product_decisions (
  user_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  liked boolean not null,
  primary key(user_id,product_id)
);
create index discovery_decisions_product_idx on public.discovery_product_decisions(product_id);
alter table public.discovery_choices enable row level security;
alter table public.discovery_product_decisions enable row level security;
revoke all on public.discovery_choices, public.discovery_product_decisions from public,anon,authenticated;
grant select,insert,update,delete on public.discovery_choices, public.discovery_product_decisions to authenticated;
create policy discovery_choices_read on public.discovery_choices for select to authenticated using(user_id=(select auth.uid()));
create policy discovery_choices_insert on public.discovery_choices for insert to authenticated with check(user_id=(select auth.uid()));
create policy discovery_choices_update on public.discovery_choices for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy discovery_choices_delete on public.discovery_choices for delete to authenticated using(user_id=(select auth.uid()));
create policy discovery_decisions_read on public.discovery_product_decisions for select to authenticated using(user_id=(select auth.uid()));
create policy discovery_decisions_insert on public.discovery_product_decisions for insert to authenticated with check(user_id=(select auth.uid()));
create policy discovery_decisions_update on public.discovery_product_decisions for update to authenticated using(user_id=(select auth.uid())) with check(user_id=(select auth.uid()));
create policy discovery_decisions_delete on public.discovery_product_decisions for delete to authenticated using(user_id=(select auth.uid()));
