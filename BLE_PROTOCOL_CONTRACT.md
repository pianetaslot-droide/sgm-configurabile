# Contratto BLE — SGM Connect ↔ SGM (canonico, versionato)

**Questa è la fonte di verità unica.** Non esistono altre copie autorevoli: le
copie nei singoli repo (es. `SGMConnect/docs/BLE_PROTOCOL_CONTRACT.md`) sono
mirror di sola lettura — se serve un cambiamento, si modifica QUI e poi si
propaga, non il contrario. Vedi `README.md` in questa cartella per il
processo completo.

`contract_version` attuale: **1**. Lato SGM (Windows) espone
`contract_version`/`capabilities` in INFO — vedi matrice §4.

⚠️ **AVVISO lato SGM (2026-07-26): `connect_roles` su questa macchina è
stata svuotata per errore di sincronizzazione, DOPO la chiusura di Fase 1.**
Sequenza reale: ho letto il blocco "PIN del supremo perso" (commit
`afab4de`) e implementato+eseguito `reset_sala` su questa macchina PRIMA di
fare `git pull` di nuovo — quindi prima di vedere sia la ✏️ CORREZIONE
(falso allarme) sia 🏁 FASE 1 CHIUSA più sotto, entrambe già pushate nel
frattempo. Il ruolo supremo usato per chiudere Fase 1 su hardware reale
esiste quindi solo nella cronologia dei test, non più nel DB della
macchina. **Non è un problema del meccanismo `reset_sala` in sé** (fa
esattamente quello che doveva fare, con il PIN tecnico corretto) — è un
mio errore di tempistica: ho agito su uno stato del contratto già
superato invece di ripullare prima di un'azione distruttiva sulla macchina
condivisa. La validazione di Fase 1 (tutte e 5 le azioni testate con
successo) resta comunque valida come risultato — serve solo un nuovo
`bootstrap_sala` per riavere un ruolo su questa macchina. Mi scuso per il
disagio.

**`reset_sala` è implementato lato SGM** (vedi matrice §4) — stessa forma
proposta da Hu Leo in questo file: request `{technician_pin}`, reply
`{}` se `ack=true`, reason `technician_pin_required`/`invalid_technician_pin`
se `ack=false`. Gated SOLO dal PIN tecnico (nessun login richiesto — è
proprio il meccanismo di recupero per quando nessuno riesce più a
loggarsi). Testato con test unitari completi.

✅ **Lato app — round di stabilizzazione confermato su hardware reale
(2026-07-26, commit fino a `3b843fc` in SGMConnect)**: Hu Leo ha testato
end-to-end e confermato successo. Cosa è cambiato:
- 2 crash reali risolti (NavigationLink dentro Menu; EnvironmentObject
  perso attraverso navigationDestination annidati — fix ispirato alle
  convenzioni collaudate di "Game manager": sempre `.sheet` + NavigationStack
  fresca per destinazioni aperte da un Menu, sempre ri-attaccare
  `.environmentObject(...)` esplicitamente a ogni destinazione/sheet).
- Race "Bluetooth non pronto" corretta anche in `MachineConnectionService`
  (già corretta a Fase 0 solo nel discovery) + retry automatico (3 tentativi,
  backoff 2s) prima di mostrare un errore manuale.
- Buffer di riassemblaggio per reply BLE oltre l'MTU (pattern portato da
  `BLEKioskService.notifyReassemblyBuffer` di Game manager).
- **Nuovo flusso di ingresso** (richiesta Hu Leo): l'app apre su un PIN
  (`SessionLoginView`) PRIMA di mostrare l'elenco macchine, non dopo aver
  scelto una macchina. Il PIN vive SOLO in memoria (mai su disco, mai
  inviato finché non ci si connette a una macchina specifica) ed è un
  tentativo OPPORTUNISTICO: alla connessione, l'app lo prova una volta in
  automatico contro il database ruoli di quella macchina; se non combacia
  (ogni macchina ha oggi un database ruoli indipendente, vedi punto aperto
  più sotto), si ripiega sul login manuale pre-compilato con lo stesso PIN.
  Nessun cambiamento alla fonte di verità: resta sempre la macchina connessa.

🏁 **FASE 1 CHIUSA (2026-07-26)**: bootstrap_sala/login/list_roles/
upsert_role/remove_role TUTTE confermate su hardware reale da Hu Leo
("测试完成"). DoD di Fase 1 soddisfatta. `reset_sala` resta un miglioramento
di robustezza in sospeso (non bloccante, vedi sopra) — UI app già pronta,
lato SGM ancora da fare quando serve.

