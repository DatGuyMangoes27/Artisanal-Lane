-- Allow authenticated users to insert a shop where they are the vendor
CREATE POLICY "vendor_insert_own_shop" ON shops FOR INSERT
  WITH CHECK (vendor_id = auth.uid());

-- Demo permissive policy for shops (matches other demo policies)
CREATE POLICY "demo_shops_all" ON shops FOR ALL
  USING (true) WITH CHECK (true);
