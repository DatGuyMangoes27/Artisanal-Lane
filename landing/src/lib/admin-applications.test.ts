import { describe, expect, it } from "vitest";

import {
  getVendorApplicationApplicantDisplay,
  getVendorApplicationDisplayStatus,
  getVendorApplicationReviewActions,
} from "./admin-applications";

describe("admin vendor application helpers", () => {
  it("keeps rejected applications recoverable", () => {
    expect(getVendorApplicationReviewActions("pending", { hasApplicant: true })).toEqual([
      "approve",
      "reject",
    ]);
    expect(getVendorApplicationReviewActions("rejected")).toEqual(["restore"]);
    expect(getVendorApplicationReviewActions("approved")).toEqual([]);
  });

  it("does not allow approving preserved applications for deleted accounts", () => {
    expect(getVendorApplicationReviewActions("pending", { hasApplicant: false })).toEqual([
      "reject",
    ]);
  });

  it("shows a deleted status once the applicant's account is removed", () => {
    expect(
      getVendorApplicationDisplayStatus({
        status: "approved",
        applicantAccountDeletedAt: "2026-05-12T13:13:00.000Z",
      }),
    ).toBe("deleted");
  });

  it("keeps the live status while the applicant account exists", () => {
    expect(
      getVendorApplicationDisplayStatus({
        status: "approved",
        applicantAccountDeletedAt: null,
      }),
    ).toBe("approved");
    expect(getVendorApplicationDisplayStatus({ status: "pending" })).toBe("pending");
  });

  it("uses preserved applicant snapshots after account deletion", () => {
    expect(
      getVendorApplicationApplicantDisplay({
        applicant: null,
        applicantDisplayNameSnapshot: "Nandi Maker",
        applicantEmailSnapshot: "nandi@example.com",
        applicantAccountDeletedAt: "2026-05-12T13:13:00.000Z",
      }),
    ).toEqual({
      name: "Nandi Maker",
      email: "nandi@example.com",
      accountStatus: "Deleted account",
      deletedAt: "2026-05-12T13:13:00.000Z",
    });
  });
});
