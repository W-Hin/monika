-- Nobody may change their own job_title, department_id, base_salary, or
-- user_role — including HR admins editing their own profile row. The
-- existing "profiles_update_own_or_hr" RLS policy (schema.sql) already lets
-- any user update their own row, and lets HR admins update anyone's row;
-- neither one restricts *which columns* can change. Without this, an HR
-- admin could give themselves a raise or promotion, and in principle any
-- employee could already do the same via a direct REST call (bypassing the
-- app UI, which never exposed these fields to non-HR users, but RLS was the
-- real gate and didn't stop it).
--
-- A trigger is used rather than a column-level RLS policy because Postgres
-- RLS policies are row-scoped, not column-scoped — this is the standard way
-- to enforce "you can change your own row, but not these specific fields on
-- it" in Postgres.
--
-- Any legitimate change to these fields must be made by another party (HR
-- admin editing someone else's row) — that path is untouched, since the
-- check only fires when the row being updated belongs to the caller
-- themselves (auth.uid() = OLD.id).

create or replace function public.prevent_self_employment_edit()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() = old.id then
    if new.job_title is distinct from old.job_title
       or new.department_id is distinct from old.department_id
       or new.base_salary is distinct from old.base_salary
       or new.user_role is distinct from old.user_role then
      raise exception 'You cannot change your own job title, department, salary, or role. Ask another HR admin to make this change.';
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_prevent_self_employment_edit on public.profiles;
create trigger trg_prevent_self_employment_edit
  before update on public.profiles
  for each row
  execute function public.prevent_self_employment_edit();
