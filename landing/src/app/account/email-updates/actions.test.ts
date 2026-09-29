import { beforeEach, describe, expect, it, vi } from "vitest";
import { saveEmailUpdates } from "./actions";
import { createClient } from "@/lib/supabase/server";

vi.mock("@/lib/supabase/server", () => ({ createClient: vi.fn() }));
vi.mock("next/cache", () => ({ revalidatePath: vi.fn() }));
const updateUser = vi.fn();
const getUser = vi.fn();
beforeEach(() => {
  vi.clearAllMocks();
  vi.mocked(createClient).mockResolvedValue({ auth: { getUser, updateUser } } as never);
  updateUser.mockResolvedValue({ error: null });
});
describe("email update consent", () => {
  it("does not write without an authenticated account", async () => {
    getUser.mockResolvedValue({ data: { user: null }, error: null });
    await saveEmailUpdates({ message: "" }, new FormData());
    expect(updateUser).not.toHaveBeenCalled();
  });
  it("requires a confirmed account email", async () => {
    getUser.mockResolvedValue({ data: { user: { email: "test@example.com" } }, error: null });
    await saveEmailUpdates({ message: "" }, new FormData());
    expect(updateUser).not.toHaveBeenCalled();
  });
  it("records explicit opt-in only for the signed-in user's address", async () => {
    getUser.mockResolvedValue({ data: { user: { email: "test@example.com", email_confirmed_at: "2026-09-01" } }, error: null });
    const form = new FormData();
    form.set("enabled", "on");
    form.set("email", "someone-else@example.com");
    await saveEmailUpdates({ message: "" }, form);
    expect(updateUser).toHaveBeenCalledWith({ data: { artisan_lane_email_updates: expect.objectContaining({ enabled: true, email: "test@example.com", consent_version: "2026-09" }) } });
  });
  it("allows withdrawal of consent", async () => {
    getUser.mockResolvedValue({ data: { user: { email: "test@example.com", email_confirmed_at: "2026-09-01" } }, error: null });
    await saveEmailUpdates({ message: "" }, new FormData());
    expect(updateUser).toHaveBeenCalledWith({ data: { artisan_lane_email_updates: expect.objectContaining({ enabled: false }) } });
  });
});
