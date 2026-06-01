import { getGuestCartQuantity, type GuestCartItem } from "./cart";

export const guestCartChangedEvent = "artisan-lane:guest-cart-changed";

export type GuestCartChangedDetail = {
  quantity: number;
  showNotice: boolean;
};

export function dispatchGuestCartChanged(
  items: GuestCartItem[],
  options: { showNotice?: boolean } = {},
) {
  if (typeof window === "undefined") {
    return;
  }

  window.dispatchEvent(
    new CustomEvent<GuestCartChangedDetail>(guestCartChangedEvent, {
      detail: {
        quantity: getGuestCartQuantity(items),
        showNotice: options.showNotice === true,
      },
    }),
  );
}
