import Link from "next/link";
import { ImageIcon, Paperclip } from "lucide-react";

export function ChatMessageAttachment({
  url,
  name,
  mime,
  mine = false,
}: {
  url: string | null;
  name: string | null;
  mime: string | null;
  mine?: boolean;
}) {
  if (!url) return null;
  const label = name ?? "Message photo";
  const isImage = mime?.startsWith("image/") ?? false;

  return (
    <Link
      href={url}
      target="_blank"
      rel="noreferrer"
      className={`mb-2 block overflow-hidden rounded-2xl border ${mine ? "border-white/20 bg-white/10" : "border-artisan-clay bg-white"}`}
    >
      {isImage ? (
        // Signed private-storage URLs are short-lived and are intentionally not optimized.
        // eslint-disable-next-line @next/next/no-img-element
        <img src={url} alt={label} className="max-h-80 w-full object-contain" />
      ) : null}
      <span className="flex items-center gap-2 px-3 py-2 text-xs font-medium">
        {isImage ? <ImageIcon className="size-4" /> : <Paperclip className="size-4" />}
        <span className="truncate">{label}</span>
      </span>
    </Link>
  );
}
