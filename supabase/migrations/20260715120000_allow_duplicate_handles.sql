-- Allow duplicate usernames. The account identity is the user id (auth.users),
-- not the handle — handles are just display names, so two people can share one.
-- Drops the case-insensitive unique index added in the initial schema.
drop index if exists profiles_handle_lower_idx;
