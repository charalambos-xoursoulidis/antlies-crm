-- ═══════════════════════════════════════════════════════════════════
-- Αντλίες CRM — κανόνες πρόσβασης (RLS)
-- Τρέξτε το ΜΙΑ φορά στο Supabase: SQL Editor → New query → Επικόλληση → Run.
-- ΠΡΙΝ: (1) έχει ανέβει το CRM v3.1 και (2) έχετε φτιάξει τον χρήστη σας
--       στο Authentication → Users → Add user (με «Auto Confirm User»).
-- Αλλάξτε το email παρακάτω (γραμμή με INSERT INTO crm_users).
--
-- Αποτέλεσμα:
--   • Μόνο οι χρήστες της λίστας crm_users (συνδεδεμένοι) διαβάζουν/γράφουν/σβήνουν.
--   • Ο δημόσιος υπολογιστής (ανώνυμος) μπορεί ΜΟΝΟ να προσθέτει νέα leads
--     και στατιστικά — δεν διαβάζει, δεν αλλάζει, δεν σβήνει τίποτα.
--
-- Επαναφορά (αν κάτι πάει στραβά): τρέξτε το supabase/rollback.sql.
-- ═══════════════════════════════════════════════════════════════════

-- 1. Λίστα επιτρεπόμενων χρηστών CRM
create table if not exists public.crm_users (email text primary key);
alter table public.crm_users enable row level security;   -- χωρίς πολιτικές: κανείς δεν τη βλέπει από το API
insert into public.crm_users(email) values ('ΤΟ-EMAIL-ΣΑΣ@example.com') on conflict do nothing;

create or replace function public.is_crm_user() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.crm_users where lower(email) = lower(auth.jwt() ->> 'email'));
$$;

-- 2. Σβήσιμο ΟΛΩΝ των παλιών πολιτικών (π.χ. allow_all) στους πίνακες του CRM
do $$
declare r record;
begin
  for r in select policyname, tablename from pg_policies
           where schemaname='public' and tablename in ('customers','properties','quotes','hm_settings','calc_events')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- 3. RLS ενεργό
alter table public.customers   enable row level security;
alter table public.properties  enable row level security;
alter table public.quotes      enable row level security;
alter table public.hm_settings enable row level security;
alter table public.calc_events enable row level security;

-- 4. Πλήρης πρόσβαση μόνο για χρήστες του CRM
create policy crm_all on public.customers   for all to authenticated using (public.is_crm_user()) with check (public.is_crm_user());
create policy crm_all on public.properties  for all to authenticated using (public.is_crm_user()) with check (public.is_crm_user());
create policy crm_all on public.quotes      for all to authenticated using (public.is_crm_user()) with check (public.is_crm_user());
create policy crm_all on public.hm_settings for all to authenticated using (public.is_crm_user()) with check (public.is_crm_user());
create policy crm_all on public.calc_events for all to authenticated using (public.is_crm_user()) with check (public.is_crm_user());

-- 5. Δημόσιος υπολογιστής: μόνο ΠΡΟΣΘΗΚΗ (insert) νέων εγγραφών
create policy calc_insert on public.customers   for insert to anon with check (true);
create policy calc_insert on public.properties  for insert to anon with check (true);
create policy calc_insert on public.quotes      for insert to anon with check (true);
create policy calc_insert on public.calc_events for insert to anon with check (true);
create policy calc_insert on public.hm_settings for insert to anon with check (id like 'hl\_%');  -- μόνο αποτελέσματα μελέτης

-- 6. Ο παλιός κωδικός της πύλης δεν χρειάζεται πια
delete from public.hm_settings where id = 'crm_pass';
