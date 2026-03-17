"use client";

import { useEffect, useRef } from "react";
import { useRouter } from "next/navigation";

import { createClient } from "@/lib/supabase/browser";

const watchedTables = [
  "orders",
  "vendor_applications",
  "disputes",
  "products",
  "shops",
  "shop_posts",
  "admin_shop_notes",
  "stationery_requests",
];

export function AdminLiveRefresh() {
  const router = useRouter();
  const refreshTimer = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    const supabase = createClient();
    const channel = supabase.channel("admin-live-refresh");

    for (const table of watchedTables) {
      channel.on(
        "postgres_changes",
        {
          event: "*",
          schema: "public",
          table,
        },
        () => {
          if (refreshTimer.current) {
            clearTimeout(refreshTimer.current);
          }

          refreshTimer.current = setTimeout(() => {
            router.refresh();
          }, 400);
        },
      );
    }

    channel.subscribe();

    return () => {
      if (refreshTimer.current) {
        clearTimeout(refreshTimer.current);
      }
      supabase.removeChannel(channel);
    };
  }, [router]);

  return null;
}
