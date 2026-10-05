-- Lock down which columns the client may write.
--
-- RLS decides which ROWS a user can touch, not which COLUMNS. "update own
-- profile" therefore let any signed-in user set is_moderator, credential and
-- verification_status on themselves, i.e. self-grant the blue seal or the
-- moderator role. The same gap let authors rewrite their own like/reply
-- counts. Column privileges close it: the client roles lose table-wide
-- INSERT/UPDATE and get back only the columns the app actually writes.
-- Moderator and verification changes now only happen from the dashboard
-- (service_role / postgres), which is unaffected.

-- ── counts: run as the table owner ───────────────────────────────────────
-- These triggers ran as the user doing the liking/replying, so RLS ("author
-- or mod edits") silently filtered the update to zero rows whenever the post
-- wasn't theirs: counts only moved on your own posts. They also need this to
-- keep working once the client loses UPDATE on the count columns below.
alter function public.bump_reply_count()         security definer set search_path = public;
alter function public.bump_question_like_count() security definer set search_path = public;
alter function public.bump_reply_like_count()    security definer set search_path = public;

-- ── profiles ─────────────────────────────────────────────────────────────
revoke insert, update on profiles from anon, authenticated;
grant insert (id) on profiles to authenticated;
grant update (handle, avatar_url, is_professional, setup_done,
              push_replies, push_mentions, push_weekly) on profiles to authenticated;

-- ── questions / replies: content yes, counts no ──────────────────────────
revoke insert, update on questions from anon, authenticated;
grant insert (author_id, topic_id, title, body, attachment) on questions to authenticated;
grant update (topic_id, title, body, attachment)            on questions to authenticated;

revoke insert, update on replies from anon, authenticated;
grant insert (question_id, author_id, body) on replies to authenticated;
grant update (body)                         on replies to authenticated;

-- ── notifications: mark read only ────────────────────────────────────────
revoke update on notifications from anon, authenticated;
grant update (read_at) on notifications to authenticated;

-- ── applications and reports: submit without choosing your own verdict ───
revoke insert, update on verification_applications from anon, authenticated;
grant insert (user_id, role, license, document_url)  on verification_applications to authenticated;
grant update (status, reviewed_at, reviewer_id)      on verification_applications to authenticated;

revoke insert, update on mod_applications from anon, authenticated;
grant insert (user_id, reason, commitment)      on mod_applications to authenticated;
grant update (status, reviewed_at, reviewer_id) on mod_applications to authenticated;

revoke insert, update on reports from anon, authenticated;
grant insert (reporter_id, target_type, target_id, reason) on reports to authenticated;
grant update (status)                                      on reports to authenticated;

-- ── repair counts that drifted while the triggers were filtered ──────────
update questions q set
    like_count  = (select count(*) from question_likes l where l.question_id = q.id),
    reply_count = (select count(*) from replies r        where r.question_id = q.id);
update replies r set
    like_count  = (select count(*) from reply_likes l where l.reply_id = r.id);
