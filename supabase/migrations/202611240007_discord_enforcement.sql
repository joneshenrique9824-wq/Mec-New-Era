begin;
create or replace function public.register_sale(p_product uuid,p_quantity integer,p_price numeric,p_request uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare p public.products%rowtype; t numeric; c numeric; result uuid;
begin
if auth.uid() is null or p_request is null or p_quantity is null or p_quantity not between 1 and 100000 or p_price is null then raise exception 'Dados invalidos'; end if;
select * into p from public.products where id=p_product and active for share;
if not found or not exists(select 1 from public.organization_members m where m.organization_id=p.organization_id and m.user_id=auth.uid() and m.status='active' and discord_verified_until>now()) then raise exception 'Acesso negado'; end if;
if p_price<p.price_min or p_price>p.price_max or p_price<>round(p_price,2) then raise exception 'Preco invalido'; end if;
t:=p_quantity*p_price; c:=round(t*0.15,2);
insert into public.sales(organization_id,employee_id,product_id,product_name,quantity,unit_price,total,mechanic_share,employee_share,request_id) values(p.organization_id,auth.uid(),p.id,p.name,p_quantity,p_price,t,c,t-c,p_request) on conflict(employee_id,request_id) do nothing returning id into result;
if result is null then select id into result from public.sales where employee_id=auth.uid() and request_id=p_request; end if;
return result;
end; $$;
create or replace function public.submit_deposit(p_org uuid,p_amount numeric,p_request uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare available numeric; result uuid;
begin
if auth.uid() is null or p_request is null or p_amount is null or p_amount<=0 or p_amount<>round(p_amount,2) then raise exception 'Dados invalidos'; end if;
perform 1 from public.organization_members where organization_id=p_org and user_id=auth.uid() and status='active' and discord_verified_until>now() for update;
if not found then raise exception 'Acesso negado'; end if;
select id into result from public.deposits where employee_id=auth.uid() and request_id=p_request and organization_id=p_org;
if found then return result; end if;
select coalesce(sum(mechanic_share),0) into available from public.sales where organization_id=p_org and employee_id=auth.uid();
available:=available-(select coalesce(sum(amount),0) from public.deposits where organization_id=p_org and employee_id=auth.uid() and status in ('pending','approved'));
if p_amount>available then raise exception 'Saldo insuficiente'; end if;
insert into public.deposits(organization_id,employee_id,amount,request_id) values(p_org,auth.uid(),p_amount,p_request) returning id into result;
return result;
end; $$;
create or replace function public.decide_deposit(p_id uuid,p_approve boolean,p_reason text) returns void language plpgsql security definer set search_path='' as $$
declare d public.deposits%rowtype;
begin
if p_approve is null then raise exception 'Decisao invalida'; end if;
select * into d from public.deposits where id=p_id for update;
if not found or not exists(select 1 from public.organization_members where organization_id=d.organization_id and user_id=auth.uid() and status='active' and discord_verified_until>now() and role in ('proprietario','diretor','administrador','gerente_geral','gerente','supervisor')) then raise exception 'Acesso negado'; end if;
if d.status<>'pending' then raise exception 'Registro ja decidido'; end if;
if not p_approve and coalesce(trim(p_reason),'')='' then raise exception 'Informe o motivo'; end if;
update public.deposits set status=case when p_approve then 'approved' else 'rejected' end,decided_at=now(),decided_by=auth.uid(),reason=p_reason where id=p_id;
end; $$;
create policy discord_membership_fresh on public.organization_members as restrictive for select to authenticated using(discord_verified_until>now());
commit;
