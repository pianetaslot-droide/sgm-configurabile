# Contratto BLE — SGM Connect ↔ SGM (canonico, versionato)

**Questa è la fonte di verità unica.** Non esistono altre copie autorevoli: le
copie nei singoli repo (es. `SGMConnect/docs/BLE_PROTOCOL_CONTRACT.md`) sono
mirror di sola lettura — se serve un cambiamento, si modifica QUI e poi si
propaga, non il contrario. Vedi `README.md` in questa cartella per il
processo completo.

`contract_version` attuale: **1**. Lato SGM (Windows) espone
`contract_version`/`capabilities` in INFO — vedi matrice §4.

🎉 **Fase 0 — happy path base CONFERMATO su hardware reale (2026-07-25,
Mac-Claude/app):** primo pairing riuscito end-to-end su iPhone fisico —
scan → connect (col timeout aggiunto in A0.1) → discoverServices → hello →
read INFO (`configured=true`, `capabilities=["hello"]` letti correttamente).
Non ancora stress-testato per la ripetibilità 3x richiesta dalla DoD
formale, ma lo sblocco vero e proprio (il "tubo" che non funzionava mai) è
risolto. **Lato SGM: puoi procedere con Fase 1** — vedi §9 per la spec
campi delle azioni ruoli, proposta per il congelamento (A1.1).

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

**Lato SGM: implementato.** Lato app: da leggere/consumare (vedi matrice §4).

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
| INFO (read)       | ✅ fatto (contract_version+capabilities inclusi) | ✅ da estendere per leggere i 2 nuovi campi | 0 |
| pairing mode (advertising) | ✅ scritto E **verificato end-to-end** (primo pairing riuscito 2026-07-25, vedi header) | ✅ scan filtrato + fallback + RSSI sort, funziona | 0 |
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

L'app NON ha un numero di porta cablato. **Lato SGM: implementato** — INFO
include `remote_host`/`remote_port` quando Tailscale/remote ops è
configurato sulla macchina (assenti se non configurato). Lato app: da
leggere.

## 7. Pairing mode (W0.1) — stato dettagliato

Causa radice confermata su hardware reale (log macchina, riavvii multipli):
questo adattatore Bluetooth trasmette advertising per **un solo GATT service
alla volta**. Il service legacy (TITO/Snai, ancora in produzione, non
ritirabile) tiene lo slot per default.

Implementato lato SGM: un "pairing mode" attivabile dal touch macchina
(menu admin → BLE (App) → "Modalità pairing →"), che per una finestra di 5
minuti ferma l'advertising del service legacy e avvia quello del service
SGM Connect (`C09A0000-...`), poi torna automaticamente al legacy. Le
connessioni legacy già aperte non si interrompono (l'advertising e la
connessione GATT sono livelli diversi del protocollo BLE) — solo la
scopribilità di NUOVI dispositivi legacy è sospesa durante la finestra.

**Non ancora verificato end-to-end**: il meccanismo usa le stesse primitive
WinRT (`GattServiceProvider.start_advertising`/`stop_advertising`) che bless
usa internamente, testate singolarmente, ma lo scambio effettivo dello slot
radio (stop legacy → start Connect sullo stesso slot appena liberato) non è
stato ancora osservato con un telefono reale in scan — solo con test
unitari/di importazione. Prossimo passo naturale: W0.4, test congiunto.

## 9. Spec campi ruoli — PROPOSTA lato app per congelamento (A1.1)

Segue il modello confermato da Hu Leo (ruoli sulla macchina, PIN tecnico
solo per il bootstrap del primo supremo, livelli/permessi liberi — vedi
`SGM_PIANO_GENERALE_2026-07-25.md` §3). Questa è la spec **già implementata
e testata (unit test, non su hardware) dal lato app in una precedente
esplorazione Python** — proposta qui per il congelamento, non ancora
vincolante finché non la implementi e non aggiungi le azioni a
`capabilities`. Se qualcosa non funziona per te, proponi una variante, non
serve rispettarla alla lettera.

