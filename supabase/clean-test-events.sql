-- ════════════════════════════════════════════════════════════════════
-- Αντλίες CRM — σβήσιμο δοκιμαστικών επισκέψεων από τα «📊 Στατιστικά»
-- Supabase → SQL Editor. Τρέξτε τα βήματα ΕΝΑ-ΕΝΑ (επιλέγετε τις γραμμές → Run).
-- Αφορά ΜΟΝΟ τον πίνακα calc_events (βήματα του υπολογιστή). Πελάτες/προσφορές δεν αγγίζονται.
-- ════════════════════════════════════════════════════════════════════

-- ΒΗΜΑ 1 — αντίγραφο ασφαλείας (κλειδωμένο, δεν φαίνεται από τη σελίδα)
create table if not exists public.calc_events_backup as select * from public.calc_events;
alter table public.calc_events_backup enable row level security;

-- ΒΗΜΑ 2 — δείτε τις επισκέψεις ανά ημέρα, για να βρείτε πού τελειώνουν οι δοκιμές
select date(created_at at time zone 'Europe/Athens') as imera,
       count(distinct sid)                           as episkepseis,
       count(*) filter (where ev = 'offer')          as prosfores
from public.calc_events
group by 1 order by 1;

-- ΒΗΜΑ 3 — σβήσιμο: αλλάξτε την ημερομηνία στην ΠΡΩΤΗ πραγματική ημέρα λειτουργίας.
-- Σβήνει ό,τι γράφτηκε ΠΡΙΝ από αυτήν (ώρα Ελλάδας).
delete from public.calc_events
where created_at < (timestamp '2026-09-18 00:00' at time zone 'Europe/Athens');

-- Επαναφορά (αν σβήσατε κάτι κατά λάθος):
-- insert into public.calc_events select * from public.calc_events_backup b
--   where not exists (select 1 from public.calc_events e where e.id = b.id);
-- Όταν είστε σίγουροι: drop table public.calc_events_backup;
