begin;
alter table public.organization_members add column if not exists manual_block boolean not null default false;
create or replace function public.sync_discord_membership(p_user uuid,p_discord text,p_name text,p_role text) returns void language plpgsql security definer set search_path='' as $$
declare o uuid;
begin
select id into strict o from public.organizations where slug='new-era-city';
insert into public.profiles(id,discord_id,character_name) values(p_user,p_discord,p_name) on conflict(id) do update set discord_id=excluded.discord_id;
insert into public.organization_members(organization_id,user_id,role,status,discord_verified_until) values(o,p_user,coalesce(p_role,'aprendiz'),case when p_role is null then 'suspended' else 'active' end,now()+interval '5 minutes') on conflict(organization_id,user_id) do update set role=excluded.role,status=case when public.organization_members.manual_block then 'suspended' else excluded.status end,discord_verified_until=case when public.organization_members.manual_block then null else excluded.discord_verified_until end;
end;$$;
create or replace function public.manage_staff_access(p_org uuid,p_employee uuid,p_block boolean,p_reason text) returns void language plpgsql security definer set search_path='' as $$
declare actor_role text; target_role text;
begin
select role into actor_role from public.organization_members where organization_id=p_org and user_id=auth.uid() and status='active' and discord_verified_until>now() and not manual_block;
if actor_role is null or actor_role not in ('proprietario','gerente') or p_employee=auth.uid() or p_block is null then raise exception 'Acesso negado'; end if;
select role into target_role from public.organization_members where organization_id=p_org and user_id=p_employee for update;
if target_role is null or target_role='proprietario' or (actor_role='gerente' and target_role='gerente') then raise exception 'Cargo protegido'; end if;
if length(trim(coalesce(p_reason,'')))<5 then raise exception 'Informe o motivo'; end if;
update public.organization_members set manual_block=p_block,status='suspended',discord_verified_until=null where organization_id=p_org and user_id=p_employee;
insert into public.admin_events(organization_id,actor,action,reason,amount,snapshot) values(p_org,auth.uid(),case when p_block then 'staff_block' else 'staff_unblock' end,p_reason,0,jsonb_build_object('employee',p_employee));
end;$$;
revoke all on function public.manage_staff_access(uuid,uuid,boolean,text) from public,anon;
grant execute on function public.manage_staff_access(uuid,uuid,boolean,text) to authenticated;
commit;