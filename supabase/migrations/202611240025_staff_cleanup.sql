begin;
create or replace function public.clear_staff_history(p_org uuid,p_employee uuid,p_reason text) returns void language plpgsql security definer set search_path='' as $$
declare backup jsonb; approved numeric;
begin
if not exists(select 1 from public.organization_members where organization_id=p_org and user_id=auth.uid() and status='active' and role in ('proprietario','gerente') and discord_verified_until>now()) then raise exception 'Acesso negado'; end if;
if length(trim(coalesce(p_reason,'')))<5 then raise exception 'Informe o motivo'; end if;
perform pg_advisory_xact_lock(hashtextextended(p_org::text,0));
lock table public.sales,public.deposits,public.service_orders in share row exclusive mode;
if not exists(select 1 from public.organization_members where organization_id=p_org and user_id=p_employee) then raise exception 'Funcionário não encontrado'; end if;
if exists(select 1 from public.deposits where organization_id=p_org and employee_id=p_employee and status='pending') then raise exception 'Resolva os depósitos pendentes antes da limpeza'; end if;
select coalesce(sum(amount),0) into approved from public.deposits where organization_id=p_org and employee_id=p_employee and status='approved';
select jsonb_build_object('employee',p_employee,'sales',(select coalesce(jsonb_agg(to_jsonb(s)),'[]') from public.sales s where organization_id=p_org and employee_id=p_employee),'deposits',(select coalesce(jsonb_agg(to_jsonb(d)),'[]') from public.deposits d where organization_id=p_org and employee_id=p_employee),'orders',(select coalesce(jsonb_agg(to_jsonb(o)),'[]') from public.service_orders o where organization_id=p_org and employee_id=p_employee)) into backup;
insert into public.admin_events(organization_id,actor,action,reason,amount,snapshot) values(p_org,auth.uid(),'staff_cleanup',p_reason,approved,backup);
delete from public.sales where organization_id=p_org and employee_id=p_employee;
delete from public.deposits where organization_id=p_org and employee_id=p_employee;
delete from public.service_orders where organization_id=p_org and employee_id=p_employee;
end;$$;
revoke all on function public.clear_staff_history(uuid,uuid,text) from public,anon;
grant execute on function public.clear_staff_history(uuid,uuid,text) to authenticated;
commit;