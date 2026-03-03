-- ============================================================
-- Artisanal Lane - Update categories to lifestyle-based taxonomy
-- ============================================================

-- Rename / re-slug existing rows (keep UUIDs so product FK links stay intact)
update categories set name = 'Art & Design',  slug = 'art-design',  sort_order = 1 where id = 'c0000000-0000-0000-0000-000000000001';
update categories set name = 'Clothing',       slug = 'clothing',    sort_order = 2 where id = 'c0000000-0000-0000-0000-000000000002';
update categories set name = 'Beauty',         slug = 'beauty',      sort_order = 3 where id = 'c0000000-0000-0000-0000-000000000003';
update categories set name = 'Jewellery',      slug = 'jewellery',   sort_order = 4 where id = 'c0000000-0000-0000-0000-000000000004';
update categories set name = 'Home & Living',  slug = 'home-living', sort_order = 5 where id = 'c0000000-0000-0000-0000-000000000005';

-- Add new Baby & Kids category
insert into categories (id, name, slug, icon_url, sort_order)
values ('c0000000-0000-0000-0000-000000000006', 'Baby & Kids', 'baby-kids', null, 6)
on conflict (id) do update set name = excluded.name, slug = excluded.slug, sort_order = excluded.sort_order;
