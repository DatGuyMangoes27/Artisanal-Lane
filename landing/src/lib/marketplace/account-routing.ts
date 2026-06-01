export type AccountRole = "admin" | "vendor" | "buyer";
export type LoginIntent = "buyer" | "vendor";

export function normalizeAccountRole(role: string | null | undefined): AccountRole {
  if (role === "admin" || role === "vendor") {
    return role;
  }

  return "buyer";
}

export function getAccountHomeHref(role: string | null | undefined) {
  if (!role) {
    return "/login";
  }

  switch (normalizeAccountRole(role)) {
    case "admin":
      return "/admin";
    case "vendor":
      return "/vendor";
    case "buyer":
      return "/account";
  }
}

export function normalizeLoginIntent(intent: string | null | undefined): LoginIntent {
  return intent === "vendor" ? "vendor" : "buyer";
}

export function getLoginRedirectForIntent(intent: string | null | undefined) {
  return normalizeLoginIntent(intent) === "vendor" ? "/vendor" : "/shop";
}

export function getLoginIntentCopy(intent: string | null | undefined) {
  const normalized = normalizeLoginIntent(intent);

  if (normalized === "vendor") {
    return {
      title: "Vendor Sign In",
      createTitle: "Create Vendor Account",
      description:
        "Sign in to manage your artisan portal, products, orders, payouts, and shop profile.",
      requestedRole: "vendor",
    };
  }

  return {
    title: "Buyer Sign In",
    createTitle: "Create Buyer Account",
    description: "Sign in to finish checkout and keep your order history connected to your account.",
    requestedRole: "buyer",
  };
}
