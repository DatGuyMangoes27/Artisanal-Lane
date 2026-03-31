-- ============================================================
-- Add subcategories, product tags, and expanded category taxonomy
-- ============================================================

-- 1. Update existing categories
update categories set name = 'Home',       slug = 'home',      sort_order = 1 where id = 'c0000000-0000-0000-0000-000000000005';
update categories set name = 'Art & Design', slug = 'art-design', sort_order = 2 where id = 'c0000000-0000-0000-0000-000000000001';
update categories set name = 'Jewellery',    slug = 'jewellery',  sort_order = 3 where id = 'c0000000-0000-0000-0000-000000000004';
update categories set name = 'Clothing',     slug = 'clothing',   sort_order = 4 where id = 'c0000000-0000-0000-0000-000000000002';
update categories set name = 'Self Care',    slug = 'self-care',  sort_order = 7 where id = 'c0000000-0000-0000-0000-000000000003';
update categories set name = 'Baby & Kids',  slug = 'baby-kids',  sort_order = 6 where id = 'c0000000-0000-0000-0000-000000000006';

-- 2. Add new categories
insert into categories (id, name, slug, icon_url, sort_order) values
  ('c0000000-0000-0000-0000-000000000007', 'Accessories', 'accessories', null, 5),
  ('c0000000-0000-0000-0000-000000000008', 'Pantry',      'pantry',      null, 8),
  ('c0000000-0000-0000-0000-000000000009', 'Pets',        'pets',        null, 9)
on conflict (id) do update set name = excluded.name, slug = excluded.slug, sort_order = excluded.sort_order;

-- 3. Create subcategories table
create table if not exists public.subcategories (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id) on delete cascade,
  name text not null,
  slug text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_subcategories_category_id on subcategories(category_id, sort_order);

alter table public.subcategories enable row level security;

create policy "Subcategories are publicly readable"
  on public.subcategories for select using (true);

-- 4. Add subcategory_id and tags to products
alter table products
  add column if not exists subcategory_id uuid references public.subcategories(id) on delete set null,
  add column if not exists tags text[] not null default '{}';

create index if not exists idx_products_subcategory_id on products(subcategory_id);
create index if not exists idx_products_tags on products using gin(tags);

-- 5. Seed subcategories
-- HOME (c...05)
insert into subcategories (id, category_id, name, slug, sort_order) values
  ('5c000000-0000-0000-0001-000000000001', 'c0000000-0000-0000-0000-000000000005', 'Dining',    'dining',    1),
  ('5c000000-0000-0000-0001-000000000002', 'c0000000-0000-0000-0000-000000000005', 'Décor',     'decor',     2),
  ('5c000000-0000-0000-0001-000000000003', 'c0000000-0000-0000-0000-000000000005', 'Bath',      'bath',      3),
  ('5c000000-0000-0000-0001-000000000004', 'c0000000-0000-0000-0000-000000000005', 'Kitchen',   'kitchen',   4),
  ('5c000000-0000-0000-0001-000000000005', 'c0000000-0000-0000-0000-000000000005', 'Furniture', 'furniture', 5),
  ('5c000000-0000-0000-0001-000000000006', 'c0000000-0000-0000-0000-000000000005', 'Garden',    'garden',    6),
  ('5c000000-0000-0000-0001-000000000007', 'c0000000-0000-0000-0000-000000000005', 'Other',     'other',     99)
on conflict (id) do nothing;

-- ART & DESIGN (c...01)
insert into subcategories (id, category_id, name, slug, sort_order) values
  ('5c000000-0000-0000-0002-000000000001', 'c0000000-0000-0000-0000-000000000001', 'Paintings',    'paintings',    1),
  ('5c000000-0000-0000-0002-000000000002', 'c0000000-0000-0000-0000-000000000001', 'Sketches',     'sketches',     2),
  ('5c000000-0000-0000-0002-000000000003', 'c0000000-0000-0000-0000-000000000001', 'Sculpture',    'sculpture',    3),
  ('5c000000-0000-0000-0002-000000000004', 'c0000000-0000-0000-0000-000000000001', '3D Art',       '3d-art',       4),
  ('5c000000-0000-0000-0002-000000000005', 'c0000000-0000-0000-0000-000000000001', 'Photography',  'photography',  5),
  ('5c000000-0000-0000-0002-000000000006', 'c0000000-0000-0000-0000-000000000001', 'Other',        'other',        99)
on conflict (id) do nothing;

-- JEWELLERY (c...04)
insert into subcategories (id, category_id, name, slug, sort_order) values
  ('5c000000-0000-0000-0003-000000000001', 'c0000000-0000-0000-0000-000000000004', 'Rings',      'rings',      1),
  ('5c000000-0000-0000-0003-000000000002', 'c0000000-0000-0000-0000-000000000004', 'Necklaces',  'necklaces',  2),
  ('5c000000-0000-0000-0003-000000000003', 'c0000000-0000-0000-0000-000000000004', 'Bracelets',  'bracelets',  3),
  ('5c000000-0000-0000-0003-000000000004', 'c0000000-0000-0000-0000-000000000004', 'Earrings',   'earrings',   4),
  ('5c000000-0000-0000-0003-000000000005', 'c0000000-0000-0000-0000-000000000004', 'Other',      'other',      99)
on conflict (id) do nothing;

