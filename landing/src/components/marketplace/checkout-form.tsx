"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";

import { CheckoutGroupPayment } from "@/components/marketplace/checkout-group-payment";
import { useGuestCart } from "@/components/marketplace/guest-cart-provider";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  buildCartLines,
  buildCheckoutRequestBody,
  calculateCheckoutTotals,
  calculateShippingTotal,
  checkoutBlockingMessage,
  firstIncompleteCheckoutField,
  getAvailableShippingOptionsForCart,
  getCheckoutBlocker,
  getSavedAddressCheckoutFields,
  GIFT_SERVICE_FEE_PER_SHOP,
  groupCartLinesByShop,
  parseCheckoutResponse,
  requiresPickupPoint,
  requiresShippingAddress,
  type CheckoutGroupStatus,
  type ShopCartGroup,
} from "@/lib/marketplace/checkout";
import {
  forgetRememberedCheckoutGroup,
  lastCheckoutOrderStorageKey,
  markPendingCheckoutGroup,
  rememberCheckoutGroup,
  successPageHrefForGroup,
  takePendingCheckoutGroup,
} from "@/lib/marketplace/checkout-groups";
import {
  clearGuestCartReservationToken,
  getGuestCartReservationToken,
  reserveGuestCartItem,
} from "@/lib/marketplace/cart-reservations";
import { getAddressSummary, normalizeSavedAddresses, type SavedAddress } from "@/lib/marketplace/buyer-preferences";
import { formatPrice } from "@/lib/marketplace/format";
import { shippingMethodDescription, shippingMethodName } from "@/lib/marketplace/shipping";
import { formatRateEta, isBobGoQuoteExpired } from "@/lib/marketplace/bobgo-status";
import { useBobGoAvailabilityByShop } from "@/lib/marketplace/use-bobgo-availability";
import type { MarketplaceProduct, ShippingOption } from "@/lib/marketplace/types";
import { createClient } from "@/lib/supabase/browser";

const provinces = [
  "Eastern Cape",
  "Free State",
  "Gauteng",
  "KwaZulu-Natal",
  "Limpopo",
  "Mpumalanga",
  "Northern Cape",
  "North West",
  "Western Cape",
];

type BobGoRate = {
  rateResponseId: number;
  providerId: number;
  providerSlug: string;
  providerName: string;
  serviceLevelCode: string;
  serviceLevelName: string;
  description: string;
  serviceType: string;
  deliveryType: "door";
  amount: number;
  amountExcludingVat: number;
  chargedWeightKg: number;
  etaFrom?: string | null;
  etaTo?: string | null;
  etaMinDays?: number | null;
  etaMaxDays?: number | null;
};

type CourierGuyLocker = {
  code: string;
  name: string;
  address: string;
  landmark?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  detailed_address?: {
    province?: string;
    locality?: string;
    formatted_address?: string;
  };
  type?: {
    name?: string;
  };
  place?: {
    town?: string;
  };
};

type PargoPickupPoint = {
  code: string;
  name: string;
  address: string;
  city: string;
  province: string;
  postal_code?: string;
  latitude?: number | null;
  longitude?: number | null;
};

function marketPickupSummary(option: ShippingOption) {
  return [option.marketName, option.marketLocation, option.marketProvince]
    .filter((part) => Boolean(part?.trim()))
    .join(" • ");
}

function courierGuyLockerSummary(locker: CourierGuyLocker) {
  return [
    locker.code ? `${locker.name} (${locker.code})` : locker.name,
    locker.address || locker.detailed_address?.formatted_address,
    locker.detailed_address?.province,
  ].filter(Boolean).join(" • ");
}

function pargoPickupPointSummary(point: PargoPickupPoint) {
  return [
    point.code ? `${point.name} (${point.code})` : point.name,
    point.address,
    point.city,
    point.province,
  ].filter(Boolean).join(" • ");
}

function courierGuyLockerToOrderJson(locker: CourierGuyLocker) {
  return {
    carrier: "courier_guy",
    point_type: (locker.type?.name ?? "Locker").toLowerCase(),
    code: locker.code,
    name: locker.name,
    address: locker.address || locker.detailed_address?.formatted_address || "",
    city: locker.place?.town ?? locker.detailed_address?.locality ?? "",
    province: locker.detailed_address?.province ?? "",
    ...(locker.landmark ? { landmark: locker.landmark } : {}),
    ...(locker.latitude != null ? { latitude: locker.latitude } : {}),
    ...(locker.longitude != null ? { longitude: locker.longitude } : {}),
  };
}

function pargoPickupPointToOrderJson(point: PargoPickupPoint) {
  return {
    carrier: "pargo",
    point_type: "pickup_point",
    code: point.code,
    name: point.name,
    address: point.address,
    city: point.city,
    province: point.province,
    ...(point.postal_code ? { postal_code: point.postal_code } : {}),
    ...(point.latitude != null ? { latitude: point.latitude } : {}),
    ...(point.longitude != null ? { longitude: point.longitude } : {}),
  };
}

type BobGoShopState = {
  quoteId: string | null;
  fingerprint: string | null;
  expiresAt: string | null;
  rates: BobGoRate[];
  selectedRate: BobGoRate | null;
  isLoading: boolean;
  error: string | null;
};

const emptyBobGoState: BobGoShopState = {
  quoteId: null,
  fingerprint: null,
  expiresAt: null,
  rates: [],
  selectedRate: null,
  isLoading: false,
  error: null,
};

type ShopDelivery = ShopCartGroup & {
  options: ShippingOption[];
  selected: ShippingOption | null;
  shippingCost: number;
  bobGo: BobGoShopState;
};

type PendingCheckoutGroup = {
  checkoutGroupId: string;
  status: CheckoutGroupStatus;
  checkoutUrl: string | null;
  orderIds: string[];
  total: number | null;
};

function bobGoOption(amount: number | null | undefined): ShippingOption {
  return {
    key: "bobgo_door_to_door",
    enabled: true,
    price: amount ?? 0,
    marketName: null,
    marketLocation: null,
    marketProvince: null,
  };
}

/** The message create-checkout sent with a non-2xx answer, when there is one. */
async function functionErrorMessage(error: unknown, fallback: string) {
  const context = (error as { context?: unknown } | null)?.context;
  if (typeof Response !== "undefined" && context instanceof Response) {
    try {
      const payload = (await context.clone().json()) as { error?: unknown } | null;
      if (typeof payload?.error === "string" && payload.error.trim()) {
        return payload.error;
      }
    } catch {
      // Fall through to the generic message.
    }
  }
  return error instanceof Error && error.message ? error.message : fallback;
}

type ShopPickupSelection = {
  courierGuyLocker: CourierGuyLocker | null;
  pargoPoint: PargoPickupPoint | null;
  text: string;
};

const emptyPickupSelection: ShopPickupSelection = { courierGuyLocker: null, pargoPoint: null, text: "" };

