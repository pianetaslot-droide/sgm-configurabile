# SGM/Windows → app iOS — schema Supabase da AUTO-CREARE al factory setup (col vostro PAT) (2026-07-27)

Requisito (Hu Leo): NIENTE più `ALTER TABLE` a mano per macchina. Al **factory setup** tutte le
tabelle/colonne che SGM scrive devono già esistere. Voi avete un **Supabase PAT** che può
creare tabelle/colonne → fate voi il provisioning; SGM vi fornisce il **contratto schema** esatto.

Motivo urgente: proprio queste mancanze hanno rotto cose reali oggi —
`pagamenti_tito`/`pagamenti_betting` senza `manual_cents`/`fornitore`/`identificazione_cliente`
→ Flussi vuoto; `kiosk_livelli_cash` senza `count_verified` → tabella livelli VUOTA (0 righe) →
auto-pay residuo vedeva stock 0. Sono errori PostgREST `42703 / PGRST204`.

## Tabelle che SGM SCRIVE (insert/update/upsert)

`pagamenti_tito` · `pagamenti_betting` · `cambio_operazioni` · `kiosk_livelli_cash` ·
`kiosk_livelli_movimenti` · `kiosk_hardware_state` · `kiosk_dispositivi` · `kiosk_eventi` ·
`kiosk_comandi` (stato) · `ordini_payout_tito` · `ordini_payout_betting` ·
`kiosk_inventario_cash` · `depositi_incasso_turno` · `turni` · `chiusure_contabilita` /
`vne_chiusure_contabilita` · `app_users`.

## Colonne ESATTE per le tabelle cash/reporting (le critiche)

**`pagamenti_tito`**: `kiosk_id`, `importo_pagato`, `valuta_erogata`(jsonb), **`manual_cents`**(int),
`stato`(text), `operatore_id`, `sessione_id`, `completato_at`, `created_at`, `ticket_barcode`,
`ticket_valore`, **`fornitore`**(text), `motivo_fallimento`, **`identificazione_cliente`**(jsonb).

**`pagamenti_betting`**: come tito ma senza `ticket_*`/`fornitore`; con `riferimento_vincita`,
`importo_vincita`, `tipo_gioco`, e **`manual_cents`**(int).

**`cambio_operazioni`**: `kiosk_id`, `tipo_cambio`, `importo_ricevuto`, `importo_erogato`,
`valuta_ricevuta`(jsonb), `valuta_erogata`(jsonb), `stato`, `sessione_id`, `completato_at`,
`created_at`, `credito_residuo_cent`, `credito_residuo_gestito_at`,
`credito_residuo_gestito_note`, `motivo_fallimento`.

**`kiosk_livelli_cash`**: `kiosk_id`, `tipo`, `unita`, `denom_cent`, `livello_attuale`,
`livello_minimo`, `livello_massimo`, `enabled`, `metadata`(jsonb), **`count_verified`**(bool),
`updated_at`.

**`kiosk_dispositivi`**: … + **`config_json`**(jsonb) (mancava → self-info fallito).

**`kiosk_f53_attempts`**: esiste ma **RLS blocca l'insert** (`42501 new row violates row-level
security policy`) → serve una policy che permetta l'insert col kiosk anon key.

## Colonne/policy DRIFT provate mancanti OGGI (da garantire subito)

| tabella | manca |
|---|---|
| `pagamenti_tito` | `manual_cents`, `fornitore`, `identificazione_cliente` |
| `pagamenti_betting` | `manual_cents` |
| `kiosk_livelli_cash` | `count_verified` |
| `kiosk_dispositivi` | `config_json` |
| `kiosk_f53_attempts` | RLS insert policy (non una colonna) |

## Proposta di "integrazione factory setup"

SGM è la fonte di verità di COSA scrive. Proponiamo:
1. SGM pubblica in repo un file **idempotente** `supabase_schema.sql`
   (`CREATE TABLE IF NOT EXISTS …` + `ALTER TABLE … ADD COLUMN IF NOT EXISTS …` + policy RLS
   per `kiosk_f53_attempts`) che copre TUTTE le tabelle/colonne sopra.
2. Il vostro provisioning col **PAT** lo applica una volta al factory setup di ogni progetto/sala
   → zero SQL a mano, idempotente (ri-eseguibile senza danni).
3. In parallelo SGM rende **tolleranti** le proprie scritture (droppa colonna assente e riscrive)
   così un drift futuro non blocca mai il contante — già fatto per il mirror pagamenti (v53);
   estenderemo a livelli/hardware.

**Domande**: (a) ok a consumare un `supabase_schema.sql` idempotente dal repo col vostro PAT?
(b) volete i tipi colonna esatti per TUTTE le tabelle (ve li estraiamo dal codice) o bastano le
critiche sopra + voi derivate il resto? (c) confermate la policy RLS insert per
`kiosk_f53_attempts`. Appena confermate, generiamo `supabase_schema.sql` completo.
