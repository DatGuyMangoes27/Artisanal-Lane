import "server-only";

import { redirect } from "next/navigation";

import { createClient } from "@/lib/supabase/server";

import { mapBuyerOrder, type BuyerOrder } from "./orders";

export type BuyerProfile = {
  id: string;
  role: string;
  display_name: string | null;
  email: string | null;
  phone: string | null;
  avatar_url: string | null;
};

const buyerOrderSelect = `
  id,
  buyer_id,
  shop_id,
  status,
  total,
  shipping_cost,
  shipping_method,
  shipping_address,
  tracking_number,
  tracking_url,
  payment_state,
  payment_provider,
  payment_url,
  shipped_at,
  received_at,
  is_gift,
  gift_recipient,
  gift_message,
  created_at,
  updated_at,
  shops(name, slug),
  order_items(id, order_id, product_id, variant_id, variant_name, variant_image, quantity, unit_price, is_made_to_order, custom_note, lead_time_min_days, lead_time_max_days, created_at, products(title, images))
`;

export async function requireBuyerAccountSession(redirectTo: string) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect(`/login?redirect=${encodeURIComponent(redirectTo)}`);
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("id, role, display_name, email, phone, avatar_url")
    .eq("id", user.id)
    .maybeSingle<BuyerProfile>();

  return {
    supabase,
    user,
    profile,
  };
}

export async function listBuyerOrders(userId: string): Promise<BuyerOrder[]> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("orders")
    .select(buyerOrderSelect)
    .eq("buyer_id", userId)
    .order("created_at", { ascending: false });

  if (error) {
    throw new Error("Failed to load buyer orders", { cause: error });
  }

  return ((data ?? []) as Array<Record<string, unknown>>).map(mapBuyerOrder);
}

export async function getBuyerOrder(
  userId: string,
  orderId: string,
): Promise<BuyerOrder | null> {
  const supabase = await createClient();
  const { data, error } = await supabase
    .from("orders")
    .select(buyerOrderSelect)
    .eq("buyer_id", userId)
    .eq("id", orderId)
    .maybeSingle();

  if (error) {
    throw new Error("Failed to load buyer order", { cause: error });
  }

  return data ? mapBuyerOrder(data as Record<string, unknown>) : null;
}
