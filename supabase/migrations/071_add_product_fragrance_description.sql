-- Optional fragrance description for scented products (candles, soaps,
-- creams, ...). Vendors describe the fragrances they offer; the text is
-- shown on the product page.
alter table public.products
  add column if not exists fragrance_description text;
