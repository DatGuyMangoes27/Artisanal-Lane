import { createClient } from "npm:@supabase/supabase-js@2";

import { getBearerToken, jsonResponse, optionsResponse } from "../_shared/http.ts";
import {
  getFirebaseAccessToken,
  parseFirebaseServiceAccount,
  type PushPayload,
  sendFirebasePush,
} from "../_shared/push.ts";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

type AdminClient = ReturnType<typeof createClient<any, any, any>>;

const audienceTypes = [
  "user",
  "all_vendors",
  "all_buyers",
  "subscribed_vendors",
  "vendors_without_shop",
] as const;

type AudienceType = (typeof audienceTypes)[number];

const pageSize = 1000;
const insertChunkSize = 500;
const tokenChunkSize = 200;

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return optionsResponse();
  }

  try {
    const body = await request.json();
    const title = typeof body.title === "string" ? body.title.trim() : "";
    const message = typeof body.body === "string" ? body.body.trim() : "";
    const route = typeof body.route === "string" ? body.route.trim() : "";
    const audience = String(body.audience ?? "");
    const userId = typeof body.userId === "string" ? body.userId.trim() : "";

    if (!title || !message || !isAudienceType(audience)) {
      return jsonResponse({ error: "Unsupported broadcast push request." }, {
        status: 400,
      });
    }

    if (audience === "user" && !userId) {
      return jsonResponse({ error: "A target user id is required." }, {
        status: 400,
      });
    }

    if (route.length > 0 && !route.startsWith("/")) {
      return jsonResponse({ error: "Route must start with '/'." }, {
        status: 400,
      });
    }

    const jwt = getBearerToken(request);
    const isServiceRequest = jwt === supabaseServiceRoleKey ||
      getJwtRole(jwt) === "service_role";

    const admin = createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    if (!isServiceRequest && !(await isAdminCaller(admin, jwt))) {
      return jsonResponse({ error: "Unauthorized" }, { status: 401 });
    }

    const firebaseServiceAccountRaw = Deno.env.get(
      "FIREBASE_SERVICE_ACCOUNT_JSON",
    );
    if (!firebaseServiceAccountRaw) {
      throw new Error("Missing FIREBASE_SERVICE_ACCOUNT_JSON secret.");
    }

    const recipientIds = await resolveAudience(admin, audience, userId);
    if (recipientIds.length === 0) {
      return jsonResponse({
        ok: true,
        recipients: 0,
        sent: 0,
        failed: 0,
      });
    }

    const broadcastId = crypto.randomUUID();
    const payload: PushPayload = {
      title,
      body: message,
      data: {
        type: "admin_broadcast",
        broadcast_id: broadcastId,
        ...(route.length > 0 ? { route } : {}),
      },
    };

    await storeNotifications(admin, recipientIds, payload, broadcastId);

    const firebaseServiceAccount = parseFirebaseServiceAccount(
      firebaseServiceAccountRaw,
    );
    const accessToken = await getFirebaseAccessToken(firebaseServiceAccount);

    let sent = 0;
    let failed = 0;
    for (
      let index = 0;
      index < recipientIds.length;
      index += tokenChunkSize
    ) {
      const chunk = recipientIds.slice(index, index + tokenChunkSize);
      const { data: tokens } = await admin
        .from("user_push_tokens")
        .select("id, token")
        .in("user_id", chunk)
        .is("revoked_at", null);

      for (const tokenRow of tokens ?? []) {
        const result = await sendFirebasePush({
          accessToken,
          projectId: firebaseServiceAccount.project_id,
          token: tokenRow.token as string,
          payload,
        });

        if (result.ok) {
          sent += 1;
        } else {
          failed += 1;
          if (result.status === 404 || result.status === 400) {
            await admin
              .from("user_push_tokens")
              .update({ revoked_at: new Date().toISOString() })
              .eq("id", tokenRow.id);
          }
        }
      }
    }

    return jsonResponse({
      ok: true,
      recipients: recipientIds.length,
      sent,
      failed,
    });
  } catch (error) {
    return jsonResponse(
      {
        error: error instanceof Error
          ? error.message
          : "Unable to send broadcast push notification.",
      },
      { status: 500 },
    );
  }
});

