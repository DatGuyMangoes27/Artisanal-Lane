import { buildAllocationDisputeDeliveryRequest } from "./tradesafe-dispute.mjs";

type TradeSafeGraphQlResponse<T> = {
  data?: T;
  errors?: Array<{ message: string }>;
};

type TokenInput = {
  existingTokenId?: string | null;
  displayName: string;
  email: string;
  mobile: string;
  idNumber?: string | null;
  idType?: "NATIONAL" | "PASSPORT";
  idCountry?: string | null;
  organization?: {
    name: string;
    tradeName?: string | null;
    type: "PRIVATE";
    registrationNumber?: string | null;
  } | null;
  bankAccount?: {
    bank: string;
    accountNumber: string;
    accountType: "CHEQUE" | "SAVINGS" | "TRANSMISSION" | "BOND";
  } | null;
};

const TRADE_SAFE_AUTH_URL =
  Deno.env.get("TRADESAFE_AUTH_URL") ??
  "https://auth.tradesafe.co.za/oauth/token";
const TRADE_SAFE_API_URL = Deno.env.get("TRADESAFE_API_URL");
const TRADE_SAFE_GRAPHQL_URL =
  Deno.env.get("TRADESAFE_GRAPHQL_URL") ??
  "https://api.tradesafe.co.za/graphql";

function buildTradeSafeAuthCandidates() {
  const raw = TRADE_SAFE_AUTH_URL.trim().replace(/\/+$/, "");
  const candidates = new Set<string>();
  candidates.add(
    raw.endsWith("/oauth/token") ? raw : `${raw}/oauth/token`,
  );
  candidates.add("https://auth.tradesafe.co.za/oauth/token");
  return Array.from(candidates);
}

function normalizeTradeSafeGraphqlUrl(value: string) {
  const raw = value.trim().replace(/\/+$/, "");
  return raw.endsWith("/graphql") ? raw : `${raw}/graphql`;
}

function resolveTradeSafeGraphqlCandidates() {
  const configuredGraphqlUrl = Deno.env.get("TRADESAFE_GRAPHQL_URL");
  if (configuredGraphqlUrl != null && configuredGraphqlUrl.trim().length > 0) {
    return [normalizeTradeSafeGraphqlUrl(configuredGraphqlUrl)];
  }

  const configuredApiUrl = TRADE_SAFE_API_URL?.trim();
  if (configuredApiUrl != null && configuredApiUrl.length > 0) {
    return [normalizeTradeSafeGraphqlUrl(configuredApiUrl)];
  }

  return [
    normalizeTradeSafeGraphqlUrl(TRADE_SAFE_GRAPHQL_URL),
    "https://api-developer.tradesafe.dev/graphql",
  ];
}

function requireEnv(name: string) {
  const value = Deno.env.get(name);
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function splitDisplayName(displayName: string) {
  const clean = displayName.trim() || "Artisan Lane User";
  const parts = clean.split(/\s+/).filter(Boolean);
  const givenName = parts[0] ?? "Artisan";
  const familyName = parts.length > 1 ? parts.slice(1).join(" ") : "Lane";
  return { givenName, familyName };
}

function trimToNull(value: string | null | undefined) {
  const trimmed = value?.trim();
  return trimmed != null && trimmed.length > 0 ? trimmed : null;
}

function buildTokenInput(input: TokenInput) {
  const { givenName, familyName } = splitDisplayName(input.displayName);

  return {
    user: {
      givenName,
      familyName,
      email: input.email,
      mobile: input.mobile,
      ...(input.idNumber != null
          ? {
              idNumber: input.idNumber,
              idType: input.idType ?? "NATIONAL",
              idCountry: input.idCountry ?? "ZAF",
            }
          : {}),
    },
    ...(input.organization != null ? { organization: input.organization } : {}),
    ...(input.bankAccount != null ? { bankAccount: input.bankAccount } : {}),
  };
}

export function normalizeMobile(value: string | null | undefined) {
  const digits = (value ?? "").replace(/[^+\d]/g, "");
  if (!digits) {
    throw new Error("A mobile number is required for TradeSafe checkout.");
  }
  if (digits.startsWith("+")) {
    return digits;
  }
  if (digits.startsWith("0")) {
    return `+27${digits.substring(1)}`;
  }
  if (digits.startsWith("27")) {
    return `+${digits}`;
  }
  return `+${digits}`;
}

async function getAccessToken() {
  const body = new URLSearchParams({
    grant_type: "client_credentials",
    client_id: requireEnv("TRADESAFE_CLIENT_ID"),
    client_secret: requireEnv("TRADESAFE_CLIENT_SECRET"),
  });

  let lastError: string | null = null;

  for (const authUrl of buildTradeSafeAuthCandidates()) {
    try {
      console.log(`[checkout-debug] TradeSafe auth request url=${authUrl}`);
      const response = await fetch(authUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body,
      });

      if (!response.ok) {
        const errorBody = await response.text();
        lastError =
          `status=${response.status} url=${authUrl} body=${errorBody}`;
        console.log(`[checkout-debug] TradeSafe auth failed ${lastError}`);
        continue;
      }

      const payload = await response.json();
      const accessToken = payload.access_token as string | undefined;
      if (accessToken == null || accessToken.length === 0) {
        lastError = `missing access_token url=${authUrl}`;
        console.log(`[checkout-debug] TradeSafe auth failed ${lastError}`);
        continue;
      }

      console.log(`[checkout-debug] TradeSafe auth succeeded url=${authUrl}`);
      return accessToken;
    } catch (error) {
      lastError = `url=${authUrl} error=${error instanceof Error ? error.message : String(error)}`;
      console.log(`[checkout-debug] TradeSafe auth threw ${lastError}`);
    }
  }

  throw new Error(`TradeSafe auth failed. ${lastError ?? "Unknown error."}`);
}

