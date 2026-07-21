"use client";

import { useActionState } from "react";

import { deleteBuyerAccount } from "@/app/account/actions";
import { Button } from "@/components/ui/button";

const initialState = {
  error: null as string | null,
};

export function DeleteAccountForm() {
  const [state, formAction, pending] = useActionState(
    deleteBuyerAccount,
    initialState,
  );

  return (
    <form
      action={formAction}
      className="space-y-3"
      onSubmit={(event) => {
        if (
          !window.confirm(
            "Delete your Artisan Lane account permanently? This cannot be undone.",
          )
        ) {
          event.preventDefault();
        }
      }}
    >
      <Button
        type="submit"
        variant="outline"
        className="rounded-full border-red-200 text-red-700 hover:text-red-800"
        disabled={pending}
      >
        {pending ? "Deleting account..." : "Delete my account"}
      </Button>
      {state.error ? (
        <p
          aria-live="polite"
          className="max-w-xl text-sm font-medium text-red-700"
          role="alert"
        >
          {state.error}
        </p>
      ) : null}
    </form>
  );
}
