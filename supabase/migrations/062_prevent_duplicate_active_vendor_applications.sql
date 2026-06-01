-- Keep the admin audit trail, but only one active application row should stay
-- attached to a live applicant. Older duplicate submissions are superseded so
-- app lookups and the admin queue do not loop over multiple rows.
alter table public.vendor_applications
add column if not exists superseded_by_application_id uuid
  references public.vendor_applications(id) on delete set null,
add column if not exists superseded_at timestamptz;

with ranked_applications as (
  select
    application.id,
    application.user_id,
    first_value(application.id) over (
      partition by application.user_id
      order by
        case application.status
          when 'approved' then 1
          when 'pending' then 2
          else 3
        end,
        application.created_at desc,
        application.id desc
    ) as latest_application_id,
    row_number() over (
      partition by application.user_id
      order by
        case application.status
          when 'approved' then 1
          when 'pending' then 2
          else 3
        end,
        application.created_at desc,
        application.id desc
    ) as row_number
  from public.vendor_applications as application
  where application.user_id is not null
),
duplicate_applications as (
  select *
  from ranked_applications
  where row_number > 1
)
update public.vendor_applications as application
set
  applicant_user_id_snapshot = coalesce(
    application.applicant_user_id_snapshot,
    application.user_id
  ),
  applicant_display_name_snapshot = coalesce(
    application.applicant_display_name_snapshot,
    profile.display_name
  ),
  applicant_email_snapshot = coalesce(
    application.applicant_email_snapshot,
    profile.email
  ),
  superseded_by_application_id = duplicate.latest_application_id,
  superseded_at = coalesce(application.superseded_at, now()),
  user_id = null
from duplicate_applications as duplicate
left join public.profiles as profile
  on profile.id = duplicate.user_id
where application.id = duplicate.id;

create unique index if not exists idx_vendor_applications_one_active_per_user
on public.vendor_applications (user_id)
where user_id is not null;

create index if not exists idx_vendor_applications_superseded
on public.vendor_applications (superseded_at)
where superseded_at is not null;
