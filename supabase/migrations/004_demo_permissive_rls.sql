-- ============================================================
-- Demo-mode permissive RLS policies
-- Allows unauthenticated access for development/demo purposes.
-- Remove these policies when real authentication is implemented.
-- ============================================================

-- Profiles: allow all operations for demo
CREATE POLICY "demo_profiles_all" ON profiles FOR ALL USING (true) WITH CHECK (true);

-- Favourites: allow all for demo
CREATE POLICY "demo_favourites_all" ON favourites FOR ALL USING (true) WITH CHECK (true);

-- Carts: allow all for demo
CREATE POLICY "demo_carts_all" ON carts FOR ALL USING (true) WITH CHECK (true);

-- Cart Items: allow all for demo
CREATE POLICY "demo_cart_items_all" ON cart_items FOR ALL USING (true) WITH CHECK (true);

-- Orders: allow all for demo
CREATE POLICY "demo_orders_all" ON orders FOR ALL USING (true) WITH CHECK (true);

-- Order Items: allow all for demo
CREATE POLICY "demo_order_items_all" ON order_items FOR ALL USING (true) WITH CHECK (true);

-- Escrow Transactions: allow all for demo
CREATE POLICY "demo_escrow_all" ON escrow_transactions FOR ALL USING (true) WITH CHECK (true);

-- Disputes: allow all for demo
CREATE POLICY "demo_disputes_all" ON disputes FOR ALL USING (true) WITH CHECK (true);

-- Shop Follows: allow all for demo
CREATE POLICY "demo_shop_follows_all" ON shop_follows FOR ALL USING (true) WITH CHECK (true);

-- Shop Posts: allow select for demo
CREATE POLICY "demo_shop_posts_select" ON shop_posts FOR SELECT USING (true);
