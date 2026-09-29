-- Guest queries evaluate policies that check profiles.role for admins
-- (current_user_is_admin() and inline checks). Without column access those
-- queries fail, so guests may read role alongside public display fields.
-- Email, phone, addresses and payment identity stay hidden.
grant select (role) on public.profiles to anon;
