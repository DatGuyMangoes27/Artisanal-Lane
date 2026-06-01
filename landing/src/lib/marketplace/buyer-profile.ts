export type BuyerProfileIdentity = {
  display_name: string | null;
  email: string | null;
};

export function getBuyerProfileUpdate(formData: FormData) {
  return {
    display_name: String(formData.get("displayName") ?? "").trim(),
    phone: String(formData.get("phone") ?? "").trim(),
  };
}

export function getBuyerInitial(profile: BuyerProfileIdentity | null | undefined) {
  const source = profile?.display_name || profile?.email || "Buyer";
  return source.trim().charAt(0).toUpperCase();
}

export function profileAvatarStoragePath({
  userId,
  originalPath,
  timestampMillis,
}: {
  userId: string;
  originalPath: string;
  timestampMillis: number;
}) {
  const normalizedExtension = originalPath.split(".").pop()?.toLowerCase();
  const extension =
    normalizedExtension && normalizedExtension !== originalPath.toLowerCase()
      ? normalizedExtension
      : "jpg";

  return `${userId}/avatar-${timestampMillis}.${extension}`;
}
