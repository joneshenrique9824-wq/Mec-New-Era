begin;
create table if not exists public.service_orders(id uuid primary key, organization_id uuid not null references public.organizations(id), employee_id uuid not null references public.profiles(id), customer text not null, notes text not null, created_at timestamptz not null default now());
alter table public.service_orders enable row level security;
grant select on public.service_orders to authenticated;
create policy service_orders_read on public.service_orders for select to authenticated using(exists(select 1 from public.organization_members m where m.organization_id=service_orders.organization_id and m.user_id=auth.uid() and m.status='active' and (employee_id=auth.uid() or m.role in ('proprietario','gerente','supervisor'))));
alter table public.sales add column if not exists service_order_id uuid references public.service_orders(id);
create or replace function public.finalize_service_order(p_order uuid,p_org uuid,p_customer text,p_notes text,p_items jsonb) returns uuid language plpgsql security definer set search_path='' as $$
declare item jsonb; sid uuid; pid uuid;
begin
if auth.uid() is null or not exists(select 1 from public.organization_members m where m.organization_id=p_org and m.user_id=auth.uid() and m.status='active') then raise exception 'Acesso negado'; end if;
if p_order is null or jsonb_typeof(p_items) is distinct from 'array' or jsonb_array_length(p_items) not between 1 and 100 then raise exception 'Itens invalidos'; end if;
insert into public.service_orders(id,organization_id,employee_id,customer,notes) values(p_order,p_org,auth.uid(),left(coalesce(p_customer,''),200),left(coalesce(p_notes,''),2000)) on conflict(id) do nothing;
if not found then
if exists(select 1 from public.service_orders where id=p_order and employee_id=auth.uid() and organization_id=p_org) then return p_order; end if;
raise exception 'Protocolo invalido';
end if;
for item in select value from jsonb_array_elements(p_items) loop
pid:=(item->>'id')::uuid;
if not exists(select 1 from public.products where id=pid and organization_id=p_org and active) then raise exception 'Produto invalido'; end if;
sid:=public.register_sale(pid,(item->>'qty')::integer,(item->>'price')::numeric,gen_random_uuid());
update public.sales set service_order_id=p_order where id=sid;
end loop;
return p_order;
end; $$;
revoke all on function public.finalize_service_order(uuid,uuid,text,text,jsonb) from public,anon;
grant execute on function public.finalize_service_order(uuid,uuid,text,text,jsonb) to authenticated;
commit;