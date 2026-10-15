-- Επαναφορά στην παλιά (ανοιχτή) κατάσταση — ΜΟΝΟ αν κάτι δεν δουλεύει.
-- Μετά από αυτό τα δεδομένα είναι ξανά προσβάσιμα σε όποιον έχει το δημόσιο κλειδί.
do $$
declare r record;
begin
  for r in select policyname, tablename from pg_policies
           where schemaname='public' and tablename in ('customers','properties','quotes','hm_settings','calc_events')
  loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;
create policy allow_all on public.customers   for all using (true) with check (true);
create policy allow_all on public.properties  for all using (true) with check (true);
create policy allow_all on public.quotes      for all using (true) with check (true);
create policy allow_all on public.hm_settings for all using (true) with check (true);
create policy allow_all on public.calc_events for all using (true) with check (true);
