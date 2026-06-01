-- Keep vendor application records visible in the admin portal after an
-- applicant deletes their account. The profile row can disappear, but the
-- review/audit record should remain.
alter table public.vendor_applications
drop constraint if exists vendor_applications_user_id_fkey;

alter table public.vendor_applications
alter column user_id drop not null;

alter table public.vendor_applications
add constraint vendor_applications_user_id_fkey
foreign key (user_id) references public.profiles(id) on delete set null;
