-- peprally · starter questions
--
-- Purpose: a new user opening the live app should land on questions worth
-- answering rather than an empty feed. These are posted by ONE real account
-- that Jake controls (@jake), they are questions only — never answers, never
-- dosing, never anything that reads as advice — and no credential or
-- verification field is touched by this script.
--
-- Run in the Supabase SQL editor (service_role, so RLS is bypassed).
-- Idempotent: re-running inserts nothing new.
-- Raises if the author handle doesn't exist, rather than silently doing
-- nothing — which is exactly how the first version of this file failed.

do $$
declare
    v_handle  text := 'jake';   -- change this to post from a different account
    v_author  uuid;
    v_added   int;
begin
    select id into v_author from profiles where lower(handle) = lower(v_handle);

    if v_author is null then
        raise exception
            'No profile with handle "%" — set the handle first, then re-run.', v_handle;
    end if;

    insert into questions (author_id, topic_id, title, body)
    select v_author, t.id, s.title, s.body
      from (values
        ('bpc-157', 'What made you start looking into BPC-157 — and what stopped you?',
         'Both halves are useful. The reasons people walk away get posted far less often than the reasons they start.'),

        ('bpc-157', 'What does the evidence actually support here, and where does it run out?',
         'Link what you have read. Preclinical, clinical, case reports — say which, so people can weigh it themselves.'),

        ('bpc-157', 'If you have talked to a clinician about this, how did that conversation go?',
         'Curious how often the conversation happens at all, and what the response tends to be.'),

        ('semaglutide', 'What surprised you most in the first month?',
         'The side effects get discussed. The things nobody warned you about get discussed much less.'),

        ('semaglutide', 'How are you tracking whether it is working, beyond the scale?',
         'Bloodwork, measurements, how you feel at week 12 versus week 1 — what are you actually measuring?'),

        ('semaglutide', 'What questions do you wish you had asked your prescriber before starting?',
         'Answers here are worth more to someone at week zero than any protocol post.'),

        ('tb-500', 'How do you decide something is worth trying versus worth skipping?',
         'Everyone has a threshold. What is yours, and has it moved over time?'),

        ('tb-500', 'What would change your mind about something you currently believe works?',
         'Naming the evidence that would move you is the most useful thing you can post in a thread like this.'),

        ('nad', 'Where do you go for information now, and how much do you trust it?',
         'Papers, clinicians, forums, vendors, podcasts — and how you tell the difference between them.'),

        ('nad', 'What is the most misleading thing you have been told about peptides?',
         'By anyone — a vendor, a clinic, a forum, a friend. Worth collecting in one place.'),

        ('tirzepatide', 'What do you want to see discussed on here that is not being discussed anywhere else?',
         'This one shapes the rally. Tell us what is missing and it becomes the thing we build toward.'),

        ('mots-c', 'Are you a clinician or researcher reading this? What does the public conversation get wrong?',
         'If you work in this area, your read on the gap between the literature and the discourse is the whole point of this app. Verification is in Settings → Account.')
      ) as s(slug, title, body)
      join topics t on t.slug = s.slug
     where not exists (select 1 from questions q where q.title = s.title);

    get diagnostics v_added = row_count;
    raise notice 'Seeded % starter questions as @%.', v_added, v_handle;
end $$;

-- Verify:
-- select q.title, p.handle, t.name, q.created_at
--   from questions q
--   join profiles p on p.id = q.author_id
--   left join topics t on t.id = q.topic_id
--  order by q.created_at;
