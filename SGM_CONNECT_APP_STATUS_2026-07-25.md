# SGM Connect (app iOS) — stato del progetto (2026-07-25)

Scritto da Mac-Claude per sincronizzarsi con la Claude che sviluppa il lato SGM
Python/Windows, prima di decidere i prossimi passi. Copre: cos'è, divisione del
lavoro, architettura, cosa è stato testato davvero, i bug trovati/risolti, e il
blocco attuale.

## 1. Cos'è

App iOS NUOVA e INDIPENDENTE (non la "Game manager" esistente) per gestire
genericamente più macchine SGM configurabili future. NON legata a un business
specifico (Betting/VLT) — deve poter trovare e gestire QUALSIASI macchina SGM
Connect nelle vicinanze.

- Workspace: `/Volumes/Dati/DIY APP（ARCHIVIO)/sgm-configurable/SGMConnect/`
- Repo git separato, generato con `xcodegen` da `project.yml` (NON editare
  `.xcodeproj` a mano — rigenerare con `xcodegen generate` dopo ogni modifica
  a `project.yml` o dopo aggiunta/rimozione file).
- Bundle id: `com.leohu.SGMConnect`. Deployment target iOS 17.0.
- Ultimo commit: `90aa92f`.

## 2. Divisione del lavoro (corretta il 2026-07-24)

- **Lato Python/Windows del SGM configurabile**: sviluppato da un'ALTRA
  istanza Claude (non Mac-Claude). Mac-Claude non scrive né pusha più codice
  in quel repo/branch (`sgm-windows` su `pianetaslot-droide/SalaScommessa`).
- **Lato iOS (questo progetto)**: Mac-Claude scrive direttamente Swift +
  compila con xcodebuild.
- **Punto di sincronizzazione tra i due lati**: `docs/BLE_PROTOCOL_CONTRACT.md`
  (mirror-ato in entrambi i repo) — contratto GATT "SGM Connect": 1 service,
  3 characteristics, envelope JSON. Vedi §4.
