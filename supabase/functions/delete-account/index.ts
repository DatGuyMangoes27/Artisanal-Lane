import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse } from "../_shared/http.ts";
import { cancelPayFastSubscription } from "../_shared/payfast.ts";
import {
  getPayFastCancellationToken,
  hasPayFastBillingReference,
} from "../_shared/subscription-cancellation.mjs";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const activeOrderStatuses = [
  "pending",
  "paid",
  "shipped",
  "delivered",
  "disputed",
];

type AdminClient = ReturnType<typeof createClient<any, any, any>>;

async function collectStorageFiles(
  admin: AdminClient,
  bucket: string,
  prefix: string,
): Promise<string[]> {
  const paths: string[] = [];
  let offset = 0;
  const limit = 100;

  while (true) {
    const { data, error } = await admin.storage.from(bucket).list(prefix, {
      limit,
      offset,
      sortBy: { column: "name", order: "asc" },
    });

    if (error != null) {
      throw new Error(`Could not list ${bucket} files.`, { cause: error });
    }

    for (const item of data ?? []) {
      const path = prefix.length > 0 ? `${prefix}/${item.name}` : item.name;
      if (item.id == null) {
        paths.push(...await collectStorageFiles(admin, bucket, path));
      } else {
        paths.push(path);
      }
    }

    if ((data?.length ?? 0) < limit) break;
    offset += limit;
  }

  return paths;
}

async function removeStoragePaths(
  admin: AdminClient,
  bucket: string,
  paths: string[],
) {
  const uniquePaths = [...new Set(paths.filter((path) => path.length > 0))];
  for (let index = 0; index < uniquePaths.length; index += 100) {
    const { error } = await admin.storage
      .from(bucket)
      .remove(uniquePaths.slice(index, index + 100));
    if (error != null) {
      throw new Error(`Could not remove ${bucket} files.`, { cause: error });
    }
  }
}

async function removeUserStorage(admin: AdminClient, userId: string) {
  const [
    avatarPaths,
    productImagePaths,
    shopAssetPaths,
    chatResult,
    disputeResult,
  ] = await Promise.all([
    collectStorageFiles(admin, "avatars", userId),
    collectStorageFiles(admin, "product-images", userId),
    collectStorageFiles(admin, "shop-assets", userId),
    admin
      .from("chat_messages")
      .select("attachment_path")
      .eq("sender_id", userId)
      .not("attachment_path", "is", null),
    admin
      .from("dispute_conversation_messages")
      .select("attachment_path")
      .eq("sender_id", userId)
      .not("attachment_path", "is", null),
  ]);

  if (chatResult.error != null || disputeResult.error != null) {
    throw new Error("Could not load account attachments.", {
      cause: chatResult.error ?? disputeResult.error,
    });
  }

  await removeStoragePaths(admin, "avatars", avatarPaths);
  await removeStoragePaths(admin, "product-images", productImagePaths);
  await removeStoragePaths(admin, "shop-assets", shopAssetPaths);
  await removeStoragePaths(
    admin,
    "chat-attachments",
    (chatResult.data ?? [])
      .map((row) => row.attachment_path)
      .filter((path): path is string => typeof path === "string"),
  );
  await removeStoragePaths(
    admin,
    "dispute-attachments",
    (disputeResult.data ?? [])
      .map((row) => row.attachment_path)
      .filter((path): path is string => typeof path === "string"),
  );
}

