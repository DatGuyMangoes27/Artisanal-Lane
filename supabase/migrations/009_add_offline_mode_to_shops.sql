-- Add out-of-office / offline mode fields to shops
ALTER TABLE shops ADD COLUMN IF NOT EXISTS is_offline boolean NOT NULL DEFAULT false;
ALTER TABLE shops ADD COLUMN IF NOT EXISTS back_to_work_date date;
