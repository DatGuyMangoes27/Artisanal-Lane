import { describe, expect, it } from "vitest";

import { getBuyerInitial, getBuyerProfileUpdate } from "./buyer-profile";

describe("buyer profile helpers", () => {
  it("builds a trimmed profile update payload from form values", () => {
    const formData = new FormData();
    formData.set("displayName", "  Ros From Scratch  ");
    formData.set("phone", "  071 000 0000  ");

    expect(getBuyerProfileUpdate(formData)).toEqual({
      display_name: "Ros From Scratch",
      phone: "071 000 0000",
    });
  });

  it("falls back to buyer initial from email when display name is missing", () => {
    expect(getBuyerInitial({ display_name: null, email: "buyer@example.com" })).toBe("B");
  });
});