**Oggetto ruolo (mai include il PIN o il suo hash — solo verso l'app):**
```json
{ "id": "string", "name": "string", "level": 0, "permissions": ["manageRoles", "..."] }
```
Valori validi per `permissions` (stringhe esatte, case-sensitive — devono
combaciare 1:1 con `AppPermission.rawValue` lato Swift):
`manageRoles`, `manageMachineConfig`, `viewMonitoring`, `performCashOps`,
`pairNewMachine`.

**`bootstrap_sala`** — crea la sala su QUESTA macchina + il suo primo
supremo (livello 0, TUTTI i permessi). Sicurezza: richiede il PIN TECNICO
REALE di questa macchina (quello del wizard fisico) nel payload — il
telefono non lo conosce/salva mai, lo digita l'utente fresco ogni volta.
```json
// request payload
{ "technician_pin": "1234", "sala": "Lido", "supremo_pin": "4821" }
// reply payload (ack=true)
{ "role": { "id": "...", "name": "Supremo", "level": 0, "permissions": [tutti e 5] } }
```
Reason possibili se `ack=false`: `technician_pin_not_set_on_machine`,
`invalid_technician_pin`, `sala_required`.

**`login`** — verifica il PIN contro i ruoli della macchina, autentica LA
SESSIONE BLE corrente (non persiste nulla sul telefono). Un nuovo `hello`
azzera l'autenticazione della sessione.
```json
// request payload
{ "pin": "4821" }
// reply payload (ack=true)
{ "role": { "id": "...", "name": "Supremo", "level": 0, "permissions": [...] } }
```
Reason se `ack=false`: `invalid_pin`.

**`list_roles` / `upsert_role` / `remove_role`** — richiedono che la
sessione corrente abbia già fatto `login` con un ruolo che ha il permesso
`manageRoles`; altrimenti `ack=false` reason `not_authorized`.
```json
// list_roles: request payload {} — reply payload
{ "roles": [ { "id": "...", "name": "...", "level": 0, "permissions": [...] }, ... ] }

// upsert_role: request payload
{ "id": "string opzionale (assente = nuovo ruolo)", "name": "Operatore",
  "level": 3, "permissions": ["viewMonitoring"], "pin": "1111 opzionale" }
// "pin" obbligatorio se è un ruolo NUOVO (id assente/non esistente),
// opzionale se esistente (assente = non cambiare il PIN attuale).
// reply payload
{ "role": { "id": "...", "name": "Operatore", "level": 3, "permissions": ["viewMonitoring"] } }

// remove_role: request payload
{ "id": "string" }
// reply payload (lista aggiornata, comodo per l'app)
{ "roles": [ ... ] }
```

## 10. Changelog

- **v1** (2026-07-25): stato iniziale documentato in forma canonica in questa
  cartella condivisa. `capabilities`/`contract_version` proposti ma non
  ancora implementati su nessun lato — è il primo task di Fase 0.
- **v1, aggiornamento 2026-07-25 (SGM/Windows)**: implementati W0.1 (pairing
  mode, non ancora verificato su hardware reale con telefono), W0.2
  (`contract_version`+`capabilities` in INFO, `capabilities=["hello"]`),
  W0.3 (log esplicito su lettura INFO / scritture REQUEST per il test
  congiunto). Nessun cambio alla forma dei messaggi esistenti — solo campi
  aggiunti, `contract_version` resta 1.
- **v1, aggiornamento 2026-07-25 sera (app)**: confermato il primo pairing
  end-to-end riuscito su iPhone fisico — Fase 0 sostanzialmente sbloccata.
  Aggiunta §9, proposta di spec campi per le azioni ruoli (A1.1), per dare
  al lato SGM tutto il necessario per iniziare Fase 1 senza aspettare un
  altro giro di round-trip.
