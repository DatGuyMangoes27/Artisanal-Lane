"use client";

import { useActionState, useState } from "react";

import { sendAdminPushNotification } from "@/app/admin/actions";
import { AdminActionFeedback } from "@/components/admin/admin-action-feedback";
import { Button } from "@/components/ui/button";
import { initialAdminActionState } from "@/lib/admin-action-state";
import type { AdminNotificationRecipient } from "@/lib/admin-data";

const inputClass =
  "w-full rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta";

const audienceOptions = [
  {
    value: "user",
    label: "A specific user",
    description: "Search by email or name above, then pick the recipient.",
  },
  {
    value: "all_vendors",
    label: "All artisans",
    description: "Every account with the vendor role.",
  },
  {
    value: "all_buyers",
    label: "All customers",
    description: "Every account with the buyer role.",
  },
  {
    value: "subscribed_vendors",
    label: "Subscribed artisans",
    description: "Artisans with an active subscription.",
  },
  {
    value: "vendors_without_shop",
    label: "Artisans without a store",
    description: "Vendor accounts that have not set up a shop yet.",
  },
] as const;

function recipientLabel(recipient: AdminNotificationRecipient) {
  const name = recipient.display_name?.trim() || "Unnamed user";
  const email = recipient.email?.trim();
  return `${name}${email ? ` (${email})` : ""} - ${recipient.role}`;
}

export function PushNotificationForm({
  recipients,
}: {
  recipients: AdminNotificationRecipient[];
}) {
  const [state, formAction, pending] = useActionState(
    sendAdminPushNotification,
    initialAdminActionState,
  );
  const [audience, setAudience] = useState<string>(
    recipients.length > 0 ? "user" : "all_vendors",
  );

  return (
    <form action={formAction} className="space-y-4">
      <fieldset className="space-y-2">
        <legend className="text-sm font-medium text-artisan-sienna">Audience</legend>
        {audienceOptions.map((option) => (
          <label
            key={option.value}
            className="flex items-start gap-3 rounded-2xl border border-artisan-clay bg-white px-4 py-3"
          >
            <input
              checked={audience === option.value}
              className="mt-1"
              name="audience"
              onChange={() => setAudience(option.value)}
              type="radio"
              value={option.value}
            />
            <span>
              <span className="block text-sm font-medium text-artisan-sienna">
                {option.label}
              </span>
              <span className="block text-xs text-muted-foreground">
                {option.description}
              </span>
            </span>
          </label>
        ))}
      </fieldset>

      {audience === "user" ? (
        <label className="block space-y-1">
          <span className="text-sm font-medium text-artisan-sienna">Recipient</span>
          {recipients.length > 0 ? (
            <select className={inputClass} defaultValue={recipients[0].id} name="userId">
              {recipients.map((recipient) => (
                <option key={recipient.id} value={recipient.id}>
                  {recipientLabel(recipient)}
                </option>
              ))}
            </select>
          ) : (
            <p className="rounded-2xl border border-dashed border-artisan-clay bg-white px-4 py-3 text-sm text-muted-foreground">
              Use the search above to find a user by email or name.
            </p>
          )}
        </label>
      ) : null}

      <label className="block space-y-1">
        <span className="text-sm font-medium text-artisan-sienna">Title</span>
        <input
          className={inputClass}
          maxLength={120}
          name="title"
          placeholder="e.g. New feature for artisans"
          required
        />
      </label>

      <label className="block space-y-1">
        <span className="text-sm font-medium text-artisan-sienna">Message</span>
        <textarea
          className={`${inputClass} min-h-24`}
          maxLength={500}
          name="body"
          placeholder="The notification text shown on the user's device."
          required
        />
      </label>

      <label className="block space-y-1">
        <span className="text-sm font-medium text-artisan-sienna">
          App link (optional)
        </span>
        <input
          className={inputClass}
          name="route"
          placeholder="e.g. /learn or /vendor/orders"
        />
        <span className="text-xs text-muted-foreground">
          An in-app route opened when the user taps the notification. Must start with /.
        </span>
      </label>

      <div className="flex flex-wrap items-center gap-3">
        <Button
          className="bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
          disabled={pending}
          type="submit"
        >
          {pending ? "Sending..." : "Send notification"}
        </Button>
        <AdminActionFeedback state={state} />
      </div>
    </form>
  );
}
