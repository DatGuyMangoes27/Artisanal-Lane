export function normalizeRequestUserId(value) {
  if (typeof value !== "string") return null;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

export function resolveRequestUserId({ requestUserId, resolvedUserId }) {
  return resolvedUserId ?? normalizeRequestUserId(requestUserId);
}
