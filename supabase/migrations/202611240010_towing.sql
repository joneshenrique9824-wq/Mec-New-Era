begin;
create table public.towing_jobs(id uuid primary key default gen_random_uuid(),organization_id uuid not null references public.organizations(id),employee_id uuid not null references public.profiles(id),customer text not null,description text not null,amount numeric(14,2) not null check(amount>0),created_at timestamptz not null default now(),request_id uuid not null,unique(employee_id,request_id));
alter table public.towing_jobs enable row level security;
revoke all on public.towing_jobs from anon,authenticated;
grant select on public.towing_jobs to authenticated;
create policy towing_read on public.towing_jobs for select to authenticated using(exists(select 1 from public.organization_members m where m.organization_id=towing_jobs.organization_id and m.user_id=auth.uid() and m.status='active' and m.discord_verified_until>now() and (towing_jobs.employee_id=auth.uid() or m.role in ('proprietario','gerente','supervisor'))));
create function public.register_towing(p_org uuid,p_customer text,p_description text,p_amount numeric,p_request uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
if not exists(select 1 from public.organization_members m where m.organization_id=p_org and m.user_id=auth.uid() and m.status='active' and m.discord_verified_until>now()) then raise exception 'Acesso negado'; end if;
if p_request is null or p_amount is null or p_amount<=0 or p_amount<>round(p_amount,2) or coalesce(length(trim(p_customer)),0) not between 1 and 120 or coalesce(length(trim(p_description)),0) not between 1 and 1000 then raise exception 'Dados invalidos'; end if;
insert into public.towing_jobs(organization_id,employee_id,customer,description,amount,request_id) values(p_org,auth.uid(),trim(p_customer),trim(p_description),p_amount,p_request) on conflict(employee_id,request_id) do nothing returning id into result;
if result is null then select id into result from public.towing_jobs where employee_id=auth.uid() and request_id=p_request and organization_id=p_org; end if;
return result;
end; $$;
revoke all on function public.register_towing(uuid,text,text,numeric,uuid) from public,anon;
grant execute on function public.register_towing(uuid,text,text,numeric,uuid) to authenticated;
commit;