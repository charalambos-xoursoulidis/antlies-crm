-- ════════════════════════════════════════════════════════════════════
-- Αντλίες CRM — email στο γραφείο για κάθε νέο αίτημα από τον υπολογιστή (δωρεάν)
--
-- Η βάση στέλνει μόνη της email μόλις γραφτεί νέος πελάτης από τον δημόσιο
-- υπολογιστή. Δεν εξαρτάται από το αν ο πελάτης πάτησε «αποστολή» στο δικό του email.
-- Αποστολή μέσω Resend (δωρεάν: 3.000 email/μήνα, 100/ημέρα, χωρίς κάρτα).
--
-- ΒΗΜΑΤΑ (μία φορά):
--  1. https://resend.com → Sign up με το email που θέλετε να λαμβάνει τις ειδοποιήσεις.
--  2. Resend → API Keys → Create API Key (Sending access) → αντιγράψτε το (re_...).
--  3. Supabase → SQL Editor → τρέξτε ΜΟΝΟ αυτή τη γραμμή, με το δικό σας κλειδί:
--       select vault.create_secret('re_ΤΟ_ΚΛΕΙΔΙ_ΣΑΣ', 'resend_api_key');
--     (Το κλειδί μένει κρυπτογραφημένο στη βάση — ΠΟΤΕ στη σελίδα ή στο GitHub.)
--  4. Αλλάξτε παρακάτω το notify_to αν χρειάζεται (πρέπει να είναι το email του λογαριασμού Resend)
--     και τρέξτε όλο το υπόλοιπο αρχείο.
-- Αναίρεση: δείτε το τέλος του αρχείου.
-- ════════════════════════════════════════════════════════════════════

create extension if not exists pg_net;

create or replace function public.notify_new_lead()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  notify_to text := 'charalambos@xoursoulidis.com';
  k   text;
  txt text;
begin
  if coalesce(auth.role(), '') <> 'anon' then
    return new;                                   -- εγγραφές από το CRM: χωρίς email
  end if;
  select decrypted_secret into k from vault.decrypted_secrets where name = 'resend_api_key' limit 1;
  if k is null then
    return new;
  end if;
  txt := 'Νέο αίτημα από τον υπολογιστή αντλίας θερμότητας' || chr(10) || chr(10)
      || 'Όνομα: '    || coalesce(new.lastname, '') || ' ' || coalesce(new.firstname, '') || chr(10)
      || 'Τηλέφωνο: ' || coalesce(new.phone, '')    || chr(10)
      || 'Email: '    || coalesce(nullif(new.email, ''), '—') || chr(10)
      || 'Διεύθυνση: '|| coalesce(new.address, '')  || ' (' || coalesce(new.city, '') || ')' || chr(10)
      || 'Σημειώσεις: '|| coalesce(new.notes, '')   || chr(10) || chr(10)
      || 'Ανοίξτε το CRM για την πρόχειρη προσφορά.';
  perform net.http_post(
    url     := 'https://api.resend.com/emails',
    headers := jsonb_build_object('Authorization', 'Bearer ' || k, 'Content-Type', 'application/json'),
    body    := jsonb_build_object(
                 'from', 'Αντλίες CRM <onboarding@resend.dev>',
                 'to', jsonb_build_array(notify_to),
                 'subject', 'Νέο αίτημα: ' || coalesce(new.lastname, '') || ' ' || coalesce(new.firstname, ''),
                 'text', txt)
  );
  return new;
exception when others then
  return new;                                     -- ποτέ μην χαθεί αίτημα επειδή απέτυχε το email
end;
$$;

drop trigger if exists notify_new_lead on public.customers;
create trigger notify_new_lead after insert on public.customers
  for each row execute function public.notify_new_lead();

-- ── Αναίρεση (αν χρειαστεί) ──────────────────────────────────────────
-- drop trigger if exists notify_new_lead on public.customers;
-- drop function if exists public.notify_new_lead();
-- delete from vault.secrets where name = 'resend_api_key';
