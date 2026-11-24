begin;
create table if not exists public.discord_access (
 organization_id uuid not null references public.organizations(id),
 discord_id text not null check(discord_id ~ '^[0-9]{17,20}$'),
 role text not null default 'mecanico' check(role in ('proprietario','diretor','administrador','gerente_geral','gerente','supervisor','mecanico','aprendiz')),
 active boolean not null default true,
 primary key(organization_id,discord_id)
);
alter table public.discord_access enable row level security;
revoke all on public.discord_access from anon,authenticated;
create or replace function public.claim_discord_access() returns jsonb language plpgsql security definer set search_path='' as $$
declare d text; n text; a record;
begin
if auth.uid() is null then raise exception 'Acesso negado'; end if;
select provider_id, coalesce(identity_data->>'full_name',identity_data->>'name',identity_data->>'preferred_username','Discord') into d,n from auth.identities where user_id=auth.uid() and provider='discord' limit 1;
if d is null then return jsonb_build_object('discord_id',null); end if;
insert into public.profiles(id,discord_id,character_name) values(auth.uid(),d,n) on conflict(id) do update set discord_id=excluded.discord_id;
for a in select * from public.discord_access where discord_id=d loop
 insert into public.organization_members(organization_id,user_id,role,status) values(a.organization_id,auth.uid(),a.role,case when a.active then 'active' else 'suspended' end) on conflict(organization_id,user_id) do update set role=excluded.role,status=excluded.status;
end loop;
return jsonb_build_object('discord_id',d,'name',n);
end; $$;
revoke all on function public.claim_discord_access() from public,anon;
grant execute on function public.claim_discord_access() to authenticated;
commit;
