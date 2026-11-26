-- Execute after farm-goals.sql and towing-register.sql.
alter table public.towing_entries add column if not exists region text check(region in ('Sul','Norte'));
alter table public.towing_entries add column if not exists discord_message_id text;
alter table public.towing_entries add column if not exists receipt_hash text;
create unique index if not exists towing_receipt_unique on public.towing_entries(organization_id,receipt_hash) where receipt_hash is not null;
revoke insert on public.towing_entries from authenticated;
revoke insert(organization_id,quantity,notes) on public.towing_entries from authenticated;
