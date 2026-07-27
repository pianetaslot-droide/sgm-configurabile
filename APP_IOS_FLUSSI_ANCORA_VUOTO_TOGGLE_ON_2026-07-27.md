# App iOS → SGM/Windows — Flussi ANCORA vuoto con toggle ON (app-side OK) + note (2026-07-27)

## Flussi vuoto anche con toggle ON — lato app tutto verificato OK
Hu Leo ha acceso il toggle "Esiti pagamento → Supabase" ma Flussi resta vuoto
("Totale erogato (0)"). Verificato lato app, è tutto a posto:
- **Supabase URL = `pcoltegzfkrdfqyiyhlf`** (confermato da Hu Leo in Configurazione backend) =
  lo STESSO progetto su cui scrivete. Nessun mismatch di progetto.
- **Filtro data "Oggi" usa Europe/Rome** (`Date.romeCalendar`, non UTC) → nessun errore di
  confine giorno.
- Query `pagamenti_tito` per `created_at` range, **nessun** filtro kiosk_id/tipo → non esclude nulla.
- La tabella esiste. "(0)" = zero righe realmente restituite dalla query.

→ Conclusione: **l'app leggerebbe le righe se ci fossero — non ci sono righe in `pagamenti_tito`**
per oggi sul progetto `pcoltegzfkrdfqyiyhlf`. Il mirror non ha scritto.

## Verifiche lato macchina (ci servono)
1. Su questa macchina è deployata la **v52** (toggle persistente/live)? Il toggle è ON e
   **RESTA** ON (non si è richiuso da solo)?
2. Il **mirror worker** gira? Ci sono righe in `pagamenti_tito`/`pagamenti_betting` con i
   `sessione_id` dei payout di oggi sul progetto `pcoltegzfkrdfqyiyhlf`?
3. La **sweep di backfill** al primo toggle-ON è partita (le ~63 pending)? Log errori del mirror
   (auth Supabase? colonna mancante? RLS/permessi?)?

Se lato vostro CI SONO righe ma l'app non le vede → è decode lato app: mandatemi lo schema
ESATTO delle colonne che scrivete in `pagamenti_tito` e verifico il mapping. Se NON ci sono
righe → è il mirror che non scrive: caccia lato macchina.

## Note (dal vostro v52)
- **in_revisione blocco re-pay = IMPLEMENTATO lato app** (build compilata OK): `isTitoTicketPagato`
  ora conta `completato` + `in_revisione` come "non ri-pagabile"; `cancelled` resta ri-pagabile.
- **failed_no_cash_moved**: mappatelo come **`cancelled`** (nessun contante mosso, ri-pagabile) —
  semantica identica al vostro cancelled, così l'app non gestisce un quinto stato.
- **E2E esito da Supabase**: appena Flussi si popola validiamo la lettura join `sessione_id` per
  i quattro stati. Reply BLE resta pieno per ora.
