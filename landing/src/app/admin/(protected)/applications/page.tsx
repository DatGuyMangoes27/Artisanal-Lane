import Link from "next/link";
import { Check, MessageSquare, RotateCcw, X } from "lucide-react";

import { approveApplication, rejectApplication, restoreApplication } from "@/app/admin/actions";
import { AdminActionButtonForm } from "@/components/admin/admin-action-button-form";
import { AdminPageHeader, PanelCard, StatusBadge } from "@/components/admin/admin-ui";
import { Button } from "@/components/ui/button";
import {
  getVendorApplicationApplicantDisplay,
  getVendorApplicationDisplayStatus,
  getVendorApplicationReviewActions,
} from "@/lib/admin-applications";
import { listVendorApplications } from "@/lib/admin-data";

function getPortfolioHref(url: string) {
  if (/^https?:\/\//i.test(url)) {
    return url;
  }

  return `https://${url}`;
}

function getPortfolioDisplay(url: string) {
  return getPortfolioHref(url).replace(/^https?:\/\//i, "");
}

export default async function AdminApplicationsPage() {
  const applications = await listVendorApplications();

  return (
    <>
      <AdminPageHeader
        eyebrow="Vendor Applications"
        title="Approve New Artisans"
        description="Review every application before a seller goes live on the marketplace."
      />

      <PanelCard
        description="Applications are sorted newest first. Approving an application promotes the user to vendor and provisions their initial shop."
        title="Applications Queue"
      >
        <div className="space-y-4">
          {applications.map((application) => {
            const reviewActions = getVendorApplicationReviewActions(application.status, {
              hasApplicant: application.user_id != null && application.applicant != null,
            });
            const applicantDisplay = getVendorApplicationApplicantDisplay({
              applicant: application.applicant,
              applicantDisplayNameSnapshot: application.applicant_display_name_snapshot,
              applicantEmailSnapshot: application.applicant_email_snapshot,
              applicantAccountDeletedAt: application.applicant_account_deleted_at,
            });
            const displayStatus = getVendorApplicationDisplayStatus({
              status: application.status,
              applicantAccountDeletedAt: application.applicant_account_deleted_at,
            });

            return (
              <div
                key={application.id}
                className="rounded-3xl border border-artisan-clay bg-artisan-bone/35 p-5"
              >
                <div className="flex flex-col gap-4 xl:flex-row xl:items-start xl:justify-between">
                  <div className="space-y-3">
                  <div className="flex flex-wrap items-center gap-3">
                    <h3 className="text-2xl font-semibold text-artisan-sienna">
                      {application.business_name}
                    </h3>
                    <StatusBadge value={displayStatus} />
                  </div>
                  <div className="grid gap-2 text-sm text-muted-foreground md:grid-cols-2">
                    <p>
                      <span className="font-medium text-artisan-sienna">Applicant:</span>{" "}
                      {applicantDisplay.name}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Email:</span>{" "}
                      {applicantDisplay.email}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Location:</span>{" "}
                      {application.location ?? "Not provided"}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Account:</span>{" "}
                      {applicantDisplay.accountStatus}
                      {applicantDisplay.deletedAt
                        ? ` on ${new Date(applicantDisplay.deletedAt).toLocaleDateString()}`
                        : ""}
                    </p>
                  </div>
                  {application.motivation ? (
                    <p className="text-sm text-muted-foreground">
                      <span className="font-medium text-artisan-sienna">Motivation:</span>{" "}
                      {application.motivation}
                    </p>
                  ) : null}
                  {application.delivery_info ? (
                    <p className="text-sm text-muted-foreground">
                      <span className="font-medium text-artisan-sienna">Fulfilment:</span>{" "}
                      {application.delivery_info}
                    </p>
                  ) : null}
                  {application.turnaround_time ? (
                    <p className="text-sm text-muted-foreground">
                      <span className="font-medium text-artisan-sienna">Turnaround:</span>{" "}
                      {application.turnaround_time}
                    </p>
                  ) : null}
                  {application.portfolio_url ? (
                    <p className="text-sm text-muted-foreground">
                      <span className="font-medium text-artisan-sienna">
                        Submitted portfolio:
                      </span>{" "}
                      <a
                        className="font-medium text-artisan-terracotta hover:underline"
                        href={getPortfolioHref(application.portfolio_url)}
                      >
                        {getPortfolioDisplay(application.portfolio_url)}
                      </a>
                    </p>
                  ) : null}
                  {application.proof_image_urls.length > 0 ? (
                    <div className="space-y-2">
                      <p className="text-sm font-medium text-artisan-sienna">
                        Work photos
                      </p>
                      <div className="flex flex-wrap gap-3">
                        {application.proof_image_urls.map((imageUrl: string, index: number) => (
                          <a
                            key={imageUrl}
                            className="group block"
                            href={imageUrl}
                            rel="noreferrer"
                            target="_blank"
                          >
                            <div
                              aria-label={`${application.business_name} proof photo ${index + 1}`}
                              className="h-24 w-24 rounded-2xl border border-artisan-clay bg-artisan-bone bg-cover bg-center transition group-hover:opacity-90"
                              style={{ backgroundImage: `url("${imageUrl}")` }}
                            />
                          </a>
                        ))}
                      </div>
                    </div>
                  ) : null}
                  </div>

                  {reviewActions.length > 0 ? (
                    <div className="flex shrink-0 flex-col gap-3 sm:flex-row xl:flex-col">
                      {application.user_id && !applicantDisplay.deletedAt ? (
                        <Button
                          asChild
                          className="w-full bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
                        >
                          <Link href={`/admin/applications/${application.user_id}/messages`}>
                            <MessageSquare className="mr-2 h-4 w-4" />
                            Message applicant
                          </Link>
                        </Button>
                      ) : null}
                      {reviewActions.includes("approve") && application.user_id ? (
                        <AdminActionButtonForm
                          action={approveApplication}
                          buttonClassName="w-full bg-artisan-baobab text-white hover:bg-artisan-baobab/90"
                          hiddenFields={[
                            { name: "applicationId", value: application.id },
                            { name: "userId", value: application.user_id },
                            { name: "businessName", value: application.business_name },
                            { name: "location", value: application.location ?? "" },
                          ]}
                          idleContent={
                            <>
                              <Check className="mr-2 h-4 w-4" />
                              Approve
                            </>
                          }
                          pendingLabel="Approving..."
                        />
                      ) : null}
                      {reviewActions.includes("reject") ? (
                        <AdminActionButtonForm
                          action={rejectApplication}
                          buttonClassName="w-full bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
                          hiddenFields={[{ name: "applicationId", value: application.id }]}
                          idleContent={
                            <>
                              <X className="mr-2 h-4 w-4" />
                              Reject
                            </>
                          }
                          pendingLabel="Rejecting..."
                        />
                      ) : null}
                      {reviewActions.includes("restore") ? (
                        <AdminActionButtonForm
                          action={restoreApplication}
                          buttonClassName="w-full border border-artisan-terracotta bg-white text-artisan-terracotta hover:bg-artisan-bone"
                          hiddenFields={[{ name: "applicationId", value: application.id }]}
                          idleContent={
                            <>
                              <RotateCcw className="mr-2 h-4 w-4" />
                              Restore to Review
                            </>
                          }
                          pendingLabel="Restoring..."
                        />
                      ) : null}
                    </div>
                  ) : (
                    <div className="text-sm text-muted-foreground">
                      Reviewed{" "}
                      {application.reviewer?.display_name
                        ? `by ${application.reviewer.display_name}`
                        : ""}
                      {application.reviewed_at
                        ? ` on ${new Date(application.reviewed_at).toLocaleDateString()}`
                        : ""}
                    </div>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </PanelCard>
    </>
  );
}
