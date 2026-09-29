import { createHandler, imageBytes, listingResult } from "./core.ts";
const user = "10000000-0000-4000-8000-000000000001";
const id = "30000000-0000-4000-8000-000000000001";
const shop = "20000000-0000-4000-8000-000000000001";
function assert(value: unknown, message = "assertion failed"): asserts value {
  if (!value) throw new Error(message);
}
const png = btoa(
  String.fromCharCode(137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0),
);
const valid = {
  status: "completed",
  output: [{
    content: [{
      type: "output_text",
      text: JSON.stringify({
        title: "Handmade bowl",
        description: "A blue ceramic bowl.",
      }),
    }],
  }],
};
function fixture(overrides: Record<string, string> = {}, providerFail = false) {
  const values: Record<string, string> = {
    SUPABASE_URL: "https://test.invalid",
    SUPABASE_ANON_KEY: "anon",
    SUPABASE_SERVICE_ROLE_KEY: "service",
    ARTISAN_AI_ENABLED: "true",
    ARTISAN_AI_ALLOWED_USERS: user,
    OPENAI_API_KEY: "test-only-not-real",
    ARTISAN_AI_TEXT_MODEL: "configured-text-model",
    ARTISAN_AI_IMAGE_MODEL: "configured-image-model",
    ...overrides,
  };
  const requests = new Map<string, any>();
  let calls = 0, uploads = 0;
  const fetcher: typeof fetch = async (input, init) => {
    const url = String(input);
    if (url.endsWith("/auth/v1/user")) return Response.json({ id: user });
    if (url.includes("/rpc/")) {
      const b = JSON.parse(init!.body as string);
      if (b.p_shop !== shop) {
        return new Response("shop_not_owned", { status: 400 });
      }
      if (requests.has(b.p_id)) {
        return Response.json({ reserved: false, ...requests.get(b.p_id) });
      }
      requests.set(b.p_id, { status: "pending" });
      return Response.json({ reserved: true });
    }
    if (url.includes("api.openai.com")) {
      calls++;
      if (providerFail) {
        return new Response("provider internal secret", { status: 500 });
      }
      if (url.endsWith("/edits")) {
        assert(init!.body instanceof FormData);
        assert(init!.body.get("image") instanceof Blob);
        return Response.json({ data: [{ b64_json: png }] });
      }
      const b = JSON.parse(init!.body as string);
      assert(b.store === false && b.text.format.strict === true);
      return Response.json(valid);
    }
    if (url.includes("/storage/")) {
      uploads++;
      return Response.json({ Key: "result" });
    }
    if (url.includes("/artisan_ai_requests?")) {
      requests.set(id, JSON.parse(init!.body as string));
      return new Response(null, { status: 204 });
    }
    throw new Error("Unexpected network request " + url);
  };
  return {
    handler: createHandler((k) => values[k], fetcher),
    calls: () => calls,
    uploads: () => uploads,
  };
}
const request = (body: Record<string, unknown>, auth = true) =>
  new Request("https://local.test", {
    method: "POST",
    headers: auth ? { authorization: "Bearer test" } : {},
    body: JSON.stringify(body),
  });
const listing = {
  id,
  shop_id: shop,
  operation: "listing",
  facts: "Handmade blue ceramic bowl.",
  consent: true,
};
Deno.test("disabled pilot and missing consent never call provider", async () => {
  const f = fixture({ ARTISAN_AI_ENABLED: "false" });
  assert((await f.handler(request(listing))).status === 503);
  assert(f.calls() === 0);
  const active = fixture();
  assert(
    (await active.handler(request({ ...listing, consent: false }))).status ===
      400,
  );
  assert(active.calls() === 0);
});
Deno.test("authentication and allowlist enforced", async () => {
  const f = fixture();
  assert((await f.handler(request(listing, false))).status === 401);
  const blocked = fixture({ ARTISAN_AI_ALLOWED_USERS: "another-user" });
  assert((await blocked.handler(request(listing))).status === 503);
  assert(blocked.calls() === 0);
});
Deno.test("capabilities are read-only and disabled models stay unavailable", async () => {
  const f = fixture({ ARTISAN_AI_IMAGE_MODEL: "" });
  const body = await (await f.handler(request({ operation: "capabilities" })))
    .json();
  assert(body.listing === true && body.image === false && f.calls() === 0);
});
Deno.test("listing review result and retry make only one paid call", async () => {
  const f = fixture();
  const first = await (await f.handler(request(listing))).json();
  const second = await (await f.handler(request(listing))).json();
  assert(
    first.result.title === "Handmade bowl" && second.status === "succeeded" &&
      f.calls() === 1,
  );
});
Deno.test("foreign shop never calls AI", async () => {
  const f = fixture();
  assert(
    (await f.handler(request({ ...listing, shop_id: user }))).status === 403,
  );
  assert(f.calls() === 0);
});
Deno.test("failed provider is sanitized and not replayed", async () => {
  const f = fixture({}, true);
  const response = await f.handler(request(listing));
  assert(response.status === 502);
  assert(!(await response.text()).includes("secret"));
  const retry = await (await f.handler(request(listing))).json();
  assert(retry.status === "failed" && f.calls() === 1);
});
Deno.test("image edits use uploaded bytes and private result", async () => {
  const f = fixture();
  const result = await (await f.handler(
    request({ ...listing, operation: "image", image: png, style: "studio" }),
  )).json();
  assert(
    result.result.image_path === user + "/" + id + ".png" &&
      f.uploads() === 1 && f.calls() === 1,
  );
});
Deno.test("unsupported photo and style rejected before provider", async () => {
  const f = fixture();
  assert(
    (await f.handler(
      request({
        ...listing,
        operation: "image",
        image: btoa("not an image"),
        style: "studio",
      }),
    )).status === 400,
  );
  assert(
    (await f.handler(
      request({ ...listing, operation: "image", image: png, style: "unknown" }),
    )).status === 400,
  );
  assert(f.calls() === 0);
});
Deno.test("invalid or refused structured output is never accepted", () => {
  for (
    const value of [{ status: "incomplete" }, {
      status: "completed",
      output: [{ content: [{ type: "refusal" }] }],
    }, {
      status: "completed",
      output: [{
        content: [{
          type: "output_text",
          text: '{"title":"","description":"x"}',
        }],
      }],
    }]
  ) {
    let threw = false;
    try {
      listingResult(value);
    } catch {
      threw = true;
    }
    assert(threw);
  }
  assert(imageBytes(png).mime === "image/png");
});
