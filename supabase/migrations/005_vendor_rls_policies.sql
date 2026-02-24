-- ============================================================
-- Vendor-specific RLS policies
-- Vendors can manage their own shop, products, orders, and posts
-- ============================================================

-- Vendors can update their own shop
CREATE POLICY "vendor_update_own_shop" ON shops FOR UPDATE
  USING (vendor_id = auth.uid());

-- Vendors can manage products in their shop
CREATE POLICY "vendor_insert_products" ON products FOR INSERT
  WITH CHECK (shop_id IN (SELECT id FROM shops WHERE vendor_id = auth.uid()));

CREATE POLICY "vendor_update_products" ON products FOR UPDATE
  USING (shop_id IN (SELECT id FROM shops WHERE vendor_id = auth.uid()));

CREATE POLICY "vendor_delete_products" ON products FOR DELETE
  USING (shop_id IN (SELECT id FROM shops WHERE vendor_id = auth.uid()));

-- Vendors can view all products in their shop (incl. unpublished)
CREATE POLICY "vendor_select_own_products" ON products FOR SELECT
  USING (shop_id IN (SELECT id FROM shops WHERE vendor_id = auth.uid()));

-- Vendors can view orders for their shop
CREATE POLICY "vendor_select_shop_orders" ON orders FOR SELECT
  USING (shop_id IN (SELECT id FROM shops WHERE vendor_id = auth.uid()));

-- Vendors can update orders for their shop (mark shipped, etc.)
CREATE POLICY "vendor_update_shop_orders" ON orders FOR UPDATE
  USING (shop_id IN (SELECT id FROM shops WHERE vendor_id = auth.uid()));

-- Vendors can view order items for their orders
CREATE POLICY "vendor_select_order_items" ON order_items FOR SELECT
  USING (order_id IN (SELECT id FROM orders WHERE shop_id IN (SELECT id FROM shops WHERE vendor_id = auth.uid())));

-- Vendors can view escrow for their orders
CREATE POLICY "vendor_select_escrow" ON escrow_transactions FOR SELECT
  USING (order_id IN (SELECT id FROM orders WHERE shop_id IN (SELECT id FROM shops WHERE vendor_id = auth.uid())));

-- Vendors can manage their shop posts
CREATE POLICY "vendor_insert_posts" ON shop_posts FOR INSERT
  WITH CHECK (shop_id IN (SELECT id FROM shops WHERE vendor_id = auth.uid()));

CREATE POLICY "vendor_update_posts" ON shop_posts FOR UPDATE
  USING (shop_id IN (SELECT id FROM shops WHERE vendor_id = auth.uid()));

CREATE POLICY "vendor_delete_posts" ON shop_posts FOR DELETE
  USING (shop_id IN (SELECT id FROM shops WHERE vendor_id = auth.uid()));

-- Vendor applications: users can view and insert their own
CREATE POLICY "users_view_own_application" ON vendor_applications FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "users_insert_application" ON vendor_applications FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Invite codes: allow select to check validity, allow update to mark used
CREATE POLICY "users_select_invite_codes" ON invite_codes FOR SELECT
  USING (true);

CREATE POLICY "users_update_invite_codes" ON invite_codes FOR UPDATE
  USING (true);
