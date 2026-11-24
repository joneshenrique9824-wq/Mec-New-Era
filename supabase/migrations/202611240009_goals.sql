begin;
create table public.daily_goals(organization_id uuid primary key references public.organizations(id),target numeric(20,2) not null check(target>0),updated_at timestamptz not null default now());
alter table public.daily_goals enable row level security;
revoke all on public.daily_goals from anon,authenticated;
create function public.set_daily_goal(p_org uuid,p_target numeric) returns void language plpgsql security definer set search_path='' as $$
begin
if not exists(select 1 from public.organization_members m where m.organization_id=p_org and m.user_id=auth.uid() and m.status='active' and m.discord_verified_until>now() and m.role in ('proprietario','gerente')) then raise exception 'Acesso negado'; end if;
if p_target is null or p_target<=0 then raise exception 'Meta invalida'; end if;
insert into public.daily_goals values(p_org,p_target,now()) on conflict(organization_id) do update set target=excluded.target,updated_at=now();
end; $$;
create function public.goal_ranking(p_org uuid,p_period text) returns jsonb language plpgsql security definer set search_path='' as $$
declare start_at timestamptz; day_at timestamptz; result jsonb;
begin
if not exists(select 1 from public.organization_members m where m.organization_id=p_org and m.user_id=auth.uid() and m.status='active' and m.discord_verified_until>now()) then raise exception 'Acesso negado'; end if;
if p_period is null or p_period not in ('day','week','month') then raise exception 'Periodo invalido'; end if;
start_at:=date_trunc(p_period,now() at time zone 'America/Sao_Paulo') at time zone 'America/Sao_Paulo';
day_at:=date_trunc('day',now() at time zone 'America/Sao_Paulo') at time zone 'America/Sao_Paulo';
select jsonb_build_object('target',(select target from public.daily_goals where organization_id=p_org),'today',(select coalesce(sum(total),0) from public.sales where organization_id=p_org and employee_id=auth.uid() and created_at>=day_at),'team_today',(select coalesce(sum(total),0) from public.sales where organization_id=p_org and created_at>=day_at),'ranking',coalesce((select jsonb_agg(to_jsonb(t) order by t.total desc,t.name) from (select coalesce(p.character_name,'Sem nome') name,sum(s.total) total,count(*) sales from public.sales s join public.profiles p on p.id=s.employee_id where s.organization_id=p_org and s.created_at>=start_at group by s.employee_id,p.character_name) t),'[]'::jsonb)) into result;
return result;
end; $$;
revoke all on function public.set_daily_goal(uuid,numeric),public.goal_ranking(uuid,text) from public,anon;
grant execute on function public.set_daily_goal(uuid,numeric),public.goal_ranking(uuid,text) to authenticated;
commit;