import type { AdminActionState } from "@/lib/admin-action-state";

function formatSavedAt(value: string | null) {
  if (!value) {
    return null;
  }

  return new Date(value).toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function AdminActionFeedback({
  state,
}: {
  state: AdminActionState;
}) {
  if (state.status === "idle" && !state.message) {
    return null;
  }

  return (
    <p
      aria-live="polite"
      className={
        state.status === "error"
          ? "text-sm text-red-600"
          : state.status === "success"
            ? "text-sm text-green-700"
            : "text-sm text-muted-foreground"
      }
    >
      {state.status === "success"
        ? `${state.message} ${formatSavedAt(state.savedAt) ? `Saved at ${formatSavedAt(state.savedAt)}.` : ""}`.trim()
        : state.message}
    </p>
  );
}
