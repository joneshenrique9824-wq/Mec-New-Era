begin;
create table public.receipt_fingerprints(organization_id uuid not null references public.organizations(id),deposit_id uuid not null, fingerprint text not null check(fingerprint ~ '^[0-9a-f]{64}$'),storage_path text not null,created_at timestamptz not null default now(),primary key(organization_id,fingerprint));
alter table public.receipt_fingerprints enable row level security;
revoke all on public.receipt_fingerprints from anon,authenticated;
grant select,insert on public.receipt_fingerprints to service_role;
commit;