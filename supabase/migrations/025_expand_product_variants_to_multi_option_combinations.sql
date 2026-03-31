-- ============================================================
-- Expand product variants into multi-option combinations
-- ============================================================

alter table public.products
  add column if not exists option_groups jsonb not null default '[]'::jsonb;

alter table public.product_variants
  add column if not exists display_name text,
  add column if not exists option_values jsonb not null default '[]'::jsonb;

update public.product_variants
set option_values = case
    when jsonb_typeof(option_values) = 'array' and jsonb_array_length(option_values) > 0
      then option_values
    when color_name is not null and btrim(color_name) <> ''
      then jsonb_build_array(color_name)
    else '[]'::jsonb
  end,
  display_name = case
    when display_name is not null and btrim(display_name) <> ''
      then display_name
    when color_name is not null and btrim(color_name) <> ''
      then color_name
    else 'Option'
  end;

alter table public.product_variants
  alter column display_name set not null;

alter table public.product_variants
  drop constraint if exists product_variants_product_id_color_name_key;

alter table public.product_variants
  add constraint product_variants_product_id_display_name_key
  unique (product_id, display_name);
