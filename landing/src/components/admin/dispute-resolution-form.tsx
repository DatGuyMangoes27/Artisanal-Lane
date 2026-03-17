"use client";

import { useActionState } from "react";

import { AdminActionFeedback } from "@/components/admin/admin-action-feedback";
import { Button } from "@/components/ui/button";
import type { AdminActionState } from "@/lib/admin-action-state";
import { initialAdminActionState } from "@/lib/admin-action-state";

type DisputeResolutionFormProps = {
  action: (
    previousState: AdminActionState,
    formData: FormData,
  ) => Promise<AdminActionState>;
  disputeId: string;
  orderId: string;
  placeholder: string;
  buttonClassName: string;
  pendingLabel: string;
  idleContent: React.ReactNode;
};

export function DisputeResolutionForm({
  action,
  disputeId,
  orderId,
  placeholder,
  buttonClassName,
  pendingLabel,
  idleContent,
}: DisputeResolutionFormProps) {
  const [state, formAction, pending] = useActionState(
    action,
    initialAdminActionState,
  );

  return (
    <form action={formAction} className="space-y-3">
      <input name="disputeId" type="hidden" value={disputeId} />
      <input name="orderId" type="hidden" value={orderId} />
      <textarea
        className="min-h-24 w-full rounded-2xl border border-artisan-clay bg-artisan-bone/30 px-4 py-3 text-sm outline-none transition focus:border-artisan-terracotta"
        name="resolution"
        placeholder={placeholder}
        required
      />
      <div className="flex flex-wrap items-center gap-3">
        <Button className={buttonClassName} disabled={pending} type="submit">
          {pending ? pendingLabel : idleContent}
        </Button>
        <AdminActionFeedback state={state} />
      </div>
    </form>
  );
}
