import Link from "next/link";

import { LibraryPageContent } from "@/components/learning/library-page-content";

export default function AdminLibraryPage() {
  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center justify-between gap-3 rounded-3xl border border-artisan-clay bg-white p-5 text-sm text-muted-foreground">
        <p>This is the artisan Library as vendors see it. Resources are added and edited in the Learning Hub.</p>
        <Link
          className="rounded-full bg-artisan-sienna px-4 py-2 font-semibold text-white hover:bg-artisan-sienna/90"
          href="/admin/learning"
        >
          Add to Library
        </Link>
      </div>
      <LibraryPageContent />
    </div>
  );
}
