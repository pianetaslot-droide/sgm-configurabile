# Ordine di lavoro — lato App / iOS (Swift)

Data: 2026-07-25 · Attua: `SGM_PIANO_GENERALE_2026-07-25.md`
Workspace: `/Volumes/Dati/DIY APP（ARCHIVIO)/sgm-configurable/SGMConnect/`
Bundle id: `com.leohu.SGMConnect` · iOS 17.0 · ultimo commit `90aa92f`.
Ricorda: `xcodegen generate` dopo ogni modifica a `project.yml`. Testare SOLO
su device fisico (il Simulator non fa BLE reale).

Regola: **non modificare il contratto BLE da solo.** Il contratto è posseduto
dal repo Windows/SGM; se serve un cambiamento, proponilo nel piano, non
scriverlo unilateralmente. La verità su cosa la macchina supporta la leggi da
`INFO.capabilities`, non dai documenti.

I task sono in ordine di priorità. Non passare di fase finché la Definition of
Done non è verde su hardware reale.

---

## FASE 0 — Sbloccare il pairing (priorità massima)

### A0.1 — Timeout su OGNI step di `connect()` (bug del blocco attuale)
È la causa probabile già identificata (§8 del doc app): il primo step di
`MachineConnectionService.connect()` — `central.connect(peripheral,
options: nil)` atteso via `CheckedContinuation` — **non ha timeout**. Se
CoreBluetooth non richiama né `didConnect` né `didFailToConnect`, spinner
infinito.

- Aggiungere un timeout (proposta 10s, come l'handshake `hello`) al connect
  GATT e ad ogni step successivo (discoverServices, readInfo, hello).
- In ogni caso di fallimento/timeout: messaggio d'errore VISIBILE all'utente
  (mai spinner infinito). Distinguere i casi: "connessione non riuscita",
  "servizi non trovati", "INFO non leggibile", "hello scaduto".
- File: `Services/BLE/MachineConnectionService.swift`.

### A0.2 — Scan filtrato per service UUID + fallback
Oggi il fallback mostra ~10 dispositivi anonimi. Con la macchina che (dopo il
lavoro W0.1) pubblicizza il service UUID SGM Connect, filtrare lo scan riduce
drasticamente i candidati.

- Usare `scanForPeripherals(withServices: [SGM_SERVICE_UUID])` come percorso
  primario.
- Mantenere il fallback senza filtro (già in `4be88ff`) per il caso in cui la
  macchina non riesca a pubblicizzare il service UUID — ma marcare quei
  candidati come "da verificare".
- File: `Services/BLE/MachineDiscoveryService.swift`.

### A0.3 — Verifica identità via INFO (aggancio autorevole)
Una macchina è "vera SGM" se e solo se, dopo il connect, la lettura di INFO
restituisce un payload valido. Questo risolve il problema di non sapere quale
dei dispositivi anonimi sia la macchina.

- Nel flusso di pairing: connect → discoverServices → **read INFO** → se INFO
  valida, è la macchina; altrimenti disconnetti e segnala "non è una macchina
  SGM".
- Leggere e memorizzare i nuovi campi `contract_version` e `capabilities`
  (vedi A0.4).
- File: `Services/BLE/MachineConnectionService.swift`,
  `Services/BLE/SGMBLEProtocol.swift` (struct Info da estendere).

### A0.4 — Leggere `contract_version` e `capabilities` da INFO
Estendere la struct `Info` in `SGMBLEProtocol.swift` con i due nuovi campi.
Salvarli sull'oggetto macchina in modo da poterli usare per abilitare/
disabilitare le funzioni (fondamentale dalle fasi successive).

- Se `contract_version` diverge (major) da quella attesa dall'app: mostrare
  un avviso chiaro invece di fallire in modo opaco.

### A0.5 — UX pairing: ordinamento per RSSI
Ordinare/evidenziare i candidati per RSSI (§8 del doc: il più vicino era
`7BF6A2C3` a -52, gli altri a -74/-87), così è ovvio quale tentare per primo.
File: `Views/Machines/PairMachineView.swift`.

### A0.6 — Test congiunto (con il lato SGM)
Sessione su hardware reale sull'happy path esatto del piano §4. Chiudere solo
quando il pairing riesce 3 volte di fila e salva la macchina in `MachineStore`.

**DoD Fase 0:** pairing reale completo end-to-end su iPhone fisico + macchina
reale, ripetibile, con errori sempre visibili.

---

## FASE 1 — Ruoli-sala

> Precondizione: Fase 0 chiusa. Prima di tutto: **definire la spec dei campi**
> delle azioni ruoli (è responsabilità dell'app perché modella la UI) e
> proporla per il congelamento nel contratto. Il lato SGM la implementa solo
> dopo che è congelata.

### A1.1 — Congelare la spec campi ruoli nel contratto
Per `bootstrap_sala`/`login`/`list_roles`/`upsert_role`/`remove_role`: campi
del payload di request e reply, in coerenza con il modello confermato (ruoli
sulla macchina, PIN tecnico solo per bootstrap del primo supremo, livelli non
cablati). Consegnare al lato SGM.

### A1.2 — Abilitare le schermate ruoli solo se in `capabilities`
Le view esistono già (`MachineBootstrapView`, `MachineLoginView`,
`RoleManagementView`) e il codice delle azioni è in `MachineRoleSession.swift`,
ma non è mai stato eseguito contro una macchina reale. Collegarle al gate:
mostrarle SOLO se le azioni corrispondenti sono presenti in
`INFO.capabilities`. Finché la macchina non le espone, restano nascoste/
disabilitate (niente più assunzioni sul fatto che "SGM le abbia già").

### A1.3 — Eseguire il flusso ruoli contro macchina reale
Bootstrap → login → gestione ruoli, verificando che nessun dato di ruolo/PIN
persista sul telefono (in `MachineStore` resta solo id/label/sala/
blePeripheralId/configured).

**DoD Fase 1:** bootstrap+login+upsert+remove eseguiti su macchina reale.

---

## FASE 2 — Operazioni cassa

> Precondizione: Fase 1 chiusa (la cassa richiede ruolo autenticato).

### A2.1 — Contratto azioni cassa (congiunto)
Concordare con il lato SGM le azioni, partendo dalla **lettura livelli** (basso
rischio) prima di deposito/dispensa.

### A2.2 — Sostituire il placeholder con la UI reale
`Views/CashOps/CashOperationsView.swift` è oggi un placeholder deliberato.
Implementare la UI reale abilitandola solo se le azioni cassa sono in
`capabilities`.

**DoD Fase 2:** lettura livelli eseguita contro macchina reale, numeri
identici a quelli mostrati sul touch della macchina.

---

## Promemoria tecnici (dal doc app)
- Simulator NON fa scan/central BLE reale → tutto il test BLE su device fisico.
- `xcrun devicectl ... process launch --console` inaffidabile se l'app è già
  attaccata a Xcode → per log live usare la console di Xcode.
- Log diagnostici già con prefisso `[BLE]` in `MachineDiscoveryService.swift` e
  `MachineConnectionService.swift`.
- Remote ops / Tailscale (`RemoteOpsService.swift`): skeleton, fuori scope
  fino a Fase 2 chiusa.
