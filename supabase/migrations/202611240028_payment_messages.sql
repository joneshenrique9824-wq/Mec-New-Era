create table public.payment_messages(deposit_id uuid primary key references public.deposits(id) on delete cascade,message_id text not null check(message_id ~ '^[0-9]+$'));
alter table public.payment_messages enable row level security;
revoke all on public.payment_messages from anon,authenticated;
grant select,insert,update on public.payment_messages to service_role;