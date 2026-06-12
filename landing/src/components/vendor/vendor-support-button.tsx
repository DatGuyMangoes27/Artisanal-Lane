const WHATSAPP_SUPPORT_URL =
  "https://wa.me/27730687908?text=" +
  encodeURIComponent("Hi Artisan Lane support, I need help with my vendor shop.");

function WhatsAppIcon({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 32 32"
      fill="currentColor"
      aria-hidden
      className={className}
    >
      <path d="M16.04 4C9.46 4 4.13 9.33 4.13 15.91c0 2.1.55 4.15 1.6 5.95L4 28l6.3-1.65a11.86 11.86 0 0 0 5.73 1.46h.01c6.58 0 11.92-5.33 11.92-11.91 0-3.18-1.24-6.17-3.49-8.42A11.83 11.83 0 0 0 16.04 4Zm0 21.81h-.01a9.9 9.9 0 0 1-5.04-1.38l-.36-.21-3.74.98 1-3.65-.24-.37a9.86 9.86 0 0 1-1.51-5.27c0-5.46 4.44-9.9 9.91-9.9a9.84 9.84 0 0 1 9.9 9.91c0 5.46-4.45 9.89-9.91 9.89Zm5.43-7.41c-.3-.15-1.76-.87-2.04-.97-.27-.1-.47-.15-.67.15-.2.3-.77.97-.94 1.17-.17.2-.35.22-.65.07-.3-.15-1.25-.46-2.39-1.47a8.96 8.96 0 0 1-1.65-2.05c-.17-.3-.02-.46.13-.61.14-.13.3-.35.45-.52.15-.17.2-.3.3-.5.1-.2.05-.37-.03-.52-.07-.15-.66-1.6-.91-2.2-.24-.57-.49-.5-.67-.5l-.57-.01c-.2 0-.52.07-.8.37-.27.3-1.04 1.02-1.04 2.48 0 1.46 1.07 2.88 1.22 3.08.15.2 2.1 3.2 5.08 4.49.71.3 1.26.49 1.7.63.71.22 1.36.19 1.87.12.57-.09 1.76-.72 2-1.42.25-.7.25-1.29.18-1.42-.07-.12-.27-.2-.57-.35Z" />
    </svg>
  );
}

/**
 * Floating WhatsApp support button. Rendered inside the vendor portal shell,
 * so it is only ever visible to logged-in vendors.
 */
export function VendorSupportButton() {
  return (
    <a
      href={WHATSAPP_SUPPORT_URL}
      target="_blank"
      rel="noopener noreferrer"
      aria-label="Chat to Artisan Lane support on WhatsApp"
      className="fixed bottom-6 right-6 z-50 flex items-center gap-2 rounded-full bg-[#25D366] px-4 py-3 text-sm font-semibold text-white shadow-xl transition hover:scale-105 hover:bg-[#1ebe5b]"
    >
      <WhatsAppIcon className="h-6 w-6" />
      <span className="hidden sm:inline">Support</span>
    </a>
  );
}
