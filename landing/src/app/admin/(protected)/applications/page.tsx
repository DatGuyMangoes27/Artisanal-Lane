import { Check, X } from "lucide-react";

import { approveApplication, rejectApplication } from "@/app/admin/actions";
import { AdminActionButtonForm } from "@/components/admin/admin-action-button-form";
import { AdminPageHeader, PanelCard, StatusBadge } from "@/components/admin/admin-ui";
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
          {applications.map((application) => (
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
                    <StatusBadge value={application.status} />
                  </div>
                  <div className="grid gap-2 text-sm text-muted-foreground md:grid-cols-2">
                    <p>
                      <span className="font-medium text-artisan-sienna">Applicant:</span>{" "}
                      {application.applicant?.display_name ?? "Unknown"}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Email:</span>{" "}
                      {application.applicant?.email ?? "Unknown"}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Location:</span>{" "}
                      {application.location ?? "Not provided"}
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
                </div>

                {application.status === "pending" ? (
                  <div className="flex shrink-0 flex-col gap-3 sm:flex-row xl:flex-col">
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
          ))}
        </div>
      </PanelCard>
    </>
  );
}
