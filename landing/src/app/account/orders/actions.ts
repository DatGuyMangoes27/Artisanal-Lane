"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { canConfirmReceipt } from "@/lib/marketplace/orders";
import { createClient } from "@/lib/supabase/server";

export async function confirmBuyerOrderReceipt(formData: FormData) {
  const orderId = String(formData.get("orderId") ?? "").trim();
  const redirectTo = String(formData.get("redirectTo") ?? `/account/orders/${orderId}`);
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect(`/login?redirect=${encodeURIComponent(redirectTo)}`);
  }

  if (!orderId) {
    redirect(redirectTo);
  }

  const { data: order } = await supabase
    .from("orders")
    .select("id, buyer_id, status, received_at")
    .eq("id", orderId)
    .eq("buyer_id", user.id)
    .single();
  const orderRow = order as { id?: string; status?: string; received_at?: string | null } | null;

  if (!orderRow?.id || !canConfirmReceipt({ status: orderRow.status ?? "", receivedAt: orderRow.received_at ?? null })) {
    redirect(redirectTo);
  }

  const { error } = await supabase.functions.invoke("release-escrow", {
    body: {
      orderId,
      userId: user.id,
    },
  });

  if (error) {
    throw new Error(error.message);
  }

  revalidatePath("/account");
  revalidatePath("/account/orders");
  revalidatePath(redirectTo);
  redirect(redirectTo);
}
