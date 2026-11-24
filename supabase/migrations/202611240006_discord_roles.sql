begin;
alter table public.organization_members add column if not exists discord_verified_until timestamptz;
create or replace function public.sync_discord_membership(p_user uuid,p_discord text,p_name text,p_role text) returns void language plpgsql security definer set search_path='' as $$
declare o uuid;
begin
select id into strict o from public.organizations where slug='new-era-city';
insert into public.profiles(id,discord_id,character_name) values(p_user,p_discord,p_name) on conflict(id) do update set discord_id=excluded.discord_id;
insert into public.organization_members(organization_id,user_id,role,status,discord_verified_until) values(o,p_user,coalesce(p_role,'aprendiz'),case when p_role is null then 'suspended' else 'active' end,now()+interval '5 minutes') on conflict(organization_id,user_id) do update set role=excluded.role,status=excluded.status,discord_verified_until=excluded.discord_verified_until;
end; $$;
revoke all on function public.sync_discord_membership(uuid,text,text,text) from public,anon,authenticated;
grant execute on function public.sync_discord_membership(uuid,text,text,text) to service_role;
revoke execute on function public.claim_discord_access() from authenticated;
commit;