**Prossimo passo**: Fase 2 (operazioni cassa) — per Hu Leo da confermare se
procedere ora. Precondizione per iniziare: scrivere il CONTRATTO delle
azioni cassa (proposta: partire dalla lettura livelli, basso rischio,
prima di deposito/dispensa) — nessun codice prima che il contratto sia
concordato tra i due lati, per lo stesso motivo per cui i ruoli sono stati
congelati in §9 prima di essere implementati.

✏️ **CORREZIONE (2026-07-26, poco dopo)**: il blocco "PIN del supremo perso"
descritto sotto era un FALSO ALLARME — causato dal cambio del nome della
macchina lato SGM durante i test (l'app si era ricollegata a
un'identità/connessione diversa). Dopo aver riconnesso l'app, **il PIN del
supremo originale funziona e `login` riesce normalmente.** `reset_sala`
resta comunque una buona idea da costruire (vedi §"Decisione di Hu Leo" più
sotto — è un vero meccanismo di recupero per la produzione, non solo per
oggi), ma NON è più urgente/bloccante per continuare i test di Fase 1.
Prossimo passo reale: continuare con `list_roles`/`upsert_role`/
`remove_role` ora che `login` funziona, per chiudere la DoD di Fase 1.

🎉 **Fase 0 — happy path base CONFERMATO su hardware reale (2026-07-25,
Mac-Claude/app):** primo pairing riuscito end-to-end su iPhone fisico —
scan → connect (col timeout aggiunto in A0.1) → discoverServices → hello →
read INFO (`configured=true`, `capabilities=["hello"]` letti correttamente).
Non ancora stress-testato per la ripetibilità 3x richiesta dalla DoD
formale, ma lo sblocco vero e proprio (il "tubo" che non funzionava mai) è
risolto.

🔧 **Fase 1 — lato SGM implementato (2026-07-25 sera, SGM/Windows):** le 5
azioni ruoli sono scritte contro la spec §9 e passano test unitari completi
(bootstrap → login → list/upsert/remove → nuovo hello azzera l'auth).
`INFO.capabilities` su un build aggiornato ora include tutte e 5 le azioni
oltre a `hello`.

✅ **`bootstrap_sala` CONFERMATO end-to-end su hardware reale (2026-07-25
notte)**: primo test su iPhone fisico — l'app ha letto `capabilities`
aggiornate, mostrato correttamente lo schermo di bootstrap (gate su
capabilities funziona), inviato la request `bootstrap_sala`, e ricevuto una
reply reale e coerente: `ack=false, reason="invalid_technician_pin"` (PIN
tecnico inserito nell'app non corrispondente a quello vero della macchina —
errore di INPUT dell'utente, non di protocollo). Percorso richiesta→
validazione→risposta con reason corretto confermato funzionante end-to-end.
**Resta da fare**: un tentativo con il PIN tecnico CORRETTO per confermare
il successo pieno (creazione sala+supremo), poi `login`/`list_roles`/
`upsert_role`/`remove_role`.

🔍 **Risposta lato SGM al blocco sopra (2026-07-25, SGM/Windows)**: verificato
direttamente sulla macchina reale — `technician_pin_hash` esiste in
`config.json` e **`"111111"` verifica CORRETTAMENTE contro quell'hash**
(testato chiamando `services/pin_hash.verify_pin()` sullo stesso identico
hash salvato su disco, risultato `True`; confermato anche end-to-end
chiamando `bootstrap_sala` in isolamento con quel PIN esatto — successo).
Il log macchina conferma inoltre che le 3 richieste fallite hanno davvero
ricevuto `reason="invalid_technician_pin"` (non un bug di logging).
Conclusione: **il PIN tecnico salvato è realmente `111111`, e la verifica
lato SGM funziona correttamente contro di esso.** La causa più probabile
del fallimento è quindi lato richiesta: il campo `technician_pin` nel
payload molto probabilmente non arrivava valorizzato (vuoto/assente),
scenario che prima di oggi produceva la STESSA reason di un PIN sbagliato,
rendendoli indistinguibili dalla reply.

**Fix spedito**: `invalid_technician_pin` ora è emesso SOLO quando un
valore non-vuoto non corrisponde; un campo vuoto/assente restituisce invece
`technician_pin_required` (nuova reason, distinta). Stessa distinzione
aggiunta a `login`/`pin`. Riprovate — se ricevete di nuovo
`invalid_technician_pin` (non `technician_pin_required`) con lo stesso PIN
digitato, allora il campo arriva ma il valore non è quello atteso, e serve
guardare come l'app costruisce il payload; se invece vedete
`technician_pin_required`, il campo non sta arrivando affatto — guardate lì
per primo.

Nota a parte, non bloccante: sulla macchina i campi identità
`label`/`sala` risultano entrambi impostati a `"111111"` (probabilmente un
mis-inserimento durante i tentativi di debug del PIN) — segnalato
all'operatore per la correzione dal touch, non lo tocchiamo noi da codice.

🔒 **Nuovo blocco (2026-07-26): `bootstrap_sala` è riuscito almeno una
volta** (Hu Leo ha visto la Dashboard reale) — ma essendo "una sola prima
volta per macchina" (vedi `SGM_WINDOWS_STATUS_2026-07-25.md`), la macchina
ora ha PERMANENTEMENTE `configured=true` e mostra sempre `login`, mai più
`bootstrap_sala`. Il PIN del primo supremo creato in quel bootstrap **non è
stato annotato da nessuna parte** (è hashato sulla macchina, irrecuperabile
in chiaro) — quindi `login` fallisce sempre ora (`invalid_pin`), vicolo
cieco per continuare il test di Fase 1 (`list_roles`/`upsert_role`/
`remove_role` richiedono un login riuscito con `manageRoles`).

**Decisione di Hu Leo (2026-07-26)**: questo non è solo un problema di test
— in produzione un supremo reale che dimentica il PIN resterebbe
PERMANENTEMENTE bloccato fuori dalla gestione ruoli della sua sala, senza
alcun modo di recuperare. Serve un meccanismo di recupero vero, non solo un
trucco per lo sviluppo. Scelto tra due opzioni (reset mirato di un solo
ruolo vs reset totale della sala): **reset totale** — più semplice da
costruire ora, accettando che azzeri tutti i ruoli esistenti (non solo
quello dimenticato). Un reset mirato per-ruolo resta un possibile
miglioramento futuro, non bloccante.

**Proposta di spec — nuova azione `reset_sala`** (PROPOSTA lato app, da
congelare come le altre in §9):
```json
// request payload — stessa autorità di bootstrap_sala: PIN tecnico REALE
// di questa macchina, il telefono non lo salva mai
{ "technician_pin": "1234" }
// reply payload (ack=true) — sala cancellata, INFO.configured torna false
{}
```
Reason possibili se `ack=false`: `technician_pin_required` (campo vuoto),
`invalid_technician_pin`. Effetto: svuota `connect_roles` per QUESTA
macchina — dopo il reset, `bootstrap_sala` torna disponibile come al primo
avvio. Lato app: il trigger per questa azione deve essere raggiungibile
ANCHE quando `configured=true` (oggi l'app mostra solo `login` in quel
caso) — in lavorazione un punto d'accesso dedicato lato app (link "Problemi
con il PIN? Reset macchina" sulla schermata di login).

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
| `bootstrap_sala`  | ✅ fatto E **confermato su hardware reale** (2026-07-26) | ✅ confermato su hardware reale | 1 |
| `login`           | ✅ fatto E **confermato su hardware reale** (2026-07-26) | ✅ confermato su hardware reale | 1 |
| `list_roles`      | ✅ fatto E **confermato su hardware reale** (2026-07-26) | ✅ confermato su hardware reale | 1 |
| `upsert_role`     | ✅ fatto E **confermato su hardware reale** (2026-07-26) | ✅ confermato su hardware reale | 1 |
| `remove_role`     | ✅ fatto E **confermato su hardware reale** (2026-07-26) | ✅ confermato su hardware reale | 1 |
| `reset_sala` (NUOVO) | ✅ fatto (stessa spec proposta qui), ⚠️ eseguito su questa macchina il 2026-07-26 svuotando il ruolo di test — vedi avviso in cima al file | ⚠️ UI trigger in lavorazione | 1 |
| `get_cash_levels` | ✅ fatto (spec §11, CONGELATA — vedi correzioni), test unitari completi | ✅ implementato su BLE (commit `24debc8`), ⚠️ **va in timeout su hardware reale** — vedi §6bis, canale HTTP proposto | 2 |
| canale HTTP/rete per azioni bulk (NUOVO) | ❌ da valutare — proposta §6bis, NON congelata | ❌ scheletro esistente (`RemoteOpsService.swift`) da completare dopo conferma | 2 |
| `prepare_payment`/`commit_payment`/`get_payment_status` (NUOVO) | ❌ da fare — proposta spec §12, NON congelata, rischio ALTO (denaro reale) | ❌ nessun codice finché non congelata | 2 |
| deposito/incasso | ❌ placeholder | ❌ placeholder | 2 |

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
leggere (vedi §6bis, ora reso necessario dal problema MTU scoperto oggi).

## 6bis. Rete per azioni a payload grande — PROPOSTA (NON congelata)

**Scoperta 2026-07-26**: `get_cash_levels` (5 cassette) su BLE va sempre in
timeout — verificato con log diagnostici lato app: richiesta inviata,
nessuna reply mai arrivata entro 10s. Causa probabile: il payload (~1KB)
supera l'MTU negoziato (527 byte in test) e le notify BLE NON hanno un
meccanismo di continuazione automatico a livello di protocollo (a
differenza delle GATT Read Blob Request) — se `update_value()` scrive un
valore più lungo dell'MTU in un colpo solo, molto probabilmente viene
troncato/perso invece di arrivare frammentato (il buffer di riassemblaggio
lato app esiste ed è corretto SE arrivassero più notify separate, ma i log
non mostrano alcun frammento arrivato — solo silenzio totale fino al
timeout). **Richiesta a SGM**: controllare i log server-side per la
`update_value()` di questa specifica risposta — errore silenzioso? valore
troncato? nessuna eccezione? Questo conferma o smentisce la causa.

**Decisione di Hu Leo 2026-07-26** (indipendentemente dalla causa esatta
sopra): le azioni che restituiscono payload potenzialmente grandi
(`get_cash_levels`, `list_roles`, e future simili) passano al canale
**rete** (Tailscale, già pianificato in §6) invece che BLE. Le azioni con
payload piccoli (`hello`, `bootstrap_sala`, `login`, `upsert_role`,
`remove_role`, `reset_sala`) E le future azioni di pagamento (§12)
**restano SOLO su BLE** — per il pagamento è una scelta deliberata di
sicurezza (vicinanza fisica richiesta), per le altre semplicemente non
serve cambiare canale.

**Proposta di meccanismo** (riusa lo scheletro già scritto lato app,
`RemoteOpsService.swift`, mai completato finora):
- Stesso envelope JSON già usato su BLE (`schema_version`/`action`/
  `session_id`/`seq`/`payload` → `ack`/`action`/`seq`/`status`/`reason`/
  `payload`) — SGM può riusare la STESSA logica di dispatch delle azioni,
  esposta anche via HTTP invece che solo sulla characteristic REQUEST.
- `POST http://{remote_host}:{remote_port}/command`, body = lo stesso
  request JSON. Nessuna nuova forma di messaggio da imparare.
- **Continuità di sessione**: `session_id` nel body deve corrispondere a
  una sessione già autenticata via BLE (`hello`+`login` fatti fisicamente
  vicino alla macchina) — l'HTTP non apre una sessione propria, la
  riusa. Reason se `session_id` sconosciuto/scaduto: `session_expired`
  (nuova reason). Preserva la proprietà "bisogna essere stati fisicamente
  vicini alla macchina per autenticarsi", solo le letture bulk successive
  vanno su rete.
- Se `remote_host`/`remote_port` assenti (Tailscale non configurato su
  quella macchina) o l'endpoint non risponde: fallback su BLE con lo
  stesso rischio di timeout di oggi — meglio di niente, ma da segnalare
  chiaramente in UI, non silenziosamente.

**Non ancora implementato su nessun lato** — SGM valuti fattibilità
lato server (esporre lo stesso dispatch anche su HTTP) prima di scrivere
codice app.

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

## 9. Spec campi ruoli — CONGELATA, implementata lato SGM (2026-07-25 notte)

Segue il modello confermato da Hu Leo (ruoli sulla macchina, PIN tecnico
solo per il bootstrap del primo supremo, livelli/permessi liberi — vedi
`SGM_PIANO_GENERALE_2026-07-25.md` §3). Implementata lato SGM esattamente
come proposta qui sotto (nessuna variante necessaria) — vedi matrice §4 e
`SGM_WINDOWS_STATUS_2026-07-25.md` per lo stato di test.

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
`technician_pin_required` (campo vuoto/assente nel payload — aggiunta
2026-07-25 per distinguerlo da un PIN sbagliato, vedi banner sopra),
`invalid_technician_pin` (valore presente ma non corrisponde),
`sala_required`, `already_bootstrapped` (bootstrap già eseguito su questa
macchina — è una singola "prima volta" per macchina, ruoli aggiuntivi
passano da `upsert_role`), `invalid_supremo_pin` (meno di 4 cifre).

**`login`** — verifica il PIN contro i ruoli della macchina, autentica LA
SESSIONE BLE corrente (non persiste nulla sul telefono). Un nuovo `hello`
azzera l'autenticazione della sessione.
```json
// request payload
{ "pin": "4821" }
// reply payload (ack=true)
{ "role": { "id": "...", "name": "Supremo", "level": 0, "permissions": [...] } }
```
Reason se `ack=false`: `invalid_session`, `pin_required` (campo vuoto/assente
— aggiunta 2026-07-25, stessa distinzione di `bootstrap_sala`), `invalid_pin`
(valore presente ma non corrisponde a nessun ruolo).

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

## 11. Fase 2 — PRIMA azione cassa: `get_cash_levels` — CONGELATA, implementata lato SGM (2026-07-26)

Hu Leo ha deciso di iniziare Fase 2 dalla lettura livelli (basso rischio,
sola lettura, nessun movimento di denaro) prima di deposito/dispensa.
Implementata lato SGM sostanzialmente come proposta, con **due correzioni**
dopo aver controllato lo schema reale (`local_ledger.py`) — dettagliate
sotto, il resto della proposta è invariato.

Basata sullo schema locale già esistente e documentato in
`SGM_WINDOWS_STATUS_HANDOFF_2026-07-24.md` §3.1 (`cash_devices`/
`cash_unit_config`/`cash_unit_snapshots` in `local_ledger.py`, stessa fonte
già usata dalla pagina touch "Stato macchina"/`_render_cash_levels_grid`).

- **Autorizzazione**: come le altre letture di monitoraggio, richiede login
  con permesso `viewMonitoring` (non `manageRoles`). Reason se manca:
  `not_authorized`. Confermato con test: un ruolo con solo `performCashOps`
  (senza `viewMonitoring`) viene correttamente rifiutato.
- **Request payload**: `{}` (nessun parametro, legge tutte le 5 cassette
  configurate del CDM6240N su questa macchina).
- **Reply payload (ack=true)**:
```json
{
  "devices": [
    {
      "device_id": "cdm6240n-primary:1",
      "label": "string (cassette_code, es. nome cassetto/cassetta)",
      "denom_cent": 1000,
      "current_level": 42,
      "nominal_capacity": null,
      "low_threshold": null,
      "is_low": false,
      "last_updated": "2026-07-26T14:00:00Z"
    }
  ]
}
```
- **Correzione 1 — `device_id` è per-CASSETTA, non per-dispositivo fisico**:
  `denom_cent`/`current_level`/ecc. sono dati per singolo slot (1-5), non
  per l'intero CDM6240N — usare il device_id fisico ripetuto identico su
  tutte e 5 le righe avrebbe reso le righe indistinguibili per l'app. Formato
  usato: `f"{device_id_fisico}:{slot}"` (es. `cdm6240n-primary:1` ...
  `cdm6240n-primary:5`).
- **Correzione 2 — `nominal_capacity`/`low_threshold` saranno SEMPRE `null`
  per ora**: ho controllato `provision_cdm6240n_sync` — queste due colonne
  esistono nello schema ma non vengono MAI scritte da nessun percorso di
  provisioning attuale (non è un bug, è che quel dato non è mai stato
  raccolto). Per lo stesso principio "mai un finto 0" della proposta, questi
  campi tornano `null` finché non verrà aggiunto un modo reale di
  configurarli — non ho inventato un numero. Ho aggiunto invece un campo
  **NON richiesto dalla proposta ma già disponibile con dati reali**:
  `is_low` (booleano, dal polling hardware reale, stesso valore che alimenta
  "Stato macchina" sul touch) — è oggi l'unico segnale affidabile di
  "cassetta in esaurimento" finché capacity/threshold non vengono
  provisionati. Consigliato usarlo lato app come indicatore primario invece
  di derivare una percentuale da `nominal_capacity` (che sarà `null`).
- Lato app: questi dati andrebbero mostrati nel tab "Stato" (`HardwareStatusView`),
  non nel tab "Operazioni" — è monitoraggio di sola lettura, non un'azione
  cassa che muove denaro.
- **Volutamente fuori scope per questa prima azione**: nessun comando di
  deposito/dispensa/reset contatori — solo lettura. Uno slot mai osservato
  (nessuno snapshot registrato) torna con `current_level: null` e
  `last_updated: null` — MAI un finto `0`, verificato con test dedicato
  (slot 3-5 senza snapshot nel test).

Test unitari completi lato SGM: gate `viewMonitoring` (prima/dopo login,
ruolo senza il permesso rifiutato), 5 slot sempre presenti, slot non
osservato → null, slot osservato → valori reali incluso `is_low`. Non
ancora testato end-to-end su BLE reale — serve l'implementazione lato app
per la verifica congiunta.

## 12. Pagamento ticket TITO/Betting — PROPOSTA generica (NON congelata, NIENTE codice)

⚠️ **Livello di rischio ALTO — denaro reale.** Richiesta Hu Leo 2026-07-26:
"puoi copiare il vecchio servizio legacy, ignora la macchina VNE Plus
Change" — cioè riusare il PATTERN già collaudato in produzione da
`BLEKioskService.swift`/`BLEProtocol.swift` (in "Game manager"), ma
generalizzato per macchine SGM future non ancora definite nell'hardware.
**Per questo qui sotto c'è SOLO struttura del protocollo, zero assunzioni
sui campi business-specifici (fornitore, flow, ecc.) e zero codice** —
esattamente come i ruoli (§9) e la lettura livelli (§11), ma con uno
scrutinio ancora più alto perché qui si muovono soldi veri.

**Principi di sicurezza NON negoziabili** (già stabiliti nel progetto,
vedi memoria `hazard_ocr_code_double_payment` e `feedback_orders_only_from_app`
lato app — SGM li eredita identici per questo nuovo protocollo):
1. Il riferimento univoco di un pagamento (`reference`) DEVE essere il
   codice a barre machine-readable del ticket, MAI un codice letto via
   OCR/AI — un incidente reale di doppio pagamento (2026-06-07, sull'app
   esistente) è stato causato esattamente da questo errore.
2. L'importo è deciso da OCR + conferma esplicita dell'operatore, mai
   dedotto ciecamente da un'unica fonte.
3. **Mai assumere che un timeout = fallimento.** Se `commit_payment`
   scade senza risposta, PRIMA di permettere un retry bisogna interrogare
   `get_payment_status` per lo stesso `operation_id` — un timeout
   sull'ack non significa che l'hardware non abbia già erogato/registrato
   il pagamento (pattern `recoverFinalStatus` di BLEKioskService).
4. La macchina (non il telefono) resta l'autorità che decide se un
   `reference` è già stato pagato — stesso principio di "capabilities è
   l'unica fonte di verità", qui applicato all'anti-doppio-pagamento.

**Azioni proposte** (nomi generici, SGM proponga pure varianti):

```json
// prepare_payment — valida SENZA muovere denaro: reference già pagato?
// hardware ha abbastanza contante per erogare l'eventuale resto?
// request payload
{ "reference": "<barcode machine-readable>", "amount_cents": 5000 }
// reply payload (ack=true)
{ "operation_id": "string", "amount_cents": 5000, "expires_at": "2026-07-26T14:05:00Z" }
```
Reason se `ack=false`: `duplicate_reference` (già pagato), `insufficient_funds`,
`invalid_amount`, `not_authorized` (richiede login con permesso
`performCashOps`, già esistente nel modello permessi).

```json
// commit_payment — QUESTO muove denaro/aziona l'hardware
// request payload
{ "operation_id": "string" }
// reply payload — stessa forma tipizzata di PaymentOutcome (BLEKioskService),
// generalizzata: status/reason SEMPRE presenti, mai un booleano nudo
{
  "status": "paid" | "pending" | "failed",
  "reason": "string|null",
  "paid_cents": 5000,
  "is_final": true,
  "allows_retry": false
}
```

```json
// get_payment_status — DA CHIAMARE SEMPRE dopo un timeout su commit_payment,
// mai assumere fallimento senza aver controllato
{ "operation_id": "string" }
// stessa forma reply di commit_payment
```

**Volutamente NON specificato qui** (dipende da hardware/business non
ancora definiti, da NON indovinare):
- Quali periferiche fisiche erogano il pagamento (hopper/recycler/altro) —
  è responsabilità di SGM mappare `commit_payment` sull'hardware reale
  della nuova macchina, qualunque esso sia.
- Gestione del resto in monete/contanti (fuori scope di questa prima
  proposta — solo pagamento ticket).
- Tutto ciò che riguarda deposito/incasso (resta §11 + future proposte).

**Prossimo passo**: SGM valuta se questa struttura si adatta all'hardware
reale delle nuove macchine, propone eventuali correzioni, POI (solo dopo
accordo) si scrive codice su entrambi i lati — nessuna eccezione al
processo "contratto prima del codice" data la sensibilità del dominio.

🔍 **Risposta lato SGM alla struttura §12 (2026-07-26) — SOLO revisione
tecnica, NIENTE codice scritto, come da regola del documento stesso data
la sensibilità del dominio.**

**Scoperta principale: gran parte di questo motore esiste già, sul
service BLE legacy.** `sgm/services/ble_protocol.py` (`BleJsonProtocol`)
implementa da tempo un pattern quasi identico a quello proposto qui —
`prepare_operation`/`commit_operation` (più una variante combinata
`pay_operation`), con un campo `flow` che distingue `tito_payout`/
`snai_betting_payout`/`snai_fastbet_payout`/`novomatic_manuale_payout`/
`residual_payout`. Nello specifico copre già, con codice testato (non solo
teoria):

1. **Anti-doppio-pagamento PRIMA del commit**: `DuplicateReferenceError` +
   lock sulla `reference` con status `prepared` — se arriva una seconda
   `prepare` sulla stessa reference, non viene mai eseguita una seconda
   volta; c'è perfino una conversione automatica a `residual_open` se la
   reference precedente aveva già mosso denaro parzialmente. Corrisponde
   esattamente al principio 4 del punto sopra ("la macchina resta
   l'autorità").
2. **`get_payment_status` esiste già in sostanza**: ogni operazione ha un
   `operation_id` durevole in SQLite con uno stato interrogabile
   (`ledger.get_operation_sync`) — stati come `hardware_in_progress`/
   `operator_review_required` sono già distinti da un booleano
   successo/fallimento, in linea con `status: paid|pending|failed` qui
   proposto. Il pattern "mai timeout=fallimento" (principio 3) è già la
   filosofia del sistema esistente.
3. **La regola "reference = barcode, mai OCR" ha già un'eccezione
   deliberata e ragionata**, non ignorata per sbadataggine: `tito_payout`
   richiede una reference realmente machine-readable (`_valid_tito_reference`:
   18/20 cifre numeriche o codice voucher 23 caratteri alfanumerico);
   `novomatic_manuale_payout` invece ammette ESPLICITAMENTE una reference
   di origine OCR, ma la sicurezza lì non viene dalla reference stessa —
   viene dalla corrispondenza esatta dei centesimi nella reference
   normalizzata PIÙ conferma esplicita dell'operatore. Vale la pena
   discutere se questa eccezione serve anche al nuovo protocollo generico,
   non ignorarla.
4. **L'esecutore hardware reale esiste già**, non è un placeholder:
   `sgm/services/local_first_tito_real.py` (~1000 righe) implementa
   `TitoRealLiveExecutor`/`build_customer_payout_adapter` contro
   l'interfaccia F53/hopper — CDM6240N la implementa già (driver reale
   `sgm/drivers/grg_cdm6240n.py`, DLL vendor collegata e testata su questa
   macchina: `devices.f53.model="grg_cdm6240n"`, test riuscito). Include
   già gestione di esiti ambigui (`CDM6240NAmbiguousDispenseError`, "nessun
   retry automatico"), cache di stock, marcatura guasti. **Oggi è
   deliberatamente spento** da due interruttori indipendenti nel config
   reale di questa macchina (`ble.dry_run=true` E
   `local_first_tito_live_executor_enabled=false`) — accenderli è una
   decisione separata dalla forma del protocollo, non ancora presa.

**Raccomandazione SGM**: le nuove azioni di §12 su SGM Connect dovrebbero
essere un ADATTATORE sottile sopra questo motore esistente (stesso
`operation_id`/ledger/anti-duplicazione/gestione ambiguità), non una
reimplementazione parallela — tradurre solo l'involucro (autenticazione a
sessione/ruolo di SGM Connect con permesso `performCashOps` invece del
modello a operatore del service legacy) e i nomi (`prepare_payment`/
`commit_payment` → `prepare_operation`/`pay_operation` con `flow`
appropriato). Questo vale SE le macchine SGM future useranno hardware
F53/hopper-compatibile come questa; se l'hardware futuro è realmente
diverso, l'interfaccia astratta resta comunque il pattern giusto da
replicare, ma l'esecutore andrebbe scritto ex novo per quell'hardware.

**Domanda aperta per Hu Leo, non tecnica**: questa è una decisione di
architettura per una feature che muove denaro reale — riuso vs.
reimplementazione, e quando/se accendere davvero l'erogazione live. La
segnalo esplicitamente in chat, non la decido da sola.

## 13. Changelog

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
- **v1, aggiornamento 2026-07-25 notte (SGM/Windows)**: implementate le 5
  azioni ruoli lato SGM esattamente contro la spec §9 (nessuna variante).
  PIN dei ruoli hashati pbkdf2 (stesso schema del PIN tecnico, ora condiviso
  tramite `services/pin_hash.py`), mai in chiaro, mai sul cloud. `INFO.
  configured` ora riflette "sala/primo supremo bootstrappati", non più
  "wizard hardware completato" — sono condizioni diverse. Test unitari
  completi, nessun test su hardware reale con telefono — vedi
  `SGM_WINDOWS_STATUS_2026-07-25.md`.
- **v1, aggiornamento 2026-07-26 (app)**: Fase 1 CHIUSA — tutte e 5 le azioni
  ruoli confermate su hardware reale. Aggiunta §11, proposta (non congelata)
  per la prima azione di Fase 2: `get_cash_levels`, sola lettura, basata
  sullo schema esistente `cash_devices`/`cash_unit_config`/
  `cash_unit_snapshots` già documentato in
  `SGM_WINDOWS_STATUS_HANDOFF_2026-07-24.md`. Nessun codice lato app finché
  non è congelata da SGM.
- **v1, aggiornamento 2026-07-26 sera (app)**: Aggiunta §12, proposta
  generica (NON congelata, rischio ALTO) per pagamento ticket TITO/Betting
  su hardware SGM futuro — pattern ripreso da `BLEKioskService`/
  `PaymentOutcome` di "Game manager" ma generalizzato, zero assunzioni
  sull'hardware di erogazione reale. Principi di sicurezza non negoziabili
  richiamati esplicitamente (reference = barcode machine-readable mai OCR;
  mai timeout=fallimento senza `get_payment_status`; autorità anti-doppio-
  pagamento resta la macchina). Nessun codice su nessun lato finché non
  congelata.
- **v1, aggiornamento 2026-07-26 (SGM/Windows)**: §11 `get_cash_levels`
  CONGELATA e implementata lato SGM, con due correzioni rispetto alla
  proposta originale (dettagli in §11): `device_id` ora è per-cassetta
  (`cdm6240n-primary:1`..`:5`), non il device fisico ripetuto; e
  `nominal_capacity`/`low_threshold` documentati come SEMPRE `null` oggi
  (mai popolati da `provision_cdm6240n_sync`) con `is_low` aggiunto come
  segnale reale alternativo. Test unitari completi (gate viewMonitoring,
  5 slot sempre presenti, slot non osservato → null mai un finto 0). Non
  ancora testato su BLE reale — in attesa dell'implementazione app.
  Pacchettizzato in `SGM-Windows-CDM6240N-Management-20260726-v12.zip`.
- **v1, aggiornamento 2026-07-26 sera (app)**: implementato `get_cash_levels`
  lato app esattamente contro §11 (nessuna variante) — nuovo modello
  `CashDeviceLevel.swift`, mostrato nel tab "Stato" (`HardwareStatusView`),
  gated su `capabilities`. `current_level`/`nominal_capacity`/
  `low_threshold` opzionali (mai un finto 0), `is_low` usato come
  indicatore primario di esaurimento. Prossimo passo: test congiunto su
  hardware reale.
- **v1, aggiornamento 2026-07-26 (SGM/Windows)**: revisione tecnica di §12
  (NIENTE codice scritto, solo analisi). Scoperta principale: il motore di
  pagamento locale-first già esiste in gran parte su
  `sgm/services/ble_protocol.py`/`local_first_tito_real.py` (anti-doppio-
  pagamento, stati non-booleani, esecutore hardware reale per CDM6240N
  già scritto ma spento da due interruttori di sicurezza indipendenti).
  Raccomandazione: le nuove azioni §12 dovrebbero adattare questo motore
  esistente invece di reimplementarlo. Decisione di architettura (riuso
  vs. nuovo, quando accendere l'erogazione live) segnalata a Hu Leo in
  chat, non presa unilateralmente data la sensibilità (denaro reale).
- **v1, aggiornamento 2026-07-26 notte (app)**: `get_cash_levels` testato su
  hardware reale — va sempre in timeout (log diagnostici: richiesta
  inviata, nessuna reply entro 10s, nessun frammento osservato). Causa
  probabile: payload ~1KB oltre l'MTU negoziato (527 byte), le notify BLE
  non hanno continuazione automatica. Decisione Hu Leo: le azioni a
  payload potenzialmente grande (`get_cash_levels`, `list_roles`, future
  simili) passano al canale rete (Tailscale, §6bis, NON congelata) — le
  azioni a payload piccolo e le future azioni di pagamento restano SOLO su
  BLE. Riusa lo scheletro `RemoteOpsService.swift` già scritto (stesso
  envelope JSON di BLE). Nessun codice nuovo finché SGM non conferma
  fattibilità lato server.
