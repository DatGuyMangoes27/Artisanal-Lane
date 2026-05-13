"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";

import { getLatestEligibleProductReviewContext } from "@/lib/marketplace/review-data";
import { normalizeReviewRating, sanitizeReviewText } from "@/lib/marketplace/reviews";
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

export async function submitProductReview(formData: FormData) {
  const productId = String(formData.get("productId") ?? "").trim();
  const redirectTo = String(formData.get("redirectTo") ?? `/products/${productId}`);
  const { supabase, user } = await requireUser(redirectTo);

  if (!productId) {
    redirect(redirectTo);
  }

  const reviewContext = await getLatestEligibleProductReviewContext(user.id, productId);
  if (!reviewContext) {
    redirect(redirectTo);
  }

  const { data: product } = await supabase
    .from("products")
    .select("shop_id")
    .eq("id", productId)
    .single();
  const productRow = product as { shop_id?: string } | null;

  if (!productRow?.shop_id) {
    redirect(redirectTo);
  }

  const payload = {
    product_id: productId,
    shop_id: productRow.shop_id,
    buyer_id: user.id,
    order_id: reviewContext.orderId,
    order_item_id: reviewContext.orderItemId,
    rating: normalizeReviewRating(formData.get("rating")),
    review_text: sanitizeReviewText(formData.get("reviewText")),
  };

  const { data: existing } = await supabase
    .from("product_reviews")
    .select("id")
    .eq("product_id", productId)
    .eq("buyer_id", user.id)
    .maybeSingle();
  const existingReview = existing as { id?: string } | null;

  if (existingReview?.id) {
    await supabase.from("product_reviews").update(payload).eq("id", existingReview.id);
  } else {
    await supabase.from("product_reviews").insert(payload);
  }

  revalidatePath(`/products/${productId}`);
  revalidatePath(redirectTo);
  redirect(redirectTo);
}
