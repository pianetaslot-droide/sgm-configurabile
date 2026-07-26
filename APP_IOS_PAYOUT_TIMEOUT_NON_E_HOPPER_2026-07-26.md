# App iOS → SGM/Windows — payout timeout NON è l'hopper (2026-07-26)

Aggiornamento a `APP_IOS_PAYOUT_TIMEOUT_E_HOPPER_FALLBACK`: **abbiamo escluso l'hopper.**

Test: ticket TITO da **€15** (importo intero, SOLO banconote, nessuna moneta richiesta) →
**stesso "Timeout risposta kiosk"**. Quindi il timeout NON dipende dall'hopper: la macchina
**non invia la reply/notify di stato ordine** su ORDER_WRITE, a prescindere dall'importo.

## Diagnosi
- AUTH `a1000001`: OK (token combacia).
- ORDER_WRITE `a1000002`: l'app scrive l'ordine.
- ORDER_STATUS `a1000003` (notify): **l'app NON riceve nulla** entro il timeout → "Timeout
  risposta kiosk".

Sembra che sulla macchina SGM/Windows il flusso **ORDER_WRITE → ORDER_STATUS del payout Legacy
`a1000000` non sia implementato/inviato** (mentre AUTH e Connect/set_config funzionano).

## Domande / richieste
1. La macchina SGM/Windows **processa** l'ORDER_WRITE del payout Legacy `a1000000` ed **eroga**?
   Cioè: dopo il nostro invio, la macchina ha davvero dispensato (F53) i €15 e i €10,25 dei test?
   (Ci serve per la cash-safety: se eroga ma non risponde, c'è rischio doppio pagamento al retry.)
2. La macchina invia la **notify ORDER_STATUS su `a1000003`** (pending → completato/fallito) come
   nel contratto Legacy? Se no, è questo il pezzo mancante da implementare.
3. Formato esatto della notify di stato che mandate (o manderete): `stato`, importo erogato,
   eventuale residuo, id ordine — così l'app matcha la risposta all'ordine inviato.

Priorità cash-safety: finché la macchina non risponde SEMPRE, il payout non è sicuro (l'app non
sa se ha pagato). Confermateci se ORDER_STATUS lato Legacy è già attivo o va aggiunto nella
prossima build. Grazie.
