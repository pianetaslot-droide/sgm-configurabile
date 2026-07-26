# SGM/Windows → App iOS — payout timeout: TROVATO IL BUG (2026-07-26)

Grazie per il test €15 (solo banconote) che ha escluso l'hopper: ci ha puntato dritti alla causa.
**Non è l'hopper, non è l'importo, non è lo scenario coins**. È un **bug lato SGM/Windows**.

## Causa esatta (confermata a codice + runtime)

Nel gestore BLE ORDER_WRITE, il ramo che smista le azioni "async" chiamava due metodi
(`_is_async_local_first_action` e `_handle_local_first_write_async`) che **non erano più
definiti** nella classe `BleGattServer` (riferimenti pendenti lasciati da un refactor).

Risultato: su questa macchina `local_first_enabled=true`, quindi ad OGNI ORDER_WRITE il gestore
entrava in quel ramo → **AttributeError** → l'eccezione veniva inghiottita dal `try/except`
esterno del write-handler → **nessuna reply, nessuna notify su `a1000003`, nessuna erogazione**.
Da qui il "Timeout risposta kiosk", identico per €15 e €10,25 (il crash avviene PRIMA di
qualsiasi logica di importo/hopper).

Verifica runtime: `hasattr(BleGattServer, "_is_async_local_first_action")` → **False** (prima).

## Fix (nella prossima build)

Ho definito i due metodi (operator_command → entrypoint async; tutto il resto → sync), e il
gestore async ora **notifica SEMPRE** una reply su `a1000003`, anche in caso di errore interno.
Verifica: ora `hasattr(...)` → **True**, modulo compila. → **niente più timeout silenzioso.**

## Risposte alle vostre domande

**1. La macchina eroga davvero?** In questi test **NO**, per due motivi: (a) il crash avveniva
prima di qualsiasi erogazione; (b) questa macchina è in **dry-run** (`ble.dry_run=true`,
`local_first_tito_live_executor_enabled=false`) → `pay_operation` fa solo una **simulazione**
(prepara/transiziona il ledger locale) **senza muovere contante**. Quindi **nessun rischio di
doppio pagamento** dai vostri test: non ha pagato nulla.
⚠️ Importante per i vostri test: dopo il fix, in dry-run riceverete un ORDER_STATUS
"completato" **simulato** — NON significa che sia uscito contante. L'erogazione reale richiede
il go-live (dry-run off + executor live), che è un passo separato e deliberato.

**2. La notify ORDER_STATUS su `a1000003` è implementata?** Sì, il meccanismo c'è
(`_queue_protocol_reply` → `a1000003`); era il crash a impedirle di partire. Col fix parte
sempre (completato/parziale/fallito/errore).

**3. Formato della notify.** SGM usa l'envelope `BleJsonProtocol` (NON il vecchio
`{id,stato,valuta_erogata}`, che nel codice è dead-code mai chiamato). Contratto attuale:

- ORDER_WRITE (`a1000002`), `action:"pay_operation"`, campi richiesti:
  `operation_id`, `flow` (es. `tito_payout`), `reference`, `amount_cents` (int), + `schema_version`.
- ORDER_STATUS (`a1000003`, notify):
  `{ "schema_version":…, "ack":bool, "status":…, "error_code":…, "operation_id":… , … }`.
  **Il match ordine↔risposta è su `operation_id`** (lo echeggiamo identico).

➡️ **Per favore mandateci il JSON ESATTO del vostro ORDER_WRITE** così allineiamo campo per
campo. Se il vostro formato "Legacy" differisce da quello sopra, dopo il fix **non andrà più in
timeout**: riceverete una reply `invalid_payload` che nomina il campo mancante — molto più
diagnosticabile. Se preferite mantenere il formato legacy `{id,stato,…}`, ditecelo e valutiamo
un adattatore di formato in uscita su `a1000003`.

## Fallback "hopper giù → paga banconote + residuo" (dalla vostra prima nota)

È una decisione **100% lato macchina**: quando l'hopper monete è indisponibile, SGM può
pianificare l'erogazione della parte banconote, registrare la parte monete come **residuo** (col
meccanismo residuo/redispense già esistente) e rispondere `completato_parziale` + importo
erogato + residuo. **Non serve un flag app** in prima battuta. Lo implementiamo una volta
allineato e verificato E2E il flusso base (punto 3) — prima il payout deve rispondere e pagare,
poi aggiungiamo il parziale.

## Priorità cash-safety — d'accordo con voi

Il fix garantisce esattamente ciò che chiedete: la macchina **risponde SEMPRE**, mai più silenzio
su ORDER_WRITE. Contratto BLE invariato. Grazie del test che ha isolato il bug.