export async function tradeSafeRequest<T>(
  operationName: string,
  query: string,
  variables: Record<string, unknown> = {},
) {
  const accessToken = await getAccessToken();
  const graphqlCandidates = resolveTradeSafeGraphqlCandidates();
  let lastError: string | null = null;

  for (const [index, graphqlUrl] of graphqlCandidates.entries()) {
    console.log(
      `[checkout-debug] TradeSafe ${operationName} request url=${graphqlUrl}`,
    );

    const response = await fetch(graphqlUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        query,
        variables,
      }),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      lastError =
        `url=${graphqlUrl} status=${response.status} body=${errorBody}`;
      console.log(
        `[checkout-debug] TradeSafe ${operationName} http failure ${lastError}`,
      );
      continue;
    }

    const payload =
      (await response.json()) as TradeSafeGraphQlResponse<T>;

    if (payload.errors?.length) {
      const errorMessage = payload.errors.map((error) => error.message).join("; ");
      lastError = `url=${graphqlUrl} errors=${errorMessage}`;
      console.log(
        `[checkout-debug] TradeSafe ${operationName} graphql failure ${lastError}`,
      );

      if (
        /Unauthenticated/i.test(errorMessage) &&
        index < graphqlCandidates.length - 1
      ) {
        continue;
      }

      throw new Error(`TradeSafe ${operationName} failed: ${lastError}`);
    }

    if (!payload.data) {
      lastError = `url=${graphqlUrl} empty response`;
      console.log(
        `[checkout-debug] TradeSafe ${operationName} empty response ${lastError}`,
      );
      continue;
    }

    return payload.data;
  }

  throw new Error(
    `TradeSafe ${operationName} failed: ${lastError ?? "Unknown error."}`,
  );
}

export async function ensureTradeSafeToken(input: TokenInput) {
  if (input.existingTokenId) {
    const updateMutation = `
      mutation UpdateToken($id: ID!, $input: TokenInput!) {
        tokenUpdate(id: $id, input: $input) {
          id
        }
      }
    `;

    const updated = await tradeSafeRequest<{
      tokenUpdate: { id: string };
    }>("tokenUpdate", updateMutation, {
      id: input.existingTokenId,
      input: buildTokenInput(input),
    });

    return updated.tokenUpdate.id;
  }

  const createMutation = `
    mutation CreateToken($input: TokenInput!) {
      tokenCreate(input: $input) {
        id
      }
    }
  `;

  const created = await tradeSafeRequest<{
    tokenCreate: { id: string };
  }>("tokenCreate", createMutation, {
    input: buildTokenInput(input),
  });

  return created.tokenCreate.id;
}

export function mapTradeSafeBankAccountType(value: string | null | undefined) {
  const normalized = trimToNull(value)?.toLowerCase();
  switch (normalized) {
    case "cheque":
    case "checking":
    case "current":
      return "CHEQUE" as const;
    case "savings":
    case "saving":
      return "SAVINGS" as const;
    case "transmission":
      return "TRANSMISSION" as const;
    case "bond":
      return "BOND" as const;
    default:
      return null;
  }
}

