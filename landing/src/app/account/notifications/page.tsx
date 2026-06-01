import Link from "next/link";

import { markNotificationRead } from "@/app/account/actions";
import { MarketplaceHeader } from "@/components/marketplace/marketplace-header";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { requireBuyerAccountSession } from "@/lib/marketplace/account";
import { listBuyerNotifications } from "@/lib/marketplace/notification-data";

export default async function BuyerNotificationsPage() {
  const { user } = await requireBuyerAccountSession("/account/notifications");
  const notifications = await listBuyerNotifications(user.id);

  return (
    <div className="min-h-screen bg-background">
      <MarketplaceHeader />
      <main className="mx-auto max-w-4xl px-4 py-10 sm:px-6 lg:px-8">
        <div className="flex flex-col gap-4 md:flex-row md:items-end md:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.28em] text-artisan-terracotta">
              Buyer account
            </p>
            <h1 className="mt-3 font-serif text-4xl font-bold tracking-tight text-foreground md:text-5xl">
              Notifications
            </h1>
          </div>
          <Button asChild variant="outline" className="rounded-full">
            <Link href="/account">Back to account</Link>
          </Button>
        </div>

        <div className="mt-10 space-y-4">
          {notifications.length === 0 ? (
            <Card className="border-artisan-clay bg-card text-center">
              <CardContent className="p-8">
                <h2 className="font-serif text-2xl font-bold text-foreground">No notifications yet</h2>
                <p className="mt-2 text-muted-foreground">
                  Order updates, receipt reminders, and dispute messages will appear here.
                </p>
              </CardContent>
            </Card>
          ) : null}
          {notifications.map((notification) => (
            <Card key={notification.id} className="border-artisan-clay bg-card">
              <CardContent className="p-5">
                <div className="flex flex-col gap-3 md:flex-row md:items-start md:justify-between">
                  <div>
                    <div className="flex flex-wrap items-center gap-2">
                      <h2 className="font-serif text-xl font-bold text-foreground">{notification.title}</h2>
                      {!notification.readAt ? <Badge className="bg-artisan-terracotta">New</Badge> : null}
                    </div>
                    {notification.body ? (
                      <p className="mt-2 text-sm leading-6 text-muted-foreground">{notification.body}</p>
                    ) : null}
                    <p className="mt-2 text-xs text-muted-foreground">
                      {new Date(notification.createdAt).toLocaleString("en-ZA")}
                    </p>
                  </div>
                  {!notification.readAt ? (
                    <form action={markNotificationRead}>
                      <input type="hidden" name="notificationId" value={notification.id} />
                      <input type="hidden" name="redirectTo" value="/account/notifications" />
                      <Button type="submit" variant="outline" className="rounded-full">
                        Mark read
                      </Button>
                    </form>
                  ) : null}
                </div>
              </CardContent>
            </Card>
          ))}
        </div>
      </main>
    </div>
  );
}