function pickupSelectionSummary(method: string | null, selection: ShopPickupSelection) {
  if (method === "courier_guy" && selection.courierGuyLocker) {
    return courierGuyLockerSummary(selection.courierGuyLocker);
  }
  if (method === "pargo" && selection.pargoPoint) {
    return pargoPickupPointSummary(selection.pargoPoint);
  }
  return selection.text.trim();
}

/** The `pickup_point` saved on a shop's order (same shape as before), if any. */
function pickupPointForOrder(option: ShippingOption | null, selection: ShopPickupSelection) {
  if (option?.key === "market_pickup") {
    return {
      carrier: "market_pickup",
      point_type: "market",
      name: option.marketName,
      address: option.marketLocation,
      province: option.marketProvince,
    };
  }
  if (!option || !requiresPickupPoint(option.key)) {
    return null;
  }
  if (option.key === "courier_guy" && selection.courierGuyLocker) {
    return courierGuyLockerToOrderJson(selection.courierGuyLocker);
  }
  if (option.key === "pargo" && selection.pargoPoint) {
    return pargoPickupPointToOrderJson(selection.pargoPoint);
  }
  return selection.text.trim() || null;
}

/** Finds a Pudo locker or Pargo point for one shop's parcel. */
function PickupPointPicker({
  method,
  inputName,
  selection,
  onChange,
}: {
  method: string;
  inputName: string;
  selection: ShopPickupSelection;
  onChange: (selection: ShopPickupSelection) => void;
}) {
  const [courierGuyLockerProvince, setCourierGuyLockerProvince] = useState("");
  const [courierGuySearch, setCourierGuySearch] = useState("");
  const [courierGuyLockers, setCourierGuyLockers] = useState<CourierGuyLocker[]>([]);
  const [isLoadingCourierGuyLockers, setIsLoadingCourierGuyLockers] = useState(false);
  const [courierGuyLockerError, setCourierGuyLockerError] = useState<string | null>(null);
  const [pargoPointProvince, setPargoPointProvince] = useState("");
  const [pargoSearch, setPargoSearch] = useState("");
  const [pargoPickupPoints, setPargoPickupPoints] = useState<PargoPickupPoint[]>([]);
  const [isLoadingPargoPoints, setIsLoadingPargoPoints] = useState(false);
  const [pargoPointError, setPargoPointError] = useState<string | null>(null);

  const searchCourierGuyLockers = useCallback(
    async (query: string, province: string, notifyEmptyInput: boolean) => {
      if (query.length < 2 && province.length === 0) {
        setCourierGuyLockers([]);
        setCourierGuyLockerError(
          notifyEmptyInput ? "Choose a province or type at least two characters to search." : null,
        );
        setIsLoadingCourierGuyLockers(false);
        return;
      }

      setIsLoadingCourierGuyLockers(true);
      setCourierGuyLockerError(null);

      try {
        const response = await fetch("/api/marketplace/pickup-points/", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ carrier: "courier_guy", query, province, limit: 8 }),
        });
        const payload = (await response.json()) as { lockers?: CourierGuyLocker[]; error?: string } | null;

        if (!response.ok || payload?.error) {
          setCourierGuyLockers([]);
          setCourierGuyLockerError(payload?.error ?? "Could not load Pudo lockers.");
        } else {
          setCourierGuyLockers(payload?.lockers ?? []);
        }
      } catch {
        setCourierGuyLockers([]);
        setCourierGuyLockerError("Could not load Pudo lockers right now. Try again in a moment.");
      }

      setIsLoadingCourierGuyLockers(false);
    },
    [],
  );

  const searchPargoPickupPoints = useCallback(
    async (query: string, province: string, notifyEmptyInput: boolean) => {
      if (query.length < 2 && province.length === 0) {
        setPargoPickupPoints([]);
        setPargoPointError(
          notifyEmptyInput ? "Choose a province or type at least two characters to search." : null,
        );
        setIsLoadingPargoPoints(false);
        return;
      }

      setIsLoadingPargoPoints(true);
      setPargoPointError(null);

      try {
        const response = await fetch("/api/marketplace/pickup-points/", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ carrier: "pargo", query, province, limit: 8 }),
        });
        const payload = (await response.json()) as { points?: PargoPickupPoint[]; error?: string } | null;

        if (!response.ok || payload?.error) {
          setPargoPickupPoints([]);
          setPargoPointError(payload?.error ?? "Could not load Pargo pickup points.");
        } else {
          setPargoPickupPoints(payload?.points ?? []);
        }
      } catch {
        setPargoPickupPoints([]);
        setPargoPointError("Could not load Pargo pickup points right now. Try again in a moment.");
      }

      setIsLoadingPargoPoints(false);
    },
    [],
  );

  // Mirror mobile: search runs automatically (debounced) as the buyer types
  // or changes the province filter.
  useEffect(() => {
    if (method !== "courier_guy" || selection.courierGuyLocker) {
      return;
    }

    const timeout = window.setTimeout(() => {
      void searchCourierGuyLockers(courierGuySearch.trim(), courierGuyLockerProvince.trim(), false);
    }, 300);

    return () => window.clearTimeout(timeout);
  }, [
    method,
    courierGuySearch,
    courierGuyLockerProvince,
    selection.courierGuyLocker,
    searchCourierGuyLockers,
  ]);

  useEffect(() => {
    if (method !== "pargo" || selection.pargoPoint) {
      return;
    }

    const timeout = window.setTimeout(() => {
      void searchPargoPickupPoints(pargoSearch.trim(), pargoPointProvince.trim(), false);
    }, 300);

    return () => window.clearTimeout(timeout);
  }, [method, pargoSearch, pargoPointProvince, selection.pargoPoint, searchPargoPickupPoints]);

  return (
    <>
      {method === "courier_guy" ? (
        <>
          <p className="text-sm text-muted-foreground">
            Search and select the Pudo locker where you want to collect your parcel.
          </p>
          <div className="grid gap-3 sm:grid-cols-[180px_1fr_auto]">
            <select
              value={courierGuyLockerProvince}
              onChange={(event) => {
                setCourierGuyLockerProvince(event.target.value);
                onChange({ ...selection, courierGuyLocker: null, text: "" });
              }}
              className="rounded-xl border border-artisan-clay bg-white px-3 py-2 text-sm"
            >
              <option value="">All provinces</option>
              {provinces.map((province) => (
                <option key={province} value={province}>{province}</option>
              ))}
            </select>
            <input
              value={courierGuySearch}
              onChange={(event) => {
                setCourierGuySearch(event.target.value);
                onChange({ ...selection, courierGuyLocker: null, text: "" });
              }}
              placeholder="Type a mall, suburb, town, or locker code"
              className="rounded-xl border border-artisan-clay bg-white px-3 py-2 text-sm"
            />
            <Button
              type="button"
              variant="outline"
              onClick={() =>
                searchCourierGuyLockers(
                  courierGuySearch.trim(),
                  courierGuyLockerProvince.trim(),
                  true,
                )
              }
            >
              Search
            </Button>
          </div>
          {selection.courierGuyLocker ? (
            <div className="rounded-2xl border border-artisan-clay bg-background p-4 text-sm">
              <p className="font-semibold text-foreground">Selected locker</p>
              <p className="mt-1 text-muted-foreground">
                {courierGuyLockerSummary(selection.courierGuyLocker)}
              </p>
            </div>
          ) : null}
          {courierGuyLockerError ? (
            <p className="rounded-2xl border border-red-200 bg-red-50 p-3 text-sm text-red-700">
              {courierGuyLockerError}
            </p>
          ) : null}
          {isLoadingCourierGuyLockers ? (
            <p className="text-sm text-muted-foreground">Loading Pudo lockers...</p>
          ) : courierGuyLockers.length > 0 ? (
            <div className="divide-y overflow-hidden rounded-2xl border border-artisan-clay bg-background">
              {courierGuyLockers.map((locker) => (
                <button
                  key={`${locker.code}-${locker.name}`}
                  type="button"
                  onClick={() => {
                    onChange({ ...selection, courierGuyLocker: locker, text: courierGuyLockerSummary(locker) });
                    setCourierGuyLockers([]);
                    setCourierGuyLockerError(null);
                  }}
                  className="block w-full p-4 text-left text-sm transition hover:bg-secondary"
                >
                  <span className="block font-semibold text-foreground">
                    {locker.code ? `${locker.name} (${locker.code})` : locker.name}
                  </span>
                  <span className="mt-1 block text-muted-foreground">
                    {[locker.address, locker.landmark, locker.detailed_address?.province]
                      .filter(Boolean)
                      .join(" • ")}
                  </span>
                </button>
              ))}
            </div>
          ) : null}
        </>
      ) : method === "pargo" ? (
        <>
          <p className="text-sm text-muted-foreground">
            Search and select the Pargo pickup point where you want to collect your parcel.
          </p>
          <div className="grid gap-3 sm:grid-cols-[180px_1fr_auto]">
            <select
              value={pargoPointProvince}
              onChange={(event) => {
                setPargoPointProvince(event.target.value);
                onChange({ ...selection, pargoPoint: null, text: "" });
              }}
              className="rounded-xl border border-artisan-clay bg-white px-3 py-2 text-sm"
            >
              <option value="">All provinces</option>
              {provinces.map((province) => (
                <option key={province} value={province}>{province}</option>
              ))}
            </select>
            <input
              value={pargoSearch}
              onChange={(event) => {
                setPargoSearch(event.target.value);
                onChange({ ...selection, pargoPoint: null, text: "" });
              }}
              placeholder="Type a store, suburb, town, or point code"
              className="rounded-xl border border-artisan-clay bg-white px-3 py-2 text-sm"
            />
            <Button
              type="button"
              variant="outline"
              onClick={() =>
                searchPargoPickupPoints(pargoSearch.trim(), pargoPointProvince.trim(), true)
              }
            >
              Search
            </Button>
          </div>
          {selection.pargoPoint ? (
            <div className="rounded-2xl border border-artisan-clay bg-background p-4 text-sm">
              <p className="font-semibold text-foreground">Selected pickup point</p>
              <p className="mt-1 text-muted-foreground">
                {pargoPickupPointSummary(selection.pargoPoint)}
              </p>
            </div>
          ) : null}
          {pargoPointError ? (
            <p className="rounded-2xl border border-red-200 bg-red-50 p-3 text-sm text-red-700">
              {pargoPointError}
            </p>
          ) : null}
          {isLoadingPargoPoints ? (
            <p className="text-sm text-muted-foreground">Loading Pargo pickup points...</p>
          ) : pargoPickupPoints.length > 0 ? (
            <div className="divide-y overflow-hidden rounded-2xl border border-artisan-clay bg-background">
              {pargoPickupPoints.map((point) => (
                <button
                  key={`${point.code}-${point.name}`}
                  type="button"
                  onClick={() => {
                    onChange({ ...selection, pargoPoint: point, text: pargoPickupPointSummary(point) });
                    setPargoPickupPoints([]);
                    setPargoPointError(null);
                  }}
                  className="block w-full p-4 text-left text-sm transition hover:bg-secondary"
                >
                  <span className="block font-semibold text-foreground">
                    {point.code ? `${point.name} (${point.code})` : point.name}
                  </span>
                  <span className="mt-1 block text-muted-foreground">
                    {[point.address, point.city, point.province].filter(Boolean).join(" • ")}
                  </span>
                </button>
              ))}
            </div>
          ) : null}
        </>
      ) : (
        <label className="text-sm font-medium text-foreground">
          Pickup point
          <input
            name={inputName}
            required
            value={selection.text}
            onChange={(event) => onChange({ ...selection, text: event.target.value })}
            placeholder="Enter the pickup point or drop-off location"
            className="mt-2 w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
          />
        </label>
      )}
    </>
  );
}

