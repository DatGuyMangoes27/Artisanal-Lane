import { beforeEach, describe, expect, it, vi } from "vitest";
import { subscribeToUpdates, unsubscribeFromUpdates } from "./actions";
const { insert, update, eq, from } = vi.hoisted(() => ({ insert: vi.fn(), update: vi.fn(), eq: vi.fn(), from: vi.fn() }));
vi.mock("@/lib/supabase/admin", () => ({ createAdminClient: () => ({ from }) }));
vi.mock("@/lib/supabase/env", () => ({ getSupabaseServiceRoleKey: () => "test-only" }));
vi.mock("next/headers", () => ({ headers: async () => new Headers() }));
beforeEach(() => {
  vi.clearAllMocks();
  from.mockReturnValue({ insert, update, select: () => ({ eq: () => ({ gte: async () => ({ count: 0, error: null }) }) }) });
  insert.mockResolvedValue({ error: null }); update.mockReturnValue({ eq }); eq.mockResolvedValue({ error: null });
});
function form(consent = true) { const f = new FormData(); f.set("email", " Test@Example.com "); if(consent) f.set("consent", "on"); return f; }
describe("public newsletter", () => {
  it("saves a guest signup with normalized email and unsubscribe link", async () => {
    const result = await subscribeToUpdates({message:""}, form());
    expect(insert).toHaveBeenCalledWith(expect.objectContaining({email:"test@example.com"}));
    expect(result.unsubscribeUrl).toContain("/stay-updated/unsubscribe?token=");
  });
  it("requires consent", async () => { await subscribeToUpdates({message:""}, form(false)); expect(insert).not.toHaveBeenCalled(); });
  it("does not expose existing subscriber tokens or resubscribe", async () => { insert.mockResolvedValue({error:{code:"23505"}}); const r=await subscribeToUpdates({message:""},form()); expect(r.unsubscribeUrl).toBeUndefined(); expect(update).not.toHaveBeenCalled(); });
  it("rejects invalid email", async () => {const f=form();f.set("email","bad");await subscribeToUpdates({message:""},f);expect(insert).not.toHaveBeenCalled();});
  it("rejects invalid unsubscribe tokens",async()=>{await unsubscribeFromUpdates({message:""},new FormData());expect(update).not.toHaveBeenCalled();});
  it("unsubscribes only the supplied token",async()=>{const f=new FormData();f.set("token","00000000-0000-4000-8000-000000000001");await unsubscribeFromUpdates({message:""},f);expect(eq).toHaveBeenCalledWith("unsubscribe_token","00000000-0000-4000-8000-000000000001");});
});
