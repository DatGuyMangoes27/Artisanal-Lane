import { AdminPageHeader, PanelCard } from "@/components/admin/admin-ui";
import { PushNotificationForm } from "@/components/admin/push-notification-form";
import { searchNotificationRecipients } from "@/lib/admin-data";

function readParam(value: string | string[] | undefined, fallback = "") {
  return typeof value === "string" ? value : fallback;
}

export default async function AdminNotificationsPage({
  searchParams,
}: {
  searchParams: Promise<{ [key: string]: string | string[] | undefined }>;
}) {
  const params = await searchParams;
  const query = readParam(params.query);
  const recipients = query ? await searchNotificationRecipients(query) : [];

  return (
    <>
      <AdminPageHeader
        eyebrow="Engagement"
        title="Push Notifications"
        description="Send a custom push notification to a single user or a whole audience. Notifications also appear in the app's notification feed."
      />

      <div className="space-y-6">
        <PanelCard
          title="Find a specific user"
          description="Only needed when sending to a single user. Search by email address or display name."
        >
          <form className="flex flex-wrap gap-3" method="get">
            <input
              className="w-full max-w-md rounded-2xl border border-artisan-clay bg-white px-4 py-2 text-sm outline-none transition focus:border-artisan-terracotta"
              defaultValue={query}
              name="query"
              placeholder="Search by email or name..."
              type="search"
            />
            <button
              className="rounded-2xl bg-artisan-terracotta px-5 py-2 text-sm font-medium text-white transition hover:bg-artisan-terracotta/90"
              type="submit"
            >
              Search
            </button>
          </form>
          {query ? (
            <p className="mt-3 text-sm text-muted-foreground">
              {recipients.length === 0
                ? `No users found for "${query}".`
                : `${recipients.length} ${recipients.length === 1 ? "user" : "users"} found. Pick the recipient in the form below.`}
            </p>
          ) : null}
        </PanelCard>

        <PanelCard
          title="Compose notification"
          description="Choose the audience, write the message, and send. Delivery uses each user's registered devices."
        >
          <PushNotificationForm recipients={recipients} />
        </PanelCard>
      </div>
    </>
  );
}
