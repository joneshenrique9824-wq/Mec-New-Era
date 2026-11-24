begin;
create table public.organizations (
 id uuid primary key default gen_random_uuid(),
 name text not null,
 slug text unique not null,
 created_at timestamptz not null default now()
);
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 character_name text,
 city_id text,
 discord_id text,
 created_at timestamptz not null default now()
);
create table public.organization_members (
 organization_id uuid not null references public.organizations(id),
 user_id uuid not null references public.profiles(id),
 role text not null default 'aprendiz' check(role in ('proprietario','diretor','administrador','gerente_geral','gerente','supervisor','mecanico','aprendiz')),
 status text not null default 'pending' check(status in ('pending','active','suspended')),
 primary key(organization_id,user_id)
);
alter table public.organizations enable row level security;
alter table public.profiles enable row level security;
alter table public.organization_members enable row level security;
create policy profile_read on public.profiles for select to authenticated using (id=auth.uid());
create policy profile_insert on public.profiles for insert to authenticated with check (id=auth.uid());
create policy profile_update on public.profiles for update to authenticated using (id=auth.uid()) with check(id=auth.uid());
create policy membership_read on public.organization_members for select to authenticated using(user_id=auth.uid());
create policy organization_read on public.organizations for select to authenticated using(exists(select 1 from public.organization_members m where m.organization_id=organizations.id and m.user_id=auth.uid() and m.status='active'));
revoke all on public.organizations, public.profiles, public.organization_members from anon, authenticated;
grant select on public.organizations, public.organization_members to authenticated;
grant select,insert,update on public.profiles to authenticated;
insert into public.organizations(name,slug) values ('New Era City','new-era-city');
commit;
