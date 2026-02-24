-- ============================================================
-- Artisanal Lane - Addresses support
-- ============================================================

-- Add shipping_addresses JSONB column to profiles
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS shipping_addresses jsonb DEFAULT '[]'::jsonb;