export function mapTradeSafeBank(value: string | null | undefined) {
  const normalized = trimToNull(value)?.toLowerCase();
  switch (normalized) {
    case "absa":
    case "absa bank":
      return "ABSA" as const;
    case "african":
    case "african bank":
      return "AFRICAN" as const;
    case "capitec":
    case "capitec bank":
      return "CAPITEC" as const;
    case "discovery":
    case "discovery bank":
      return "DISCOVERY" as const;
    case "fnb":
    case "first national bank":
      return "FNB" as const;
    case "investec":
    case "investec bank":
      return "INVESTEC" as const;
    case "mtn":
    case "mtn banking":
      return "MTN" as const;
    case "nedbank":
      return "NEDBANK" as const;
    case "postbank":
    case "south african post office":
    case "sapo":
      return "SAPO" as const;
    case "sasfin":
    case "sasfin bank":
      return "SASFIN" as const;
    case "standard":
    case "standard bank":
    case "sbsa":
      return "SBSA" as const;
    case "tyme":
    case "tymebank":
    case "tyme bank":
      return "TYME" as const;
    default:
      return "OTHER" as const;
  }
}

export async function createTradeSafeTransaction(input: {
  reference: string;
  title: string;
  description: string;
  buyerTokenId: string;
  sellerTokenId: string;
  amount: number;
}) {
  const mutation = `
    mutation CreateTransaction($input: CreateTransactionInput!) {
      transactionCreate(input: $input) {
        id
        state
        allocations {
          id
          title
          value
          state
        }
      }
    }
  `;

  const result = await tradeSafeRequest<{
    transactionCreate: {
      id: string;
      state: string;
      allocations: Array<{ id: string; title: string; value: number; state: string }>;
    };
  }>("transactionCreate", mutation, {
    input: {
      reference: input.reference,
      title: input.title,
      description: input.description,
      industry: "GENERAL_GOODS_SERVICES",
      currency: "ZAR",
      workflow: "STANDARD",
      feeAllocation: "BUYER",
      allocations: {
        create: [
          {
            title: "Order Payment",
            description: input.description,
            value: input.amount,
            daysToDeliver: 7,
            daysToInspect: 7,
          },
        ],
      },
      parties: {
        create: [
          {
            token: input.buyerTokenId,
            role: "BUYER",
          },
          {
            token: input.sellerTokenId,
            role: "SELLER",
          },
        ],
      },
    },
  });

  const allocation = result.transactionCreate.allocations[0];

  if (!allocation) {
    throw new Error("TradeSafe did not return an allocation for the order.");
  }

  return {
    transactionId: result.transactionCreate.id,
    transactionState: result.transactionCreate.state,
    allocationId: allocation.id,
    allocationState: allocation.state,
  };
}

export async function createCheckoutLink(transactionId: string) {
  const mutation = `
    mutation CheckoutLink($transactionId: ID!) {
      checkoutLink(transactionId: $transactionId)
    }
  `;

  const result = await tradeSafeRequest<{
    checkoutLink: string;
  }>("checkoutLink", mutation, {
    transactionId,
  });

  return result.checkoutLink;
}

export async function startAllocationDelivery(allocationId: string) {
  const mutation = `
    mutation StartDelivery($id: ID!) {
      allocationStartDelivery(id: $id) {
        id
        state
      }
    }
  `;

  return tradeSafeRequest<{
    allocationStartDelivery: { id: string; state: string };
  }>("allocationStartDelivery", mutation, {
    id: allocationId,
  });
}

export async function acceptAllocationDelivery(allocationId: string) {
  const mutation = `
    mutation AcceptDelivery($id: ID!) {
      allocationAcceptDelivery(id: $id) {
        id
        state
      }
    }
  `;

  return tradeSafeRequest<{
    allocationAcceptDelivery: { id: string; state: string };
  }>("allocationAcceptDelivery", mutation, {
    id: allocationId,
  });
}

export async function disputeAllocationDelivery(allocationId: string, comment: string) {
  const request = buildAllocationDisputeDeliveryRequest({
    allocationId,
    comment,
  });
  return tradeSafeRequest<{
    allocationDisputeDelivery: { id: string; state: string };
  }>("allocationDisputeDelivery", request.mutation, request.variables);
}

export async function cancelTradeSafeTransaction(
  transactionId: string,
  comment: string,
) {
  const mutation = `
    mutation CancelTransaction($id: ID!, $comment: String!) {
      transactionCancel(id: $id, comment: $comment) {
        state
      }
    }
  `;

  return tradeSafeRequest<{
    transactionCancel: { state: string };
  }>("transactionCancel", mutation, {
    id: transactionId,
    comment,
  });
}
