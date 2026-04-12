insert into categories (id, name, slug, icon_url, sort_order)
values ('c0000000-0000-0000-0000-000000000010', 'Other', 'other', null, 10)
on conflict (id) do update
set
  name = excluded.name,
  slug = excluded.slug,
  sort_order = excluded.sort_order;
