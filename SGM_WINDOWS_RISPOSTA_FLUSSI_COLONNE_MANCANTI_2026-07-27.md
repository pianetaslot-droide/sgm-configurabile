# SGM/Windows → app iOS — Flussi vuoto: CAUSA TROVATA (colonne mancanti) + FIX (2026-07-27)

Caccia lato macchina fatta. **Non era toggle/worker/backfill**: v52 è deployata, il toggle è
ON e PERSISTE (`local_ledger_sync_enabled: true` in config), il progetto è quello giusto
(`pcoltegzfkrdfqyiyhlf`), e la sweep di backfill parte. Il mirror **prova** a scrivere ma
Supabase rifiuta ogni INSERT con **400 / `42703`**.

## Causa esatta — colonne assenti nelle tabelle legacy

Sonda colonna-per-colonna (PostgREST `column ... does not exist`, code `42703`):

| tabella | colonne che il mirror SCRIVE ma NON esistono |
|---|---|
| `pagamenti_tito` | `manual_cents`, `fornitore`, `identificazione_cliente` |
| `pagamenti_betting` | `manual_cents` |

Ogni riga TITO scrive `manual_cents`+`fornitore` → 400 → **zero righe** → Flussi vuoto. Stesso
per betting su `manual_cents`. (Stesso pattern di `kiosk_dispositivi.config_json`,
`kiosk_livelli_cash.count_verified` già visti nei log.)

## Fix applicato

1. **Colonne aggiunte** su Supabase (Hu Leo, oggi):
   ```sql
   ALTER TABLE pagamenti_tito
     ADD COLUMN IF NOT EXISTS manual_cents integer,
     ADD COLUMN IF NOT EXISTS fornitore text,
     ADD COLUMN IF NOT EXISTS identificazione_cliente jsonb;
   ALTER TABLE pagamenti_betting
     ADD COLUMN IF NOT EXISTS manual_cents integer;
   ```
2. **v53 — mirror TOLLERANTE allo schema drift**: se PostgREST rifiuta una colonna
   inesistente (`42703`), il mirror la toglie e riscrive, così la riga **atterra comunque**
   con le colonne che la tabella ha, invece di perdere l'intero payout. Non si ripeterà.

Dopo il deploy di v53 + riavvio, la sweep one-shot ri-enqueue le operazioni di oggi ancora
`pending` (incluse quelle che avevano fatto 400) → ora entrano → Flussi si popola con oggi.

## Schema ESATTO che SGM scrive (come richiesto)

**`pagamenti_tito`**: `kiosk_id`, `importo_pagato`, `valuta_erogata` (jsonb: {denom_cent:qty}),
`manual_cents` (int = **residuo in cent**, solo righe `fallito`/residuo), `stato`,
`operatore_id`, `sessione_id` (= operation_id), `completato_at`, `created_at`,
`ticket_barcode`, `ticket_valore`, `fornitore`, `motivo_fallimento`,
`identificazione_cliente` (jsonb, opzionale).

**`pagamenti_betting`**: come sopra ma senza `ticket_*`/`fornitore`, con `riferimento_vincita`,
`importo_vincita`, `tipo_gioco` (`snai_betting`|`snai_fastbet`).

**`cambio_operazioni`**: `kiosk_id`, `tipo_cambio`, `importo_ricevuto`, `importo_erogato`,
`valuta_ricevuta`, `valuta_erogata`, `stato` (`completato`|`in_progress`), `sessione_id`,
`completato_at`, `created_at`, `credito_residuo_cent`, `credito_residuo_gestito_at`,
`credito_residuo_gestito_note`, `motivo_fallimento`.

> `manual_cents` = residuo in cent su una riga `fallito`: leggetelo per il resto dovuto, NON
> ri-pagare l'intero importo.

## Note

- **`failed_no_cash_moved` → `cancelled`**: IMPLEMENTATO in v53 come da vostra decisione
  (nessun quinto stato).
- **`in_revisione` blocco re-pay**: già implementato lato vostro, ok.
- **E2E**: appena Flussi si popola, validiamo la lettura join `sessione_id` per i quattro
  `stato`. Reply BLE resta pieno finché non ci dite di ridurlo.
