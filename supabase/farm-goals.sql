create table if not exists public.farm_targets (
 organization_id uuid not null, material text not null check(material in ('Borracha','Cobre','Alumínio','Vidro','Barra de Ferro','Cabo de Alimentação')), target integer not null check(target between 1 and 1000000), primary key(organization_id,material));
create table if not exists public.farm_entries (
 id uuid primary key default gen_random_uuid(), organization_id uuid not null, employee_id uuid not null default auth.uid(), material text not null check(material in ('Borracha','Cobre','Alumínio','Vidro','Barra de Ferro','Cabo de Alimentação')), quantity integer not null check(quantity between 1 and 1000000), created_at timestamptz not null default now());
alter table public.farm_targets enable row level security;
alter table public.farm_entries enable row level security;
create or replace function public.farm_access(p_org uuid,p_admin boolean default false) returns boolean language sql stable security definer set search_path=public,pg_temp as $$
select exists(select 1 from public.organization_members m where m.organization_id=p_org and m.user_id=auth.uid() and m.status='active' and not coalesce(m.manual_block,false) and m.discord_verified_until>now() and (not p_admin or m.role in ('proprietario','gerente')));
$$;
revoke all on function public.farm_access(uuid,boolean) from public,anon;
grant execute on function public.farm_access(uuid,boolean) to authenticated;
drop policy if exists farm_targets_read on public.farm_targets;
create policy farm_targets_read on public.farm_targets for select to authenticated using(public.farm_access(organization_id));
drop policy if exists farm_targets_manage on public.farm_targets;
create policy farm_targets_manage on public.farm_targets for all to authenticated using(public.farm_access(organization_id,true)) with check(public.farm_access(organization_id,true));
drop policy if exists farm_entries_read on public.farm_entries;
create policy farm_entries_read on public.farm_entries for select to authenticated using(public.farm_access(organization_id));
drop policy if exists farm_entries_insert on public.farm_entries;
create policy farm_entries_insert on public.farm_entries for insert to authenticated with check(public.farm_access(organization_id) and employee_id=auth.uid());
revoke all on public.farm_targets,public.farm_entries from anon,authenticated;
grant select,insert,update on public.farm_targets to authenticated;
grant select on public.farm_entries to authenticated;
grant insert(organization_id,material,quantity) on public.farm_entries to authenticated;
