type TradeSafeGraphQlResponse<T> = {
  data?: T;
  errors?: Array<{ message: string }>;
};

type TokenInput = {
  existingTokenId?: string | null;
  displayName: string;
  email: string;
  mobile: string;
};

const TRADE_SAFE_AUTH_URL =
  Deno.env.get("TRADESAFE_AUTH_URL") ??
  "https://auth.tradesafe.co.za/oauth/token";
const TRADE_SAFE_GRAPHQL_URL =
  Deno.env.get("TRADESAFE_GRAPHQL_URL") ??
  "https://api.tradesafe.co.za/graphql";

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

  const response = await fetch(TRADE_SAFE_AUTH_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body,
  });

  if (!response.ok) {
    throw new Error(`TradeSafe auth failed with status ${response.status}`);
  }

  const payload = await response.json();
  return payload.access_token as string;
}

export async function tradeSafeRequest<T>(
  query: string,
  variables: Record<string, unknown> = {},
) {
  const accessToken = await getAccessToken();

  const response = await fetch(TRADE_SAFE_GRAPHQL_URL, {
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
    throw new Error(`TradeSafe request failed with status ${response.status}`);
  }

  const payload =
    (await response.json()) as TradeSafeGraphQlResponse<T>;

  if (payload.errors?.length) {
    throw new Error(payload.errors.map((error) => error.message).join("; "));
  }

  if (!payload.data) {
    throw new Error("TradeSafe returned an empty response.");
  }

  return payload.data;
}

export async function ensureTradeSafeToken(input: TokenInput) {
  const { givenName, familyName } = splitDisplayName(input.displayName);

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
    }>(updateMutation, {
      id: input.existingTokenId,
      input: {
        user: {
          givenName,
          familyName,
          email: input.email,
          mobile: input.mobile,
        },
      },
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
  }>(createMutation, {
    input: {
      user: {
        givenName,
        familyName,
        email: input.email,
        mobile: input.mobile,
      },
    },
  });

  return created.tokenCreate.id;
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
    mutation CreateTransaction($input: TransactionCreateInput!) {
      transactionCreate(input: $input) {
        id
        state
        allocations {
          id
          state
        }
      }
    }
  `;

  const result = await tradeSafeRequest<{
    transactionCreate: {
      id: string;
      state: string;
      allocations: Array<{ id: string; state: string }>;
    };
  }>(mutation, {
    input: {
      reference: input.reference,
      title: input.title,
      description: input.description,
      total: input.amount,
      buyer: {
        token: input.buyerTokenId,
      },
      seller: {
        token: input.sellerTokenId,
      },
      allocations: [
        {
          token: input.sellerTokenId,
          value: input.amount,
        },
      ],
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
  }>(mutation, {
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
  }>(mutation, {
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
  }>(mutation, {
    id: allocationId,
  });
}

export async function disputeAllocationDelivery(allocationId: string) {
  const mutation = `
    mutation DisputeDelivery($id: ID!) {
      allocationDisputeDelivery(id: $id) {
        id
        state
      }
    }
  `;

  return tradeSafeRequest<{
    allocationDisputeDelivery: { id: string; state: string };
  }>(mutation, {
    id: allocationId,
  });
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
  }>(mutation, {
    id: transactionId,
    comment,
  });
}
