export function getPayFastCancellationToken(subscription) {
  const token = subscription?.payfast_token;
  return typeof token === "string" && token.trim().length > 0
    ? token.trim()
    : null;
}

export function isPayFastCancellationSuccess(httpOk, body) {
  if (!httpOk) return false;
  if (body == null || typeof body !== "object" || Array.isArray(body)) {
    return true;
  }

  const status = typeof body.status === "string"
    ? body.status.toLowerCase()
    : null;
  if (status != null && status !== "success") return false;

  if (typeof body.code === "number" && (body.code < 200 || body.code >= 300)) {
    return false;
  }

  const response = body.data?.response;
  return response !== false;
}