-- CLOTHING (c...02)
insert into subcategories (id, category_id, name, slug, sort_order) values
  ('5c000000-0000-0000-0004-000000000001', 'c0000000-0000-0000-0000-000000000002', 'Tops',                   'tops',                    1),
  ('5c000000-0000-0000-0004-000000000002', 'c0000000-0000-0000-0000-000000000002', 'Bottoms',                'bottoms',                 2),
  ('5c000000-0000-0000-0004-000000000003', 'c0000000-0000-0000-0000-000000000002', 'Dresses & Jumpsuits',    'dresses-jumpsuits',       3),
  ('5c000000-0000-0000-0004-000000000004', 'c0000000-0000-0000-0000-000000000002', 'Shoes',                  'shoes',                   4),
  ('5c000000-0000-0000-0004-000000000005', 'c0000000-0000-0000-0000-000000000002', 'Knitwear',               'knitwear',                5),
  ('5c000000-0000-0000-0004-000000000006', 'c0000000-0000-0000-0000-000000000002', 'Other',                  'other',                   99)
on conflict (id) do nothing;

-- ACCESSORIES (c...07)
insert into subcategories (id, category_id, name, slug, sort_order) values
  ('5c000000-0000-0000-0005-000000000001', 'c0000000-0000-0000-0000-000000000007', 'Bags',   'bags',   1),
  ('5c000000-0000-0000-0005-000000000002', 'c0000000-0000-0000-0000-000000000007', 'Belts',  'belts',  2),
  ('5c000000-0000-0000-0005-000000000003', 'c0000000-0000-0000-0000-000000000007', 'Hats',   'hats',   3),
  ('5c000000-0000-0000-0005-000000000004', 'c0000000-0000-0000-0000-000000000007', 'Scarf',  'scarf',  4),
  ('5c000000-0000-0000-0005-000000000005', 'c0000000-0000-0000-0000-000000000007', 'Hair',   'hair',   5),
  ('5c000000-0000-0000-0005-000000000006', 'c0000000-0000-0000-0000-000000000007', 'Other',  'other',  99)
on conflict (id) do nothing;

-- BABY & KIDS (c...06)
insert into subcategories (id, category_id, name, slug, sort_order) values
  ('5c000000-0000-0000-0006-000000000001', 'c0000000-0000-0000-0000-000000000006', 'Clothing',     'clothing',     1),
  ('5c000000-0000-0000-0006-000000000002', 'c0000000-0000-0000-0000-000000000006', 'Accessories',  'accessories',  2),
  ('5c000000-0000-0000-0006-000000000003', 'c0000000-0000-0000-0000-000000000006', 'Toys',         'toys',         3),
  ('5c000000-0000-0000-0006-000000000004', 'c0000000-0000-0000-0000-000000000006', 'Décor',        'decor',        4),
  ('5c000000-0000-0000-0006-000000000005', 'c0000000-0000-0000-0000-000000000006', 'Other',        'other',        99)
on conflict (id) do nothing;

-- SELF CARE (c...03)
insert into subcategories (id, category_id, name, slug, sort_order) values
  ('5c000000-0000-0000-0007-000000000001', 'c0000000-0000-0000-0000-000000000003', 'Face',            'face',            1),
  ('5c000000-0000-0000-0007-000000000002', 'c0000000-0000-0000-0000-000000000003', 'Body',            'body',            2),
  ('5c000000-0000-0000-0007-000000000003', 'c0000000-0000-0000-0000-000000000003', 'Hair',            'hair',            3),
  ('5c000000-0000-0000-0007-000000000004', 'c0000000-0000-0000-0000-000000000003', 'Soaps',           'soaps',           4),
  ('5c000000-0000-0000-0007-000000000005', 'c0000000-0000-0000-0000-000000000003', 'Essential Oils',  'essential-oils',  5),
  ('5c000000-0000-0000-0007-000000000006', 'c0000000-0000-0000-0000-000000000003', 'Other',           'other',           99)
on conflict (id) do nothing;

-- PANTRY (c...08)
insert into subcategories (id, category_id, name, slug, sort_order) values
  ('5c000000-0000-0000-0008-000000000001', 'c0000000-0000-0000-0000-000000000008', 'Sauces',     'sauces',     1),
  ('5c000000-0000-0000-0008-000000000002', 'c0000000-0000-0000-0000-000000000008', 'Preserves',  'preserves',  2),
  ('5c000000-0000-0000-0008-000000000003', 'c0000000-0000-0000-0000-000000000008', 'Sweets',     'sweets',     3),
  ('5c000000-0000-0000-0008-000000000004', 'c0000000-0000-0000-0000-000000000008', 'Dry Goods',  'dry-goods',  4),
  ('5c000000-0000-0000-0008-000000000005', 'c0000000-0000-0000-0000-000000000008', 'Other',      'other',      99)
on conflict (id) do nothing;

-- PETS (c...09)
insert into subcategories (id, category_id, name, slug, sort_order) values
  ('5c000000-0000-0000-0009-000000000001', 'c0000000-0000-0000-0000-000000000009', 'Feeding',   'feeding',   1),
  ('5c000000-0000-0000-0009-000000000002', 'c0000000-0000-0000-0000-000000000009', 'Grooming',  'grooming',  2),
  ('5c000000-0000-0000-0009-000000000003', 'c0000000-0000-0000-0000-000000000009', 'Toys',      'toys',      3),
  ('5c000000-0000-0000-0009-000000000004', 'c0000000-0000-0000-0000-000000000009', 'Beds',      'beds',      4),
  ('5c000000-0000-0000-0009-000000000005', 'c0000000-0000-0000-0000-000000000009', 'Other',     'other',     99)
on conflict (id) do nothing;
