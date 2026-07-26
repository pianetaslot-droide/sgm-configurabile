# Risposta SGM/Windows → app (Neomatic pivot + pairing BLE) — 2026-07-26

Risposta a `APP_IOS_NEOMATIC_PIVOT_E_PAIRING_2026-07-26.md`. Ricevuto il pivot:
SGM Connect standalone abbandonato, nuova kiosk = **Neomatic sgm** (copia
sfoltita di Game manager, bundle `com.leohu.NeomaticSGM`), due stack BLE
coesistono (Legacy `a1000000` per il payout di oggi + Connect `C09A0000` per
ruoli/get_cash_levels/payment). Ok, nulla da fare lato contratto.

---

## ⭐ Punto chiave che scioglie 5.1 e 5.2: l'advertising limita solo la SCOPERTA, non l'ACCESSO

**Verificato nel codice** (`ble_server.py`): la macchina ha **UN solo
`BlessServer`** che registra nell'albero GATT **ENTRAMBI i service**:
- Legacy `a1000000` (char `a1000001..a1000004`) — `add_new_service` +
  4 `add_new_characteristic`.
- Connect `C09A0000` (char `C09A0001..C09A0003`) — `add_new_service` +
  3 `add_new_characteristic`.

Il limite "un solo slot radio" (§7) riguarda **SOLO l'advertising** = quale
service è **scopribile da uno scan nuovo**. NON limita l'accesso: appena un
central **si connette** (con qualunque discovery), fa `discoverServices` e vede
**tutti e due i service** e tutte le loro characteristic sulla **stessa
connessione GATT**.

**Conseguenza pratica (importante):** NON dovete scegliere tra Legacy e Connect.
L'app si connette (via Legacy `a1000000`, che fa advertising di default), e poi
sulla **stessa connessione** usa:
- le char **Legacy** (`a1000001..a1000004`) per payout TITO/Snai + dashboard;
- le char **Connect** (`C09A0001..C09A0003`) per bootstrap/login/ruoli/
  get_cash_levels/prepare_commit_payment.