async function resolveAudience(
  admin: AdminClient,
  audience: AudienceType,
  userId: string,
): Promise<string[]> {
  if (audience === "user") {
    const { data: profile } = await admin
      .from("profiles")
      .select("id")
      .eq("id", userId)
      .maybeSingle();
    return profile == null ? [] : [profile.id as string];
  }

  if (audience === "all_vendors" || audience === "all_buyers") {
    const role = audience === "all_vendors" ? "vendor" : "buyer";
    return await fetchAllIds(
      (from, to) =>
        admin
          .from("profiles")
          .select("id")
          .eq("role", role)
          .order("id")
          .range(from, to),
      (row) => row.id as string,
    );
  }

  if (audience === "subscribed_vendors") {
    return await fetchAllIds(
      (from, to) =>
        admin
          .from("vendor_subscriptions")
          .select("vendor_id")
          .eq("status", "active")
          .is("cancelled_at", null)
          .or(
            `current_period_end.is.null,current_period_end.gt.${
              new Date().toISOString()
            }`,
          )
          .order("vendor_id")
          .range(from, to),
      (row) => row.vendor_id as string,
    );
  }

  // vendors_without_shop
  const vendorIds = await fetchAllIds(
    (from, to) =>
      admin
        .from("profiles")
        .select("id")
        .eq("role", "vendor")
        .order("id")
        .range(from, to),
    (row) => row.id as string,
  );
  const shopVendorIds = new Set(
    await fetchAllIds(
      (from, to) =>
        admin
          .from("shops")
          .select("vendor_id")
          .not("vendor_id", "is", null)
          .order("vendor_id")
          .range(from, to),
      (row) => row.vendor_id as string,
    ),
  );

  return vendorIds.filter((id) => !shopVendorIds.has(id));
}

async function fetchAllIds(
  query: (
    from: number,
    to: number,
  ) => PromiseLike<{ data: Array<Record<string, unknown>> | null; error: { message: string } | null }>,
  pick: (row: Record<string, unknown>) => string,
): Promise<string[]> {
  const ids: string[] = [];
  let from = 0;

  while (true) {
    const { data, error } = await query(from, from + pageSize - 1);
    if (error != null) {
      throw new Error(error.message);
    }

    const rows = data ?? [];
    ids.push(...rows.map(pick));
    if (rows.length < pageSize) break;
    from += pageSize;
  }

  return ids;
}

async function storeNotifications(
  admin: AdminClient,
  recipientIds: string[],
  payload: PushPayload,
  broadcastId: string,
) {
  for (
    let index = 0;
    index < recipientIds.length;
    index += insertChunkSize
  ) {
    const chunk = recipientIds.slice(index, index + insertChunkSize);
    const { error } = await admin
      .from("notifications")
      .upsert(
        chunk.map((recipientId) => ({
          user_id: recipientId,
          title: payload.title,
          body: payload.body,
          notification_type: "admin_broadcast",
          event_key: `admin_broadcast:${broadcastId}`,
          data: payload.data,
        })),
        { onConflict: "user_id,event_key", ignoreDuplicates: true },
      );

    if (error != null) {
      console.error("Unable to store broadcast notifications", error.message);
    }
  }
}

async function isAdminCaller(admin: AdminClient, jwt: string) {
  const client = createClient(supabaseUrl, supabaseAnonKey, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const {
    data: { user },
  } = await client.auth.getUser();

  if (user == null) return false;

  const { data: profile } = await admin
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();

  return profile?.role === "admin";
}

function isAudienceType(value: string): value is AudienceType {
  return (audienceTypes as readonly string[]).includes(value);
}

function getJwtRole(jwt: string) {
  try {
    const payload = jwt.split(".")[1];
    if (!payload) return null;
    const decoded = JSON.parse(atob(base64UrlToBase64(payload))) as {
      role?: string;
    };
    return decoded.role ?? null;
  } catch (_) {
    return null;
  }
}

function base64UrlToBase64(value: string) {
  const padded = value.padEnd(value.length + (4 - value.length % 4) % 4, "=");
  return padded.replace(/-/g, "+").replace(/_/g, "/");
}
