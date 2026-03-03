-- ============================================================
-- Artisanal Lane - Per-shop shipping options
-- ============================================================
-- Each shop stores a JSONB array of shipping options.
-- Vendors can enable/disable each method and set their own price.
-- The checkout screen reads this array instead of using hardcoded values.

alter table shops add column if not exists shipping_options jsonb not null default '[
  {"key": "courier_guy",   "enabled": true,  "price": 99.00},
  {"key": "pargo",         "enabled": true,  "price": 65.00},
  {"key": "paxi",          "enabled": true,  "price": 45.00},
  {"key": "market_pickup", "enabled": true,  "price": 0.00}
]'::jsonb;