Deno.serve(async (request) => {
  try {
    const jwt = getBearerToken(request);
    const client = createClient(supabaseUrl, supabaseAnonKey, {
      global: {
        headers: {
          Authorization: `Bearer ${jwt}`,
        },
      },
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const {
      data: { user },
      error: authError,
    } = await client.auth.getUser();

    if (authError != null || user?.id == null) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    const { data: profile, error: profileError } = await admin
      .from("profiles")
      .select("id, role, display_name, email")
      .eq("id", user.id)
      .single();

    if (profileError != null || profile == null) {
      return jsonResponse(
        { error: "Could not load your account details." },
        { status: 404 },
      );
    }

    if (profile.role === "admin") {
      return jsonResponse(
        { error: "Admin accounts cannot be deleted from the app." },
        { status: 403 },
      );
    }

    const { count: activeBuyerOrderCount, error: buyerOrderCountError } =
      await admin
        .from("orders")
        .select("id", { count: "exact", head: true })
        .eq("buyer_id", user.id)
        .in("status", activeOrderStatuses);

    if (buyerOrderCountError != null) {
      return jsonResponse(
        { error: "Could not verify your active orders." },
        { status: 500 },
      );
    }

    if ((activeBuyerOrderCount ?? 0) > 0) {
      return jsonResponse(
        {
          error:
            "You still have active orders. Please complete or resolve them before deleting your account.",
        },
        { status: 409 },
      );
    }

    if (profile.role === "vendor") {
      const { data: shop, error: shopError } = await admin
        .from("shops")
        .select("id")
        .eq("vendor_id", user.id)
        .maybeSingle();

      if (shopError != null) {
        return jsonResponse(
          { error: "Could not verify your shop details." },
          { status: 500 },
        );
      }

      if (shop?.id != null) {
        const { count: activeOrderCount, error: orderCountError } = await admin
          .from("orders")
          .select("id", { count: "exact", head: true })
          .eq("shop_id", shop.id)
          .in("status", activeOrderStatuses);

        if (orderCountError != null) {
          return jsonResponse(
            { error: "Could not verify your active orders." },
            { status: 500 },
          );
        }

        if ((activeOrderCount ?? 0) > 0) {
          return jsonResponse(
            {
              error:
                "You still have active orders. Please complete or resolve them before deleting your vendor account.",
            },
            { status: 409 },
          );
        }
      }
    }

    const { data: subscription, error: subscriptionError } = await admin
      .from("vendor_subscriptions")
      .select(
        "status, payfast_token, payfast_subscription_id, payfast_payment_id, checkout_reference",
      )
      .eq("vendor_id", user.id)
      .maybeSingle();

    if (subscriptionError != null) {
      return jsonResponse(
        { error: "Could not verify your subscription status." },
        { status: 500 },
      );
    }

    if (subscription != null) {
      const token = getPayFastCancellationToken(subscription);
      const statusMayStillBill = ["active", "past_due"].includes(
        subscription.status,
      );
      const hasPayFastReference = hasPayFastBillingReference(subscription);

      if (token == null && statusMayStillBill && hasPayFastReference) {
        console.error("delete-account: PayFast token is missing", {
          userId: user.id,
          subscriptionStatus: subscription.status,
        });
        return jsonResponse(
          {
            error:
              "We could not verify your PayFast subscription token, so your account was not deleted. Please contact support.",
          },
          { status: 409 },
        );
      }

      if (token == null && statusMayStillBill && !hasPayFastReference) {
        console.log(
          "delete-account: complimentary subscription has no PayFast billing agreement",
          {
            userId: user.id,
            subscriptionStatus: subscription.status,
          },
        );
      }

      if (token != null && subscription.status !== "cancelled") {
        const cancelResult = await cancelPayFastSubscription(token);
        if (!cancelResult.ok) {
          return jsonResponse(
            {
              error:
                "Your subscription could not be cancelled right now, so your account was not deleted. Please try again shortly.",
            },
            { status: 502 },
          );
        }

        const { error: cancellationUpdateError } = await admin
          .from("vendor_subscriptions")
          .update({
            status: "cancelled",
            cancelled_at: new Date().toISOString(),
            status_reason:
              "PayFast cancellation confirmed during account deletion.",
          })
          .eq("vendor_id", user.id);

        if (cancellationUpdateError != null) {
          return jsonResponse(
            {
              error:
                "PayFast cancelled your subscription, but Artisan Lane could not save the update. Your account was not deleted; please contact support.",
            },
            { status: 500 },
          );
        }
      }
    }

    try {
      await removeUserStorage(admin, user.id);
    } catch (error) {
      console.error("delete-account storage cleanup failed", {
        userId: user.id,
        message: error instanceof Error ? error.message : String(error),
      });
      return jsonResponse(
        {
          error:
            "Your account files could not be removed, so your account was not deleted. Please try again or contact support.",
        },
        { status: 500 },
      );
    }

    const deletedAt = new Date().toISOString();
    const { error: applicationSnapshotError } = await admin
      .from("vendor_applications")
      .update({
        applicant_user_id_snapshot: user.id,
        applicant_display_name_snapshot: profile.display_name,
        applicant_email_snapshot: profile.email,
        applicant_account_deleted_at: deletedAt,
      })
      .eq("user_id", user.id);

    if (applicationSnapshotError != null) {
      return jsonResponse(
        { error: "Could not preserve your application history." },
        { status: 500 },
      );
    }

    const { error: deleteError } = await admin.auth.admin.deleteUser(user.id);
    if (deleteError != null) {
      return jsonResponse(
        {
          error: deleteError.message || "Could not delete your account.",
        },
        { status: 500 },
      );
    }

    return jsonResponse({
      success: true,
      role: profile.role,
      message: "Your account has been deleted.",
    });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : "Could not delete your account.",
      },
      { status: 500 },
    );
  }
});
