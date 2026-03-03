-- Add delivery fulfilment and turnaround time fields to vendor_applications
ALTER TABLE vendor_applications ADD COLUMN IF NOT EXISTS delivery_info text;
ALTER TABLE vendor_applications ADD COLUMN IF NOT EXISTS turnaround_time text;
