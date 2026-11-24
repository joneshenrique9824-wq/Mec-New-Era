begin;
create table public.deposits (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id),
 employee_id uuid not null references public.profiles(id),
 amount numeric(20,2) not null check(amount>0),
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 request_id uuid not null,
 created_at timestamptz not null default now(),
 decided_at timestamptz,
 decided_by uuid references public.profiles(id),
 reason text,
 unique(employee_id,request_id)
);
alter table public.deposits enable row level security;
revoke all on public.deposits from anon,authenticated;
grant select on public.deposits to authenticated;
create policy deposit_read on public.deposits for select to authenticated using(exists(select 1 from public.organization_members m where m.organization_id=deposits.organization_id and m.user_id=auth.uid() and m.status='active' and (deposits.employee_id=auth.uid() or m.role in ('proprietario','diretor','administrador','gerente_geral','gerente'))));
create function public.submit_deposit(p_org uuid,p_amount numeric,p_request uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare available numeric; result uuid;
begin
if auth.uid() is null or p_request is null or p_amount is null or p_amount<=0 or p_amount<>round(p_amount,2) then raise exception 'Dados invalidos'; end if;
perform 1 from public.organization_members where organization_id=p_org and user_id=auth.uid() and status='active' for update;
if not found then raise exception 'Acesso negado'; end if;
select id into result from public.deposits where employee_id=auth.uid() and request_id=p_request and organization_id=p_org;
if found then return result; end if;
select coalesce(sum(mechanic_share),0) into available from public.sales where organization_id=p_org and employee_id=auth.uid();
available:=available-(select coalesce(sum(amount),0) from public.deposits where organization_id=p_org and employee_id=auth.uid() and status in ('pending','approved'));
if p_amount>available then raise exception 'Saldo insuficiente'; end if;
insert into public.deposits(organization_id,employee_id,amount,request_id) values(p_org,auth.uid(),p_amount,p_request) returning id into result;
return result;
end; $$;
create function public.decide_deposit(p_id uuid,p_approve boolean,p_reason text) returns void language plpgsql security definer set search_path='' as $$
declare d public.deposits%rowtype;
begin
if p_approve is null then raise exception 'Decisao invalida'; end if;
select * into d from public.deposits where id=p_id for update;
if not found or not exists(select 1 from public.organization_members where organization_id=d.organization_id and user_id=auth.uid() and status='active' and role in ('proprietario','diretor','administrador','gerente_geral','gerente')) then raise exception 'Acesso negado'; end if;
if d.status<>'pending' then raise exception 'Registro ja decidido'; end if;
if not p_approve and coalesce(trim(p_reason),'')='' then raise exception 'Informe o motivo'; end if;
update public.deposits set status=case when p_approve then 'approved' else 'rejected' end,decided_at=now(),decided_by=auth.uid(),reason=p_reason where id=p_id;
end; $$;
revoke all on function public.submit_deposit(uuid,numeric,uuid),public.decide_deposit(uuid,boolean,text) from public,anon;
grant execute on function public.submit_deposit(uuid,numeric,uuid),public.decide_deposit(uuid,boolean,text) to authenticated;
commit;