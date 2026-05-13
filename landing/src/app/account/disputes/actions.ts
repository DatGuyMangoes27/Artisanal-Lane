"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { canOpenDisputeForOrderStatus, sanitizeDisputeReason } from "@/lib/marketplace/disputes";
import { createClient } from "@/lib/supabase/server";

async function requireUser(redirectTo: string) {
  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    redirect(`/login?redirect=${encodeURIComponent(redirectTo)}`);
  }

  return { supabase, user };
}

export async function openBuyerDispute(formData: FormData) {
  const orderId = String(formData.get("orderId") ?? "").trim();
  const redirectTo = String(formData.get("redirectTo") ?? `/account/orders/${orderId}`);
  const reason = sanitizeDisputeReason(formData.get("reason"));
  const { supabase, user } = await requireUser(redirectTo);

  if (!orderId || !reason) {
    redirect(redirectTo);
  }

  const { data: order } = await supabase
    .from("orders")
    .select("id, buyer_id, status")
    .eq("id", orderId)
    .eq("buyer_id", user.id)
    .single();
  const orderRow = order as { id?: string; status?: string } | null;

  if (!orderRow?.id || !canOpenDisputeForOrderStatus(orderRow.status)) {
    redirect(redirectTo);
  }

  const { error } = await supabase.functions.invoke("open-dispute", {
    body: {
      orderId,
      userId: user.id,
      reason,
    },
  });

  if (error) {
    throw new Error(error.message);
  }

  revalidatePath("/account/orders");
  revalidatePath(redirectTo);
  redirect(redirectTo);
}
