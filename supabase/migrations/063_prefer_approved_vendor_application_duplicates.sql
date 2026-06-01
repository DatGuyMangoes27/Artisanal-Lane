-- Follow-up for projects that already archived duplicates by newest row first.
-- If a duplicate set contains an approved row, keep the approved row attached to
-- the applicant so onboarding state matches the vendor role/admin decision.
with candidate_rows as (
  select
    application.id,
    coalesce(application.user_id, application.applicant_user_id_snapshot) as applicant_id,
    application.user_id,
    application.status,
    application.created_at,
    row_number() over (
      partition by coalesce(application.user_id, application.applicant_user_id_snapshot)
      order by
        case application.status
          when 'approved' then 1
          when 'pending' then 2
          else 3
        end,
        application.created_at desc,
        application.id desc
    ) as rank
  from public.vendor_applications as application
  where coalesce(application.user_id, application.applicant_user_id_snapshot) is not null
),
preferred_rows as (
  select *
  from candidate_rows
  where rank = 1 and user_id is null
),
current_rows as (
  select application.id, preferred.applicant_id, preferred.id as preferred_id
  from public.vendor_applications as application
  join preferred_rows as preferred
    on preferred.applicant_id = application.user_id
  where application.id <> preferred.id
)
update public.vendor_applications as application
set
  applicant_user_id_snapshot = coalesce(
    application.applicant_user_id_snapshot,
    current_rows.applicant_id
  ),
  superseded_by_application_id = current_rows.preferred_id,
  superseded_at = coalesce(application.superseded_at, now()),
  user_id = null
from current_rows
where application.id = current_rows.id;

with candidate_rows as (
  select
    application.id,
    coalesce(application.user_id, application.applicant_user_id_snapshot) as applicant_id,
    application.user_id,
    application.status,
    application.created_at,
    row_number() over (
      partition by coalesce(application.user_id, application.applicant_user_id_snapshot)
      order by
        case application.status
          when 'approved' then 1
          when 'pending' then 2
          else 3
        end,
        application.created_at desc,
        application.id desc
    ) as rank
  from public.vendor_applications as application
  where coalesce(application.user_id, application.applicant_user_id_snapshot) is not null
),
preferred_rows as (
  select *
  from candidate_rows
  where rank = 1 and user_id is null
)
update public.vendor_applications as application
set
  user_id = preferred.applicant_id,
  superseded_by_application_id = null,
  superseded_at = null
from preferred_rows as preferred
where application.id = preferred.id;
