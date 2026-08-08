-- Lets HR post an announcement to all employees or a specific department.
-- Routed through a SECURITY DEFINER function rather than a client-facing
-- INSERT policy on notifications, keeping the existing invariant from
-- migration 0015 intact: notifications rows are only ever written by
-- trusted server-side code, never inserted directly by the client.
create or replace function public.post_announcement(
    p_title text,
    p_body text,
    p_department_id bigint default null
) returns integer
language plpgsql
security definer
as $$
declare
  recipient_count integer;
begin
  if not public.is_hr_admin() then
    raise exception 'Only HR admins can post announcements.';
  end if;

  insert into public.notifications (user_id, title, body, type)
  select p.id, p_title, p_body, 'announcement'
  from public.profiles p
  where p_department_id is null or p.department_id = p_department_id;

  get diagnostics recipient_count = row_count;
  return recipient_count;
end;
$$;
