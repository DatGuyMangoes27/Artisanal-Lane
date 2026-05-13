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
  getAvailableShippingOptionsForCart,
  getCartSubtotal,
  getCheckoutBlocker,
  requiresPickupPoint,
  requiresShippingAddress,
} from "@/lib/marketplace/checkout";
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

type CheckoutPayload = {
  checkoutUrl?: string;
  error?: string;
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

export function CheckoutForm() {
  const router = useRouter();
  const { items, clearCart } = useGuestCart();
  const [products, setProducts] = useState<MarketplaceProduct[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [isSignedIn, setIsSignedIn] = useState<boolean | null>(null);
  const [shippingMethod, setShippingMethod] = useState<string | null>(null);

  useEffect(() => {
    const supabase = createClient();
    supabase.auth.getUser().then((result: { data: { user: unknown } }) => {
      setIsSignedIn(Boolean(result.data.user));
    });
  }, []);

  useEffect(() => {
    let isCurrent = true;

    fetch("/api/marketplace/cart", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ items }),
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
  const total = subtotal + shippingCost;
  const blocker = getCheckoutBlocker(lines);

  useEffect(() => {
    if (!shippingMethod && shippingOptions.length > 0) {
      setShippingMethod(shippingOptions[0].key);
    }
    if (shippingMethod && !shippingOptions.some((option) => option.key === shippingMethod)) {
      setShippingMethod(shippingOptions[0]?.key ?? null);
    }
  }, [shippingMethod, shippingOptions]);

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setError(null);

    if (blocker || !selectedShipping) {
      setError(blocker ?? "Choose a delivery option before starting payment.");
      return;
    }

    const formData = new FormData(event.currentTarget);
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

      const pickupPoint = String(formData.get("pickupPoint") ?? "").trim();
      const shippingAddress = {
        name: String(formData.get("name") ?? "").trim(),
        country: "South Africa",
        phone: String(formData.get("phone") ?? "").trim(),
        ...(requiresShippingAddress(selectedShipping.key)
          ? {
              street: String(formData.get("street") ?? "").trim(),
              city: String(formData.get("city") ?? "").trim(),
              postal_code: String(formData.get("postalCode") ?? "").trim(),
              province: String(formData.get("province") ?? "").trim(),
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
          : pickupPoint
            ? { pickup_point: pickupPoint }
            : {}),
      };

      const { data, error: checkoutError } = await supabase.functions.invoke(
        "create-checkout",
        {
          body: {
            userId: user.id,
            shippingAddress,
            shippingMethod: selectedShipping.key,
            shippingCost,
          },
        },
      );
      const checkoutData = data as CheckoutPayload | null;

      if (checkoutError || checkoutData?.error || !checkoutData?.checkoutUrl) {
        throw new Error(checkoutData?.error ?? checkoutError?.message ?? "Checkout failed.");
      }

      clearCart();
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
            <label className="space-y-2 text-sm font-medium text-foreground">
              Full name
              <input name="name" required className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2" />
            </label>
            <label className="space-y-2 text-sm font-medium text-foreground">
              Phone number
              <input name="phone" required className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2" />
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
                <input name="street" required className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2" />
              </label>
              <label className="space-y-2 text-sm font-medium text-foreground">
                City
                <input name="city" required className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2" />
              </label>
              <label className="space-y-2 text-sm font-medium text-foreground">
                Postal code
                <input name="postalCode" required className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2" />
              </label>
              <label className="space-y-2 text-sm font-medium text-foreground sm:col-span-2">
                Province
                <select name="province" required className="w-full rounded-xl border border-artisan-clay bg-white px-3 py-2">
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
            <CardContent className="space-y-2 p-6">
              <label className="text-sm font-medium text-foreground">
                Pickup point
                <input
                  name="pickupPoint"
                  required
                  placeholder="Enter the locker, branch, Pargo point, or pickup code"
                  className="mt-2 w-full rounded-xl border border-artisan-clay bg-white px-3 py-2"
                />
              </label>
            </CardContent>
          </Card>
        ) : null}
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
