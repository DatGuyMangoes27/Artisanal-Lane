import { CheckCircle2, Undo2 } from "lucide-react";

import {
  resolveDisputeRefund,
  resolveDisputeRelease,
} from "@/app/admin/actions";
import { DisputeResolutionForm } from "@/components/admin/dispute-resolution-form";
import { AdminPageHeader, PanelCard, StatusBadge } from "@/components/admin/admin-ui";
import { listDisputes } from "@/lib/admin-data";

function isImageAttachment(message: {
  attachment_mime?: string | null;
  attachment_name?: string | null;
}) {
  return (
    message.attachment_mime?.startsWith("image/") ??
    /\.(png|jpe?g|gif|webp|bmp|svg)$/i.test(message.attachment_name ?? "")
  );
}

function isVideoAttachment(message: {
  attachment_mime?: string | null;
  attachment_name?: string | null;
}) {
  return (
    message.attachment_mime?.startsWith("video/") ??
    /\.(mp4|mov|webm|m4v|avi)$/i.test(message.attachment_name ?? "")
  );
}

export default async function AdminDisputesPage() {
  const disputes = await listDisputes();

  return (
    <>
      <AdminPageHeader
        eyebrow="Disputes"
        title="Resolve Escrow Issues"
        description="Record a written resolution and either release funds or mark the transaction as refunded."
      />

      <PanelCard title="Disputes Queue">
        <div className="space-y-4">
          {disputes.map((dispute) => (
            <div
              key={dispute.id}
              className="rounded-3xl border border-artisan-clay bg-white p-5"
            >
              <div className="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
                <div className="space-y-2">
                  <div className="flex flex-wrap items-center gap-3">
                    <h3 className="text-xl font-semibold text-artisan-sienna">
                      {dispute.shop?.name ?? "Unknown shop"}
                    </h3>
                    <StatusBadge value={dispute.status} />
                  </div>
                  <div className="grid gap-2 text-sm text-muted-foreground md:grid-cols-2">
                    <p>
                      <span className="font-medium text-artisan-sienna">Raised by:</span>{" "}
                      {dispute.raisedByProfile?.display_name ?? "Unknown"}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Order:</span>{" "}
                      {dispute.order_id.slice(0, 8)}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Order status:</span>{" "}
                      {dispute.order?.status ?? "Unknown"}
                    </p>
                    <p>
                      <span className="font-medium text-artisan-sienna">Opened:</span>{" "}
                      {new Date(dispute.created_at).toLocaleDateString()}
                    </p>
                  </div>
                  <p className="text-sm text-muted-foreground">
                    <span className="font-medium text-artisan-sienna">Reason:</span>{" "}
                    {dispute.reason}
                  </p>
                  {dispute.conversation ? (
                    <div className="space-y-3 rounded-2xl border border-artisan-clay bg-artisan-bone/30 p-4">
                      <div className="flex flex-wrap gap-4 text-xs text-muted-foreground">
                        <p>
                          <span className="font-medium text-artisan-sienna">Buyer:</span>{" "}
                          {dispute.conversation.buyerProfile?.display_name ?? "Unknown"}
                        </p>
                        <p>
                          <span className="font-medium text-artisan-sienna">Seller:</span>{" "}
                          {dispute.conversation.sellerProfile?.display_name ??
                            dispute.shop?.name ??
                            "Unknown"}
                        </p>
                      </div>
                      <div className="max-h-80 space-y-3 overflow-y-auto pr-2">
                        {dispute.conversation.messages.length > 0 ? (
                          dispute.conversation.messages.map((message) => (
                            <div
                              key={message.id}
                              className="rounded-2xl border border-artisan-clay bg-white p-3"
                            >
                              <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-muted-foreground">
                                <span className="font-medium text-artisan-sienna">
                                  {message.senderProfile?.display_name ?? "Unknown participant"}
                                </span>
                                <span>
                                  {new Date(message.created_at).toLocaleString()}
                                </span>
                              </div>
                              {message.body ? (
                                <p className="mt-2 whitespace-pre-wrap text-sm text-foreground">
                                  {message.body}
                                </p>
                              ) : null}
                              {message.attachment_name ? (
                                <div className="mt-3 space-y-2">
                                  {message.attachment_url ? (
                                    <>
                                      {isImageAttachment(message) ? (
                                        <a
                                          href={message.attachment_url}
                                          target="_blank"
                                          rel="noopener noreferrer"
                                          className="block overflow-hidden rounded-2xl border border-artisan-clay"
                                        >
                                          {/* Signed dispute evidence is rendered with a plain img to avoid Next remote-image allowlist setup. */}
                                          {/* eslint-disable-next-line @next/next/no-img-element */}
                                          <img
                                            src={message.attachment_url}
                                            alt={message.attachment_name}
                                            className="max-h-72 w-full object-contain bg-artisan-bone/30"
                                          />
                                        </a>
                                      ) : null}
                                      {isVideoAttachment(message) ? (
                                        <video
                                          controls
                                          className="max-h-72 w-full rounded-2xl border border-artisan-clay bg-black"
                                          src={message.attachment_url}
                                        />
                                      ) : null}
                                      <a
                                        href={message.attachment_url}
                                        target="_blank"
                                        rel="noopener noreferrer"
                                        className="inline-flex text-xs font-medium text-artisan-sienna underline underline-offset-2"
                                      >
                                        Open attachment: {message.attachment_name}
                                      </a>
                                    </>
                                  ) : (
                                    <p className="text-xs text-muted-foreground">
                                      Attachment uploaded: {message.attachment_name}
                                    </p>
                                  )}
                                </div>
                              ) : null}
                            </div>
                          ))
                        ) : (
                          <p className="rounded-2xl border border-artisan-clay bg-white p-3 text-sm text-muted-foreground">
                            No dispute messages yet.
                          </p>
                        )}
                      </div>
                    </div>
                  ) : (
                    <p className="rounded-2xl border border-artisan-clay bg-artisan-bone/30 p-3 text-sm text-muted-foreground">
                      No dispute conversation has been created yet.
                    </p>
                  )}
                  {dispute.resolution ? (
                    <p className="text-sm text-muted-foreground">
                      <span className="font-medium text-artisan-sienna">Resolution:</span>{" "}
                      {dispute.resolution}
                    </p>
                  ) : null}
                </div>

                {dispute.status === "open" || dispute.status === "investigating" ? (
                  <div className="w-full max-w-xl space-y-3">
                    <DisputeResolutionForm
                      action={resolveDisputeRelease}
                      buttonClassName="bg-artisan-baobab text-white hover:bg-artisan-baobab/90"
                      disputeId={dispute.id}
                      idleContent={
                        <>
                          <CheckCircle2 className="mr-2 h-4 w-4" />
                          Release Funds
                        </>
                      }
                      orderId={dispute.order_id}
                      pendingLabel="Releasing..."
                      placeholder="Explain why funds should be released to the seller..."
                    />

                    <DisputeResolutionForm
                      action={resolveDisputeRefund}
                      buttonClassName="bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"
                      disputeId={dispute.id}
                      idleContent={
                        <>
                          <Undo2 className="mr-2 h-4 w-4" />
                          Refund Buyer
                        </>
                      }
                      orderId={dispute.order_id}
                      pendingLabel="Refunding..."
                      placeholder="Explain why the buyer should be refunded..."
                    />
                  </div>
                ) : null}
              </div>
            </div>
          ))}
        </div>
      </PanelCard>
    </>
  );
}
