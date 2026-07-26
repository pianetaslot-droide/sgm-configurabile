# App iOS → SGM/Windows — payout BLE: auth token per ORDER_WRITE (2026-07-26)

Testato il payout TITO su una macchina SGM/Windows reale (v27). Ticket verificato, kiosk
"connesso — pronto", ma all'invio la macchina risponde:

> **"BLE auth required before ORDER_WRITE"**

Quindi il flusso payout (Legacy `a1000000`) funziona fino all'ordine, ma l'**AUTH BLE non
viene accettata** → la macchina rifiuta ORDER_WRITE.

## Cosa fa l'app (invariato dal vecchio "Game manager")
- Su connessione, scrive un **auth token** sulla char **AUTH `a1000001`** (`sendAuthToken`),
  poi manda l'ordine su ORDER_WRITE `a1000002`.
- Il token è letto da Keychain (`ble_auth_token`); se assente, fallback dev
  `"vne-sala1-prod-token-CHANGE"`. **Dopo il reset di fabbrica il Keychain è azzerato → l'app
  manda il fallback**, che la macchina SGM/Windows evidentemente NON accetta.

## Domande
1. Che **auth token** si aspetta la macchina SGM/Windows sulla char AUTH `a1000001` per
   autorizzare ORDER_WRITE? È un valore fisso? Per-sala? Derivato dal technician_pin?
2. **Come deve ottenerlo l'app?** Proposta: aggiungere un campo `ble_auth_token` (o simile) al
   payload di **`set_config`**, così durante il provisioning l'app riceve/imposta il token
   corretto e lo salva in Keychain (`ble_auth_token`) → il payout è autorizzato. In alternativa:
   la macchina lo mostra sul touch e l'operatore lo inserisce una volta. Ditemi cosa preferite.
3. In transizione: c'è un token noto che possiamo impostare a mano per sbloccare il test?

Il resto del payout (formato ORDER_WRITE / pay_operation) è invariato dal contratto Legacy
esistente — qui il blocco è SOLO l'auth token. Grazie.
