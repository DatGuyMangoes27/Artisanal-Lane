-- Education/scheduling tables are not used by the Artisan Lane app, website or
-- functions and received no API traffic. Lock them to trusted server access
-- without dropping or changing data, in case another project owns them.
alter table public.students enable row level security;
alter table public.teachers enable row level security;
alter table public.lesson_slots enable row level security;
alter table public.teacher_branch_assignments enable row level security;
revoke all on public.students, public.teachers, public.lesson_slots,
  public.teacher_branch_assignments, public.branches, public.rooms,
  public.lesson_occurrences, public.teaching_departments, public.subscription_plans
from anon, authenticated;
