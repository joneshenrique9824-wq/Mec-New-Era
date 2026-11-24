begin;
create or replace function public.staff_overview(p_org uuid) returns table(user_id uuid,character_name text,discord_id text,role text,status text,verified_until timestamptz,sales_count bigint,sales_total numeric,deposits_total numeric) language plpgsql security definer set search_path='' as $$
begin
if not exists(select 1 from public.organization_members m where m.organization_id=p_org and m.user_id=auth.uid() and m.status='active' and m.discord_verified_until>now() and m.role in ('proprietario','gerente','supervisor')) then raise exception 'Acesso negado'; end if;
return query select m.user_id,p.character_name,p.discord_id,m.role,m.status,m.discord_verified_until,
(select count(*) from public.sales s where s.organization_id=p_org and s.employee_id=m.user_id),
(select coalesce(sum(s.total),0) from public.sales s where s.organization_id=p_org and s.employee_id=m.user_id),
(select coalesce(sum(d.amount),0) from public.deposits d where d.organization_id=p_org and d.employee_id=m.user_id and d.status='approved')
from public.organization_members m join public.profiles p on p.id=m.user_id where m.organization_id=p_org order by p.character_name;
end; $$;
revoke all on function public.staff_overview(uuid) from public,anon;
grant execute on function public.staff_overview(uuid) to authenticated;
commit;
