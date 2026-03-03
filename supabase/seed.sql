-- ============================================================
-- Artisanal Lane - Demo Seed Data
-- ============================================================
-- NOTE: In production, profiles are created via auth.users trigger.
-- For demo, we insert directly. The UUIDs are deterministic for testing.

-- ============================================================
-- 1. Profiles (1 admin, 6 vendors, 1 buyer)
-- ============================================================
insert into profiles (id, role, display_name, email, avatar_url, phone) values
  ('00000000-0000-0000-0000-000000000000', 'admin', 'Platform Admin', 'admin@artisanallane.co.za', 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop', '+27601234567'),
  ('00000000-0000-0000-0000-000000000001', 'buyer', 'Thandi Mokoena', 'thandi@example.com', 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&h=200&fit=crop', '+27721234567'),
  ('00000000-0000-0000-0000-000000000010', 'vendor', 'Sipho Ndlovu', 'sipho@example.com', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&h=200&fit=crop', '+27731234567'),
  ('00000000-0000-0000-0000-000000000011', 'vendor', 'Lerato Khumalo', 'lerato@example.com', 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&h=200&fit=crop', '+27741234567'),
  ('00000000-0000-0000-0000-000000000012', 'vendor', 'Pieter van der Merwe', 'pieter@example.com', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&h=200&fit=crop', '+27751234567'),
  ('00000000-0000-0000-0000-000000000013', 'vendor', 'Amahle Zulu', 'amahle@example.com', 'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=200&h=200&fit=crop', '+27761234567'),
  ('00000000-0000-0000-0000-000000000014', 'vendor', 'Johan Botha', 'johan@example.com', 'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=200&h=200&fit=crop', '+27771234567'),
  ('00000000-0000-0000-0000-000000000015', 'vendor', 'Naledi Mahlangu', 'naledi@example.com', 'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200&h=200&fit=crop', '+27781234567')
on conflict (id) do nothing;

-- ============================================================
-- 2. Categories
-- ============================================================
insert into categories (id, name, slug, icon_url, sort_order) values
  ('c0000000-0000-0000-0000-000000000001', 'Art & Design', 'art-design', null, 1),
  ('c0000000-0000-0000-0000-000000000002', 'Clothing', 'clothing', null, 2),
  ('c0000000-0000-0000-0000-000000000003', 'Beauty', 'beauty', null, 3),
  ('c0000000-0000-0000-0000-000000000004', 'Jewellery', 'jewellery', null, 4),
  ('c0000000-0000-0000-0000-000000000005', 'Home & Living', 'home-living', null, 5),
  ('c0000000-0000-0000-0000-000000000006', 'Baby & Kids', 'baby-kids', null, 6)
on conflict (id) do update set name = excluded.name, slug = excluded.slug, sort_order = excluded.sort_order;

-- ============================================================
-- 3. Invite Codes
-- ============================================================
insert into invite_codes (id, code, created_by, used_by, is_used, used_at) values
  ('i0000000-0000-0000-0000-000000000001', 'ARTISAN2024A', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000010', true, now() - interval '60 days'),
  ('i0000000-0000-0000-0000-000000000002', 'ARTISAN2024B', '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000011', true, now() - interval '45 days'),
  ('i0000000-0000-0000-0000-000000000003', 'CRAFT-WELCOME', '00000000-0000-0000-0000-000000000000', null, false, null)
on conflict (id) do nothing;

-- ============================================================
-- 4. Shops (6 vendors)
-- ============================================================
insert into shops (id, vendor_id, name, slug, bio, brand_story, cover_image_url, logo_url, location, is_active) values
  ('s0000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000010',
   'Ndlovu Ceramics',
   'ndlovu-ceramics',
   'Hand-thrown pottery inspired by the rolling hills of KwaZulu-Natal. Each piece tells a story of tradition meeting modern design.',
   'Sipho learned the art of pottery from his grandmother in a small village outside Durban. After studying fine art at DUT, he returned to his roots to create pieces that bridge traditional Zulu design with contemporary aesthetics. Every item is crafted by hand on his wheel, using locally sourced clay.',
   'https://images.unsplash.com/photo-1565193566173-7a0ee3dbe261?w=800&h=400&fit=crop',
   'https://images.unsplash.com/photo-1493106819501-66d381c466f8?w=200&h=200&fit=crop',
   'Durban, KZN',
   true),

  ('s0000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000011',
   'Khumalo Weaves',
   'khumalo-weaves',
   'Contemporary handwoven textiles rooted in Southern African tradition. Blankets, throws, and tapestries made with love.',
   'Lerato grew up watching her mother weave baskets in rural Limpopo. She trained in textile design in Johannesburg and now creates modern woven pieces that honour her heritage while fitting beautifully in contemporary homes.',
   'https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=800&h=400&fit=crop',
   'https://images.unsplash.com/photo-1594744803329-e58b31de8bf5?w=200&h=200&fit=crop',
   'Johannesburg, GP',
   true),

  ('s0000000-0000-0000-0000-000000000003',
   '00000000-0000-0000-0000-000000000012',
   'Outeniqua Woodcraft',
   'outeniqua-woodcraft',
   'Sustainably sourced hardwood homeware from the Garden Route. Cutting boards, bowls, and furniture crafted with precision.',
   'Pieter has been working with wood since he was sixteen in his father''s workshop in Knysna. He uses only reclaimed or sustainably harvested indigenous wood to create functional art for the kitchen and home.',
   'https://images.unsplash.com/photo-1610701596007-11502861dcfa?w=800&h=400&fit=crop',
   'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200&h=200&fit=crop',
   'Knysna, WC',
   true),

  ('s0000000-0000-0000-0000-000000000004',
   '00000000-0000-0000-0000-000000000013',
   'Zulu Beadwork Studio',
   'zulu-beadwork-studio',
   'Intricate beaded jewellery celebrating Zulu culture. Necklaces, bracelets, and earrings with vibrant patterns.',
   'Amahle is a third-generation beadworker from Nongoma. Her jewellery incorporates traditional Zulu colour symbolism with modern design sensibilities. Each piece takes hours to complete by hand.',
   'https://images.unsplash.com/photo-1535632066927-ab7c9ab60908?w=800&h=400&fit=crop',
   'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?w=200&h=200&fit=crop',
   'Pretoria, GP',
   true),

  ('s0000000-0000-0000-0000-000000000005',
   '00000000-0000-0000-0000-000000000014',
   'Cape Leather Co.',
   'cape-leather-co',
   'Premium handstitched leather goods made in Stellenbosch. Wallets, bags, and belts that age beautifully.',
   'Johan discovered leather-working while traveling through Italy. He brought his skills back to the Cape and now sources local full-grain leather to create timeless accessories. Every stitch is done by hand.',
   'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=800&h=400&fit=crop',
   'https://images.unsplash.com/photo-1560250097-0b93528c311a?w=200&h=200&fit=crop',
   'Stellenbosch, WC',
   true),

  ('s0000000-0000-0000-0000-000000000006',
   '00000000-0000-0000-0000-000000000015',
   'Mahlangu Pottery & Art',
   'mahlangu-pottery-art',
   'Ndebele-inspired pottery and home decor. Bold geometric patterns meet functional design.',
   'Naledi draws inspiration from the famous Ndebele house paintings of Mpumalanga. Her ceramics feature bold, geometric patterns in bright colours, making every piece a conversation starter.',
   'https://images.unsplash.com/photo-1607344645866-009c320b63e0?w=800&h=400&fit=crop',
   'https://images.unsplash.com/photo-1573496359142-b8d87734a5a2?w=200&h=200&fit=crop',
   'Cape Town, WC',
   true)
on conflict (id) do nothing;

-- ============================================================
-- 5. Products (30+ products across 6 shops)
-- ============================================================

-- Ndlovu Ceramics (Ceramics)
insert into products (id, shop_id, category_id, title, description, price, compare_at_price, stock_qty, images, is_published, created_at) values
  ('p0000000-0000-0000-0000-000000000001', 's0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001',
   'Zulu Heritage Vase', 'A stunning hand-thrown vase featuring traditional Zulu patterns in earthy tones. Perfect as a centerpiece or standalone art piece. Height: 30cm.',
   450.00, null, 8,
   '["https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=600&h=600&fit=crop", "https://images.unsplash.com/photo-1565193566173-7a0ee3dbe261?w=600&h=600&fit=crop"]',
   true, now() - interval '30 days'),

  ('p0000000-0000-0000-0000-000000000002', 's0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001',
   'Rustic Stoneware Mug Set', 'Set of 4 handmade stoneware mugs with a beautiful speckled glaze. Microwave and dishwasher safe. 350ml each.',
   320.00, 400.00, 15,
   '["https://images.unsplash.com/photo-1514228742587-6b1558fcca3d?w=600&h=600&fit=crop"]',
   true, now() - interval '25 days'),

  ('p0000000-0000-0000-0000-000000000003', 's0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001',
   'Terracotta Planter - Medium', 'Hand-shaped terracotta planter with drainage hole. Natural unglazed finish that develops character over time. Diameter: 20cm.',
   185.00, null, 22,
   '["https://images.unsplash.com/photo-1485955900006-10f4d324d411?w=600&h=600&fit=crop"]',
   true, now() - interval '20 days'),

  ('p0000000-0000-0000-0000-000000000004', 's0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001',
   'Ceramic Serving Bowl', 'Large serving bowl with a gorgeous blue reactive glaze. Each bowl is unique due to the firing process. Diameter: 28cm.',
   380.00, null, 6,
   '["https://images.unsplash.com/photo-1610701596061-2ecf227e85b2?w=600&h=600&fit=crop"]',
   true, now() - interval '15 days'),

  ('p0000000-0000-0000-0000-000000000005', 's0000000-0000-0000-0000-000000000001', 'c0000000-0000-0000-0000-000000000001',
   'Espresso Cup Duo', 'Pair of elegant espresso cups with saucers. Minimalist design with a warm honey glaze. 80ml each.',
   175.00, 220.00, 18,
   '["https://images.unsplash.com/photo-1572119865084-43c285814d63?w=600&h=600&fit=crop"]',
   true, now() - interval '10 days'),

-- Khumalo Weaves (Textiles)
  ('p0000000-0000-0000-0000-000000000006', 's0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000003',
   'Basotho-Inspired Throw Blanket', 'A luxurious hand-woven throw blanket inspired by Basotho blanket patterns. Made from 100% South African wool. 150cm x 200cm.',
   1250.00, 1500.00, 4,
   '["https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=600&h=600&fit=crop"]',
   true, now() - interval '28 days'),

  ('p0000000-0000-0000-0000-000000000007', 's0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000003',
   'Handwoven Table Runner', 'Vibrant table runner with geometric patterns in ochre and indigo. Cotton blend. 40cm x 180cm.',
   420.00, null, 12,
   '["https://images.unsplash.com/photo-1596040033229-a9821ebd058d?w=600&h=600&fit=crop"]',
   true, now() - interval '22 days'),

  ('p0000000-0000-0000-0000-000000000008', 's0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000003',
   'Woven Cushion Covers (Pair)', 'Set of 2 handwoven cushion covers in complementary earth tones. 100% cotton with zip closure. 45cm x 45cm.',
   350.00, null, 20,
   '["https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?w=600&h=600&fit=crop"]',
   true, now() - interval '18 days'),

  ('p0000000-0000-0000-0000-000000000009', 's0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000003',
   'Wall Tapestry - Sunset', 'Hand-woven wall hanging depicting a South African sunset. Mixed fibres including mohair. 60cm x 80cm.',
   680.00, null, 3,
   '["https://images.unsplash.com/photo-1615529182904-14819c35db37?w=600&h=600&fit=crop"]',
   true, now() - interval '12 days'),

  ('p0000000-0000-0000-0000-000000000010', 's0000000-0000-0000-0000-000000000002', 'c0000000-0000-0000-0000-000000000003',
   'Cotton Placemat Set', 'Set of 6 handwoven cotton placemats with fringe detail. Machine washable. 35cm x 50cm each.',
   280.00, 350.00, 14,
   '["https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=600&h=600&fit=crop"]',
   true, now() - interval '5 days'),

-- Outeniqua Woodcraft (Woodwork)
  ('p0000000-0000-0000-0000-000000000011', 's0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000002',
   'Yellowwood Cutting Board', 'Solid yellowwood cutting board hand-shaped and finished with food-safe oil. Beautiful grain pattern. 40cm x 25cm.',
   520.00, null, 10,
   '["https://images.unsplash.com/photo-1605433247501-698725862cea?w=600&h=600&fit=crop"]',
   true, now() - interval '27 days'),

  ('p0000000-0000-0000-0000-000000000012', 's0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000002',
   'Stinkwood Salad Bowl', 'Hand-turned salad bowl from reclaimed stinkwood. Rich dark grain with food-safe finish. Diameter: 30cm.',
   750.00, 900.00, 5,
   '["https://images.unsplash.com/photo-1610701596061-2ecf227e85b2?w=600&h=600&fit=crop"]',
   true, now() - interval '24 days'),

  ('p0000000-0000-0000-0000-000000000013', 's0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000002',
   'Wooden Serving Spoons (Set of 3)', 'Hand-carved serving spoons from indigenous hardwood. Perfect for salads, pasta, and stews.',
   195.00, null, 25,
   '["https://images.unsplash.com/photo-1590794056226-79ef3a8147e1?w=600&h=600&fit=crop"]',
   true, now() - interval '19 days'),

  ('p0000000-0000-0000-0000-000000000014', 's0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000002',
   'Floating Wall Shelf - Blackwood', 'Minimalist floating shelf crafted from blackwood. Includes hidden mounting bracket. 60cm x 20cm.',
   650.00, null, 7,
   '["https://images.unsplash.com/photo-1532372576444-dda954194ad0?w=600&h=600&fit=crop"]',
   true, now() - interval '14 days'),

  ('p0000000-0000-0000-0000-000000000015', 's0000000-0000-0000-0000-000000000003', 'c0000000-0000-0000-0000-000000000002',
   'Olive Wood Coaster Set', 'Set of 4 coasters hand-turned from olive wood. Natural bark edge detail. Cork-backed. Diameter: 10cm each.',
   165.00, null, 30,
   '["https://images.unsplash.com/photo-1533090161767-e6ffed986c88?w=600&h=600&fit=crop"]',
   true, now() - interval '7 days'),

-- Zulu Beadwork Studio (Jewellery)
  ('p0000000-0000-0000-0000-000000000016', 's0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000004',
   'Zulu Love Letter Necklace', 'Traditional beaded necklace encoding a Zulu love message. Glass seed beads on nylon thread. Adjustable length.',
   280.00, null, 15,
   '["https://images.unsplash.com/photo-1535632066927-ab7c9ab60908?w=600&h=600&fit=crop"]',
   true, now() - interval '26 days'),

  ('p0000000-0000-0000-0000-000000000017', 's0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000004',
   'Beaded Cuff Bracelet', 'Wide beaded cuff bracelet with bold geometric patterns. Colours represent earth, sky, and fertility. One size.',
   195.00, 250.00, 20,
   '["https://images.unsplash.com/photo-1573408301185-9146fe634ad0?w=600&h=600&fit=crop"]',
   true, now() - interval '23 days'),

  ('p0000000-0000-0000-0000-000000000018', 's0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000004',
   'Chandelier Earrings', 'Statement beaded earrings with cascading fringe detail. Lightweight despite their size. Length: 8cm.',
   145.00, null, 25,
   '["https://images.unsplash.com/photo-1630019852942-f89202989a59?w=600&h=600&fit=crop"]',
   true, now() - interval '16 days'),

  ('p0000000-0000-0000-0000-000000000019', 's0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000004',
   'Beaded Collar Necklace', 'Stunning collar necklace featuring concentric circles of colourful beadwork. A true statement piece.',
   420.00, null, 6,
   '["https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=600&h=600&fit=crop"]',
   true, now() - interval '11 days'),

  ('p0000000-0000-0000-0000-000000000020', 's0000000-0000-0000-0000-000000000004', 'c0000000-0000-0000-0000-000000000004',
   'Anklet with Bells', 'Delicate beaded anklet with tiny brass bells. Traditional design with a playful modern twist.',
   95.00, null, 35,
   '["https://images.unsplash.com/photo-1611591437281-460bfbe1220a?w=600&h=600&fit=crop"]',
   true, now() - interval '3 days'),

-- Cape Leather Co. (Leather Goods)
  ('p0000000-0000-0000-0000-000000000021', 's0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000005',
   'Classic Bifold Wallet', 'Full-grain leather bifold wallet with 6 card slots and a coin pocket. Hand-stitched with waxed thread. Colour: Tan.',
   550.00, null, 12,
   '["https://images.unsplash.com/photo-1627123424574-724758594e93?w=600&h=600&fit=crop"]',
   true, now() - interval '29 days'),

  ('p0000000-0000-0000-0000-000000000022', 's0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000005',
   'Leather Tote Bag', 'Spacious tote bag in full-grain leather. Unlined for a natural look. Interior pocket for phone. Handles with 25cm drop.',
   1450.00, 1800.00, 3,
   '["https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=600&h=600&fit=crop"]',
   true, now() - interval '21 days'),

  ('p0000000-0000-0000-0000-000000000023', 's0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000005',
   'Braided Leather Belt', 'Hand-braided leather belt with solid brass buckle. Will develop a beautiful patina with wear. Width: 3.5cm.',
   380.00, null, 18,
   '["https://images.unsplash.com/photo-1553062407-98eeb64c6a62?w=600&h=600&fit=crop"]',
   true, now() - interval '17 days'),

  ('p0000000-0000-0000-0000-000000000024', 's0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000005',
   'Leather Journal Cover', 'Refillable journal cover in soft full-grain leather. Fits A5 notebooks. Pen loop included.',
   320.00, null, 14,
   '["https://images.unsplash.com/photo-1544816155-12df9643f363?w=600&h=600&fit=crop"]',
   true, now() - interval '9 days'),

  ('p0000000-0000-0000-0000-000000000025', 's0000000-0000-0000-0000-000000000005', 'c0000000-0000-0000-0000-000000000005',
   'Key Organiser', 'Compact leather key holder that keeps keys tidy and silent. Holds up to 7 keys. Brass hardware.',
   145.00, 180.00, 28,
   '["https://images.unsplash.com/photo-1523293182086-7651a899d37f?w=600&h=600&fit=crop"]',
   true, now() - interval '2 days'),

-- Mahlangu Pottery & Art (Ceramics)
  ('p0000000-0000-0000-0000-000000000026', 's0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000001',
   'Ndebele Pattern Vase', 'Bold geometric Ndebele-style vase in bright primary colours. A stunning focal point for any room. Height: 25cm.',
   520.00, null, 6,
   '["https://images.unsplash.com/photo-1607344645866-009c320b63e0?w=600&h=600&fit=crop"]',
   true, now() - interval '26 days'),

  ('p0000000-0000-0000-0000-000000000027', 's0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000001',
   'Painted Dinner Plate Set', 'Set of 4 hand-painted dinner plates with Ndebele-inspired borders. Food safe. Diameter: 27cm each.',
   480.00, 600.00, 8,
   '["https://images.unsplash.com/photo-1603199506016-b9a694b3ecb7?w=600&h=600&fit=crop"]',
   true, now() - interval '20 days'),

  ('p0000000-0000-0000-0000-000000000028', 's0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000001',
   'Decorative Wall Plate', 'Hand-painted decorative plate for wall display. Comes with wall mount. Diameter: 35cm.',
   350.00, null, 10,
   '["https://images.unsplash.com/photo-1610701596007-11502861dcfa?w=600&h=600&fit=crop"]',
   true, now() - interval '13 days'),

  ('p0000000-0000-0000-0000-000000000029', 's0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000001',
   'Geometric Mug', 'Hand-painted mug with bold triangular patterns in black, white, and gold. 300ml capacity.',
   125.00, null, 30,
   '["https://images.unsplash.com/photo-1556909114-f6e7ad7d3136?w=600&h=600&fit=crop"]',
   true, now() - interval '6 days'),

  ('p0000000-0000-0000-0000-000000000030', 's0000000-0000-0000-0000-000000000006', 'c0000000-0000-0000-0000-000000000001',
   'Candle Holder Trio', 'Set of 3 ceramic candle holders in graduating sizes with Ndebele patterns. For taper candles.',
   275.00, null, 12,
   '["https://images.unsplash.com/photo-1602028915047-37269d1a73f7?w=600&h=600&fit=crop"]',
   true, now() - interval '1 day')
on conflict (id) do nothing;

-- ============================================================
-- 6. Favourites (buyer has 3 favourites)
-- ============================================================
insert into favourites (user_id, product_id) values
  ('00000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000016'),
  ('00000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000022')
on conflict (user_id, product_id) do nothing;

-- ============================================================
-- 7. Cart (buyer has 3 items in cart)
-- ============================================================
insert into carts (id, user_id) values
  ('cart0000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001')
on conflict (id) do nothing;

insert into cart_items (id, cart_id, product_id, quantity) values
  ('ci000000-0000-0000-0000-000000000001', 'cart0000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000002', 1),
  ('ci000000-0000-0000-0000-000000000002', 'cart0000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000011', 2),
  ('ci000000-0000-0000-0000-000000000003', 'cart0000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000020', 3)
on conflict (id) do nothing;

-- ============================================================
-- 8. Orders (5 orders in various statuses)
-- ============================================================
insert into orders (id, buyer_id, shop_id, status, total, shipping_cost, shipping_method, shipping_address, tracking_number, created_at) values
  ('o0000000-0000-0000-0000-000000000001',
   '00000000-0000-0000-0000-000000000001',
   's0000000-0000-0000-0000-000000000001',
   'completed', 770.00, 85.00, 'courier_guy',
   '{"street": "42 Long Street", "city": "Cape Town", "province": "Western Cape", "postal_code": "8001"}',
   'TCG-SA-20240101',
   now() - interval '45 days'),

  ('o0000000-0000-0000-0000-000000000002',
   '00000000-0000-0000-0000-000000000001',
   's0000000-0000-0000-0000-000000000004',
   'delivered', 475.00, 65.00, 'pargo',
   '{"street": "15 Bree Street", "city": "Cape Town", "province": "Western Cape", "postal_code": "8001"}',
   'PRG-20240215',
   now() - interval '20 days'),

  ('o0000000-0000-0000-0000-000000000003',
   '00000000-0000-0000-0000-000000000001',
   's0000000-0000-0000-0000-000000000005',
   'shipped', 930.00, 99.00, 'courier_guy',
   '{"street": "42 Long Street", "city": "Cape Town", "province": "Western Cape", "postal_code": "8001"}',
   'TCG-SA-20240301',
   now() - interval '7 days'),

  ('o0000000-0000-0000-0000-000000000004',
   '00000000-0000-0000-0000-000000000001',
   's0000000-0000-0000-0000-000000000002',
   'paid', 700.00, 45.00, 'paxi',
   '{"street": "42 Long Street", "city": "Cape Town", "province": "Western Cape", "postal_code": "8001"}',
   null,
   now() - interval '3 days'),

  ('o0000000-0000-0000-0000-000000000005',
   '00000000-0000-0000-0000-000000000001',
   's0000000-0000-0000-0000-000000000003',
   'disputed', 750.00, 85.00, 'courier_guy',
   '{"street": "42 Long Street", "city": "Cape Town", "province": "Western Cape", "postal_code": "8001"}',
   'TCG-SA-20240115',
   now() - interval '30 days')
on conflict (id) do nothing;

-- ============================================================
-- 9. Order Items
-- ============================================================
insert into order_items (id, order_id, product_id, quantity, unit_price) values
  ('oi000000-0000-0000-0000-000000000001', 'o0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000001', 1, 450.00),
  ('oi000000-0000-0000-0000-000000000002', 'o0000000-0000-0000-0000-000000000001', 'p0000000-0000-0000-0000-000000000002', 1, 320.00),
  ('oi000000-0000-0000-0000-000000000003', 'o0000000-0000-0000-0000-000000000002', 'p0000000-0000-0000-0000-000000000016', 1, 280.00),
  ('oi000000-0000-0000-0000-000000000004', 'o0000000-0000-0000-0000-000000000002', 'p0000000-0000-0000-0000-000000000017', 1, 195.00),
  ('oi000000-0000-0000-0000-000000000005', 'o0000000-0000-0000-0000-000000000003', 'p0000000-0000-0000-0000-000000000021', 1, 550.00),
  ('oi000000-0000-0000-0000-000000000006', 'o0000000-0000-0000-0000-000000000003', 'p0000000-0000-0000-0000-000000000023', 1, 380.00),
  ('oi000000-0000-0000-0000-000000000007', 'o0000000-0000-0000-0000-000000000004', 'p0000000-0000-0000-0000-000000000007', 1, 420.00),
  ('oi000000-0000-0000-0000-000000000008', 'o0000000-0000-0000-0000-000000000004', 'p0000000-0000-0000-0000-000000000010', 1, 280.00),
  ('oi000000-0000-0000-0000-000000000009', 'o0000000-0000-0000-0000-000000000005', 'p0000000-0000-0000-0000-000000000012', 1, 750.00)
on conflict (id) do nothing;

-- ============================================================
-- 10. Escrow Transactions
-- ============================================================
insert into escrow_transactions (id, order_id, payfast_payment_id, amount, platform_fee, status, released_at) values
  ('e0000000-0000-0000-0000-000000000001', 'o0000000-0000-0000-0000-000000000001', 'PF-1234567890', 855.00, 42.75, 'released', now() - interval '30 days'),
  ('e0000000-0000-0000-0000-000000000002', 'o0000000-0000-0000-0000-000000000002', 'PF-1234567891', 540.00, 27.00, 'held', null),
  ('e0000000-0000-0000-0000-000000000003', 'o0000000-0000-0000-0000-000000000003', 'PF-1234567892', 1029.00, 51.45, 'held', null)
on conflict (id) do nothing;

-- ============================================================
-- 11. Disputes
-- ============================================================
insert into disputes (id, order_id, raised_by, reason, status, resolution, resolved_by, resolved_at) values
  ('d0000000-0000-0000-0000-000000000001',
   'o0000000-0000-0000-0000-000000000005',
   '00000000-0000-0000-0000-000000000001',
   'Item arrived damaged - the salad bowl had a crack along the rim. Photos attached in correspondence.',
   'open', null, null, null)
on conflict (id) do nothing;
