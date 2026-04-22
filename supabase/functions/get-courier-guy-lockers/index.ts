import { jsonResponse } from "../_shared/http.ts";

const courierGuyApiKey = Deno.env.get("COURIER_GUY_API_KEY")!;
const courierGuyApiBaseUrl =
  Deno.env.get("COURIER_GUY_API_BASE_URL") ?? "https://sandbox.api-pudo.co.za";

type TcgLocker = {
  code?: string;
  provider?: string;
  name?: string;
  latitude?: string | number | null;
  longitude?: string | number | null;
  address?: string;
  landmark?: string | null;
  detailed_address?: {
    province?: string;
    locality?: string;
    sublocality?: string;
    formatted_address?: string;
  };
  type?: {
    id?: number;
    name?: string;
  };
  place?: {
    town?: string;
    postalCode?: string;
  };
};

function normalize(value: unknown) {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

function tokenize(value: unknown) {
  return normalize(value)
    .split(/[^a-z0-9]+/)
    .filter(Boolean);
}

function parseCoordinate(value: string | number | null | undefined) {
  if (value == null) return null;
  if (typeof value === "number") return value;
  const parsed = Number.parseFloat(value);
  return Number.isFinite(parsed) ? parsed : null;
}

type WeightedSearchField = {
  value: unknown;
  weight: number;
};

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

function scoreLocker(locker: TcgLocker, tokens: string[]) {
  if (tokens.length === 0) return 0;

  const fields: WeightedSearchField[] = [
    { value: locker.name, weight: 8 },
    { value: locker.code, weight: 9 },
    { value: locker.landmark, weight: 5 },
    { value: locker.address, weight: 4 },
    { value: locker.detailed_address?.formatted_address, weight: 4 },
    { value: locker.detailed_address?.locality, weight: 6 },
    { value: locker.detailed_address?.sublocality, weight: 5 },
    { value: locker.detailed_address?.province, weight: 2 },
    { value: locker.place?.town, weight: 6 },
    { value: locker.place?.postalCode, weight: 4 },
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

Deno.serve(async (request) => {
  try {
    const body =
      request.method === "POST"
        ? ((await request.json()) as Record<string, unknown>)
        : {};
    const query = typeof body.query === "string" ? body.query.trim() : "";
    const province =
      typeof body.province === "string" ? body.province.trim() : "";
    const limitValue =
      body.limit == null
        ? null
        : typeof body.limit === "number"
        ? body.limit
        : Number.parseInt(String(body.limit), 10);
    const limit =
      limitValue != null && Number.isFinite(limitValue) && limitValue > 0
        ? limitValue
        : null;

    const response = await fetch(
      `${courierGuyApiBaseUrl.replace(/\/+$/, "")}/api/v1/lockers-data`,
      {
        headers: {
          Authorization: `Bearer ${courierGuyApiKey}`,
          Accept: "application/json",
        },
      },
    );

    if (!response.ok) {
      const errorText = await response.text();
      console.log(
        `[courier-guy-lockers] upstream error status=${response.status} body=${errorText.slice(0, 500)}`,
      );
      return jsonResponse(
        { error: "Could not load Courier Guy lockers right now." },
        { status: 502 },
      );
    }

    const payload = (await response.json()) as TcgLocker[];
    const normalizedQuery = normalize(query);
    const queryTokens = tokenize(query);
    const normalizedProvince = normalize(province);

    const lockers = payload
      .filter((locker) => normalize(locker.type?.name) === "locker")
      .filter((locker) => {
        if (!normalizedProvince) return true;
        return normalize(locker.detailed_address?.province) === normalizedProvince;
      })
      .map((locker) => ({
        locker,
        score: normalizedQuery ? scoreLocker(locker, queryTokens) : 0,
      }))
      .filter(({ score }) => {
        if (!normalizedQuery) return true;
        return score >= 0;
      })
      .sort((a, b) => {
        if (b.score !== a.score) return b.score - a.score;

        const provinceCompare = normalize(a.locker.detailed_address?.province).localeCompare(
          normalize(b.locker.detailed_address?.province),
        );
        if (provinceCompare !== 0) return provinceCompare;
        return normalize(a.locker.name).localeCompare(normalize(b.locker.name));
      })
      .slice(0, limit ?? undefined)
      .map(({ locker }) => ({
        code: locker.code ?? "",
        provider: locker.provider ?? "TCG",
        name: locker.name ?? "",
        latitude: parseCoordinate(locker.latitude),
        longitude: parseCoordinate(locker.longitude),
        address:
          locker.detailed_address?.formatted_address ??
          locker.address ??
          "",
        landmark: locker.landmark ?? "",
        detailed_address: {
          province: locker.detailed_address?.province ?? "",
          locality:
            locker.detailed_address?.locality ??
            locker.detailed_address?.sublocality ??
            locker.place?.town ??
            "",
          formatted_address:
            locker.detailed_address?.formatted_address ?? locker.address ?? "",
        },
        type: {
          id: locker.type?.id ?? 2,
          name: locker.type?.name ?? "Locker",
        },
        place: {
          town: locker.place?.town ?? locker.detailed_address?.locality ?? "",
          postalCode: locker.place?.postalCode ?? "",
        },
      }));

    return jsonResponse({ lockers });
  } catch (error) {
    console.log(
      `[courier-guy-lockers] fatal ${error instanceof Error ? error.message : String(error)}`,
    );
    return jsonResponse(
      { error: "Could not load Courier Guy lockers right now." },
      { status: 500 },
    );
  }
});
