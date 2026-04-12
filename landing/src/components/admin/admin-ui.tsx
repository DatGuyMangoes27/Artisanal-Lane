import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { cn } from "@/lib/utils";

export function AdminPageHeader({
  eyebrow,
  title,
  description,
  actions,
}: {
  eyebrow: string;
  title: string;
  description: string;
  actions?: React.ReactNode;
}) {
  return (
    <div className="mb-6 flex flex-col gap-4 rounded-3xl border border-artisan-clay/70 bg-white/85 p-6 shadow-lg backdrop-blur md:flex-row md:items-end md:justify-between">
      <div>
        <p className="text-xs uppercase tracking-[0.3em] text-artisan-terracotta">
          {eyebrow}
        </p>
        <h2 className="mt-2 text-4xl font-semibold text-artisan-sienna">
          {title}
        </h2>
        <p className="mt-2 max-w-2xl text-sm text-muted-foreground">
          {description}
        </p>
      </div>
      {actions ? <div className="shrink-0">{actions}</div> : null}
    </div>
  );
}

export function MetricCard({
  label,
  value,
  helper,
}: {
  label: string;
  value: string;
  helper: string;
}) {
  return (
    <Card className="border-artisan-clay/70 bg-white/90">
      <CardHeader className="pb-3">
        <CardDescription className="text-xs uppercase tracking-[0.2em] text-artisan-terracotta">
          {label}
        </CardDescription>
        <CardTitle className="text-3xl text-artisan-sienna">{value}</CardTitle>
      </CardHeader>
      <CardContent className="pt-0 text-sm text-muted-foreground">
        {helper}
      </CardContent>
    </Card>
  );
}

export function PanelCard({
  title,
  description,
  children,
}: {
  title: string;
  description?: string;
  children: React.ReactNode;
}) {
  return (
    <Card className="border-artisan-clay/70 bg-white/90">
      <CardHeader>
        <CardTitle className="text-2xl text-artisan-sienna">{title}</CardTitle>
        {description ? (
          <CardDescription>{description}</CardDescription>
        ) : null}
      </CardHeader>
      <CardContent>{children}</CardContent>
    </Card>
  );
}

export function StatusBadge({
  value,
}: {
  value: string | null | undefined;
}) {
  const normalized = (value ?? "unknown").toLowerCase();
  const className = cn(
    "border px-2.5 py-1 text-xs font-medium capitalize",
    normalized === "approved" ||
      normalized === "active" ||
      normalized === "published" ||
      normalized === "featured" ||
      normalized === "spotlight" ||
      normalized === "verified" ||
      normalized === "released" ||
      normalized === "completed" ||
      normalized === "shipped" ||
      normalized === "delivered"
      ? "border-green-200 bg-green-50 text-green-700"
      : normalized === "pending" ||
          normalized === "submitted" ||
          normalized === "under_review" ||
          normalized === "processing" ||
          normalized === "offline" ||
          normalized === "paid" ||
          normalized === "held"
        ? "border-amber-200 bg-amber-50 text-amber-700"
        : normalized === "disputed" ||
            normalized === "action_required" ||
            normalized === "cancelled" ||
            normalized === "suspended" ||
            normalized === "inactive" ||
            normalized === "open" ||
            normalized === "investigating"
          ? "border-red-200 bg-red-50 text-red-700"
          : "border-artisan-clay bg-artisan-bone text-artisan-sienna",
  );

  return <Badge className={className}>{value ?? "Unknown"}</Badge>;
}
