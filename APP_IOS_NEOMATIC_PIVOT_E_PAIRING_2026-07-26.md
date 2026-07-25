# APP iOS — Pivot a "Neomatic sgm" + domande sul pairing BLE (2026-07-26)

> Handoff lato **app iOS (Mac-Claude)** → lato **SGM/Windows**.
> Supersede `SGM_CONNECT_APP_STATUS_2026-07-25.md` come stato dell'app.
> Nessuna modifica al contratto qui dentro: sono **decisioni prese lato app + domande**.

---

## 1. Decisione (cosa è cambiato lato app)

- **SGM Connect (app standalone) è ABBANDONATO.** Non lo sviluppiamo più come
  app a sé: il tentativo è considerato fallito (troppo da ricostruire da zero).
- La nuova app kiosk di produzione è **"Neomatic sgm"**, ottenuta **copiando
  integralmente Game manager e SFOLTENDO** (rimossa tutta la contabilità di
  sala; tenute solo le operazioni kiosk: payout TITO/Betting, deposito iPRO,
  livelli, conferma conteggio, operazioni da risolvere).
- **Bundle id nuovo e indipendente: `com.leohu.NeomaticSGM`** (Game Manager
  resta `com.leohu.SalaScommessa`). Le due app coesistono sul telefono.
- **Ruoli, account, autenticazione, e TUTTO il resto = restano quelli NATIVI di
  Neomatic** (login PIN + ruoli propri + MainTabView, ereditati da Game
  manager). Da SGM Connect è stato copiato **SOLO il protocollo di pairing**.

## 2. Cosa è stato preso da SGM Connect (solo il "protocollo pairing")

Copiati in `Game manager/_SGMConnect/` **6 file, livello protocollo puro**
(niente UI/ruoli/account di SGM Connect — quelli sono stati eliminati):

```
Services/BLE/SGMBLEProtocol.swift        → GATT C09A0000 (REQUEST/REPLY/INFO)
Services/BLE/MachineDiscoveryService.swift
Services/BLE/MachineConnectionService.swift
Services/RemoteOps/SGMRemoteOpsService.swift
Models/PairedMachine.swift
Services/Persistence/MachineStore.swift
```

Questi puntano al service **SGM Connect `C09A0000-1B2C-4A9E-8F3D-53474D434E31`**
(contratto §1). Al momento NON sono ancora agganciati a nessuna UI di Neomatic
(pairing multi-macchina è lavoro futuro).

## 3. Architettura BLE risultante — DUE stack coesistono

Neomatic oggi contiene **due stack BLE distinti**:

| Stack | Service UUID | Origine | Cosa fa | Advertising |
|-------|-------------|---------|---------|-------------|
| **Legacy** | `a1000000-5645-4e45-2d50-6c75732d4348` (4 char: AUTH/WRITE/NOTIFY/INFO) | `BLEKioskService.swift` (da Game manager) | pay_operation TITO/Snai, hello, dashboard summary, livelli — **è quello che l'app usa OGGI nel Pannello Kiosk** | di **default** (slot radio, §7) |
| **SGM Connect** | `C09A0000-…` (3 char: REQUEST/REPLY/INFO) | `_SGMConnect/…` (copiato) | bootstrap_sala, login, ruoli, get_cash_levels, prepare/commit_payment | **solo** in finestra "pairing mode" 5 min (§7) |

Il Pannello Kiosk / payout reale di Neomatic gira **sullo stack Legacy
`a1000000`** (non su C09A0000). Tutto il lavoro nuovo di Fase 0/1/2 del
contratto (ruoli, bootstrap, get_cash_levels, payment) è invece su **C09A0000**.

## 4. Sintomo attuale — supremo su iPhone reale NON si connette

- Utente loggato come **supremo** su **device reale** → nel Pannello Kiosk il
  BLE (stack Legacy `a1000000`) **non arriva a "connesso/pronto"**.
- Osservazioni **lato Pi** (lette in sola lettura via Tailscale, nessuna
  modifica):
  - `systemctl is-active sgm.service` → **active** ✅
  - `hciconfig hci0` → **UP RUNNING** ✅
  - `hcitool con` → **esiste già una connessione ACL cifrata**:
    `E4:B2:FB:A2:32:43 handle 12 state 1 lm CENTRAL AUTH ENCRYPT`
- Note lato app: permesso Bluetooth iOS è un **grant NUOVO** per il nuovo
  bundle id (la stringa d'uso c'è, via `INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription`).
  Escluso (per ora) il conflitto "Game Manager tiene lo slot": l'utente dice di
  no.

