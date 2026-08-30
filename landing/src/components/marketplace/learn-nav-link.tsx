import Link from "next/link";

export function TutorialsNavLink({ active = false }: { active?: boolean }) {
  return (
    <Link
      href="/tutorials"
      className={
        active
          ? "font-semibold text-artisan-terracotta transition hover:text-artisan-terracotta-dark"
          : "transition hover:text-foreground"
      }
    >
      Tutorials
    </Link>
  );
}
