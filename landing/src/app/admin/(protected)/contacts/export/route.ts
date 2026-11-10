import { NextResponse } from "next/server";

import { getAdminSession } from "@/lib/admin-auth";
import { listMarketingContacts, marketingContactsCsv } from "@/lib/marketing-contacts-data";

export async function GET() {
  const session = await getAdminSession();
  if (!session || session.profile.role !== "admin") {
    return new NextResponse("Not allowed", { status: 403 });
  }
  const csv = marketingContactsCsv(await listMarketingContacts());
  const date = new Date().toISOString().slice(0, 10);
  return new NextResponse(csv, {
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="artisan-lane-contacts-${date}.csv"`,
      "Cache-Control": "no-store",
    },
  });
}
