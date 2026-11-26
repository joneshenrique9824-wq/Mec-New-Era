-- Execute after farm-goals.sql.
create table if not exists public.towing_entries (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null,
 employee_id uuid not null default auth.uid(),
 quantity integer not null check(quantity between 1 and 100),
 notes text not null default '' check(char_length(notes)<=500),
 created_at timestamptz not null default now()
);
alter table public.towing_entries enable row level security;
drop policy if exists towing_read on public.towing_entries;
create policy towing_read on public.towing_entries for select to authenticated using(public.farm_access(organization_id) and (employee_id=auth.uid() or public.farm_access(organization_id,true)));
drop policy if exists towing_insert on public.towing_entries;
create policy towing_insert on public.towing_entries for insert to authenticated with check(public.farm_access(organization_id) and employee_id=auth.uid());
revoke all on public.towing_entries from anon,authenticated;
grant select on public.towing_entries to authenticated;
grant insert(organization_id,quantity,notes) on public.towing_entries to authenticated;
