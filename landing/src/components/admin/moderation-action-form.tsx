"use client";

import { useActionState, useId, useRef } from "react";
import { ShieldAlert, X } from "lucide-react";

import { runModerationAction } from "@/app/admin/moderation-actions";
import { AdminActionFeedback } from "@/components/admin/admin-action-feedback";
import { Button } from "@/components/ui/button";
import { initialAdminActionState } from "@/lib/admin-action-state";
import { type ModerationActionKind, maxNoteLength } from "@/lib/admin-moderation";

type ModerationActionFormProps = {
  kind: ModerationActionKind;
  targetId: string;
  reportId?: string | null;
  label: string;
  title: string;
  description: string;
  noteRequired: boolean;
  tone?: "danger" | "primary" | "neutral";
};

const toneClasses = {
  danger: "bg-red-800 text-white hover:bg-red-900",
  primary: "bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark",
  neutral: "border border-artisan-clay bg-white text-artisan-sienna hover:bg-artisan-bone",
} as const;

export function ModerationActionForm({
  kind,
  targetId,
  reportId,
  label,
  title,
  description,
  noteRequired,
  tone = "neutral",
}: ModerationActionFormProps) {
  const [state, formAction, pending] = useActionState(
    runModerationAction,
    initialAdminActionState,
  );
  const dialogRef = useRef<HTMLDialogElement>(null);
  const titleId = useId();
  const descriptionId = useId();
  const noteId = useId();

  return (
    <div className="space-y-2">
      <Button
        className={`min-h-11 px-4 ${toneClasses[tone]}`}
        disabled={pending}
        type="button"
        onClick={() => dialogRef.current?.showModal()}
      >
        {pending ? "Working..." : label}
      </Button>
      <AdminActionFeedback state={state} />
      <dialog
        ref={dialogRef}
        aria-labelledby={titleId}
        aria-describedby={descriptionId}
        className="m-auto w-[calc(100%-2rem)] max-w-lg rounded-[1.75rem] border border-artisan-clay bg-[#FFF9F2] p-0 text-left text-foreground shadow-2xl backdrop:bg-black/60 backdrop:backdrop-blur-sm"
        onClick={(event) => {
          if (event.target === event.currentTarget) dialogRef.current?.close();
        }}
      >
        <form
          action={formAction}
          className="relative p-6 sm:p-8"
          onSubmit={() => dialogRef.current?.close()}
        >
          <input type="hidden" name="kind" value={kind} />
          <input type="hidden" name="targetId" value={targetId} />
          {reportId ? <input type="hidden" name="reportId" value={reportId} /> : null}
          <button
            type="button"
            aria-label="Close confirmation"
            className="absolute right-4 top-4 grid size-11 place-items-center rounded-full border border-artisan-clay bg-white text-artisan-sienna transition hover:bg-artisan-sand"
            onClick={() => dialogRef.current?.close()}
          >
            <X className="size-5" aria-hidden="true" />
          </button>
          <div className="mb-4 grid size-12 place-items-center rounded-2xl bg-red-100 text-red-800">
            <ShieldAlert className="size-6" aria-hidden="true" />
          </div>
          <h2 id={titleId} className="pr-12 font-serif text-2xl font-bold text-artisan-sienna">
            {title}
          </h2>
          <p id={descriptionId} className="mt-3 text-sm leading-6 text-muted-foreground">
            {description}
          </p>
          <label htmlFor={noteId} className="mt-5 block text-sm font-medium text-artisan-sienna">
            {noteRequired ? "Note (required)" : "Note (optional)"}
          </label>
          <textarea
            id={noteId}
            name="note"
            required={noteRequired}
            maxLength={maxNoteLength(kind)}
            rows={4}
            className="mt-2 w-full rounded-2xl border border-artisan-clay bg-white p-3 text-base text-foreground"
            placeholder="Recorded in the moderation log."
          />
          <div className="mt-6 flex flex-col-reverse gap-3 sm:flex-row sm:justify-end">
            <Button
              type="button"
              variant="outline"
              className="min-h-11 border-artisan-clay bg-white px-5"
              onClick={() => dialogRef.current?.close()}
            >
              Cancel
            </Button>
            <Button
              type="submit"
              className={`min-h-11 px-5 ${tone === "danger" ? "bg-red-800 text-white hover:bg-red-900" : "bg-artisan-terracotta text-white hover:bg-artisan-terracotta-dark"}`}
            >
              Confirm
            </Button>
          </div>
        </form>
      </dialog>
    </div>
  );
}
