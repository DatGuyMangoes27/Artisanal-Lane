export type VendorApplicationReviewAction = "approve" | "reject" | "restore";

type VendorApplicationApplicantDisplayInput = {
  applicant?: {
    display_name: string | null;
    email: string | null;
  } | null;
  applicantDisplayNameSnapshot?: string | null;
  applicantEmailSnapshot?: string | null;
  applicantAccountDeletedAt?: string | null;
};

export function getVendorApplicationReviewActions(
  status: string | null | undefined,
  options: { hasApplicant?: boolean } = {},
): VendorApplicationReviewAction[] {
  switch ((status ?? "").toLowerCase()) {
    case "pending":
      return options.hasApplicant === false ? ["reject"] : ["approve", "reject"];
    case "rejected":
      return ["restore"];
    default:
      return [];
  }
}

export function getVendorApplicationDisplayStatus(application: {
  status: string | null | undefined;
  applicantAccountDeletedAt?: string | null;
}): string {
  // Once the applicant deletes their account, their shop is removed but the
  // application record is preserved for audit. Surface it as "deleted" instead
  // of leaving the stale "approved" badge that no longer reflects a live store.
  if (application.applicantAccountDeletedAt != null) {
    return "deleted";
  }

  return application.status ?? "unknown";
}

export function getVendorApplicationApplicantDisplay(
  application: VendorApplicationApplicantDisplayInput,
) {
  const isDeleted = application.applicant == null &&
    application.applicantAccountDeletedAt != null;

  return {
    name: application.applicant?.display_name ??
      application.applicantDisplayNameSnapshot ??
      (isDeleted ? "Deleted account" : "Unknown applicant"),
    email: application.applicant?.email ??
      application.applicantEmailSnapshot ??
      (isDeleted ? "No active profile" : "No email on file"),
    accountStatus: isDeleted ? "Deleted account" : "Active account",
    deletedAt: application.applicantAccountDeletedAt ?? null,
  };
}
