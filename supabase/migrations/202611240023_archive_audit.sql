begin;
alter table public.admin_events add column if not exists archived_at timestamptz;
create or replace function public.archive_admin_audit(p_org uuid) returns void language plpgsql security definer set search_path='' as $$
begin
if not exists(select 1 from public.organization_members where organization_id=p_org and user_id=auth.uid() and status='active' and role in ('proprietario','gerente') and discord_verified_until>now()) then raise exception 'Acesso negado'; end if;
update public.admin_events set archived_at=now() where organization_id=p_org and archived_at is null;
insert into public.admin_events(organization_id,actor,action,reason,amount,archived_at) values(p_org,auth.uid(),'archive','Limpeza da lista de auditoria',0,now());
end;$$;
revoke all on function public.archive_admin_audit(uuid) from public,anon;
grant execute on function public.archive_admin_audit(uuid) to authenticated;
commit;