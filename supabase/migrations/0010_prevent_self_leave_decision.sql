-- Same reasoning as migration 0007 (prevent_self_employment_edit): the
-- existing "leave_update_hr_only" RLS policy lets any HR admin update ANY
-- leave_applications row, including their own - so without this, an HR
-- admin could submit their own leave request and then approve it
-- themselves. Blocks changing status on a row where the caller is also
-- the applicant; another HR admin must decide on it instead.

create or replace function public.prevent_self_leave_decision()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() = old.user_id and new.status is distinct from old.status then
    raise exception 'You cannot approve or reject your own leave application. Ask another HR admin to decide on it.';
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_self_leave_decision on public.leave_applications;
create trigger trg_prevent_self_leave_decision
  before update on public.leave_applications
  for each row
  execute function public.prevent_self_leave_decision();
