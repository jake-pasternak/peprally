-- peprally · functions & triggers
-- All SECURITY DEFINER functions are owned by postgres (the table owner),
-- which is exempt from RLS, so trigger-driven writes (notifications, counts)
-- succeed without opening those tables to direct client inserts.

-- ── create a profile row whenever an auth user is created ────────────────
create function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    insert into public.profiles (id) values (new.id)
    on conflict (id) do nothing;
    return new;
end;
$$;

create trigger on_auth_user_created
    after insert on auth.users
    for each row execute function public.handle_new_user();

-- ── moderator check, used by RLS on content tables ───────────────────────
create function public.is_moderator(uid uuid default auth.uid())
returns boolean language sql security definer stable set search_path = public as $$
    select coalesce((select is_moderator from public.profiles where id = uid), false);
$$;

-- ── denormalized counts ──────────────────────────────────────────────────
create function public.bump_reply_count()
returns trigger language plpgsql as $$
begin
    if tg_op = 'INSERT' then
        update public.questions set reply_count = reply_count + 1 where id = new.question_id;
    elsif tg_op = 'DELETE' then
        update public.questions set reply_count = greatest(reply_count - 1, 0) where id = old.question_id;
    end if;
    return null;
end;
$$;
create trigger trg_reply_count
    after insert or delete on replies
    for each row execute function public.bump_reply_count();

create function public.bump_question_like_count()
returns trigger language plpgsql as $$
begin
    if tg_op = 'INSERT' then
        update public.questions set like_count = like_count + 1 where id = new.question_id;
    elsif tg_op = 'DELETE' then
        update public.questions set like_count = greatest(like_count - 1, 0) where id = old.question_id;
    end if;
    return null;
end;
$$;
create trigger trg_question_like_count
    after insert or delete on question_likes
    for each row execute function public.bump_question_like_count();

create function public.bump_reply_like_count()
returns trigger language plpgsql as $$
begin
    if tg_op = 'INSERT' then
        update public.replies set like_count = like_count + 1 where id = new.reply_id;
    elsif tg_op = 'DELETE' then
        update public.replies set like_count = greatest(like_count - 1, 0) where id = old.reply_id;
    end if;
    return null;
end;
$$;
create trigger trg_reply_like_count
    after insert or delete on reply_likes
    for each row execute function public.bump_reply_like_count();

-- ── notifications ────────────────────────────────────────────────────────
-- New reply → notify the question's author (never yourself, never if the
-- author has blocked the replier).
create function public.notify_on_reply()
returns trigger language plpgsql security definer set search_path = public as $$
declare
    q_author uuid;
begin
    select author_id into q_author from public.questions where id = new.question_id;
    if q_author is not null
       and q_author <> new.author_id
       and not exists (select 1 from public.blocks
                       where blocker_id = q_author and blocked_id = new.author_id) then
        insert into public.notifications (user_id, type, actor_id, question_id, reply_id, body)
        values (q_author, 'reply', new.author_id, new.question_id, new.id, left(new.body, 140));
    end if;
    return null;
end;
$$;
create trigger trg_notify_reply
    after insert on replies
    for each row execute function public.notify_on_reply();

-- New follow → notify the person followed.
create function public.notify_on_follow()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    if not exists (select 1 from public.blocks
                   where blocker_id = new.followee_id and blocked_id = new.follower_id) then
        insert into public.notifications (user_id, type, actor_id)
        values (new.followee_id, 'follow', new.follower_id);
    end if;
    return null;
end;
$$;
create trigger trg_notify_follow
    after insert on follows
    for each row execute function public.notify_on_follow();

-- ── account deletion (App Store 5.1.1(v)) ────────────────────────────────
-- Lets a signed-in user erase their own auth record; the on-delete cascades
-- from auth.users → profiles → all their content.
create function public.delete_my_account()
returns void language sql security definer set search_path = public, auth as $$
    delete from auth.users where id = auth.uid();
$$;
