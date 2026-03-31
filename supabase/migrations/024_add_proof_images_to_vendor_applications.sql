-- Add proof images for vendor applications when no social link is available
alter table public.vendor_applications
  add column if not exists proof_image_urls jsonb not null default '[]'::jsonb;
