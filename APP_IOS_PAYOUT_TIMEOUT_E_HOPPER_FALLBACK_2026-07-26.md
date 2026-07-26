# App iOS → SGM/Windows — payout: timeout risposta + fallback hopper giù (2026-07-26)

Il token payout funziona (grazie): l'AUTH passa, ORDER_WRITE viene accettato. Ma ora, su un
ticket TITO da **€10,25** verso la macchina SGM/Windows, l'app riceve:

> **"Timeout risposta kiosk"** (nessuna reply/notify di stato ordine entro il timeout)

Contesto: la home macchina mostra **"Hopper monete non disponibile"**. €10,25 = €10 (banconota
F53) + €0,25 (monete hopper). Sospetto: hopper giù → la macchina non può erogare i €0,25 → si
blocca senza rispondere → timeout lato app.

## Domanda (diagnosi)
1. Il timeout è perché l'hopper è indisponibile (la macchina non completa i €0,25 e non manda
   ORDER_STATUS)? Oppure la notify di stato ordine (`a1000003`) semplicemente non viene inviata
   in questo scenario?

## Richiesta (Hu Leo): fallback "hopper giù → paga le banconote + residuo"
Quando l'**hopper monete è indisponibile**, la macchina dovrebbe fare un **payout PARZIALE**:
- erogare la **parte in banconote** (l'importo in euro interi, es. €10 su €10,25);
- registrare la **parte in monete come RESIDUO** (€0,25) col meccanismo residuo/redispense già
  esistente lato SGM;
- **rispondere con ORDER_STATUS** (es. `completato_parziale` + importo erogato + residuo), NON
  restare in timeout.

Domande operative:
1. È una decisione 100% lato macchina (SGM pianifica l'erogazione + residuo), o serve che l'app
   invii un **flag** nell'ordine (es. `allow_partial: true` / `notes_only_if_no_hopper`)? Se
   serve un flag, ditemi il nome/posizione nel payload ORDER_WRITE e lo aggiungiamo.
2. Che `stato`/campi tornate nella reply per un parziale (così l'app mostra "pagato €10, residuo
   €0,25" e lo registra correttamente)?

NB cash-safety: se l'app va in timeout ma la macchina HA erogato, c'è rischio doppio pagamento al
retry. Preferiamo che la macchina risponda SEMPRE (completato/parziale/fallito) così l'app non
indovina. Contratto ORDER_WRITE invariato a parte l'eventuale flag. Grazie.
