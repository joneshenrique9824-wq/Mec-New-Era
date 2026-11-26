-- Apply in Supabase SQL Editor before deploying the new admin UI.
-- Reuse the existing admin_control authorization and audit implementation.
create or replace function public.adjust_mechanic_cash(p_org uuid,p_mode text,p_amount numeric,p_reason text)
returns jsonb
language plpgsql
security invoker
set search_path = public, pg_temp
as $$
declare
  v_current numeric;
  v_next numeric;
  v_result jsonb;
begin
  if p_mode is null or p_mode not in ('set','add','subtract') or p_amount is null or p_amount::text in ('NaN','Infinity','-Infinity') or p_amount < 0 or p_amount > 999999999999 or round(p_amount,2) <> p_amount or (p_mode <> 'set' and p_amount = 0) or length(trim(coalesce(p_reason,''))) < 5 then
    raise exception 'Movimentação inválida';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(p_org::text, 0));
  select to_jsonb(public.admin_control(p_org => p_org,p_action => 'read',p_reason => '',p_balance => null)) into v_result;
  v_current := (v_result->>'balance')::numeric;
  if v_current is null then raise exception 'Saldo indisponível'; end if;
  v_next := case p_mode when 'add' then v_current+p_amount when 'subtract' then v_current-p_amount else p_amount end;
  if v_next < 0 or v_next > 999999999999 then raise exception 'Saldo inválido ou insuficiente'; end if;
  select to_jsonb(public.admin_control(p_org => p_org,p_action => 'balance',p_reason => left(format('%s | anterior: %s | novo: %s | %s',p_mode,v_current,v_next,p_reason),500),p_balance => v_next)) into v_result;
  return v_result;
end;
$$;
revoke all on function public.adjust_mechanic_cash(uuid,text,numeric,text) from public, anon;
grant execute on function public.adjust_mechanic_cash(uuid,text,numeric,text) to authenticated;
