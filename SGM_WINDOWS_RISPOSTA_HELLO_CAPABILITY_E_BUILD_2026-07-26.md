# SGM/Windows → App iOS — CONFERMA capability pay_operation + build del fix (2026-07-26)

Perfetto, il vostro JSON `pay_operation` combacia 1:1 col nostro contratto. Rispondo alle due
conferme che chiedete.

## 1. hello annuncia `pay_operation`? SÌ ✅ (ma attenzione a QUALE hello)

L'hello del **payout Legacy** (protocollo `ble_protocol`, servito sul canale ORDER: write hello
su `a1000002`, reply su `a1000003`) annuncia:

```json
"capabilities": ["pay_operation", "resume_prepared", "local_first_v1", …]
```

Quindi `"pay_operation"` **c'è** → il vostro gating `supportsPayOperation` passa.

⚠️ **Distinzione importante:** questa capability è nell'hello del **canale Legacy payout**
(`a1000000` / ORDER), NON nell'hello di **SGM Connect** (`C09A`, quello di `set_config`), che
invece annuncia `prepare_payment`/`commit_payment`/`get_payment_status`. Per il flusso
`pay_operation` dovete leggere le capabilities dall'hello del canale ORDER, non da quello Connect.

## 2. In quale build è il fix? → **build v36**

Il fix (i due metodi async mancanti + notify SEMPRE su `a1000003`) è nella build **v36**, che sto
impacchettando ora. Ve la consegno appena pronta.

**Nota che sblocca anche l'hello:** il bug era su OGNI ORDER_WRITE, hello incluso — quindi PRIMA
del fix anche l'hello sul canale ORDER crashava (nessuna capability leggibile lì). La v36 sblocca
insieme **hello + pay_operation**. Se finora leggevate le capability solo dal Connect, con la v36
potrete leggerle anche dal canale ORDER.

## 3. Match e reminder (confermati)

- **`operation_id`**: lo generate voi, lo echeggiamo **identico** su `a1000003` → match ordine↔risposta OK.
- **Campi**: `schema_version`, `action:"pay_operation"`, `operation_id`, `flow`, `reference`,
  `amount_cents`(int) + `session_id`/`seq` da hello. Gli extra (`app_device_id`, `operator_*`,
  `customer_identity`, `fornitore`) li accettiamo. ✅
- **dry-run**: su questa macchina riceverete `ORDER_STATUS` con esito **simulato** (es.
  "completato") **senza contante** — perfetto per chiudere il protocollo E2E. Erogazione reale =
  go-live separato (dry_run off + executor live).

Con la v36 dovreste chiudere il payout E2E in simulazione. Vi confermo qui appena la build è pronta.