- Scambio di handoff finora avvenuto via file `.md` su `~/Desktop` (letti a
  vicenda tra le due sessioni Claude tramite l'utente).

## 3. Decisioni architetturali chiave (tutte confermate da Hu Leo, 2026-07-24)

- Scope app: config + monitoraggio + **operazioni cassa** (scelta più ampia
  della raccomandazione iniziale di Mac-Claude).
- **Ruoli-sala vivono SULLA MACCHINA connessa**, non sul telefono, non su
  cloud condiviso. Nessun login globale dell'app — ci si autentica per-
  macchina via BLE (`bootstrap_sala`/`login`/`list_roles`/`upsert_role`/
  `remove_role`). Numero di livelli di ruolo NON cablato: il PIN tecnico
  (della macchina, mai salvato sul telefono) fa solo il bootstrap del primo
  "supremo"; da lì il supremo di quella sala decide quanti livelli/permessi.
- Protocollo pagamento/dispense: SOLO contratto documentale per ora, NIENTE
  codice (placeholder onesto in `CashOperationsView.swift`).
- Config hardware = deve essere fisica/on-site (BLE); config cloud PUÒ
  essere remota (Tailscale, skeleton non ancora verificato).
- Porta HTTP/Tailscale per remote ops = la macchina si auto-riporta, non
  hardcoded in app.
- Multi-tecnico: ogni telefono ha il proprio PIN locale, nessuna sync tra
  tecnici.
- Pairing: scan BLE + selezione da lista (non QR, non inserimento manuale).

## 4. Contratto BLE ("SGM Connect")

```
Service   C09A0000-1B2C-4A9E-8F3D-53474D434E31
  Char    C09A0001-...  REQUEST (write)
  Char    C09A0002-...  REPLY   (notify)
  Char    C09A0003-...  INFO    (read, nessuna autenticazione richiesta)
```

Request: `{schema_version:1, action, session_id, seq, payload}`.
Reply: `{ack, action, seq, status, reason, payload}`.
INFO: `{kiosk_id, label, sala, configured}`.

Azioni implementate lato SGM (secondo l'ultimo handoff ricevuto): `hello`,
`bootstrap_sala`, `login`, `list_roles`, `upsert_role`, `remove_role`.

File Swift che lo implementano:
- `SGMConnect/Services/BLE/SGMBLEProtocol.swift` — costanti UUID + struct
  Request/Reply/Info + `JSONValue` (JSON generico Codable).
- `SGMConnect/Services/BLE/MachineDiscoveryService.swift` — scan (central).
- `SGMConnect/Services/BLE/MachineConnectionService.swift` — connessione +
  invio/ricezione richieste (central).
- `SGMConnect/Services/BLE/MachineRoleSession.swift` — chiama le azioni
  ruoli sopra il layer di connessione.

## 5. Architettura app (flusso di navigazione)

```
SGMConnectApp → RootView → MachineListView (elenco macchine associate)
  → [+] → PairMachineView (scan BLE, associa)
  → tap su una macchina → MachineAuthGateView
      (connette BLE, legge INFO.configured)
      → se non configurata: MachineBootstrapView (PIN tecnico macchina + sala + supremo)
      → se configurata ma non loggato: MachineLoginView (PIN ruolo)
      → se loggato: MachineDashboardView (tab Stato/Operazioni/Impostazioni)
          toolbar: ruolo corrente, "Gestione ruoli" (se permesso manageRoles), "Esci"
```

Persistenza locale (telefono): SOLO l'elenco macchine associate
(`MachineStore`, JSON in Application Support) — id, label, sala, ultimo
`blePeripheralId` noto, stato configured. **Nessun dato di ruolo/PIN persiste
sul telefono** (vive sulla macchina, riletto ogni volta via BLE).

## 6. Cosa è stato VERAMENTE testato (non solo compilato)

- ✅ Compilazione + avvio pulito nel Simulator iOS (iPhone 17) — solo per i
  flussi che NON richiedono BLE reale (liste vuote, navigazione, sheet).
- ✅ Installazione + avvio su iPhone fisico reale ("iPhone di Leo") via
  `xcodebuild -destination "id=<device>"` + `xcrun devicectl device install
  app` (build number: signing automatico "Apple Development", team
  585MY33C3D / account lvsncdihulijun@gmail.com).
- ✅ Su device reale: lo scan BLE ORA funziona (dopo il fix del bug §7.1) e
  trova sia la macchina SGM (probabilmente, vedi §8) sia altri dispositivi
  Bluetooth ordinari nelle vicinanze.
- ❌ **MAI completato un pairing reale end-to-end** (connect → discoverServices
  → hello → readInfo → salvataggio macchina). Questo è il blocco attuale,
  vedi §8.
- ❌ Login/bootstrap ruoli via BLE: implementato e compilato, MAI eseguito
  contro una macchina reale (dipende dal pairing, non ancora riuscito).
- ❌ Operazioni cassa: non implementate (placeholder deliberato).
- ❌ Remote ops (Tailscale): skeleton, mai testato.

## 7. Bug REALI trovati e risolti (solo visibili su device fisico, mai in Simulator)

### 7.1 — Scan mai ritentato dopo il permesso Bluetooth (fix: commit `90aa92f`)
`startScan()` abortiva silenziosamente se `CBCentralManager.state` non era
ancora `.poweredOn` (tipico al primissimo avvio, col dialog di permesso
Bluetooth non ancora confermato dall'utente). Il codice aveva un commento che
diceva "verrà ritentato da `centralManagerDidUpdateState`" ma quella funzione
non richiamava mai lo scan — bug reale, mai eseguito nessun retry.
**Fix**: flag `wantsScanning` + retry vero in `centralManagerDidUpdateState`
quando lo stato diventa `.poweredOn`.

### 7.2 — Fallback per-nome scartava proprio la macchina SGM (fix: stesso commit)
Il fallback discovery (scan senza filtro di service UUID, aggiunto in
risposta a `BLE_DISCOVERY_PROPOSAL_2026-07-24.md` — vedi commit `4be88ff`)
scartava i device SENZA `localName` nell'advertisement, assumendo fossero
"rumore". Ma la macchina SGM (`GattServiceProvider`/WinRT lato Windows) può
comparire proprio SENZA nome nell'advertisement (l'API bless usata lato SGM
espone solo `is_discoverable`/`is_connectable`, nessun campo nome), mentre
altri device BLE reali nelle vicinanze (cuffie, orologi, TV) quasi sempre
advertisano un nome. Risultato osservato: il fallback trovava "tutto tranne"
la macchina cercata. **Fix**: rimosso il filtro per nome — ora TUTTI i
device trovati in fallback vengono mostrati come candidati "da verificare"
(nome fallback: `"Dispositivo Bluetooth (<primi 8 char UUID>)"`).

## 8. BLOCCO ATTUALE (2026-07-25, screenshot da iPhone reale)

Dopo il fix §7.2, lo scan fallback ora mostra ~10 candidati, inclusi diversi
`"Dispositivo Bluetooth (XXXXXXXX)"` senza nome — plausibilmente uno di
questi è la macchina SGM. Il più vicino per RSSI è
`Dispositivo Bluetooth (7BF6A2C3)` a **RSSI -52** (nettamente il segnale più
forte tra i candidati senza nome — gli altri due sono a -87 e -74).

L'utente ha toccato un candidato per associarlo e lo spinner di connessione
resta bloccato, senza mai risolversi né in successo né in un messaggio di
errore visibile.

**Causa probabile identificata (non ancora confermata/risolta)**: in
`MachineConnectionService.connect()`, il primo step — la connessione GATT
vera e propria (`central.connect(peripheral, options: nil)`, attesa via
`CheckedContinuation`) — **non ha NESSUN timeout**. Solo il successivo
handshake `hello` (dentro `send(action:payload:timeout:)`) ha un timeout di
10s. Se CoreBluetooth non richiama mai né `didConnect` né
`didFailToConnect` (scenario plausibile con un device reale/flaky, o se il
peripheral cache-ato dallo scan precedente non è più realmente
raggiungibile/connectable), l'app resta a girare all'infinito senza nessun
segnale d'errore per l'utente.

**Non ancora fatto** (in attesa di decidere il da farsi dopo la sincronizzazione
con l'altra Claude):
- Aggiungere un timeout anche al primo step di `connect()` così l'utente
  vede sempre un errore chiaro invece di uno spinner infinito.
- Verificare CHE il device che si sta cercando di raggiungere sia
  effettivamente la macchina SGM (non c'è modo di saperlo dalla UI attuale
  finché il connect non restituisce un esito).
- Eventualmente ordinare/evidenziare i candidati per RSSI nella UI di
  pairing, per rendere più ovvio quale tentare per primo.

## 9. Limiti noti (non bug, comportamento atteso)

- Simulator iOS NON fa mai scan/central BLE reale (limite Apple
  CoreBluetooth) — tutto il testing BLE deve essere su device fisico.
- `xcrun devicectl device process launch --console` per leggere log live da
  remoto si è bloccato senza output quando l'app girava già attaccata a
  Xcode — non affidabile per ora; per debug live meglio usare la console di
  Xcode direttamente.
- I log diagnostici aggiunti hanno prefisso `[BLE]` in
  `MachineDiscoveryService.swift` e `MachineConnectionService.swift`.

## 10. File principali per orientarsi

```
SGMConnect/
  App/SGMConnectApp.swift
  Models/{PairedMachine,RoleModels,HardwareDeviceStatus}.swift
  Services/BLE/{SGMBLEProtocol,MachineDiscoveryService,MachineConnectionService,MachineRoleSession}.swift
  Services/Persistence/MachineStore.swift
  Services/RemoteOps/RemoteOpsService.swift        (skeleton, non testato)
  Views/Machines/{MachineListView,PairMachineView,MachineAuthGateView,MachineSettingsView}.swift
  Views/Auth/{MachineBootstrapView,MachineLoginView,RoleManagementView}.swift
  Views/Root/{RootView,MachineDashboardView}.swift
  Views/Monitoring/HardwareStatusView.swift
  Views/CashOps/CashOperationsView.swift           (placeholder deliberato)
  docs/{BLE_PROTOCOL_CONTRACT.md,OPEN_DESIGN_QUESTIONS.md}
```
