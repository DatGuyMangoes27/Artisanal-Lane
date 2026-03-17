"use client";

import { useActionState } from "react";

import { AdminActionFeedback } from "@/components/admin/admin-action-feedback";
import { Button } from "@/components/ui/button";
import type { AdminActionState } from "@/lib/admin-action-state";
import { initialAdminActionState } from "@/lib/admin-action-state";

type HiddenField = {
  name: string;
  value: string;
};

type AdminActionButtonFormProps = {
  action: (
    previousState: AdminActionState,
    formData: FormData,
  ) => Promise<AdminActionState>;
  hiddenFields: HiddenField[];
  idleContent: React.ReactNode;
  pendingLabel: string;
  buttonClassName: string;
  formClassName?: string;
};

export function AdminActionButtonForm({
  action,
  hiddenFields,
  idleContent,
  pendingLabel,
  buttonClassName,
  formClassName,
}: AdminActionButtonFormProps) {
  const [state, formAction, pending] = useActionState(
    action,
    initialAdminActionState,
  );

  return (
    <form action={formAction} className={formClassName ?? "space-y-2"}>
      {hiddenFields.map((field) => (
        <input key={field.name} name={field.name} type="hidden" value={field.value} />
      ))}
      <Button className={buttonClassName} disabled={pending} type="submit">
        {pending ? pendingLabel : idleContent}
      </Button>
      <AdminActionFeedback state={state} />
    </form>
  );
}
