-- peprally · schema
-- Core tables for the peptide-discussion community. Auth is handled by
-- Supabase (auth.users); every table below hangs off a public.profiles row
-- that is created automatically when a user signs up (see functions migration).

-- ── enums ────────────────────────────────────────────────────────────────
create type verification_status as enum ('none', 'pending', 'verified', 'rejected');
create type application_status  as enum ('pending', 'approved', 'rejected');
create type professional_role   as enum ('clinician', 'researcher');
create type notification_type   as enum ('reply', 'mention', 'follow', 'milestone', 'digest');
create type report_target       as enum ('question', 'reply', 'profile');
create type report_status       as enum ('open', 'actioned', 'dismissed');
create type mod_commitment      as enum ('light', 'regular', 'daily');

-- ── profiles ─────────────────────────────────────────────────────────────
-- One row per auth user. `handle` is chosen during setup, so it's nullable
-- until then; uniqueness is case-insensitive via the lower() index below.
create table profiles (
    id                     uuid primary key references auth.users (id) on delete cascade,
    handle                 text,
    avatar_url             text,
    is_professional        boolean not null default false,
    verification_status    verification_status not null default 'none',
    credential             text,                         -- e.g. "Physician"; set on approval
    is_moderator           boolean not null default false,
    mod_application_status application_status,           -- null = never applied
    setup_done             boolean not null default false,
    push_replies           boolean not null default true,
    push_mentions          boolean not null default true,
    push_weekly            boolean not null default false,
    created_at             timestamptz not null default now()
);
create unique index profiles_handle_lower_idx on profiles (lower(handle)) where handle is not null;

-- ── topics (server-owned peptide catalog) ────────────────────────────────
create table topics (
    id         uuid primary key default gen_random_uuid(),
    slug       text unique not null,
    name       text not null,
    hex        text not null,          -- capsule tint, e.g. "E9DAD5"
    sort_order int  not null default 0
);

create table topic_follows (
    user_id    uuid references profiles (id) on delete cascade,
    topic_id   uuid references topics (id)   on delete cascade,
    created_at timestamptz not null default now(),
    primary key (user_id, topic_id)
);

-- ── questions ────────────────────────────────────────────────────────────
create table questions (
    id          uuid primary key default gen_random_uuid(),
    author_id   uuid not null references profiles (id) on delete cascade,
    topic_id    uuid references topics (id) on delete set null,
    title       text not null,
    body        text not null default '',
    attachment  jsonb,                 -- {kind:"image"|"link"|"poll", ...}
    like_count  int  not null default 0,   -- denormalized, kept by triggers
    reply_count int  not null default 0,
    created_at  timestamptz not null default now()
);
create index questions_created_idx on questions (created_at desc);
create index questions_topic_idx   on questions (topic_id);
create index questions_author_idx  on questions (author_id);

-- ── replies ──────────────────────────────────────────────────────────────
create table replies (
    id          uuid primary key default gen_random_uuid(),
    question_id uuid not null references questions (id) on delete cascade,
    author_id   uuid not null references profiles (id)  on delete cascade,
    body        text not null,
    like_count  int  not null default 0,
    created_at  timestamptz not null default now()
);
create index replies_question_idx on replies (question_id, created_at);
create index replies_author_idx   on replies (author_id);

-- ── likes (own row per user/target; counts denormalized on the parent) ───
create table question_likes (
    user_id     uuid references profiles (id)  on delete cascade,
    question_id uuid references questions (id) on delete cascade,
    created_at  timestamptz not null default now(),
    primary key (user_id, question_id)
);
create table reply_likes (
    user_id    uuid references profiles (id) on delete cascade,
    reply_id   uuid references replies (id)  on delete cascade,
    created_at timestamptz not null default now(),
    primary key (user_id, reply_id)
);

-- ── social graph ─────────────────────────────────────────────────────────
create table follows (
    follower_id uuid references profiles (id) on delete cascade,
    followee_id uuid references profiles (id) on delete cascade,
    created_at  timestamptz not null default now(),
    primary key (follower_id, followee_id),
    check (follower_id <> followee_id)
);
create table blocks (
    blocker_id uuid references profiles (id) on delete cascade,
    blocked_id uuid references profiles (id) on delete cascade,
    created_at timestamptz not null default now(),
    primary key (blocker_id, blocked_id),
    check (blocker_id <> blocked_id)
);

-- ── notifications ────────────────────────────────────────────────────────
create table notifications (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references profiles (id) on delete cascade,  -- recipient
    type        notification_type not null,
    actor_id    uuid references profiles (id)  on delete cascade,
    question_id uuid references questions (id) on delete cascade,
    reply_id    uuid references replies (id)   on delete cascade,
    body        text,
    read_at     timestamptz,
    created_at  timestamptz not null default now()
);
create index notifications_user_idx on notifications (user_id, created_at desc);

-- ── verification (professional credential review) ────────────────────────
create table verification_applications (
    id           uuid primary key default gen_random_uuid(),
    user_id      uuid not null references profiles (id) on delete cascade,
    role         professional_role not null,
    license      text,
    document_url text,                 -- storage path of the uploaded credential
    status       application_status not null default 'pending',
    created_at   timestamptz not null default now(),
    reviewed_at  timestamptz,
    reviewer_id  uuid references profiles (id)
);
create index verification_status_idx on verification_applications (status, created_at);

-- ── moderator applications (volunteer role, separate from verification) ──
create table mod_applications (
    id          uuid primary key default gen_random_uuid(),
    user_id     uuid not null references profiles (id) on delete cascade,
    reason      text not null,
    commitment  mod_commitment not null,
    status      application_status not null default 'pending',
    created_at  timestamptz not null default now(),
    reviewed_at timestamptz,
    reviewer_id uuid references profiles (id)
);
create index mod_status_idx on mod_applications (status, created_at);

-- ── reports (feed the moderation queue) ──────────────────────────────────
create table reports (
    id          uuid primary key default gen_random_uuid(),
    reporter_id uuid not null references profiles (id) on delete cascade,
    target_type report_target not null,
    target_id   uuid not null,         -- id of the reported question/reply/profile
    reason      text,
    status      report_status not null default 'open',
    created_at  timestamptz not null default now()
);
create index reports_status_idx on reports (status, created_at);

-- ── push tokens (APNs) ───────────────────────────────────────────────────
create table push_tokens (
    user_id    uuid references profiles (id) on delete cascade,
    token      text not null,
    platform   text not null default 'ios',
    updated_at timestamptz not null default now(),
    primary key (user_id, token)
);
