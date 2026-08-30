const PAYFAST_CARD_UPDATE_BASE_URL =
  "https://www.payfast.co.za/eng/recurring/update";

export function buildPayFastCardUpdateUrl(
  token: string,
  returnUrl = "https://artisanlanesa.co.za/vendor/profile/subscription",
) {
  const normalizedToken = token.trim();
  if (!normalizedToken) {
    throw new Error("A PayFast subscription token is required.");
  }

  return `${PAYFAST_CARD_UPDATE_BASE_URL}/${encodeURIComponent(normalizedToken)}?return=${encodeURIComponent(returnUrl)}`;
}
