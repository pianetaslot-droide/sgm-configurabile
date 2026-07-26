# SGM/Windows → App iOS — RISPOSTA: auth token per ORDER_WRITE (2026-07-26)

Confermo il blocco: la macchina rifiuta ORDER_WRITE perché il token scritto sulla char AUTH
`a1000001` non combacia. Il controllo lato SGM è un **confronto stringa esatto** (UTF-8,
trim): il payout è autorizzato solo se `token == ble_auth_token della macchina`.

## 1. Che token si aspetta la macchina

- È un **segreto PER-MACCHINA**, salvato nella config locale (`config.json → ble.auth_token`)
  e applicato a runtime come `BLE_AUTH_TOKEN`. La stessa identica stringa è quella con cui il
  server BLE legacy confronta il valore ricevuto su `a1000001`.
- **NON** è un valore fisso globale, **NON** è per-sala, **NON** è derivato dal `technician_pin`.
- Viene **auto-generato durante il provisioning** (16 caratteri). Perciò il fallback dev
  dell'app (`"vne-sala1-prod-token-CHANGE"`) non combacia mai → "BLE auth required before
  ORDER_WRITE".

## 2. Come deve ottenerlo l'app — la vostra proposta va bene (via set_config)

Approccio scelto: **la macchina è owner del proprio token; l'app lo RICEVE** durante il
provisioning e lo salva in Keychain. Concretamente estendiamo la **reply di `set_config`** per
includere il token nel blocco `effective`:

```json
{ "ack": true, "status": "ok",
  "payload": {
    "applied": ["supabase_url", "..."],
    "effective": {
      "kiosk_id": "…",
      "ble_adv_name": "…",
      "sala": "…",
      "ble_auth_token": "<token per-macchina, 16 char>"   // ← NUOVO
    },
    "restart_required": true
  } }
```

- `set_config` è già gated dal `technician_pin` (BLE-only, tecnico sul posto), quindi restituire
  il token nella reply è sicuro: solo una sessione autenticata dal PIN lo riceve.
- L'app salva `effective.ble_auth_token` in Keychain (`ble_auth_token`) → al payout lo scrive su
  `a1000001` → combacia → ORDER_WRITE autorizzato. **Nessun riavvio necessario** in questo caso,
  perché il token NON cambia: l'app impara semplicemente quello già attivo sulla macchina.
- Opzionale (non serve al flusso standard): accettiamo anche un `ble_auth_token` NEL payload di
  `set_config` se un domani il tecnico volesse IMPOSTARLO; ma cambiare il token richiede il
  riavvio del servizio per avere effetto sul server payout legacy. Consiglio: **lasciate che sia
  la macchina a possederlo**, l'app si limita a leggerlo — così non gestite segreti lato app.

Stato implementazione: la modifica a `set_config` (ritorno del token) è pronta a essere inclusa
nella **prossima build**. Vi confermo il numero build appena impacchettata. Il contratto BLE
resta invariato — cambia solo un campo in più nella reply di `set_config`.

## 3. Sblocco IMMEDIATO del test (transizione, senza nuova build)

Non serve aspettare la build: il token attuale di **questa** macchina di test (sala Lido,
kiosk `1a253e40-…`) esiste già. **Hu Leo ve lo comunica direttamente** — di proposito NON lo
scriviamo qui nel repo per non versionare un segreto. Impostatelo a mano in Keychain
(`ble_auth_token`) su quella macchina e il payout TITO passa subito, con la v27 attuale.

Per le altre macchine: stesso principio — ogni macchina ha il suo token; dopo la build con
`set_config`→token, l'app lo riceve automaticamente in fase di provisioning e non serve più
alcun passaggio manuale.

Il resto del payout (ORDER_WRITE / pay_operation, contratto Legacy) è invariato. Grazie.
