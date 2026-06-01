"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { FormEvent, useEffect, useMemo, useState } from "react";

import { useGuestCart } from "@/components/marketplace/guest-cart-provider";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import {
  buildCartLines,
  calculateShippingTotal,
  checkoutBlockingMessage,
  firstIncompleteCheckoutField,
  getAvailableShippingOptionsForCart,
  getCartSubtotal,
  getCheckoutBlocker,
  getSavedAddressCheckoutFields,
  requiresPickupPoint,
  requiresShippingAddress,
} from "@/lib/marketplace/checkout";
import {
  clearGuestCartReservationToken,
  getGuestCartReservationToken,
  reserveGuestCartItem,
} from "@/lib/marketplace/cart-reservations";
import { getAddressSummary, normalizeSavedAddresses, type SavedAddress } from "@/lib/marketplace/buyer-preferences";
import { formatPrice } from "@/lib/marketplace/format";
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

const giftServiceFee = 30;

type CheckoutPayload = {
  checkoutUrl?: string;
  orderId?: string;
  error?: string;
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

function shippingName(option: ShippingOption) {
  switch (option.key) {
    case "courier_guy":
      return "Courier Guy Locker";
    case "courier_guy_door_to_door":
      return "Courier Guy Door to Door";
    case "pargo":
      return "Pargo";
    case "market_pickup":
      return "Market Pickup";
    default:
      return option.key.replaceAll("_", " ");
  }
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

export function CheckoutForm() {
  const router = useRouter();
  const { items, clearCart } = useGuestCart();
  const [products, setProducts] = useState<MarketplaceProduct[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isSignedIn, setIsSignedIn] = useState<boolean | null>(null);
  const [shippingMethod, setShippingMethod] = useState<string | null>(null);
  const [savedAddresses, setSavedAddresses] = useState<SavedAddress[]>([]);
  const [selectedAddressId, setSelectedAddressId] = useState("");
  const [isGift, setIsGift] = useState(false);
  const [giftRecipient, setGiftRecipient] = useState("");
  const [giftMessage, setGiftMessage] = useState("");
  const [pickupPointText, setPickupPointText] = useState("");
  const [courierGuyLockerProvince, setCourierGuyLockerProvince] = useState("");
  const [courierGuySearch, setCourierGuySearch] = useState("");
  const [courierGuyLockers, setCourierGuyLockers] = useState<CourierGuyLocker[]>([]);
  const [selectedCourierGuyLocker, setSelectedCourierGuyLocker] = useState<CourierGuyLocker | null>(null);
  const [isLoadingCourierGuyLockers, setIsLoadingCourierGuyLockers] = useState(false);
  const [courierGuyLockerError, setCourierGuyLockerError] = useState<string | null>(null);
  const [pargoPointProvince, setPargoPointProvince] = useState("");
  const [pargoSearch, setPargoSearch] = useState("");
  const [pargoPickupPoints, setPargoPickupPoints] = useState<PargoPickupPoint[]>([]);
  const [selectedPargoPoint, setSelectedPargoPoint] = useState<PargoPickupPoint | null>(null);
  const [isLoadingPargoPoints, setIsLoadingPargoPoints] = useState(false);
  const [pargoPointError, setPargoPointError] = useState<string | null>(null);
  const [addressFields, setAddressFields] = useState({
    name: "",
    phone: "",
    street: "",
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

      const { data } = await supabase
        .from("profiles")
        .select("shipping_addresses")
        .eq("id", user.id)
        .maybeSingle();

      const profile = data as { shipping_addresses?: unknown } | null;
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
  const shippingOptions = useMemo(() => getAvailableShippingOptionsForCart(lines), [lines]);
  const selectedShipping = shippingOptions.find((option) => option.key === shippingMethod) ?? null;
  const subtotal = getCartSubtotal(lines);
  const shippingCost = selectedShipping ? calculateShippingTotal(lines, selectedShipping.key) : 0;
  const total = subtotal + shippingCost + (isGift ? giftServiceFee : 0);
  const blocker = getCheckoutBlocker(lines);

  useEffect(() => {
    if (!shippingMethod && shippingOptions.length > 0) {
      setShippingMethod(shippingOptions[0].key);
    }
    if (shippingMethod && !shippingOptions.some((option) => option.key === shippingMethod)) {
      setShippingMethod(shippingOptions[0]?.key ?? null);
    }
  }, [shippingMethod, shippingOptions]);

  async function searchCourierGuyLockers() {
    const query = courierGuySearch.trim();
    const province = courierGuyLockerProvince.trim();
    if (query.length < 2 && province.length === 0) {
      setCourierGuyLockers([]);
      setCourierGuyLockerError("Choose a province or type at least two characters to search.");
      return;
    }

    setIsLoadingCourierGuyLockers(true);
    setCourierGuyLockerError(null);

    const response = await fetch("/api/marketplace/pickup-points/", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ carrier: "courier_guy", query, province, limit: 8 }),
    });
    const payload = (await response.json()) as { lockers?: CourierGuyLocker[]; error?: string } | null;

    if (!response.ok || payload?.error) {
      setCourierGuyLockers([]);
      setCourierGuyLockerError(payload?.error ?? "Could not load Courier Guy lockers.");
    } else {
      setCourierGuyLockers(payload?.lockers ?? []);
    }

    setIsLoadingCourierGuyLockers(false);
  }

  async function searchPargoPickupPoints() {
    const query = pargoSearch.trim();
    const province = pargoPointProvince.trim();
    if (query.length < 2 && province.length === 0) {
      setPargoPickupPoints([]);
      setPargoPointError("Choose a province or type at least two characters to search.");
      return;
    }

    setIsLoadingPargoPoints(true);
    setPargoPointError(null);

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

    setIsLoadingPargoPoints(false);
  }

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    if (blocker) {
      setError(blocker);
      return;
    }

    const pickupPoint = selectedShipping?.key === "courier_guy" && selectedCourierGuyLocker
      ? courierGuyLockerSummary(selectedCourierGuyLocker)
      : selectedShipping?.key === "pargo" && selectedPargoPoint
        ? pargoPickupPointSummary(selectedPargoPoint)
        : pickupPointText.trim();
    const incompleteField = firstIncompleteCheckoutField({
      fullName: addressFields.name,
      streetAddress: addressFields.street,
      city: addressFields.city,
      postalCode: addressFields.postalCode,
      province: addressFields.province,
      phoneNumber: addressFields.phone,
      selectedShippingMethod: selectedShipping?.key ?? null,
      hasAvailableShippingMethods: shippingOptions.length > 0,
      requiresShippingAddress: requiresShippingAddress(selectedShipping?.key ?? null),
      requiresPickupPoint: requiresPickupPoint(selectedShipping?.key ?? null),
      pickupPoint,
    });

    if (incompleteField || !selectedShipping) {
      setError(checkoutBlockingMessage(incompleteField ?? "shippingMethod"));
      return;
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
        lines.map((line) =>
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
        })),
      );

      if (itemsError) {
        throw new Error(itemsError.message);
      }

      const shippingAddress = {
        name: addressFields.name.trim(),
        country: "South Africa",
        phone: addressFields.phone.trim(),
        ...(requiresShippingAddress(selectedShipping.key)
          ? {
              street: addressFields.street.trim(),
              city: addressFields.city.trim(),
              postal_code: addressFields.postalCode.trim(),
              province: addressFields.province.trim(),
            }
          : {}),
        ...(selectedShipping.key === "market_pickup"
          ? {
              pickup_point: {
                carrier: "market_pickup",
                point_type: "market",
                name: selectedShipping.marketName,
                address: selectedShipping.marketLocation,
                province: selectedShipping.marketProvince,
              },
            }
          : selectedShipping.key === "courier_guy" && selectedCourierGuyLocker
            ? { pickup_point: courierGuyLockerToOrderJson(selectedCourierGuyLocker) }
            : selectedShipping.key === "pargo" && selectedPargoPoint
              ? { pickup_point: pargoPickupPointToOrderJson(selectedPargoPoint) }
          : pickupPoint
            ? { pickup_point: pickupPoint }
            : {}),
      };

      const { data, error: checkoutError } = await supabase.functions.invoke(
        "create-checkout",
        {
          body: {
            userId: user.id,
            reservationToken,
            shippingAddress,
            shippingMethod: selectedShipping.key,
            shippingCost,
            isGift,
            giftRecipient: isGift ? giftRecipient.trim() || null : null,
            giftMessage: isGift ? giftMessage.trim() || null : null,
          },
        },
      );
      const checkoutData = data as CheckoutPayload | null;

      if (checkoutError || checkoutData?.error || !checkoutData?.checkoutUrl) {
        throw new Error(checkoutData?.error ?? checkoutError?.message ?? "Checkout failed.");
      }

      clearCart();
      clearGuestCartReservationToken();
      if (checkoutData.orderId) {
        window.sessionStorage.setItem("artisanLane:lastCheckoutOrderId", checkoutData.orderId);
      }
      window.location.assign(checkoutData.checkoutUrl);
    } catch (checkoutError) {
      setError(checkoutError instanceof Error ? checkoutError.message : "Checkout failed.");
      setIsSubmitting(false);
    }
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
        </div>

        <Card className="border-artisan-clay bg-card">
          <CardContent className="grid gap-4 p-6 sm:grid-cols-2">
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

        <Card className="border-artisan-clay bg-card">
          <CardContent className="space-y-4 p-6">
            <h2 className="font-serif text-2xl font-bold text-foreground">Delivery option</h2>
            <div className="grid gap-3">
              {shippingOptions.map((option) => (
                <label
                  key={option.key}
                  className="flex cursor-pointer items-center justify-between gap-4 rounded-2xl border border-artisan-clay bg-background p-4"
                >
                  <span>
                    <span className="block font-semibold text-foreground">{shippingName(option)}</span>
                    {option.marketName || option.marketLocation || option.marketProvince ? (
                      <span className="mt-1 block text-sm text-muted-foreground">
                        {[option.marketName, option.marketLocation, option.marketProvince]
                          .filter(Boolean)
                          .join(", ")}
                      </span>
                    ) : null}
                  </span>
                  <span className="flex items-center gap-3">
                    <span className="text-sm font-semibold text-foreground">
                      {formatPrice(calculateShippingTotal(lines, option.key))}
                    </span>
                    <input
                      type="radio"
                      name="shippingMethod"
                      value={option.key}
                      checked={shippingMethod === option.key}
                      onChange={() => setShippingMethod(option.key)}
                    />
                  </span>
                </label>
              ))}
            </div>
          </CardContent>
        </Card>

        {selectedShipping && requiresShippingAddress(selectedShipping.key) ? (
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
            </CardContent>
          </Card>
        ) : null}

        {selectedShipping && requiresPickupPoint(selectedShipping.key) ? (
          <Card className="border-artisan-clay bg-card">
            <CardContent className="space-y-4 p-6">
              {selectedShipping.key === "courier_guy" ? (
                <>
                  <p className="text-sm text-muted-foreground">
                    Search and select the Courier Guy locker where you want to collect your parcel.
                  </p>
                  <div className="grid gap-3 sm:grid-cols-[180px_1fr_auto]">
                    <select
                      value={courierGuyLockerProvince}
                      onChange={(event) => {
                        setCourierGuyLockerProvince(event.target.value);
                        setSelectedCourierGuyLocker(null);
                        setPickupPointText("");
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
                        setSelectedCourierGuyLocker(null);
                        setPickupPointText("");
                      }}
                      placeholder="Type a mall, suburb, town, or locker code"
                      className="rounded-xl border border-artisan-clay bg-white px-3 py-2 text-sm"
                    />
                    <Button type="button" variant="outline" onClick={searchCourierGuyLockers}>
                      Search
                    </Button>
                  </div>
                  {selectedCourierGuyLocker ? (
                    <div className="rounded-2xl border border-artisan-clay bg-background p-4 text-sm">
                      <p className="font-semibold text-foreground">Selected locker</p>
                      <p className="mt-1 text-muted-foreground">
                        {courierGuyLockerSummary(selectedCourierGuyLocker)}
                      </p>
                    </div>
                  ) : null}
                  {courierGuyLockerError ? (
                    <p className="rounded-2xl border border-red-200 bg-red-50 p-3 text-sm text-red-700">
                      {courierGuyLockerError}
                    </p>
                  ) : null}
                  {isLoadingCourierGuyLockers ? (
                    <p className="text-sm text-muted-foreground">Loading Courier Guy lockers...</p>
                  ) : courierGuyLockers.length > 0 ? (
                    <div className="divide-y overflow-hidden rounded-2xl border border-artisan-clay bg-background">
                      {courierGuyLockers.map((locker) => (
                        <button
                          key={`${locker.code}-${locker.name}`}
                          type="button"
                          onClick={() => {
                            setSelectedCourierGuyLocker(locker);
                            setPickupPointText(courierGuyLockerSummary(locker));
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
              ) : selectedShipping.key === "pargo" ? (
                <>
                  <p className="text-sm text-muted-foreground">
                    Search and select the Pargo pickup point where you want to collect your parcel.
                  </p>
                  <div className="grid gap-3 sm:grid-cols-[180px_1fr_auto]">
                    <select
                      value={pargoPointProvince}
                      onChange={(event) => {
                        setPargoPointProvince(event.target.value);
                        setSelectedPargoPoint(null);
                        setPickupPointText("");
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
                        setSelectedPargoPoint(null);
                        setPickupPointText("");
                      }}
                      placeholder="Type a store, suburb, town, or point code"
                      className="rounded-xl border border-artisan-clay bg-white px-3 py-2 text-sm"
                    />
                    <Button type="button" variant="outline" onClick={searchPargoPickupPoints}>
                      Search
                    </Button>
                  </div>
                  {selectedPargoPoint ? (
                    <div className="rounded-2xl border border-artisan-clay bg-background p-4 text-sm">
                      <p className="font-semibold text-foreground">Selected pickup point</p>
                      <p className="mt-1 text-muted-foreground">
                        {pargoPickupPointSummary(selectedPargoPoint)}
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
                            setSelectedPargoPoint(point);
                            setPickupPointText(pargoPickupPointSummary(point));
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
                    name="pickupPoint"
                    required
                    value={pickupPointText}
                    onChange={(event) => setPickupPointText(event.target.value)}
                    placeholder="Enter the pickup point or drop-off location"
                    className="mt-2 w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                  />
                </label>
              )}
            </CardContent>
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
                <span className="mt-1 block text-muted-foreground">
                  Add recipient details and a note. A R30 gift service fee will be added.
                </span>
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
        <div className="mt-6 space-y-3 text-sm">
          <div className="flex justify-between">
            <span className="text-muted-foreground">Subtotal</span>
            <span className="font-semibold text-foreground">{formatPrice(subtotal)}</span>
          </div>
          <div className="flex justify-between">
            <span className="text-muted-foreground">Delivery</span>
            <span className="font-semibold text-foreground">{formatPrice(shippingCost)}</span>
          </div>
          {isGift ? (
            <div className="flex justify-between">
              <span className="text-muted-foreground">Gift fee</span>
              <span className="font-semibold text-foreground">{formatPrice(giftServiceFee)}</span>
            </div>
          ) : null}
          <div className="flex justify-between border-t border-artisan-clay pt-3 text-base">
            <span className="font-semibold text-foreground">Total</span>
            <span className="font-bold text-foreground">{formatPrice(total)}</span>
          </div>
        </div>
        {blocker || error ? (
          <p className="mt-5 rounded-2xl border border-red-200 bg-red-50 p-4 text-sm text-red-700">
            {error ?? blocker}
          </p>
        ) : null}
        <Button
          type="submit"
          size="lg"
          disabled={isSubmitting || Boolean(blocker) || !selectedShipping}
          className="mt-6 w-full rounded-full"
        >
          {isSubmitting ? "Starting payment..." : "Pay with TradeSafe"}
        </Button>
      </aside>
    </form>
  );
}
