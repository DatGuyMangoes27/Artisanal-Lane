import "server-only";

import { redirect } from "next/navigation";

import { createAdminClient } from "@/lib/supabase/admin";
import { createClient as createServerClient } from "@/lib/supabase/server";

type AdminProfile = {
  id: string;
  role: string;
  display_name: string | null;
  email: string | null;
};

export async function getAdminSession() {
  const supabase = await createServerClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();

  if (!user) {
    return null;
  }

  const admin = createAdminClient();
  const { data: profile, error } = await admin
    .from("profiles")
    .select("id, role, display_name, email")
    .eq("id", user.id)
    .maybeSingle<AdminProfile>();

  if (error || !profile) {
    return null;
  }

  return {
    user,
    profile,
  };
}

export async function requireAdminSession() {
  const session = await getAdminSession();

  if (!session?.user) {
    redirect("/admin/login");
  }

  if (session.profile.role !== "admin") {
    redirect("/admin/login?error=unauthorized");
  }

  return session;
}
