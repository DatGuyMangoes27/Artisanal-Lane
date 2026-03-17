"use client";

import { useActionState } from "react";

import { updateStationeryRequest } from "@/app/admin/actions";
import { AdminActionFeedback } from "@/components/admin/admin-action-feedback";
import { Button } from "@/components/ui/button";
import { initialAdminActionState } from "@/lib/admin-action-state";

type StationeryRequestFormProps = {
  request: {
    id: string;
    status: string;
    courier_name: string | null;
    tracking_number: string | null;
    admin_notes: string | null;
  };
};

export function StationeryRequestForm({
  request,
}: StationeryRequestFormProps) {
  const [state, formAction, pending] = useActionState(
    updateStationeryRequest,
    initialAdminActionState,
  );

  return (
    <form action={formAction} className="w-full max-w-xl space-y-3">
      <input name="requestId" type="hidden" value={request.id} />
      <div className="grid gap-3 md:grid-cols-2">
        <label className="space-y-1">
          <span className="text-sm font-medium text-artisan-sienna">Status</span>
          <select
            className="w-full rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={request.status}
            name="status"
          >
            <option value="pending">Pending</option>
            <option value="processing">Processing</option>
            <option value="shipped">Shipped</option>
            <option value="delivered">Delivered</option>
            <option value="cancelled">Cancelled</option>
          </select>
        </label>
        <label className="space-y-1">
          <span className="text-sm font-medium text-artisan-sienna">Courier</span>
          <input
            className="w-full rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
            defaultValue={request.courier_name ?? ""}
            name="courierName"
            placeholder="Courier Guy, Pargo, local courier..."
            type="text"
          />
        </label>
      </div>

      <label className="block space-y-1">
        <span className="text-sm font-medium text-artisan-sienna">
          Tracking number
        </span>
        <input
          className="w-full rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
          defaultValue={request.tracking_number ?? ""}
          name="trackingNumber"
          placeholder="Add tracking reference when dispatched"
          type="text"
        />
      </label>

      <label className="block space-y-1">
        <span className="text-sm font-medium text-artisan-sienna">Admin notes</span>
        <textarea
          className="min-h-24 w-full rounded-2xl border border-artisan-clay bg-white px-4 py-3 text-sm outline-none transition focus:border-artisan-terracotta"
          defaultValue={request.admin_notes ?? ""}
          name="adminNotes"
          placeholder="Packing notes, stock issues, courier follow-up..."
        />
      </label>

      <div className="flex flex-wrap items-center gap-3">
        <Button
          className="bg-artisan-sienna text-white hover:bg-artisan-sienna/90"
          disabled={pending}
          type="submit"
        >
          {pending ? "Saving..." : "Save update"}
        </Button>
        <AdminActionFeedback state={state} />
      </div>
    </form>
  );
}
