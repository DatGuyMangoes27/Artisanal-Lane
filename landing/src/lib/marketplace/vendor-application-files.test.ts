import { describe, expect, it } from "vitest";

import {
  MAX_VENDOR_PROOF_TOTAL_BYTES,
  validateVendorProofFiles,
} from "./vendor-application-files";

describe("validateVendorProofFiles", () => {
  it("accepts supported images within the combined upload limit", () => {
    expect(
      validateVendorProofFiles([
        { size: 1_000_000, type: "image/jpeg" },
        { size: 1_000_000, type: "image/png" },
      ]),
    ).toBeNull();
  });

  it("rejects unsupported file types", () => {
    expect(validateVendorProofFiles([{ size: 100, type: "application/pdf" }])).toMatch(
      /JPEG, PNG, or WebP/,
    );
  });

  it("rejects too many photos", () => {
    const files = Array.from({ length: 6 }, () => ({ size: 100, type: "image/jpeg" }));

    expect(validateVendorProofFiles(files)).toMatch(/no more than 5/);
  });

  it("rejects a combined upload that would exceed the hosting payload limit", () => {
    expect(
      validateVendorProofFiles([
        { size: MAX_VENDOR_PROOF_TOTAL_BYTES, type: "image/jpeg" },
        { size: 1, type: "image/webp" },
      ]),
    ).toMatch(/under 4 MB/);
  });
});
