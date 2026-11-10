import { AdminPageHeader, PanelCard } from "@/components/admin/admin-ui";
import { Button } from "@/components/ui/button";
import { requireAdminSession } from "@/lib/admin-auth";
import { listMarketingContacts } from "@/lib/marketing-contacts-data";

export const dynamic = "force-dynamic";

export default async function AdminContactsPage() {
  await requireAdminSession();
  const contacts = await listMarketingContacts();
  const withPhone = contacts.filter((c) => c.phone).length;

  return (
    <>
      <AdminPageHeader
        eyebrow="Marketing"
        title="Contacts"
        description="Buyers who ticked Keep me posted at checkout, plus newsletter sign-ups. Only people who agreed are listed, and anyone who unsubscribes drops off."
        actions={
          <Button asChild className="rounded-full">
            <a href="/admin/contacts/export">Download CSV</a>
          </Button>
        }
      />
      <PanelCard
        title={`${contacts.length} contacts`}
        description={`${withPhone} with a phone number. The CSV (email, phone, fn) can be uploaded straight to a Meta Custom Audience.`}
      >
        <div className="overflow-x-auto">
          <table className="w-full text-left text-sm">
            <thead className="text-xs uppercase tracking-wider text-muted-foreground">
              <tr>
                <th className="py-2 pr-4">Name</th>
                <th className="py-2 pr-4">Email</th>
                <th className="py-2 pr-4">Phone</th>
                <th className="py-2 pr-4">Where</th>
                <th className="py-2">Agreed</th>
              </tr>
            </thead>
            <tbody>
              {contacts.slice(0, 200).map((c) => (
                <tr key={`${c.email}-${c.phone}`} className="border-t border-border/60">
                  <td className="py-2 pr-4">{c.name ?? "-"}</td>
                  <td className="py-2 pr-4">{c.email ?? "-"}</td>
                  <td className="py-2 pr-4">{c.phone ?? "-"}</td>
                  <td className="py-2 pr-4">{c.source}</td>
                  <td className="py-2">{c.consentedAt.slice(0, 10)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          {contacts.length > 200 ? (
            <p className="mt-3 text-xs text-muted-foreground">Showing the latest 200. The CSV has everyone.</p>
          ) : null}
        </div>
      </PanelCard>
    </>
  );
}
