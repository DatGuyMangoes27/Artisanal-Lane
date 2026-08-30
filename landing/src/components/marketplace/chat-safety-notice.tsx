import { ShieldAlert } from "lucide-react";

export function ChatSafetyNotice() {
  return (
    <div className="flex items-start gap-3 rounded-2xl border border-amber-300/70 bg-amber-50 px-4 py-3 text-sm text-amber-900">
      <ShieldAlert className="mt-0.5 h-4 w-4 shrink-0" />
      <p>
        <span className="font-semibold">Keep it on Artisan Lane:</span> Do not move a sale or
        customer conversation off the platform. Contact details supplied for payment or delivery
        may only be used to complete that order. Artisan Lane will never ask you to
        verify payment details, click a link to receive funds, or share banking information in
        chat. Report suspicious messages to{" "}
        <a className="font-semibold underline" href="mailto:admin@artisanlanesa.co.za">
          admin@artisanlanesa.co.za
        </a>
        .
      </p>
    </div>
  );
}
