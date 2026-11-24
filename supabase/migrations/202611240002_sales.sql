begin;
create table public.products (
 id uuid primary key default gen_random_uuid(),
 organization_id uuid not null references public.organizations(id),
 name text not null,
 category text not null,
 price_min numeric(14,2) not null check(price_min>0),
 price_max numeric(14,2) not null check(price_max>=price_min),
 active boolean not null default true,
 unique(organization_id,name)
);
create table public.sales (
 id uuid primary key default gen_random_uuid(),
 protocol bigint generated always as identity unique,
 organization_id uuid not null references public.organizations(id),
 employee_id uuid not null references public.profiles(id),
 product_id uuid not null references public.products(id),
 product_name text not null,
 quantity integer not null check(quantity between 1 and 100000),
 unit_price numeric(14,2) not null,
 total numeric(20,2) not null,
 mechanic_share numeric(20,2) not null,
 employee_share numeric(20,2) not null,
 request_id uuid not null,
 created_at timestamptz not null default now(),
 unique(employee_id,request_id)
);
alter table public.products enable row level security;
alter table public.sales enable row level security;
revoke all on public.products,public.sales from anon,authenticated;
grant select on public.products,public.sales to authenticated;
create policy catalog_read on public.products for select to authenticated using(exists(select 1 from public.organization_members m where m.organization_id=products.organization_id and m.user_id=auth.uid() and m.status='active'));
create policy sales_read on public.sales for select to authenticated using(exists(select 1 from public.organization_members m where m.organization_id=sales.organization_id and m.user_id=auth.uid() and m.status='active' and (sales.employee_id=auth.uid() or m.role in ('proprietario','diretor','administrador','gerente_geral','gerente'))));
create function public.register_sale(p_product uuid,p_quantity integer,p_price numeric,p_request uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare p public.products%rowtype; t numeric; c numeric; result uuid;
begin
if auth.uid() is null or p_request is null or p_quantity is null or p_quantity not between 1 and 100000 or p_price is null then raise exception 'Dados invalidos'; end if;
select * into p from public.products where id=p_product and active for share;
if not found or not exists(select 1 from public.organization_members m where m.organization_id=p.organization_id and m.user_id=auth.uid() and m.status='active') then raise exception 'Acesso negado'; end if;
if p_price<p.price_min or p_price>p.price_max or p_price<>round(p_price,2) then raise exception 'Preco invalido'; end if;
t:=p_quantity*p_price; c:=round(t*0.15,2);
insert into public.sales(organization_id,employee_id,product_id,product_name,quantity,unit_price,total,mechanic_share,employee_share,request_id) values(p.organization_id,auth.uid(),p.id,p.name,p_quantity,p_price,t,c,t-c,p_request) on conflict(employee_id,request_id) do nothing returning id into result;
if result is null then select id into result from public.sales where employee_id=auth.uid() and request_id=p_request; end if;
return result;
end; $$;
revoke all on function public.register_sale(uuid,integer,numeric,uuid) from public,anon;
grant execute on function public.register_sale(uuid,integer,numeric,uuid) to authenticated;
insert into public.products(organization_id,name,category,price_min,price_max,active)
select o.id,v.name,v.category,v.lo,v.hi,v.active from public.organizations o cross join (values
('Kit para venda','Produtos',20000,20000,true),('Kit no NPC','Produtos',25000,25000,true),('Aplicacao de kit','Servicos',10000,15000,true),('Pneu para venda','Produtos',10000,10000,true),('Pneu no NPC','Produtos',10000,10000,true),('Rodas','Produtos',30000,30000,false),
('Motor','Performance',800000,800000,true),('Turbo','Performance',350000,350000,true),('Transmissao','Performance',150000,150000,true),('Suspensao completa','Performance',100000,100000,true),('Freios','Performance',550000,550000,true),('Blindagem','Performance',500000,500000,true),('Nitro','Performance',20000,20000,true),('Suspensao basica','Performance',40000,40000,true),('Pneu de tuning','Performance',10500,10500,true),('Escapamento','Performance',8500,8500,true),
('Neons','Visual',3500,3500,true),('Xenon','Visual',5000,5000,true),('Pintura','Visual',5000,5000,true),('Pelicula','Visual',5500,5500,true),('Adesivos','Visual',4200,4200,true),('Buzina','Visual',800,800,true),('Placa','Visual',2500,2500,true),
('Aerofolio','Carroceria',6500,6500,true),('Saia lateral','Carroceria',4000,4000,true),('Para-choque dianteiro','Carroceria',5800,5800,true),('Para-choque traseiro','Carroceria',2800,2800,true),('Para-lama D/E','Carroceria',6800,6800,true),('Capo','Carroceria',4500,4500,true),('Gaiola','Carroceria',8800,8800,true),('Grade','Carroceria',7400,7400,true),('Teto','Carroceria',3500,3500,true)
) v(name,category,lo,hi,active) where o.slug='new-era-city';
commit;