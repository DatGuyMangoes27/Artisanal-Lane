import { jsonResponse, optionsResponse } from "../_shared/http.ts";

const pargoApiUrl = Deno.env.get("PARGO_PICKUP_POINTS_URL") ??
  "https://api.live.pargo.co.za/pickup_points";
const pargoAuthUrl = Deno.env.get("PARGO_AUTH_URL") ??
  "https://api.live.pargo.co.za/auth";
const pargoUsername = Deno.env.get("PARGO_USERNAME");
const pargoPassword = Deno.env.get("PARGO_PASSWORD");
const pargoPageLimit = 100;
const pargoMaxSearchPages = Number.parseInt(
  Deno.env.get("PARGO_PICKUP_POINTS_MAX_SEARCH_PAGES") ?? "10",
  10,
);

let cachedAccessToken: string | null = null;
let cachedAccessTokenExpiresAt = 0;

type RawPoint = Record<string, unknown>;

type WeightedSearchField = {
  value: unknown;
  weight: number;
};

function normalize(value: unknown) {
  return typeof value === "string" || typeof value === "number"
    ? String(value).trim().toLowerCase()
    : "";
}

function firstText(...values: unknown[]) {
  for (const value of values) {
    const normalized = typeof value === "string" || typeof value === "number"
      ? String(value).trim()
      : "";
    if (normalized.length > 0) return normalized;
  }
  return "";
}

function tokenize(value: unknown) {
  return normalize(value)
    .split(/[^a-z0-9]+/)
    .filter(Boolean);
}

function parseCoordinate(value: unknown) {
  if (value == null) return null;
  if (typeof value === "number") return Number.isFinite(value) ? value : null;
  const parsed = Number.parseFloat(String(value));
  return Number.isFinite(parsed) ? parsed : null;
}

function nested(record: RawPoint, ...keys: string[]) {
  let current: unknown = record;
  for (const key of keys) {
    if (current == null || typeof current !== "object") return undefined;
    current = (current as Record<string, unknown>)[key];
  }
  return current;
}

function bestFieldScore(token: string, field: WeightedSearchField) {
  const normalizedField = normalize(field.value);
  if (!normalizedField) return 0;
  const terms = tokenize(field.value);

  if (normalizedField === token) return 160 * field.weight;
  if (terms.includes(token)) return 140 * field.weight;
  if (normalizedField.startsWith(token)) return 120 * field.weight;
  if (terms.some((term) => term.startsWith(token))) return 100 * field.weight;
  if (normalizedField.includes(token)) return 60 * field.weight;
  if (terms.some((term) => term.includes(token))) return 50 * field.weight;

  return 0;
}

function normalizedPoint(point: RawPoint) {
  const source = isRecord(point.attributes) ? point.attributes : point;
  const address = firstText(
    source.address,
    source.addressSms,
    source.address_sms,
    source.formatted_address,
    source.full_address,
    source.street_address,
    [source.address1, source.address2].filter((part) => firstText(part)).join(
      " ",
    ),
    nested(source, "address", "formatted"),
    nested(source, "address", "line1"),
  );
  const city = firstText(
    source.city,
    source.town,
    source.suburb,
    source.locality,
    nested(source, "address", "city"),
    nested(source, "address", "town"),
    nested(source, "address", "suburb"),
  );
  const province = firstText(
    source.province,
    source.region,
    nested(source, "address", "province"),
    nested(source, "address", "region"),
  );

  return {
    code: firstText(
      source.code,
      source.id,
      source.pickup_point_code,
      source.pickupPointCode,
      source.pargo_point_code,
      source.pargoPointCode,
      source.store_code,
    ),
    name: firstText(
      source.name,
      source.short_store_name,
      source.store_name,
      source.storeName,
      source.trading_name,
      source.pickup_point_name,
      source.description,
      source.retailChainName,
    ),
    address,
    city,
    province,
    postal_code: firstText(
      source.postal_code,
      source.postalcode,
      source.postalCode,
      source.postcode,
      source.zip,
      nested(source, "address", "postal_code"),
      nested(source, "address", "postcode"),
    ),
    latitude: parseCoordinate(
      source.latitude ?? source.lat ?? nested(source, "coordinates", "lat") ??
        nested(source, "location", "lat"),
    ),
    longitude: parseCoordinate(
      source.longitude ?? source.lng ?? source.lon ??
        nested(source, "coordinates", "lng") ??
        nested(source, "location", "lng"),
    ),
  };
}

function scorePoint(point: RawPoint, tokens: string[]) {
  if (tokens.length === 0) return 0;
  const normalized = normalizedPoint(point);
  const fields: WeightedSearchField[] = [
    { value: normalized.code, weight: 9 },
    { value: normalized.name, weight: 8 },
    { value: normalized.city, weight: 6 },
    { value: normalized.address, weight: 4 },
    { value: normalized.postal_code, weight: 4 },
    { value: normalized.province, weight: 2 },
  ];

  let totalScore = 0;
  for (const token of tokens) {
    let bestTokenScore = 0;
    for (const field of fields) {
      bestTokenScore = Math.max(bestTokenScore, bestFieldScore(token, field));
    }
    if (bestTokenScore <= 0) return -1;
    totalScore += bestTokenScore;
  }
  return totalScore;
}

