"use client";

import { useActionState, useId, useRef } from "react";
import { ShieldAlert, X } from "lucide-react";

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
  confirmMessage?: string;
};

export function AdminActionButtonForm({
  action,
  hiddenFields,
  idleContent,
  pendingLabel,
  buttonClassName,
  formClassName,
  confirmMessage,
}: AdminActionButtonFormProps) {
  const [state, formAction, pending] = useActionState(
    action,
    initialAdminActionState,
  );
  const confirmationDialogRef = useRef<HTMLDialogElement>(null);
  const confirmationTitleId = useId();
  const confirmationDescriptionId = useId();

  return (
    <form
      action={formAction}
      className={formClassName ?? "space-y-2"}
      onSubmit={() => confirmationDialogRef.current?.close()}
    >
      {hiddenFields.map((field) => (
        <input key={field.name} name={field.name} type="hidden" value={field.value} />
      ))}
      <Button
        className={buttonClassName}
        disabled={pending}
        type={confirmMessage ? "button" : "submit"}
        onClick={
          confirmMessage
            ? () => confirmationDialogRef.current?.showModal()
            : undefined
        }
      >
        {pending ? pendingLabel : idleContent}
      </Button>
      <AdminActionFeedback state={state} />
      {confirmMessage ? (
        <dialog
          ref={confirmationDialogRef}
          aria-labelledby={confirmationTitleId}
          aria-describedby={confirmationDescriptionId}
          className="m-auto w-[calc(100%-2rem)] max-w-lg rounded-[1.75rem] border border-artisan-clay bg-[#FFF9F2] p-0 text-left text-foreground shadow-2xl backdrop:bg-black/60 backdrop:backdrop-blur-sm"
          onClick={(event) => {
            if (event.target === event.currentTarget) {
              confirmationDialogRef.current?.close();
            }
          }}
        >
          <div className="relative p-6 sm:p-8">
            <button
              type="button"
              aria-label="Close confirmation"
              className="absolute right-5 top-5 grid size-10 place-items-center rounded-full border border-artisan-clay bg-white text-artisan-sienna transition hover:bg-artisan-sand"
              onClick={() => confirmationDialogRef.current?.close()}
            >
              <X className="size-5" aria-hidden="true" />
            </button>

            <div className="mb-5 grid size-14 place-items-center rounded-2xl bg-red-100 text-red-800">
              <ShieldAlert className="size-7" aria-hidden="true" />
            </div>
            <p className="mb-2 text-xs font-bold uppercase tracking-[0.24em] text-red-800">
              Irreversible action
            </p>
            <h2
              id={confirmationTitleId}
              className="pr-12 font-serif text-3xl font-bold text-artisan-sienna"
            >
              Release this payout?
            </h2>
            <p
              id={confirmationDescriptionId}
              className="mt-4 text-sm leading-6 text-muted-foreground sm:text-base"
            >
              {confirmMessage}
            </p>

            <div className="mt-7 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
              <Button
                type="button"
                variant="outline"
                className="min-h-11 border-artisan-clay bg-white px-5"
                onClick={() => confirmationDialogRef.current?.close()}
              >
                Keep payout on hold
              </Button>
              <Button
                type="submit"
                className="min-h-11 bg-red-800 px-5 text-white hover:bg-red-900"
              >
                Yes, release payout
              </Button>
            </div>
          </div>
        </dialog>
      ) : null}
    </form>
  );
}
