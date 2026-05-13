export type SavedAddress = {
  id: string;
  name: string;
  street: string;
  city: string;
  postalCode: string;
  province: string;
  country: string;
  phone: string;
  isDefault: boolean;
};

type SavedAddressInput = Omit<SavedAddress, "id">;
type JsonRecord = Record<string, unknown>;

function toRecord(value: unknown): JsonRecord | null {
  return value != null && typeof value === "object" && !Array.isArray(value)
    ? (value as JsonRecord)
    : null;
}

function text(value: unknown) {
  return typeof value === "string" ? value.trim() : "";
}

export function mapSavedAddress(value: unknown, index: number): SavedAddress | null {
  const row = toRecord(value);
  if (!row) return null;

  const address = {
    id: text(row.id) || String(index),
    name: text(row.name),
    street: text(row.street),
    city: text(row.city),
    postalCode: text(row.postal_code ?? row.postalCode),
    province: text(row.province),
    country: text(row.country) || "South Africa",
    phone: text(row.phone),
    isDefault: row.is_default === true || row.isDefault === true,
  };

  return address.name && address.street && address.city && address.postalCode &&
      address.province && address.phone
    ? address
    : null;
}

export function normalizeSavedAddresses(value: unknown): SavedAddress[] {
  if (!Array.isArray(value)) return [];
  return value
    .map(mapSavedAddress)
    .filter((address): address is SavedAddress => address != null);
}

export function serializeSavedAddresses(addresses: SavedAddress[]) {
  return addresses.map((address) => ({
    name: address.name,
    street: address.street,
    city: address.city,
    postal_code: address.postalCode,
    province: address.province,
    country: address.country,
    phone: address.phone,
    is_default: address.isDefault,
  }));
}

export function getAddressSummary(address: SavedAddress) {
  return [address.street, address.city, address.province, address.postalCode]
    .filter(Boolean)
    .join(", ");
}

export function upsertSavedAddress(
  addresses: SavedAddress[],
  input: SavedAddressInput,
  id?: string,
) {
  const nextAddress: SavedAddress = {
    ...input,
    id: id ?? String(addresses.length),
  };

  const next = id
    ? addresses.map((address) => (address.id === id ? nextAddress : address))
    : [...addresses, nextAddress];

  if (!nextAddress.isDefault) {
    return next;
  }

  return next.map((address) => ({
    ...address,
    isDefault: address.id === nextAddress.id,
  }));
}
