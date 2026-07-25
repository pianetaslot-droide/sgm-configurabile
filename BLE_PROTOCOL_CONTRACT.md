# Contratto BLE — SGM Connect ↔ SGM (canonico, versionato)

**Questa è la fonte di verità unica.** Non esistono altre copie autorevoli: le
copie nei singoli repo (es. `SGMConnect/docs/BLE_PROTOCOL_CONTRACT.md`) sono
mirror di sola lettura — se serve un cambiamento, si modifica QUI e poi si
propaga, non il contrario. Vedi `README.md` in questa cartella per il
processo completo.

`contract_version` attuale: **1** (nessuna macchina reale espone ancora
`capabilities` — vedi matrice §4, riga INFO).

---

## 1. GATT

```
Service   C09A0000-1B2C-4A9E-8F3D-53474D434E31   ("SGM Connect")
  Char    C09A0001-...  REQUEST (write, no-response ok anche with-response)
  Char    C09A0002-...  REPLY   (notify)
  Char    C09A0003-...  INFO    (read, SENZA autenticazione)
```

## 2. Envelope

**Request** (app → macchina, su REQUEST):
```json
{
  "schema_version": 1,
  "action": "hello" | "<altra azione>",
  "session_id": null | "<id sessione, dopo il primo hello>",
  "seq": 1,
  "payload": {}
}
```

**Reply** (macchina → app, notify su REPLY):
```json
{
  "ack": true,
  "action": "hello",
  "seq": 1,
  "status": "ok",
  "reason": null,
  "payload": { "session_id": "<nuovo id sessione>" }
}
```
`seq` nella risposta DEVE combaciare con quello della richiesta.

## 3. INFO — payload (leggibile senza connessione autenticata)

**Campo obbligatorio da aggiungere (non ancora implementato su nessun lato,
vedi matrice §4):**

```json
{
  "kiosk_id": "uuid",
  "label": "Sala 1",
  "sala": "Lido",
  "configured": true,
  "contract_version": 1,
  "capabilities": ["hello"]
}
```

- `configured=false` → macchina appena installata, nessun setup fatto →
  l'app propone il bootstrap.
- `contract_version`: intero. Se diverge di major tra app e macchina, l'app
  mostra un avviso invece di fallire in modo opaco.
- `capabilities`: elenco delle azioni che QUESTA macchina, ORA, implementa
  davvero. **È l'unica fonte autorevole** — l'app abilita/disabilita le
  schermate in base a questo campo, mai assumendo dai documenti. Finché
  un'azione non compare qui, l'app la tratta come inesistente anche se il
  codice per chiamarla è già scritto.

## 4. Matrice di stato — azione → lato SGM → lato app → fase

Aggiornare questa tabella ad OGNI modifica del contratto o dell'implementazione.
Regola: `capabilities` in INFO deve sempre riflettere la colonna "Lato SGM".

| Azione            | Lato SGM (Windows)      | Lato App (iOS)          | Fase |
|-------------------|--------------------------|--------------------------|------|
| `hello`           | ✅ fatto                 | ✅ fatto, testato*        | 0    |
| INFO (read)       | ✅ base, ⚠️ da estendere | ✅ da estendere per leggere i 2 nuovi campi | 0 |
| `bootstrap_sala`  | ❌ da fare                | ✅ codice scritto, mai eseguito su macchina reale | 1 |
| `login`           | ❌ da fare                | ✅ codice scritto, mai eseguito | 1 |
| `list_roles`      | ❌ da fare                | ✅ codice scritto, mai eseguito | 1 |
| `upsert_role`     | ❌ da fare                | ✅ codice scritto, mai eseguito | 1 |
| `remove_role`     | ❌ da fare                | ✅ codice scritto, mai eseguito | 1 |
| operazioni cassa  | ❌ placeholder             | ❌ placeholder            | 2    |

`*` "testato" = handshake logico verificato (unit/scripted), NON un pairing
BLE reale end-to-end su hardware — quello è tuttora il blocco di Fase 0.

## 5. Volutamente NON progettato (per ora)

- Qualsiasi comando di movimento contante — solo contratto testuale quando
  verrà disegnato davvero, non abbozzare senza approvazione esplicita.
- Scrittura remota di hardware/porte — le modifiche HARDWARE restano SOLO
  fisiche/BLE on-site; solo le impostazioni CLOUD potranno essere cambiate
  da remoto in futuro.

## 6. Endpoint remoto (Tailscale) — auto-riportato dalla macchina

L'app NON ha un numero di porta cablato. Quando configurato, la macchina
riporterà `remote_host`/`remote_port` (campo ancora da aggiungere a INFO o a
una risposta hello estesa, non ancora implementato su nessun lato).

## 7. Changelog

- **v1** (2026-07-25): stato iniziale documentato in forma canonica in questa
  cartella condivisa. `capabilities`/`contract_version` proposti ma non
  ancora implementati su nessun lato — è il primo task di Fase 0.
