import { describe, expect, it } from "vitest";

import { marketingContactsCsv } from "./marketing-contacts-csv";

describe("marketingContactsCsv", () => {
  it("uses Meta's column names and escapes awkward values", () => {
    const csv = marketingContactsCsv([
      {
        email: "a@b.co",
        phone: "0821234567",
        name: "Lerato Dlamini",
        source: "web-checkout",
        consentedAt: "2026-11-10",
      },
      { email: "x@y.co", phone: null, name: "=cmd,x", source: "newsletter", consentedAt: "2026-11-09" },
    ]);
    expect(csv.split("\n")[0]).toBe("email,phone,fn,source,consented_at");
    expect(csv).toContain("a@b.co,0821234567,Lerato,web-checkout,2026-11-10");
    expect(csv).toContain(`x@y.co,,"'=cmd,x",newsletter,2026-11-09`);
  });
});
