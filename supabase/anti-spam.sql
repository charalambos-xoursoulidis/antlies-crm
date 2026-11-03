-- ════════════════════════════════════════════════════════════════════
-- Αντλίες CRM — προστασία της βάσης από bots / μαζικές εγγραφές (δωρεάν)
-- Supabase → SQL Editor → New query → επικόλληση → Run. Μπορεί να τρέξει ξανά.
--
-- Ο δημόσιος υπολογιστής γράφει ως «anon» (χωρίς σύνδεση). Το φίλτρο στη φόρμα
-- σταματά τα απλά bots, αλλά όποιος στέλνει απευθείας στη βάση το παρακάμπτει.
-- Εδώ η βάση ελέγχει μόνη της ΚΑΘΕ εγγραφή anon:
--   • όριο ανά ώρα για κάθε πίνακα (π.χ. 15 νέοι πελάτες/ώρα από το κοινό)
--   • λογικά μήκη/μορφή στα στοιχεία πελάτη (τηλέφωνο ≥ 10 ψηφία κ.λπ.)
-- Οι εγγραφές από το CRM (συνδεδεμένοι χρήστες) ΔΕΝ επηρεάζονται.
-- Αναίρεση: δείτε το τέλος του αρχείου.
-- ════════════════════════════════════════════════════════════════════

create table if not exists public.anon_rate (
  tbl text not null,
  ts  timestamptz not null default now()
);
create index if not exists anon_rate_tbl_ts on public.anon_rate (tbl, ts);
alter table public.anon_rate enable row level security;   -- καμία πολιτική: μόνο η συνάρτηση γράφει

create or replace function public.anon_guard()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  lim int;
  n   int;
  digits text;
begin
  if coalesce(auth.role(), '') <> 'anon' then
    return new;                                  -- CRM / admin: χωρίς έλεγχο
  end if;

  lim := case tg_table_name
           when 'calc_events' then 3000           -- βήματα του υπολογιστή
           else 15                                -- πελάτες, ακίνητα, προσφορές, απώλειες
         end;

  select count(*) into n from public.anon_rate
   where tbl = tg_table_name and ts > now() - interval '1 hour';
  if n >= lim then
    raise exception 'Πολλές εγγραφές σε λίγο χρόνο — δοκιμάστε αργότερα' using errcode = 'P0001';
  end if;

  if tg_table_name = 'customers' then
    digits := regexp_replace(coalesce(new.phone, ''), '\D', '', 'g');
    if length(coalesce(new.lastname, '')) not between 1 and 60
       or length(coalesce(new.firstname, '')) not between 1 and 60
       or length(digits) not between 10 and 15
       or length(coalesce(new.email, '')) > 120
       or length(coalesce(new.address, '')) > 200
       or length(coalesce(new.notes, '')) > 2000 then
      raise exception 'Μη έγκυρα στοιχεία' using errcode = 'P0001';
    end if;
  end if;

  insert into public.anon_rate (tbl) values (tg_table_name);
  if random() < 0.02 then
    delete from public.anon_rate where ts < now() - interval '1 day';   -- καθάρισμα
  end if;
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array['customers','properties','quotes','hm_settings','calc_events'] loop
    execute format('drop trigger if exists anon_guard on public.%I', t);
    execute format('create trigger anon_guard before insert on public.%I for each row execute function public.anon_guard()', t);
  end loop;
end $$;

-- ── Αναίρεση (αν χρειαστεί) ──────────────────────────────────────────
-- do $$ declare t text; begin
--   foreach t in array array['customers','properties','quotes','hm_settings','calc_events'] loop
--     execute format('drop trigger if exists anon_guard on public.%I', t);
--   end loop; end $$;
-- drop function if exists public.anon_guard();
-- drop table if exists public.anon_rate;