Ipotesi aperte (da confermare con voi): (a) lo **slot radio singolo** del §7 —
se la macchina è/è rimasta in un certo stato di advertising, il Legacy
`a1000000` potrebbe non essere scopribile; (b) la connessione ACL già presente
occupa lo slot peripheral; (c) qualcosa nel handshake hello Legacy.

## 5. Domande a SGM/Windows (le decisioni che servono)

**5.1 — Su quale canale deve parlare la Neomatic di PRODUZIONE, e per cosa?**
Oggi abbiamo Legacy (`a1000000`, cash-ops in produzione) + Connect (`C09A0000`,
config/ruoli/cassa nuova). I due **non possono fare advertising insieme** (§7).
Domanda: la macchina di produzione deve esporre **entrambi** (Legacy per
payout TITO/Snai già in campo + Connect per config/ruoli), oppure il piano è
**migrare le cash-ops su C09A0000** e ritirare il Legacy? Come le facciamo
convivere su una singola radio?

**5.2 — Nuovo setup di pairing Bluetooth (priorità n.1 per Hu Leo).**
Confermate il flusso che Neomatic deve guidare per il primo aggancio:
- l'operatore va sul **touch macchina → menu admin → BLE (App) → "Modalità
  pairing →"**, si apre la finestra 5 min in cui la macchina fa advertising di
  `C09A0000`;
- l'app scansiona, connette, `discoverServices`, `hello`, legge INFO
  (`configured`, `capabilities`).

Domande concrete:
- Neomatic deve **mostrare istruzioni all'operatore** ("attiva pairing mode
  sulla macchina") e gestire il timeout dei 5 min? Serve un feedback
  macchina→app che dica "pairing window attiva / scaduta"?
- Una volta appaiata, la connessione operativa quotidiana è ancora su
  `C09A0000` (che però non fa advertising fuori dalla finestra) o si torna al
  Legacy? Cioè: **dopo il pairing iniziale, come si riconnette l'app ogni
  giorno** se lo slot di default è il Legacy?
- C'è **bonding/whitelist** lato macchina? Se sì, come deve comportarsi un
  nuovo bundle id? (il nuovo app è un'app diversa ma stessa identità BT del
  telefono).

**5.3 — Perché la connessione Legacy `a1000000` non riesce ORA?**
È la causa-radice §7 (slot singolo, magari la macchina è rimasta in pairing
mode e ha tolto l'advertising Legacy)? Oppure la connessione ACL cifrata già
presente (`E4:B2:FB:A2:32:43`) occupa lo slot peripheral e impedisce una
seconda connessione? Potete dirci **cos'è `E4:B2:FB:A2:32:43`** dai log
macchina e se possiamo/dobbiamo liberarlo?

**5.4 — INFO leggibile senza auth (§3): vale anche sul Legacy?**
Sul Connect INFO è leggibile senza sessione. Sul Legacy `a1000000` l'app ha una
char INFO (`a1000004`): riporta gli stessi campi `configured`/`contract_version`/
`capabilities`? Ci serve per capire lo stato macchina prima di autenticare.

## 6. Riferimenti app-side (per rispondere con precisione)

- Progetto: `Progetto sgm configurabile/Neomatic sgm.xcodeproj`, sorgenti in
  `Game manager/` (stesso layout di Game manager), bundle `com.leohu.NeomaticSGM`.
- Legacy: `Game manager/Services/BLEKioskService.swift`
  (service `a1000000-…`, char `a1000001..a1000004`, scan `VNE-*`).
- Connect (copiato): `Game manager/_SGMConnect/Services/BLE/SGMBLEProtocol.swift`
  (service `C09A0000-…`, char `C09A0001..C09A0003`).
- North-star architettura (confermato Hu Leo): SGM **locale** (BLE on-site +
  Tailscale remoto) = verità operativa/cassa; **Supabase = solo server di
  sync/backup di riserva** (non nel percorso cassa).

---

**Riassunto per voi in una riga:** abbiamo buttato l'app SGM Connect e rifatto
la kiosk sfoltendo Game manager (`Neomatic sgm`, bundle nuovo); da SGM Connect
teniamo **solo il protocollo pairing C09A0000**; l'app di tutti i giorni oggi
gira sul BLE **Legacy `a1000000`** e **non si connette** — diteci **come deve
appaiarsi/connettersi la nuova app** (setup pairing) e **come far convivere
Legacy + Connect** su una radio sola.
