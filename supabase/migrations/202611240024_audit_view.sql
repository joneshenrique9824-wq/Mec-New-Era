begin;
create or replace function public.admin_control(p_org uuid,p_action text,p_reason text default '',p_balance numeric default null) returns jsonb language plpgsql security definer set search_path='' as $$
declare approved numeric; adjustments numeric; current_balance numeric; backup jsonb;
begin
if not exists(select 1 from public.organization_members where organization_id=p_org and user_id=auth.uid() and status='active' and role in ('proprietario','gerente') and discord_verified_until>now()) then raise exception 'Acesso exclusivo da administração'; end if;
perform pg_advisory_xact_lock(hashtextextended(p_org::text,0));
if p_action not in ('read','balance','reset') then raise exception 'Ação inválida'; end if;
if p_action<>'read' and length(trim(coalesce(p_reason,'')))<5 then raise exception 'Informe o motivo'; end if;
if p_action<>'read' then lock table public.sales,public.deposits,public.service_orders in share row exclusive mode; end if;
select coalesce(sum(amount),0) into approved from public.deposits where organization_id=p_org and status='approved';
select coalesce(sum(amount),0) into adjustments from public.admin_events where organization_id=p_org;
current_balance:=approved+adjustments;
if p_action='balance' then
if p_balance is null or p_balance<0 or p_balance>999999999999999999 or p_balance<>round(p_balance,2) then raise exception 'Saldo inválido'; end if;
insert into public.admin_events(organization_id,actor,action,reason,amount) values(p_org,auth.uid(),'balance',p_reason,p_balance-current_balance);
current_balance:=p_balance;
elsif p_action='reset' then
select jsonb_build_object('sales',(select coalesce(jsonb_agg(to_jsonb(s)),'[]') from public.sales s where organization_id=p_org),'deposits',(select coalesce(jsonb_agg(to_jsonb(d)),'[]') from public.deposits d where organization_id=p_org),'orders',(select coalesce(jsonb_agg(to_jsonb(o)),'[]') from public.service_orders o where organization_id=p_org)) into backup;
insert into public.admin_events(organization_id,actor,action,reason,amount,snapshot) values(p_org,auth.uid(),'reset',p_reason,-adjustments,backup);
delete from public.sales where organization_id=p_org;
delete from public.deposits where organization_id=p_org;
delete from public.service_orders where organization_id=p_org;
current_balance:=0;
end if;
return jsonb_build_object('balance',current_balance,'sales',(select count(*) from public.sales where organization_id=p_org),'deposits',(select count(*) from public.deposits where organization_id=p_org),'events',(select coalesce(jsonb_agg(to_jsonb(e)),'[]') from (select action,reason,amount,actor,created_at from public.admin_events where organization_id=p_org and archived_at is null order by created_at desc limit 30)e));
end;$$;

commit;