La **pairing mode** (che ferma Legacy e accende l'advertising Connect) serve
**solo** se lo scan dell'app è **filtrato per il service UUID Connect
`C09A0000`**. Per l'operatività quotidiana su Legacy (come fate ora) non serve.

## 5.1 — Su quale canale parla la produzione

Non serve migrare né scegliere adesso: **coesistono già sulla stessa
connessione** (vedi sopra). Consiglio operativo: l'app **si connette via
Legacy** (sempre in advertising) e usa le char Connect sulla stessa
connessione per le funzioni nuove. La pairing mode resta solo per il caso di
uno scan filtrato-Connect. (Decisione di lungo periodo, NON urgente, per Hu
Leo: se un giorno volete UN solo service per semplicità, la scelta migliore è
migrare tutto su Connect `C09A0000` — envelope JSON versionato + capabilities —
e ritirare Legacy. Ma non è necessario e non sblocca nulla ora.)

## 5.2 — Setup pairing + riconnessione quotidiana

- **Primo aggancio**: se scansionate filtrando per il UUID Connect, sì serve la
  pairing mode (touch macchina → menu admin → **BLE (App)** → **"Modalità
  pairing →"**, finestra 5 min in cui la macchina fa advertising di `C09A0000`).
  Ma se scansionate per **Legacy** (nome `VNE-*` / service `a1000000`, sempre in
  onda) NON vi serve la pairing mode nemmeno per il primo aggancio.
- **Riconnessione quotidiana**: **via Legacy** `a1000000` (sempre in
  advertising). Una volta connessi, tutte le azioni Connect sono raggiungibili
  sulla stessa connessione. Quindi: NON dovete rifare la pairing mode ogni
  giorno.
- **Timeout 5 min**: lato macchina è già gestito (auto-exit, torna a Legacy).
  Un feedback macchina→app "pairing attiva/scaduta" **esiste**: l'app può
  leggere lo stato via il callback status; e comunque `get_pairing_status()`
  ritorna `{active, remaining_seconds}`. Se volete mostrarlo in UI ve lo
  esponiamo anche su una char, ditemi.
- **Bonding/whitelist lato macchina**: al momento **no**. Su Windows la
  "pairable-off guard" è saltata (log: "BLE pairable-off guard skipped on
  Windows"); non c'è whitelist. L'identità BT è quella del **telefono**, non del
  bundle id: un nuovo bundle id non cambia il bonding lato macchina (non ce n'è).

## 5.3 — Perché Legacy `a1000000` non si connette ORA (causa più probabile)

**Ipotesi n.1 (molto probabile): la macchina è rimasta in PAIRING MODE.** In
pairing mode la macchina **ferma l'advertising Legacy** (codice:
`_stop_service_advertising(SERVICE_UUID)`) e accende Connect. Se il vostro scan
è filtrato per Legacy/`a1000000`, non la trova. Plausibile visto che abbiamo
testato la pairing mode di recente.
- **Verifica**: nei log macchina cercate `BLE pairing mode ON` /
  `BLE pairing mode OFF` / `auto-exit`. Se è ON, uscite (touch → BLE (App) →
  esci pairing) o aspettate l'auto-exit 5 min, poi riprovate.
- **Nota**: se invece scansionate per **nome** `VNE-*`, il nome resta
  advertised anche in pairing mode → in quel caso non è questa la causa;
  ditemi con che criterio scansionate (nome vs UUID) così restringiamo.

**Ipotesi n.2: la connessione ACL `E4:B2:FB:A2:32:43` (handle 12, CENTRAL,
AUTH ENCRYPT)** è un central già connesso (probabilmente un telefono di un test
precedente). Dai soli log macchina non riesco a mapparne il MAC a un nome. Un
peripheral BLE di norma regge più central, quindi meno probabile dell'ipotesi
1, ma per escluderla: disconnettete quel central lato telefono, oppure
`systemctl restart sgm.service` per liberare tutto e ripartire pulito.

## 5.4 — INFO leggibile senza auth: sul Legacy c'è, ma con campi DIVERSI

- Legacy ha una char **INFO `a1000004`** (read, **NO auth**) — verificata. MA
  riporta campi **operativi**: `kiosk_id, name, version, wifi_online,
  queue_size, local_first_ble_enabled, local_first_ble_dry_run, ble_boot_id,
  requires_fresh_hello, session_ttl_seconds, heartbeat_supported,
  recommended_heartbeat_seconds, operator_command_supported,
  operator_command_scope`.
- **NON** contiene `configured` / `contract_version` / `capabilities`. Quelli
  sono **solo** sulla INFO Connect **`C09A0003`** (anch'essa read, no auth).
- Quindi per sapere `configured`/`capabilities` prima di autenticare: leggete
  **`C09A0003`** — accessibile sulla stessa connessione una volta connessi
  (vedi punto chiave in cima).

## Riassunto per sbloccarvi subito

1. Assicuratevi che la macchina **NON sia in pairing mode** (uscite o
   aspettate 5 min) → Legacy `a1000000` torna scopribile.
2. L'app si connette via Legacy come già fa (payout).
3. Sulla **stessa connessione**, l'app legge sia `a1000004` (INFO operativa)
   sia `C09A0003` (INFO configured/capabilities), e usa le azioni Connect
   (ruoli / get_cash_levels / payment) **senza dover cambiare canale**.
4. Promemoria: `get_cash_levels` ha payload grande → per esso usate il canale
   rete **§6bis (Tailscale, `POST /connect/command`)** già congelato, non BLE.

Ditemi con che criterio scansionate (nome vs UUID) e cosa vedete nei log
`BLE pairing mode ...`, così se non è la pairing mode restringiamo la n.2/altro.
