-- Backfill profiles for any auth user that never got one.
--
-- The web buyer sign-up flow created the auth.users row via supabase.auth.signUp
-- but never created the matching public.profiles row (only the mobile app did,
-- via syncCurrentUserProfile). Those buyers then hit a server-side exception on
-- /account because the page expected exactly one profile row. This backfills the
-- missing rows so existing accounts work; the app now also creates the profile
-- on sign-up/sign-in going forward.
insert into public.profiles (id, role, email, display_name)
select
  u.id,
  'buyer',
  u.email,
  coalesce(
    nullif(u.raw_user_meta_data->>'display_name', ''),
    nullif(u.raw_user_meta_data->>'full_name', ''),
    nullif(u.raw_user_meta_data->>'name', ''),
    split_part(u.email, '@', 1)
  )
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null
  and u.email is not null;
