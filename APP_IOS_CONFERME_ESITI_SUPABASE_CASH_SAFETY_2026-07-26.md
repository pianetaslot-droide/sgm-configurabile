# App iOS → SGM/Windows — CONFERME esiti su Supabase + cash-safety (2026-07-26)

Root cause chiara (RPC `sgm_ledger_sync_operation` NON deployata → tutto `pending`), e la
direzione "**comando in BLE, esito da Supabase**" è giusta. Confermo le tre decisioni (Hu Leo).

## 1. `operator_review_required` → SÌ: gestiamo `in_revisione` + BLOCCO re-pay ✅
Priorità cash-safety. Introducete `in_revisione` (**NON** `fallito`) su
pagamenti_tito/pagamenti_betting. Lato app: mostriamo "IN VERIFICA — non ri-pagare" e
**blocchiamo il re-pay** su quella operation/reference (nessun retry automatico, nessun nuovo
`pay_operation`) finché non è risolto. Mai trattarlo come "non pagato". Procedete.

## 2. `cancelled` → SÌ, mirroratelo ✅
Segnale esplicito "chiuso, nessun contante mosso, biglietto ri-pagabile". L'app lo distingue da
completato / fallito / in_revisione.

## 3. "Esito da Supabase" → SÌ, iniziamo ORA (parallelo) ✅
- **Ora**: v43 scrive gli esiti (toggle ON). Lato app INIZIAMO a leggere l'esito da
  pagamenti_tito/pagamenti_betting con **join su `sessione_id` = il nostro `operation_id`**, in
  parallelo al reply BLE.
- **Poi** (dopo che l'app legge da Supabase e lo verifichiamo su un payout reale): riducete il
  reply BLE ad ack minimale. **Ve lo diciamo noi quando siamo pronti** (non prima).

## Domande per implementare preciso (lato app)
1. **Valori ESATTI di `stato`** in pagamenti_tito/betting per ogni caso: confermate le stringhe?
   `completato` / `fallito` / `in_revisione` / `cancelled` — mappo senza ambiguità.
2. **`sessione_id`**: è una colonna GIÀ esistente su pagamenti_tito / pagamenti_betting /
   cambio_operazioni, e contiene ESATTAMENTE l'`operation_id` che inviamo nel `pay_operation`?
   (Ci serve per il join. Se il nome colonna è diverso, ditecelo.)
3. **Join TITO/betting**: meglio `sessione_id` o la reference (ticket_barcode /
   riferimento_vincita)? Consigliate voi (per cambio avete già detto `sessione_id`).
4. **Backfill**: le operazioni di OGGI già chiuse (le 63 `pending`) vengono mirrorate
   RETROATTIVAMENTE all'accensione del toggle, o solo le nuove da adesso? Ci servono anche
   quelle di oggi in Flussi.

## Lato app parto con
Lettura esito da Supabase (join `sessione_id`) + gestione stati `in_revisione` (blocco re-pay) /
`cancelled`, in parallelo al reply BLE. Vi aggiorno appena pronto per il test E2E.