function extractPoints(payload: unknown): RawPoint[] {
  if (Array.isArray(payload)) return payload.filter(isRecord);
  if (!isRecord(payload)) return [];

  for (
    const key of ["pickup_points", "pickupPoints", "points", "data", "results"]
  ) {
    const value = payload[key];
    if (Array.isArray(value)) return value.filter(isRecord);
  }
  return [];
}

function isRecord(value: unknown): value is RawPoint {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

async function getPargoAccessToken() {
  const now = Date.now();
  if (cachedAccessToken != null && cachedAccessTokenExpiresAt > now + 30_000) {
    return cachedAccessToken;
  }

  if (!pargoUsername || !pargoPassword) {
    throw new Error("Missing Pargo credentials.");
  }

  const response = await fetch(pargoAuthUrl, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      username: pargoUsername,
      password: pargoPassword,
    }),
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok || !isRecord(payload)) {
    console.log(
      `[pargo-pickup-points] auth error status=${response.status} body=${
        JSON.stringify(payload).slice(0, 500)
      }`,
    );
    throw new Error("Could not authenticate with Pargo.");
  }

  const token = firstText(payload.access_token, payload.accessToken);
  const expiresIn = typeof payload.expires_in === "number"
    ? payload.expires_in
    : Number.parseInt(String(payload.expires_in ?? "4200"), 10);

  if (!token) {
    throw new Error("Pargo auth response did not include an access token.");
  }

  cachedAccessToken = token;
  cachedAccessTokenExpiresAt = now +
    (Number.isFinite(expiresIn) ? expiresIn * 1000 : 4_200_000);
  return token;
}

Deno.serve(async (request) => {
  try {
    if (request.method === "OPTIONS") {
      return optionsResponse();
    }

    if (!pargoUsername || !pargoPassword) {
      throw new Error("Missing Pargo credentials.");
    }

    const body = request.method === "POST"
      ? ((await request.json()) as Record<string, unknown>)
      : {};
    const query = typeof body.query === "string" ? body.query.trim() : "";
    const province = typeof body.province === "string"
      ? body.province.trim()
      : "";
    const limitValue = body.limit == null
      ? null
      : typeof body.limit === "number"
      ? body.limit
      : Number.parseInt(String(body.limit), 10);
    const limit =
      limitValue != null && Number.isFinite(limitValue) && limitValue > 0
        ? limitValue
        : 20;

    const accessToken = await getPargoAccessToken();
    const queryTokens = tokenize(query);
    const normalizedProvince = normalize(province);
    const pagesToSearch = queryTokens.length > 0 || normalizedProvince
      ? Math.max(
        1,
        Number.isFinite(pargoMaxSearchPages) ? pargoMaxSearchPages : 10,
      )
      : 1;
    const rawPoints: RawPoint[] = [];

    for (let page = 1; page <= pagesToSearch; page += 1) {
      const url = new URL(pargoApiUrl);
      url.searchParams.set("limit", String(pargoPageLimit));
      url.searchParams.set("page", String(page));

      const response = await fetch(url, {
        headers: {
          Authorization: `Bearer ${accessToken}`,
          Accept: "application/json",
        },
      });

      if (!response.ok) {
        const errorText = await response.text();
        console.log(
          `[pargo-pickup-points] upstream error status=${response.status} body=${
            errorText.slice(0, 500)
          }`,
        );
        return jsonResponse(
          {
            error: "Could not load Pargo pickup points right now.",
            upstream_status: response.status,
          },
          { status: 502 },
        );
      }

      const pagePoints = extractPoints(await response.json());
      rawPoints.push(...pagePoints);
      if (pagePoints.length < pargoPageLimit) break;
    }

    const points = rawPoints
      .map((point) => ({
        point,
        normalized: normalizedPoint(point),
        score: query.trim().length === 0 ? 0 : scorePoint(point, queryTokens),
      }))
      .filter(({ normalized, score }) => {
        if (score < 0) return false;
        if (!normalizedProvince) return true;
        return normalize(normalized.province) === normalizedProvince;
      })
      .sort((a, b) => {
        if (b.score !== a.score) return b.score - a.score;
        const provinceCompare = normalize(a.normalized.province).localeCompare(
          normalize(b.normalized.province),
        );
        if (provinceCompare !== 0) return provinceCompare;
        return normalize(a.normalized.name).localeCompare(
          normalize(b.normalized.name),
        );
      })
      .slice(0, limit)
      .map(({ normalized }) => normalized);

    return jsonResponse({ points });
  } catch (error) {
    console.log(
      `[pargo-pickup-points] fatal ${
        error instanceof Error ? error.message : String(error)
      }`,
    );
    return jsonResponse(
      { error: "Could not load Pargo pickup points right now." },
      { status: 500 },
    );
  }
});
