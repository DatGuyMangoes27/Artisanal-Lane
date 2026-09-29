-- Stage 1 of profile privacy: guests may read only public display fields.
-- Guest embeds (shop owners, reviewers) request display_name/avatar_url only.
-- Note: app builds before 27 Sep 2026 look up the reset email in profiles as a
-- guest; that lookup stops matching after this change.
revoke select on public.profiles from anon;
grant select (id, display_name, avatar_url) on public.profiles to anon;
