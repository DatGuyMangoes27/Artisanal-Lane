"use client";

import { useRouter } from "next/navigation";
import { LogOut } from "lucide-react";

import { Button } from "@/components/ui/button";
import { createClient } from "@/lib/supabase/browser";
import { cn } from "@/lib/utils";

type VendorLogoutButtonProps = {
  className?: string;
  variant?: "default" | "ghost" | "outline";
};

export function VendorLogoutButton({
  className,
  variant = "ghost",
}: VendorLogoutButtonProps) {
  const router = useRouter();

  async function handleSignOut() {
    const supabase = createClient();
    await supabase.auth.signOut();
    router.replace("/login?intent=vendor&signedOut=1");
    router.refresh();
  }

  return (
    <Button
      type="button"
      variant={variant}
      className={cn("justify-start rounded-2xl", className)}
      onClick={handleSignOut}
    >
      <LogOut className="h-4 w-4" />
      Log out
    </Button>
  );
}
