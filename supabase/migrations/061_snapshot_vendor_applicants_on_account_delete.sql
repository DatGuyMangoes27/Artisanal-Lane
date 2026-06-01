-- Preserve enough application context for admin audit/drop-off tracking when
-- an applicant deletes their account and the profile row is removed.
alter table public.vendor_applications
add column if not exists applicant_user_id_snapshot uuid,
add column if not exists applicant_display_name_snapshot text,
add column if not exists applicant_email_snapshot text,
add column if not exists applicant_account_deleted_at timestamptz;

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
  )
from public.profiles as profile
where application.user_id = profile.id
  and (
    application.applicant_user_id_snapshot is null
    or application.applicant_display_name_snapshot is null
    or application.applicant_email_snapshot is null
  );

create index if not exists idx_vendor_applications_deleted_applicants
on public.vendor_applications (applicant_account_deleted_at)
where applicant_account_deleted_at is not null;
