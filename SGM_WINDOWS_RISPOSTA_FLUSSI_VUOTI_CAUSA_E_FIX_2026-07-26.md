# SGM/Windows → App iOS — Flussi vuoti: causa REALE + fix (v43) (2026-07-26)

Grazie per il handoff. **La vostra ipotesi #1 (mirror sul Supabase VECCHIO) è esclusa**:
ho verificato sulla macchina che SGM punta GIÀ al progetto di `set_config`. La causa vera è
un'altra (il mirror non scriveva affatto), ed è **corretta in v43**.

## Ipotesi "progetto vecchio" → ESCLUSA (con prova)

- `config.json` → `cloud.supabase_url` = **`https://pcoltegzfkrdfqyiyhlf.supabase.co`**
  (esattamente ciò che `set_config` ha persistito: log `set_config applied=[supabase_url,
  supabase_anon_key,…]` alle 13:56).
- I log HTTP di SGM colpiscono **lo stesso** `pcoltegzfkrdfqyiyhlf.supabase.co`.
- `config_store` propaga `SUPABASE_URL = cfg.cloud.supabase_url`, e SGM è stato riavviato
  (19:08) DOPO il `set_config`, quindi il client vivo usa le credenziali nuove.

→ SGM scrive sul progetto GIUSTO (quello che legge l'app). Non c'è nulla da ri-puntare.

## Causa vera: il mirror non scriveva PROPRIO (né vecchio né nuovo)

Due blocchi in serie (li ho trovati sulla macchina):
1. **Worker di sync SPENTO**: `local_ledger_sync_enabled=false` → 63 operazioni tutte
   `cloud_sync_status=pending`, **0 mirrorate**. Mai scritto `pagamenti_tito`.
2. Anche acceso, il mirror era **gated dietro la RPC `sgm_ledger_sync_operation`** che **non è
   deployata** → sarebbe fallito comunque.

**Fix v43**: sganciata la RPC (mirror scrive DIRETTO nelle tabelle legacy) + **toggle
touchscreen** "Esiti pagamento → Supabase" (worker sempre attivo, si abilita dal vivo).

## Le vostre 4 domande

1. **Target mirror**: già il progetto di `set_config` (pcoltegzfkrdfqyiyhlf). Ok.
2. **Tabelle mirrorate dagli ESITI PAYOUT**: `pagamenti_tito` (tito/novomatic, chiave
   `ticket_barcode`), `pagamenti_betting` (snai_betting/fastbet, chiave `riferimento_vincita`),
   `cambio_operazioni` (cambio, `sessione_id`). Join consigliato ovunque: **`sessione_id` =
   l'`operation_id`** del vostro pay_operation. Colonne: `stato` (completato/fallito),
   `importo_pagato`, `manual_cents` (residuo), `motivo_fallimento`.
   - NB: **Livelli/Dashboard** usano ALTRE sync (kiosk_livelli_cash, hardware_state) che già
     giravano — se Livelli è vuoto sul nuovo progetto è un punto separato, ditemi e verifico.
3. **Backfill di OGGI** (verificato adesso sul ledger):
   - I nuovi payout da adesso → mirrorati subito (toggle ON).
   - In coda `sync_outbox` ci sono **16 operazioni `completed`** che si mirrorano appena
     accendete il toggle (retry automatico della coda). ✅
   - MA **44 operazioni terminali più vecchie NON hanno una riga outbox** → NON si
     ri-mirrorano da sole. Per lo storico completo di oggi aggiungo uno **sweep di backfill**
     (ri-accoda le operazioni terminali `pending` senza outbox) — se vi serve subito lo metto
     nella prossima build; altrimenti i nuovi + i 16 in coda bastano per validare E2E.
4. **Cadenza**: il worker drena l'outbox ogni ~60s (una riga outbox è accodata a fine payout);
   retry con backoff, dead-letter dopo 10 tentativi. "Pagato ma non ancora mirato" = riga
   outbox `pending` (coda di retry) — la quadratura resta sul ledger locale (verità), il
   mirror la insegue.

## Come validare (dopo deploy v43)

Touch → Impostazioni BLE → **"Esiti pagamento → Supabase" ON** → fate un payout → in Supabase
`pagamenti_tito` (o `pagamenti_betting` per snai) compare la riga con `sessione_id` =
operation_id. Flussi "Oggi" si popola.

## Altri due punti (dal vostro CONFERME)

- **no_50 v42**: confermato il best-effort (confluisce nel resto) — è esattamente il
  comportamento della build. Ripetete pure il test €150·€50 → atteso 2×€20+1×€10+2×€50.
- **set_operators**: ricevuto §1+§2, procedo con l'implementazione `connect_roles`
  full-replace (Connect C09A, pbkdf2 verbatim). Il bypass "000000" lo lascio **gated a debug**.
