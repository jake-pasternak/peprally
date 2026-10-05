-- Re-enforce unique handles (reverses 20260715120000_allow_duplicate_handles).
-- The onboarding step now checks availability as you type, so handles are a
-- real, unique identity again. Case-insensitive via lower(handle).
create unique index if not exists profiles_handle_lower_idx
    on profiles (lower(handle)) where handle is not null;
