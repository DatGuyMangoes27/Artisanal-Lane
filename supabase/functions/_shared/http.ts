export function jsonResponse(
  body: Record<string, unknown>,
  init: ResponseInit = {},
) {
  return new Response(JSON.stringify(body), {
    ...init,
    headers: {
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
}

export function getBearerToken(request: Request) {
  const header = request.headers.get("Authorization");
  if (!header?.startsWith("Bearer ")) {
    throw new Error("Missing bearer token.");
  }
  return header.replace("Bearer ", "");
}
