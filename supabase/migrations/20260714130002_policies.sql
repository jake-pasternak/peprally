-- peprally · row level security
-- Default deny: RLS is enabled on every table and access is granted only by
-- the policies below. Reads are public where the app shows public content
-- (profiles, questions, replies, follows, topics); writes are restricted to
-- the owning user, with moderators able to edit/remove content and review
-- applications. Blocked-user filtering happens in queries, not RLS.

alter table profiles                  enable row level security;
alter table topics                    enable row level security;
alter table topic_follows             enable row level security;
alter table questions                 enable row level security;
alter table replies                   enable row level security;
alter table question_likes            enable row level security;
alter table reply_likes               enable row level security;
alter table follows                   enable row level security;
alter table blocks                    enable row level security;
alter table notifications             enable row level security;
alter table verification_applications enable row level security;
alter table mod_applications          enable row level security;
alter table reports                   enable row level security;
alter table push_tokens               enable row level security;

-- ── profiles ─────────────────────────────────────────────────────────────
create policy "profiles are public"        on profiles for select using (true);
create policy "insert own profile"          on profiles for insert with check (id = auth.uid());
create policy "update own profile"          on profiles for update using (id = auth.uid()) with check (id = auth.uid());

-- ── topics (read-only to clients; seeded/administered via service role) ──
create policy "topics are public"           on topics for select using (true);

-- ── topic follows ────────────────────────────────────────────────────────
create policy "read own topic follows"      on topic_follows for select using (user_id = auth.uid());
create policy "manage own topic follows"    on topic_follows for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ── questions ────────────────────────────────────────────────────────────
create policy "questions are public"        on questions for select using (true);
create policy "author creates questions"    on questions for insert with check (author_id = auth.uid());
create policy "author or mod edits"         on questions for update using (author_id = auth.uid() or public.is_moderator());
create policy "author or mod deletes"       on questions for delete using (author_id = auth.uid() or public.is_moderator());

-- ── replies ──────────────────────────────────────────────────────────────
create policy "replies are public"          on replies for select using (true);
create policy "author creates replies"      on replies for insert with check (author_id = auth.uid());
create policy "author or mod edits reply"   on replies for update using (author_id = auth.uid() or public.is_moderator());
create policy "author or mod deletes reply" on replies for delete using (author_id = auth.uid() or public.is_moderator());

-- ── likes (a user sees and manages only their own like rows; the visible
--     totals live in the denormalized *_count columns on the parent) ──────
create policy "read own question likes"     on question_likes for select using (user_id = auth.uid());
create policy "manage own question likes"   on question_likes for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "read own reply likes"        on reply_likes for select using (user_id = auth.uid());
create policy "manage own reply likes"      on reply_likes for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ── follows (public graph; you manage only your own follow edges) ────────
create policy "follows are public"          on follows for select using (true);
create policy "manage own follows"          on follows for all using (follower_id = auth.uid()) with check (follower_id = auth.uid());

-- ── blocks (private to the blocker) ──────────────────────────────────────
create policy "read own blocks"             on blocks for select using (blocker_id = auth.uid());
create policy "manage own blocks"           on blocks for all using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- ── notifications (recipient-only; rows are written by SECURITY DEFINER
--     triggers, so no client insert policy is granted) ────────────────────
create policy "read own notifications"      on notifications for select using (user_id = auth.uid());
create policy "update own notifications"    on notifications for update using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ── verification applications (owner + moderators) ───────────────────────
create policy "read own or mod verifications"   on verification_applications for select using (user_id = auth.uid() or public.is_moderator());
create policy "submit own verification"         on verification_applications for insert with check (user_id = auth.uid());
create policy "mod reviews verification"         on verification_applications for update using (public.is_moderator());

-- ── moderator applications (owner + moderators) ──────────────────────────
create policy "read own or mod mod-apps"    on mod_applications for select using (user_id = auth.uid() or public.is_moderator());
create policy "submit own mod-app"          on mod_applications for insert with check (user_id = auth.uid());
create policy "mod reviews mod-app"          on mod_applications for update using (public.is_moderator());

-- ── reports (reporter + moderators) ──────────────────────────────────────
create policy "read own or mod reports"     on reports for select using (reporter_id = auth.uid() or public.is_moderator());
create policy "submit own report"           on reports for insert with check (reporter_id = auth.uid());
create policy "mod resolves report"          on reports for update using (public.is_moderator());

-- ── push tokens (owner-only) ─────────────────────────────────────────────
create policy "manage own push tokens"      on push_tokens for all using (user_id = auth.uid()) with check (user_id = auth.uid());
