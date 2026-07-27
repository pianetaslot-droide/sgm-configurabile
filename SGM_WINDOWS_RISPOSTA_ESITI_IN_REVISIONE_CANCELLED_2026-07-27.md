# SGM/Windows → app iOS — esiti `in_revisione` + `cancelled` IMPLEMENTATI (v52) + risposte alle 4 domande (2026-07-27)

Ricevute le tre CONFERME (Hu Leo). Implementato in **v52** e rispondo punto per punto.

## Fatto in v52 (mirror Supabase)

Nel builder del mirror (`local_ledger_sync._legacy_payment_row_from_snapshot`):

- **`in_revisione`** — mappato dall'INTERO cluster "non ri-pagare, verifica umana":
  `operator_review_required` + `ambiguous_requires_count` + `recovery_check_required`.
  Così un esito ambiguo o in recovery **non può mai sembrare "non pagato"** all'app e
  innescare un doppio pagamento.
  - `stato = "in_revisione"`
  - `manual_cents = 0` **di proposito**: il residuo è IGNOTO mentre è in revisione; non
    esponiamo un resto "pagabile" che potrebbe farvi partire un re-pay parziale.
  - `motivo_fallimento = "local_first_operator_review:<status>"`
- **`cancelled`** — `stato = "cancelled"`, `manual_cents = 0`,
  `motivo_fallimento = "local_first_cancelled_no_cash_moved"`.
- **Backfill esteso**: la sweep one-shot al primo toggle-ON ora include anche
  `in_revisione` / `cancelled` (prima solo `completed*` / `residual*`), così le operazioni
  di OGGI già chiuse in questi stati arrivano comunque a Supabase.

Dedup/upsert: le righe non-`completato` deduplicano su `sessione_id` e vengono
**aggiornate in place** — una transizione (es. `in_revisione` → `cancelled`) aggiorna la
stessa riga. La transizione → `completato` inserisce la riga `completato` (biglietto pagato:
il blocco re-pay resta corretto).

## Risposte alle 4 domande

**1. Valori ESATTI di `stato`** — confermo, mappo senza ambiguità:

| tabella | valori `stato` prodotti da SGM |
|---|---|
| `pagamenti_tito` / `pagamenti_betting` | `completato` · `fallito` · `in_revisione` · `cancelled` |
| `cambio_operazioni` | `completato` · `in_progress` (residuo aperto) |

> Nota: `failed_no_cash_moved` (fallimento pulito, zero contante, ri-pagabile) al momento
> **NON è mirrorato** — l'app lo vede solo dal reply BLE. Ditemi se lo volete come
> `fallito` (con `manual_cents=0`) o come `cancelled`: lo aggiungo nel prossimo giro.

**2. `sessione_id`** — SÌ. SGM scrive `sessione_id = operation_id` **esatto** inviato nel
`pay_operation`, su tutte e tre le tabelle (`pagamenti_tito`, `pagamenti_betting`,
`cambio_operazioni`). È la vostra join key. Il nome colonna è `sessione_id`.

**3. Join TITO/betting** — consigliamo **`sessione_id`**: è 1:1 con l'`operation_id` BLE e
uniforme con `cambio_operazioni`. `ticket_barcode` / `riferimento_vincita` ci sono
comunque, ma una reference può ripetersi tra tentativi/riletture; `sessione_id` è la chiave
univoca per operazione.

**4. Backfill** — SÌ, retroattivo. Al **primo toggle-ON** la sweep one-shot ri-enqueue le
operazioni ancora `pending` (incluse quelle di OGGI) negli stati mirrorabili
`completed* / residual* / in_revisione / cancelled`. È idempotente (salta le operazioni che
hanno già una riga outbox attiva), quindi le ~63 `pending` di oggi finiscono in Flussi senza
duplicati.

## Semantica cash-safety per la mappatura lato app

- `completato` = pagato, chiuso.
- `fallito` = residuo aperto, contante **PARZIALE** erogato → leggete `manual_cents` per il
  resto dovuto, **non** ri-pagare l'intero importo.
- `in_revisione` = esito **INCERTO** / conteggio umano in corso → **BLOCCATE il re-pay**;
  `manual_cents = 0` (residuo ignoto, non è un resto pagabile).
- `cancelled` = chiuso, **nessun contante mosso**, biglietto ri-pagabile.

## Note operative

- Il toggle "esito su Supabase" che **"si richiudeva da solo"** è risolto in v52: era un
  campo non persistito nello schema config; ora è un campo reale + bridge al runtime, quindi
  si attiva/disattiva **live** senza riavvio.
- Il **reply BLE resta pieno** finché non ci dite di ridurlo ad ack minimale (come da vostra
  richiesta: "ve lo diciamo noi quando siamo pronti").

## Prossimo passo E2E

Al vostro OK: un payout reale con toggle ON → verifichiamo che l'app legga l'esito da
Supabase (join `sessione_id`) in parallelo al reply BLE, per i quattro `stato`.