export function CheckoutForm() {
  const router = useRouter();
  const { items, clearCart } = useGuestCart();
  const [products, setProducts] = useState<MarketplaceProduct[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isSignedIn, setIsSignedIn] = useState<boolean | null>(null);
  const [shippingMethods, setShippingMethods] = useState<Record<string, string | null>>({});
  const [savedAddresses, setSavedAddresses] = useState<SavedAddress[]>([]);
  const [selectedAddressId, setSelectedAddressId] = useState("");
  const [isGift, setIsGift] = useState(false);
  const [giftRecipient, setGiftRecipient] = useState("");
  const [giftMessage, setGiftMessage] = useState("");
  const [couponCode, setCouponCode] = useState("");
  // Each shop has its own pickup point and Bob Go quote: each artisan sends their own parcel.
  const [pickupByShop, setPickupByShop] = useState<Record<string, ShopPickupSelection>>({});
  const [bobGoByShop, setBobGoByShop] = useState<Record<string, BobGoShopState>>({});
  const [pendingGroup, setPendingGroup] = useState<PendingCheckoutGroup | null>(null);
  const [addressFields, setAddressFields] = useState({
    name: "",
    phone: "",
    street: "",
    localArea: "",
    city: "",
    postalCode: "",
    province: "",
  });

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then(async (result: { data: { user: { id: string } | null } }) => {
      const user = result.data.user;
      setIsSignedIn(Boolean(user));

      if (!user) {
        return;
      }

      const { data } = await supabase.rpc("get_my_profile");

      const profile = (data?.[0] as { shipping_addresses?: unknown } | undefined) ?? null;
      const addresses = normalizeSavedAddresses(profile?.shipping_addresses);
      setSavedAddresses(addresses);
      const defaultAddress = addresses.find((address) => address.isDefault) ?? addresses[0];
      if (defaultAddress) {
        setSelectedAddressId(defaultAddress.id);
        setAddressFields(getSavedAddressCheckoutFields(defaultAddress));
      }
    });
  }, []);

  useEffect(() => {
    let isCurrent = true;

    fetch("/api/marketplace/cart", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ items, reservationToken: getGuestCartReservationToken() }),
    })
      .then((response) => response.json() as Promise<{ products: MarketplaceProduct[] }>)
      .then((payload) => {
        if (isCurrent) {
          setProducts(payload.products);
        }
      })
      .finally(() => {
        if (isCurrent) {
          setIsLoading(false);
        }
      });

    return () => {
      isCurrent = false;
    };
  }, [items]);

  const lines = useMemo(() => buildCartLines(items, products), [items, products]);
  const shopGroups = useMemo(() => groupCartLinesByShop(lines), [lines]);
  const isMultiShop = shopGroups.length > 1;
  const deliveryFingerprint = useMemo(
    () => JSON.stringify({
      name: addressFields.name.trim(),
      phone: addressFields.phone.trim(),
      street: addressFields.street.trim(),
      localArea: addressFields.localArea.trim(),
      city: addressFields.city.trim(),
      province: addressFields.province.trim(),
      postalCode: addressFields.postalCode.trim(),
    }),
    [addressFields],
  );
  const bobGoFingerprints = useMemo(
    () => Object.fromEntries(
      shopGroups.map((shop) => [
        shop.shopId,
        JSON.stringify({
          items: shop.lines
            .map((line) => ({ productId: line.productId, quantity: line.quantity }))
            .sort((left, right) => left.productId.localeCompare(right.productId)),
          delivery: deliveryFingerprint,
        }),
      ]),
    ) as Record<string, string>,
    [deliveryFingerprint, shopGroups],
  );
  const bobGoFlagEnabled =
    process.env.NEXT_PUBLIC_BOBGO_SHIPPING_ENABLED === "true" || process.env.NODE_ENV === "development";
  // Bob Go is offered for a shop only when the server confirms this artisan
  // enabled it with complete collection details and every product has parcel sizes.
  const bobGoShopIds = useBobGoAvailabilityByShop(lines, bobGoFlagEnabled);
  const shopDeliveries = useMemo<ShopDelivery[]>(
    () => shopGroups.map((shop) => {
      const bobGo = bobGoByShop[shop.shopId] ?? emptyBobGoState;
      const staticOptions = getAvailableShippingOptionsForCart(shop.lines);
      const options = bobGoShopIds.has(shop.shopId)
        ? [...staticOptions, bobGoOption(bobGo.selectedRate?.amount)]
        : staticOptions;
      const selected = options.find((option) => option.key === shippingMethods[shop.shopId]) ?? null;
      const shippingCost = selected?.key === "bobgo_door_to_door"
        ? bobGo.selectedRate?.amount ?? 0
        : selected
          ? calculateShippingTotal(shop.lines, selected.key)
          : 0;
      return { ...shop, options, selected, shippingCost, bobGo };
    }),
    [bobGoByShop, bobGoShopIds, shippingMethods, shopGroups],
  );
  const totals = calculateCheckoutTotals(
    shopDeliveries.map((shop) => ({
      shopId: shop.shopId,
      shopName: shop.shopName,
      subtotal: shop.subtotal,
      shippingCost: shop.shippingCost,
    })),
    isGift,
  );
  const blocker = getCheckoutBlocker(lines, { allowDynamicShipping: (shopId) => bobGoShopIds.has(shopId) });
  const selectedKeys = shopDeliveries.map((shop) => shop.selected?.key ?? null);
  const allShopsSelected = shopDeliveries.length > 0 && selectedKeys.every((key) => key != null);
  const needsShippingAddress = selectedKeys.some((key) => requiresShippingAddress(key));
  const bobGoShops = shopDeliveries.filter((shop) => shop.selected?.key === "bobgo_door_to_door");
  const isMissingBobGoRate = bobGoShops.some((shop) => !shop.bobGo.selectedRate);

  // Default each shop to its first delivery option, preferring one another
  // shop already uses so the basket is delivered the same way where possible.
  useEffect(() => {
    const chosen = new Set(Object.values(shippingMethods).filter((key): key is string => Boolean(key)));
    const updates: Record<string, string | null> = {};
    for (const shop of shopDeliveries) {
      const current = shippingMethods[shop.shopId] ?? null;
      if (current && shop.options.some((option) => option.key === current)) continue;
      const next = (shop.options.find((option) => chosen.has(option.key)) ?? shop.options[0])?.key ?? null;
      if (next !== current) {
        updates[shop.shopId] = next;
      }
    }
    if (Object.keys(updates).length > 0) {
      setShippingMethods((current) => ({ ...current, ...updates }));
    }
  }, [shippingMethods, shopDeliveries]);

  const updateBobGo = useCallback(
    (shopId: string, update: (current: BobGoShopState) => BobGoShopState) => {
      setBobGoByShop((current) => ({
        ...current,
        [shopId]: update(current[shopId] ?? emptyBobGoState),
      }));
    },
    [],
  );

  const requestBobGoRates = useCallback(
    async (shop: ShopCartGroup) => {
      const fingerprint = bobGoFingerprints[shop.shopId] ?? null;
      updateBobGo(shop.shopId, () => ({ ...emptyBobGoState, isLoading: true }));

      try {
        const supabase = createClient();
        const {
          data: { user },
        } = await supabase.auth.getUser();
        if (!user) {
          throw new Error("Sign in before requesting a Bob Go delivery rate.");
        }

        // Only this shop's items: the quote is saved per shop and buyer.
        const response = await fetch("/api/marketplace/bobgo/rates/", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            items: shop.lines.map((line) => ({
              productId: line.productId,
              quantity: line.quantity,
            })),
            delivery: {
              fullName: addressFields.name,
              email: user.email,
              phone: addressFields.phone,
              streetAddress: addressFields.street,
              localArea: addressFields.localArea,
              city: addressFields.city,
              province: addressFields.province,
              postalCode: addressFields.postalCode,
            },
          }),
        });
        const payload = (await response.json()) as {
          quoteId?: string;
          expiresAt?: string;
          rates?: BobGoRate[];
          error?: string;
        };
        if (!response.ok || payload.error || !payload.quoteId || !payload.rates?.length) {
          throw new Error(payload.error ?? "Bob Go returned no door-to-door rates.");
        }

        updateBobGo(shop.shopId, () => ({
          ...emptyBobGoState,
          quoteId: payload.quoteId ?? null,
          expiresAt: payload.expiresAt ?? null,
          fingerprint,
          rates: payload.rates ?? [],
        }));
      } catch (rateError) {
        updateBobGo(shop.shopId, () => ({
          ...emptyBobGoState,
          error: rateError instanceof Error ? rateError.message : "Could not load Bob Go rates.",
        }));
      }
    },
    [addressFields, bobGoFingerprints, updateBobGo],
  );

  // A quote only fits the basket and address it was made for.
  useEffect(() => {
    const staleShopIds = Object.entries(bobGoByShop)
      .filter(([shopId, state]) => state.quoteId && state.fingerprint !== bobGoFingerprints[shopId])
      .map(([shopId]) => shopId);
    if (staleShopIds.length === 0) return;
    setBobGoByShop((current) => {
      const next = { ...current };
      for (const shopId of staleShopIds) {
        next[shopId] = {
          ...emptyBobGoState,
          error: "Your basket or address changed. Request a fresh Bob Go rate.",
        };
      }
      return next;
    });
  }, [bobGoByShop, bobGoFingerprints]);

  // Saved quotes live for 20 minutes server-side. Drop an expired one here so
  // the buyer is asked for a fresh rate instead of hitting a checkout error.
  useEffect(() => {
    const timers: number[] = [];
    for (const [shopId, state] of Object.entries(bobGoByShop)) {
      if (!state.quoteId || !state.expiresAt) continue;
      const quoteId = state.quoteId;
      const expire = () =>
        updateBobGo(shopId, (current) =>
          current.quoteId === quoteId
            ? { ...emptyBobGoState, error: "Your delivery quote expired. Request a fresh Bob Go rate." }
            : current,
        );
      const remaining = new Date(state.expiresAt).getTime() - Date.now();
      timers.push(window.setTimeout(expire, Number.isNaN(remaining) ? 0 : Math.max(0, remaining)));
    }
    return () => timers.forEach((timer) => window.clearTimeout(timer));
  }, [bobGoByShop, updateBobGo]);

  // Mirror mobile: switching delivery method clears that shop's pickup-point
  // and Bob Go state so stale selections are never submitted.
  function selectShippingMethod(shopId: string, key: string) {
    if (shippingMethods[shopId] !== key) {
      setPickupByShop((current) => ({ ...current, [shopId]: emptyPickupSelection }));
    }
    setShippingMethods((current) => ({ ...current, [shopId]: key }));
    if (key !== "bobgo_door_to_door") {
      updateBobGo(shopId, () => emptyBobGoState);
    }
  }

  function pickupSelectionFor(shopId: string) {
    return pickupByShop[shopId] ?? emptyPickupSelection;
  }

  function finishPaidCheckout(checkoutGroupId: string) {
    takePendingCheckoutGroup(checkoutGroupId);
    clearCart();
    clearGuestCartReservationToken();
    router.push(successPageHrefForGroup(checkoutGroupId));
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    if (blocker) {
      setError(blocker);
      return;
    }

    const pickupShops = shopDeliveries.filter((shop) => requiresPickupPoint(shop.selected?.key ?? null));
    const shopMissingPickup = pickupShops.find(
      (shop) => !pickupSelectionSummary(shop.selected?.key ?? null, pickupSelectionFor(shop.shopId)),
    );
    const incompleteField = firstIncompleteCheckoutField({
      fullName: addressFields.name,
      streetAddress: addressFields.street,
      city: addressFields.city,
      postalCode: addressFields.postalCode,
      province: addressFields.province,
      phoneNumber: addressFields.phone,
      selectedShippingMethod: allShopsSelected ? selectedKeys[0] : null,
      hasAvailableShippingMethods: shopDeliveries.every((shop) => shop.options.length > 0),
      requiresShippingAddress: needsShippingAddress,
      requiresPickupPoint: pickupShops.length > 0,
      pickupPoint: shopMissingPickup ? "" : "selected",
    });

    if (incompleteField || !allShopsSelected) {
      const shopWithoutOption = shopDeliveries.find((shop) => !shop.selected);
      const message = checkoutBlockingMessage(incompleteField ?? "shippingMethod");
      setError(
        isMultiShop && shopWithoutOption && (incompleteField ?? "shippingMethod") === "shippingMethod"
          ? `${shopWithoutOption.shopName}: please choose a delivery option.`
          : isMultiShop && shopMissingPickup && incompleteField === "pickupPoint"
            ? `${shopMissingPickup.shopName}: ${message}`
            : message,
      );
      return;
    }
    for (const shop of bobGoShops) {
      const prefix = isMultiShop ? `${shop.shopName}: ` : "";
      if (!shop.bobGo.quoteId || !shop.bobGo.selectedRate) {
        setError(`${prefix}Request and select a Bob Go door-to-door rate before payment.`);
        return;
      }
      if (isBobGoQuoteExpired(shop.bobGo.expiresAt)) {
        setError(`${prefix}Your delivery quote expired. Request a fresh Bob Go rate before payment.`);
        return;
      }
    }

    const supabase = createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      router.push("/login?redirect=/checkout");
      return;
    }

    setIsSubmitting(true);

    try {
      const reservationToken = getGuestCartReservationToken();
      await Promise.all(
        lines
          // Made-to-order lines are produced on demand and never reserve stock.
          .filter((line) => !line.isMadeToOrder)
          .map((line) =>
            reserveGuestCartItem({
              productId: line.productId,
              variantId: line.variantId,
              quantity: line.quantity,
            }),
          ),
      );

      const { data: cart, error: cartError } = await supabase
        .from("carts")
        .upsert({ user_id: user.id }, { onConflict: "user_id" })
        .select("id")
        .single();

      if (cartError || !cart) {
        throw new Error(cartError?.message ?? "Could not prepare your cart.");
      }

      await supabase.from("cart_items").delete().eq("cart_id", cart.id);
      const { error: itemsError } = await supabase.from("cart_items").insert(
        lines.map((line) => ({
          cart_id: cart.id,
          product_id: line.productId,
          variant_id: line.variantId,
          quantity: line.quantity,
          is_made_to_order: line.isMadeToOrder,
          custom_note: line.isMadeToOrder ? line.customNote : null,
        })),
      );

      if (itemsError) {
        throw new Error(itemsError.message);
      }

      const pickupPointFor = (shop: ShopDelivery) =>
        pickupPointForOrder(shop.selected, pickupSelectionFor(shop.shopId));
      const singleShopPickup = isMultiShop ? null : pickupPointFor(shopDeliveries[0]);
      // The buyer's contact and door address apply to every shop. A one-shop
      // basket keeps its pickup point here as before; with several shops each
      // shop's pickup point travels in its own entry.
      const shippingAddress = {
        name: addressFields.name.trim(),
        country: "South Africa",
        phone: addressFields.phone.trim(),
        ...(needsShippingAddress
          ? {
              street: addressFields.street.trim(),
              local_area: addressFields.localArea.trim() || addressFields.city.trim(),
              city: addressFields.city.trim(),
              postal_code: addressFields.postalCode.trim(),
              province: addressFields.province.trim(),
            }
          : {}),
        ...(singleShopPickup ? { pickup_point: singleShopPickup } : {}),
      };

      const { data, error: checkoutError } = await supabase.functions.invoke("create-checkout", {
        body: buildCheckoutRequestBody({
          userId: user.id,
          reservationToken,
          shippingAddress,
          shops: shopDeliveries.map((shop) => ({
            shopId: shop.shopId,
            shippingMethod: shop.selected!.key,
            shippingCost: shop.shippingCost,
            shippingAddress: isMultiShop && pickupPointFor(shop)
              ? { pickup_point: pickupPointFor(shop) }
              : null,
            bobgo: shop.selected!.key === "bobgo_door_to_door"
              ? {
                  quoteId: shop.bobGo.quoteId,
                  rateResponseId: shop.bobGo.selectedRate?.rateResponseId ?? null,
                  providerSlug: shop.bobGo.selectedRate?.providerSlug ?? null,
                  serviceLevelCode: shop.bobGo.selectedRate?.serviceLevelCode ?? null,
                }
              : null,
          })),
          isGift,
          giftRecipient,
          giftMessage,
          couponCode,
        }),
      });

      if (checkoutError) {
        throw new Error(await functionErrorMessage(checkoutError, "Checkout failed."));
      }
      const result = parseCheckoutResponse(data);

      if (result.kind === "error") {
        throw new Error(result.message);
      }

      if (result.kind === "single") {
        clearCart();
        clearGuestCartReservationToken();
        forgetRememberedCheckoutGroup();
        if (result.orderId) {
          window.sessionStorage.setItem(lastCheckoutOrderStorageKey, result.orderId);
        }
        window.location.assign(result.checkoutUrl);
        return;
      }

      // Several shops: one payment for the basket. Keep the cart until the
      // payment arrives so the buyer can try again if it expires.
      rememberCheckoutGroup(result.checkoutGroupId, result.orderIds[0] ?? null);
      markPendingCheckoutGroup(result.checkoutGroupId);
      if (result.status === "funded") {
        finishPaidCheckout(result.checkoutGroupId);
        return;
      }
      setPendingGroup({
        checkoutGroupId: result.checkoutGroupId,
        status: result.status,
        checkoutUrl: result.checkoutUrl,
        orderIds: result.orderIds,
        total: result.total,
      });
      setIsSubmitting(false);
      window.scrollTo({ top: 0, behavior: "smooth" });
    } catch (checkoutError) {
      setError(checkoutError instanceof Error ? checkoutError.message : "Checkout failed.");
      setIsSubmitting(false);
    }
  }

  if (pendingGroup) {
    return (
      <section className="mx-auto max-w-3xl px-4 py-10 sm:px-6 lg:px-8">
        <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
          Checkout
        </p>
        <div className="mt-6">
          <CheckoutGroupPayment
            checkoutGroupId={pendingGroup.checkoutGroupId}
            initialStatus={pendingGroup.status}
            initialCheckoutUrl={pendingGroup.checkoutUrl}
            initialOrderIds={pendingGroup.orderIds}
            total={pendingGroup.total}
            showOrdersWhenFunded={false}
            onFunded={(state) => finishPaidCheckout(state.checkoutGroupId)}
            onSettled={(state) => {
              if (state.status === "cancelled") {
                takePendingCheckoutGroup(state.checkoutGroupId);
                forgetRememberedCheckoutGroup();
              }
            }}
          />
        </div>
      </section>
    );
  }

  if (isLoading || isSignedIn == null) {
    return (
      <section className="mx-auto max-w-3xl px-4 py-16 sm:px-6 lg:px-8">
        <Card className="border-artisan-clay bg-card">
          <CardContent className="p-6 text-muted-foreground">Preparing checkout...</CardContent>
        </Card>
      </section>
    );
  }

  if (!isSignedIn) {
    return (
      <section className="mx-auto max-w-3xl px-4 py-16 text-center sm:px-6 lg:px-8">
        <h1 className="font-serif text-4xl font-bold tracking-tight text-foreground">
          Sign in to continue checkout
        </h1>
        <p className="mt-4 text-muted-foreground">
          You can browse as a guest, but payment needs an Artisan Lane account so we can attach the
          order to you.
        </p>
        <Button asChild size="lg" className="mt-8 rounded-full">
          <Link href="/login?redirect=/checkout">Sign in or create account</Link>
        </Button>
      </section>
    );
  }

  const selectedSavedAddress = savedAddresses.find((address) => address.id === selectedAddressId) ?? null;
  const giftFeeCopy = isMultiShop
    ? `Add recipient details and a note. A R${GIFT_SERVICE_FEE_PER_SHOP} gift service fee is added per shop (${formatPrice(totals.giftFee || GIFT_SERVICE_FEE_PER_SHOP * shopGroups.length)} for ${shopGroups.length} shops), because each artisan wraps their own parcel.`
    : `Add recipient details and a note. A R${GIFT_SERVICE_FEE_PER_SHOP} gift service fee will be added.`;

  function renderDeliveryOptions(shop: ShopDelivery) {
    return (
      <>
        <div className="grid gap-3">
          {shop.options.map((option) => (
            <label
              key={option.key}
              className="flex cursor-pointer items-center justify-between gap-4 rounded-2xl border border-artisan-clay bg-background p-4"
            >
              <span>
                <span className="block font-semibold text-foreground">
                  {shippingMethodName(option.key)}
                </span>
                {shippingMethodDescription(option.key) ? (
                  <span className="mt-1 block text-sm text-muted-foreground">
                    {shippingMethodDescription(option.key)}
                  </span>
                ) : null}
                {option.key === "market_pickup" && marketPickupSummary(option) ? (
                  <span className="mt-1 block text-sm text-muted-foreground">
                    {marketPickupSummary(option)}
                  </span>
                ) : null}
              </span>
              <span className="flex items-center gap-3">
                <span className="text-sm font-semibold text-foreground">
                  {option.key === "bobgo_door_to_door"
                    ? shop.bobGo.selectedRate
                      ? formatPrice(shop.bobGo.selectedRate.amount)
                      : "Quote required"
                    : calculateShippingTotal(shop.lines, option.key) === 0
                      ? "FREE"
                      : formatPrice(calculateShippingTotal(shop.lines, option.key))}
                </span>
                <input
                  type="radio"
                  name={isMultiShop ? `shippingMethod-${shop.shopId}` : "shippingMethod"}
                  value={option.key}
                  checked={shop.selected?.key === option.key}
                  onChange={() => selectShippingMethod(shop.shopId, option.key)}
                />
              </span>
            </label>
          ))}
        </div>
        {shop.selected?.key === "market_pickup" ? (
          <p className="rounded-2xl border border-artisan-clay bg-background p-4 text-sm text-muted-foreground">
            {marketPickupSummary(shop.selected)
              ? `Market pickup: ${marketPickupSummary(shop.selected)}. Please only choose this if you can collect from this market.`
              : "For market pickup, please message the seller after checkout to confirm which market, date, and collection time applies to your order."}
          </p>
        ) : null}
      </>
    );
  }

  function renderPickupPicker(shop: ShopDelivery) {
    const method = shop.selected?.key ?? null;
    if (!method || !requiresPickupPoint(method)) return null;
    return (
      <PickupPointPicker
        key={`${shop.shopId}-${method}`}
        method={method}
        inputName={isMultiShop ? `pickupPoint-${shop.shopId}` : "pickupPoint"}
        selection={pickupSelectionFor(shop.shopId)}
        onChange={(selection) => setPickupByShop((current) => ({ ...current, [shop.shopId]: selection }))}
      />
    );
  }

  function renderBobGoRates(shop: ShopDelivery) {
    const bobGo = shop.bobGo;
    return (
      <div key={shop.shopId} className="space-y-4 sm:col-span-2">
        {isMultiShop ? (
          <p className="font-semibold text-foreground">Bob Go rates for {shop.shopName}</p>
        ) : null}
        <Button
          type="button"
          variant="outline"
          disabled={bobGo.isLoading}
          onClick={() => void requestBobGoRates(shop)}
          className="rounded-full"
        >
          {bobGo.isLoading ? "Getting live rates..." : "Get Bob Go door-to-door rates"}
        </Button>
        {bobGo.error ? (
          <p className="rounded-2xl border border-red-200 bg-red-50 p-3 text-sm text-red-700">
            {bobGo.error}
          </p>
        ) : null}
        {bobGo.rates.length > 0 ? (
          <div className="grid gap-3">
            {bobGo.rates.map((rate) => (
              <label
                key={`${rate.rateResponseId}-${rate.serviceLevelCode}`}
                className="flex cursor-pointer items-start justify-between gap-4 rounded-2xl border border-artisan-clay bg-background p-4"
              >
                <span>
                  <span className="block font-semibold text-foreground">
                    {rate.providerName} · {rate.serviceLevelName}
                  </span>
                  <span className="mt-1 block text-sm text-muted-foreground">
                    {rate.description} · charged weight {rate.chargedWeightKg} kg
                  </span>
                  {formatRateEta(rate) ? (
                    <span className="mt-1 block text-sm text-muted-foreground">
                      {formatRateEta(rate)}
                    </span>
                  ) : null}
                </span>
                <span className="flex items-center gap-3">
                  <span className="text-right">
                    <span className="block font-semibold">{formatPrice(rate.amount)}</span>
                    <span className="block text-xs text-muted-foreground">incl. VAT</span>
                  </span>
                  <input
                    type="radio"
                    name={isMultiShop ? `bobGoRate-${shop.shopId}` : "bobGoRate"}
                    checked={
                      bobGo.selectedRate?.rateResponseId === rate.rateResponseId &&
                      bobGo.selectedRate?.serviceLevelCode === rate.serviceLevelCode
                    }
                    onChange={() => updateBobGo(shop.shopId, (current) => ({ ...current, selectedRate: rate }))}
                  />
                </span>
              </label>
            ))}
          </div>
        ) : null}
      </div>
    );
  }

  return (
    <form
      onSubmit={handleSubmit}
      className="mx-auto grid max-w-7xl gap-8 px-4 py-10 sm:px-6 lg:grid-cols-[1fr_380px] lg:px-8"
    >
      <div className="space-y-8">
        <div>
          <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
            Checkout
          </p>
          <h1 className="mt-3 font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
            Delivery details
          </h1>
          {isMultiShop ? (
            <p className="mt-3 text-muted-foreground">
              You&apos;re buying from {shopGroups.length} shops. Each artisan sends their own parcel, so
              choose delivery for each shop. You pay once for everything.
            </p>
          ) : null}
        </div>

        <Card className="border-artisan-clay bg-card">
          <CardContent className="grid gap-4 p-6 sm:grid-cols-2">
            <p className="rounded-2xl border border-artisan-clay bg-background p-4 text-sm text-muted-foreground sm:col-span-2">
              {allShopsSelected && !needsShippingAddress
                ? "We only need your name and phone number for this collection method. No delivery address is required."
                : "Orders can be placed from abroad, but delivery addresses must be within South Africa."}
            </p>
            {savedAddresses.length > 0 ? (
              <label className="space-y-2 text-sm font-medium text-foreground sm:col-span-2">
                Saved delivery address
                <select
                  value={selectedAddressId}
                  onChange={(event) => {
                    const addressId = event.target.value;
                    setSelectedAddressId(addressId);
                    const address = savedAddresses.find((candidate) => candidate.id === addressId);
                    if (address) {
                      setAddressFields(getSavedAddressCheckoutFields(address));
                    }
                  }}
                  className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                >
                  <option value="">Enter a new address</option>
                  {savedAddresses.map((address) => (
                    <option key={address.id} value={address.id}>
                      {address.name} - {getAddressSummary(address)}
                    </option>
                  ))}
                </select>
                {selectedSavedAddress ? (
                  <span className="block text-xs font-normal text-muted-foreground">
                    Using {getAddressSummary(selectedSavedAddress)}
                  </span>
                ) : null}
              </label>
            ) : null}
            <label className="space-y-2 text-sm font-medium text-foreground">
              Full name
              <input
                name="name"
                required
                value={addressFields.name}
                onChange={(event) => setAddressFields((current) => ({ ...current, name: event.target.value }))}
                className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
              />
            </label>
            <label className="space-y-2 text-sm font-medium text-foreground">
              Phone number
              <input
                name="phone"
                required
                value={addressFields.phone}
                onChange={(event) => setAddressFields((current) => ({ ...current, phone: event.target.value }))}
                className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
              />
            </label>
          </CardContent>
        </Card>

        {isMultiShop ? (
          shopDeliveries.map((shop) => (
            <Card key={shop.shopId} className="border-artisan-clay bg-card">
              <CardContent className="space-y-4 p-6">
                <div className="flex flex-wrap items-baseline justify-between gap-2">
                  <h2 className="font-serif text-2xl font-bold text-foreground">Delivery from {shop.shopName}</h2>
                  <span className="text-sm text-muted-foreground">
                    {shop.quantity} {shop.quantity === 1 ? "item" : "items"}
                  </span>
                </div>
                <ul className="space-y-1 text-sm">
                  {shop.lines.map((line) => (
                    <li key={line.key} className="flex justify-between gap-4">
                      <span className="text-muted-foreground">
                        {line.title}
                        {line.variantName ? ` · ${line.variantName}` : ""} × {line.quantity}
                      </span>
                      <span className="font-medium text-foreground">{formatPrice(line.lineTotal)}</span>
                    </li>
                  ))}
                </ul>
                {shop.options.length === 0 ? (
                  <p className="rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm text-amber-800">
                    These items do not share a delivery option yet.
                  </p>
                ) : (
                  renderDeliveryOptions(shop)
                )}
                {renderPickupPicker(shop)}
              </CardContent>
            </Card>
          ))
        ) : shopDeliveries[0] ? (
          <Card className="border-artisan-clay bg-card">
            <CardContent className="space-y-4 p-6">
              <h2 className="font-serif text-2xl font-bold text-foreground">Delivery option</h2>
              {renderDeliveryOptions(shopDeliveries[0])}
            </CardContent>
          </Card>
        ) : null}

        {needsShippingAddress ? (
          <Card className="border-artisan-clay bg-card">
            <CardContent className="grid gap-4 p-6 sm:grid-cols-2">
              <label className="space-y-2 text-sm font-medium text-foreground sm:col-span-2">
                Street address
                <input
                  name="street"
                  required
                  value={addressFields.street}
                  onChange={(event) => setAddressFields((current) => ({ ...current, street: event.target.value }))}
                  className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                />
              </label>
              {bobGoShops.length > 0 ? (
                <label className="space-y-2 text-sm font-medium text-foreground sm:col-span-2">
                  Suburb / local area
                  <input
                    name="localArea"
                    required
                    value={addressFields.localArea}
                    onChange={(event) =>
                      setAddressFields((current) => ({ ...current, localArea: event.target.value }))
                    }
                    className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                  />
                </label>
              ) : null}
              <label className="space-y-2 text-sm font-medium text-foreground">
                City
                <input
                  name="city"
                  required
                  value={addressFields.city}
                  onChange={(event) => setAddressFields((current) => ({ ...current, city: event.target.value }))}
                  className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                />
              </label>
              <label className="space-y-2 text-sm font-medium text-foreground">
                Postal code
                <input
                  name="postalCode"
                  required
                  value={addressFields.postalCode}
                  onChange={(event) =>
                    setAddressFields((current) => ({ ...current, postalCode: event.target.value }))
                  }
                  className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                />
              </label>
              <label className="space-y-2 text-sm font-medium text-foreground sm:col-span-2">
                Province
                <select
                  name="province"
                  required
                  value={addressFields.province}
                  onChange={(event) =>
                    setAddressFields((current) => ({ ...current, province: event.target.value }))
                  }
                  className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                >
                  <option value="">Choose province</option>
                  {provinces.map((province) => (
                    <option key={province} value={province}>{province}</option>
                  ))}
                </select>
              </label>
              {bobGoShops.map((shop) => renderBobGoRates(shop))}
            </CardContent>
          </Card>
        ) : null}

        {!isMultiShop && shopDeliveries[0] && requiresPickupPoint(shopDeliveries[0].selected?.key ?? null) ? (
          <Card className="border-artisan-clay bg-card">
            <CardContent className="space-y-4 p-6">{renderPickupPicker(shopDeliveries[0])}</CardContent>
          </Card>
        ) : null}

        <Card className="border-artisan-clay bg-card">
          <CardContent className="space-y-4 p-6">
            <label className="flex cursor-pointer items-start gap-3 text-sm">
              <input
                type="checkbox"
                checked={isGift}
                onChange={(event) => setIsGift(event.target.checked)}
                className="mt-1"
              />
              <span>
                <span className="block font-semibold text-foreground">This is a gift</span>
                <span className="mt-1 block text-muted-foreground">{giftFeeCopy}</span>
              </span>
            </label>
            {isGift ? (
              <div className="grid gap-4 sm:grid-cols-2">
                <label className="space-y-2 text-sm font-medium text-foreground">
                  Recipient name
                  <input
                    value={giftRecipient}
                    onChange={(event) => setGiftRecipient(event.target.value)}
                    className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                    placeholder="Optional"
                  />
                </label>
                <label className="space-y-2 text-sm font-medium text-foreground sm:col-span-2">
                  Gift message
                  <textarea
                    value={giftMessage}
                    onChange={(event) => setGiftMessage(event.target.value)}
                    rows={3}
                    className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                    placeholder="Optional message for the recipient"
                  />
                </label>
              </div>
            ) : null}
          </CardContent>
        </Card>
      </div>

      <aside className="h-fit rounded-[2rem] border border-artisan-clay bg-card p-6 shadow-sm">
        <h2 className="font-serif text-2xl font-bold text-foreground">Payment summary</h2>
        <label className="mt-5 block space-y-2 text-sm font-medium text-foreground">
          Discount code
          <input
            value={couponCode}
            onChange={(event) => setCouponCode(event.target.value.toUpperCase())}
            className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2 uppercase"
            placeholder="Enter shop code"
            maxLength={32}
          />
          <span className="block text-xs font-normal text-muted-foreground">
            {isMultiShop
              ? "A code belongs to one shop and comes off that shop's items. It is checked securely before TradeSafe payment."
              : "Your code is checked securely and the discount is applied before TradeSafe payment."}
          </span>
        </label>
        {isMultiShop ? (
          <div className="mt-6 space-y-4 text-sm">
            {totals.shops.map((shop) => (
              <div key={shop.shopId} className="space-y-1 rounded-2xl border border-artisan-clay bg-background p-3">
                <p className="font-semibold text-foreground">{shop.shopName}</p>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Items</span>
                  <span className="text-foreground">{formatPrice(shop.subtotal)}</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-muted-foreground">Delivery</span>
                  <span className="text-foreground">
                    {shop.shippingCost === 0 ? "FREE" : formatPrice(shop.shippingCost)}
                  </span>
                </div>
                {isGift ? (
                  <div className="flex justify-between">
                    <span className="text-muted-foreground">Gift fee</span>
                    <span className="text-foreground">{formatPrice(shop.giftFee)}</span>
                  </div>
                ) : null}
                <div className="flex justify-between font-semibold">
                  <span className="text-foreground">Shop total</span>
                  <span className="text-foreground">{formatPrice(shop.total)}</span>
                </div>
              </div>
            ))}
          </div>
        ) : null}
        <div className="mt-6 space-y-3 text-sm">
          <div className="flex justify-between">
            <span className="text-muted-foreground">Subtotal</span>
            <span className="font-semibold text-foreground">{formatPrice(totals.subtotal)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-muted-foreground">Delivery</span>
            <span className="font-semibold text-foreground">
              {totals.shippingCost === 0 ? "FREE" : formatPrice(totals.shippingCost)}
            </span>
          </div>
          {isGift ? (
            <div className="flex justify-between">
              <span className="text-muted-foreground">
                {isMultiShop ? `Gift fees (${shopGroups.length} shops)` : "Gift fee"}
              </span>
              <span className="font-semibold text-foreground">{formatPrice(totals.giftFee)}</span>
            </div>
          ) : null}
          <div className="flex justify-between border-t border-artisan-clay pt-3 text-base">
            <span className="font-semibold text-foreground">Total</span>
            <span className="font-bold text-foreground">{formatPrice(totals.total)}</span>
          </div>
        </div>
        {isMultiShop ? (
          <p className="mt-4 text-xs leading-5 text-muted-foreground">
            You pay once for all {shopGroups.length} shops, and TradeSafe holds each shop&apos;s share
            until your parcel arrives. TradeSafe takes whole rands, so you may pay a few cents more; any
            change stays in your TradeSafe wallet for next time.
          </p>
        ) : null}
        {blocker || error ? (
          <p className="mt-5 rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
            {error ?? blocker}
          </p>
        ) : null}
        <Button
          type="submit"
          size="lg"
          disabled={
            isSubmitting ||
            Boolean(blocker) ||
            !allShopsSelected ||
            isMissingBobGoRate
          }
          className="mt-6 w-full rounded-full"
        >
          {isSubmitting ? "Starting payment..." : "Pay with TradeSafe"}
        </Button>
      </aside>
    </form>
  );
}
