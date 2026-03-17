export type AdminActionState = {
  status: "idle" | "success" | "error";
  message: string | null;
  savedAt: string | null;
};

export const initialAdminActionState: AdminActionState = {
  status: "idle",
  message: null,
  savedAt: null,
};
