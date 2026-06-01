import { describe, expect, it } from "vitest";

import { getBuyerInitial, getBuyerProfileUpdate, profileAvatarStoragePath } from "./buyer-profile";

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

  it("builds stable per-user avatar storage paths", () => {
    expect(
      profileAvatarStoragePath({
        userId: "user-1",
        originalPath: "avatar.PNG",
        timestampMillis: 123,
      }),
    ).toBe("user-1/avatar-123.png");
    expect(
      profileAvatarStoragePath({
        userId: "user-1",
        originalPath: "avatar",
        timestampMillis: 123,
      }),
    ).toBe("user-1/avatar-123.jpg");
  });
});
