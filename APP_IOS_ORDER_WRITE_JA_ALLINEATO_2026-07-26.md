# App iOS → SGM/Windows — il nostro ORDER_WRITE È GIÀ pay_operation (allineato) (2026-07-26)

Ottimo, bug isolato! Rispondo alla richiesta "mandate il JSON esatto del vostro ORDER_WRITE":
**usiamo già il vostro envelope `pay_operation`, non il vecchio `{id,stato}`** (quel formato è
dead-code anche da noi). Nessun adattatore serve.

## JSON esatto che l'app scrive su ORDER_WRITE (`a1000002`)
```json
{
  "schema_version": 1,
  "action": "pay_operation",
  "session_id": "<da hello>",
  "seq": <int>,
  "operation_id": "<id univoco generato dall'app>",
  "flow": "<es. tito_payout | betting_payout>",
  "reference": "<barcode/riferimento ticket>",
  "amount_cents": <int>,
  "app_device_id": "<uuid device>",
  "operator_id": "<uuid>", "operator_name": "<str>", "operator_role": "commesso",
  "customer_identity": { "id": "<opz.>" },   // solo se presente
  "fornitore": "<opz.>"                        // solo se presente
}
```
→ Combacia col vostro contratto: `operation_id`, `flow`, `reference`, `amount_cents`(int),
`schema_version`. **Match ordine↔risposta su `operation_id`**: perfetto, lo generiamo noi e ci
aspettiamo che lo echeggiate identico su `a1000003`.

## Una conferma che ci serve (gating capability)
Lato app il flusso `pay_operation` è **gated dalla capability**: lo usiamo solo se la macchina
annuncia `"pay_operation"` tra le `capabilities` nell'hello (`supportsPayOperation`). Confermateci
che l'hello di SGM/Windows include `"pay_operation"` così l'app instrada su questo flusso (se non
c'è, l'app non manda pay_operation).

## Recepito
- **Fix del crash** (metodi async mancanti → notify sempre): 👍 aspettiamo la build, poi
  ri-testiamo. Ci confermate il numero build?
- **dry-run**: capito — dopo il fix riceveremo `ORDER_STATUS "completato"` **simulato** (nessun
  contante). Va bene per validare il protocollo E2E. L'erogazione reale = go-live separato
  (dry_run off + executor live), lo faremo deliberatamente dopo.
- **Fallback hopper→banconote+residuo**: ok, 100% lato macchina, dopo il flusso base. Nessun flag app.

Grazie — con il vostro fix dovremmo chiudere il payout E2E (in simulazione).
