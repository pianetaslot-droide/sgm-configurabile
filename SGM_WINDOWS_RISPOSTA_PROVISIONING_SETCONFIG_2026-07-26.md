# SGM/Windows → App iOS — risposta: set_config, registro macchine, Supabase runtime (2026-07-26)

Risponde a `APP_IOS_NUOVO_PAIRING_REGISTRY_E_RENAME_SGM_2026-07-26.md` e
`APP_IOS_PROVISIONING_FLOW_2026-07-26.md`. Il nuovo modello (registro Supabase +
scan Legacy senza pairing mode + Tailscale da remoto) è chiaro; per la parte BLE
non serve nulla di nuovo nel contratto tranne l'azione **`set_config`**, che
congelo qui sotto (avete delegato a noi il meccanismo: "decidete voi, conoscete
il vostro BLE server").

---

## 0. Chiarimento importante: su SGM/Windows Supabase NON è hardcoded

(Provisioning, domanda 3.) L'hardcode `fzgxqqjvpzqtdhdqupfw` è il **vecchio Pi
Game manager**, non questo stack. Su SGM/Windows la config vive già a runtime:

- File: `C:\ProgramData\SGM\config.json` (MachineConfig), tradotto in variabili
  d'ambiente da `apply_to_env()`.
- `cloud.supabase_url` / `supabase_key` → `SUPABASE_URL` / `SUPABASE_ANON_KEY`
  (default placeholder finché non configurati — non è hardcoded a un progetto).
- `cloud.tailscale_host` / `tailscale_token` → `SGM_REMOTE_OPS_HOST` /
  `SGM_REMOTE_OPS_TOKEN`; porta da `SGM_REMOTE_OPS_PORT` (default 8787).

→ Quindi `set_config` che sovrascrive Supabase/Tailscale è **pienamente
fattibile**: scrive la MachineConfig, la salva su disco, la riapplica. Nessun
hardcode da rimuovere lato nostro.

---

## 1. Azione BLE `set_config` — CONTRATTO (congelato lato SGM)

**Canale: SGM Connect `C09A0000`** (envelope JSON), NON Legacy. Motivi: payload
JSON con URL/chiavi lunghe, l'envelope Connect è già fatto per questo, ed è
un'azione di fabbrica una-tantum col tecnico davanti. Resta **BLE-only** (NON
entra in `NETWORK_ALLOWED_ACTIONS`: il provisioning richiede prossimità fisica).

Caratteristiche (già attive sul server):
- Service `C09A0000-1B2C-4A9E-8F3D-53474D434E31`
- REQUEST (write)  `C09A0001-…`
- REPLY (notify)   `C09A0002-…`
- INFO (read)      `C09A0003-…`

NB: **`set_config` NON richiede pairing mode.** Nel nuovo modello il Legacy
`a1000000` resta sempre in advertising; una volta connessi, entrambi i service
(Legacy + Connect) sono sulla stessa connessione GATT → scrivete su `C09A0001`
direttamente.

**Request (envelope Connect standard):**
```json
{
  "schema_version": 1,
  "action": "set_config",
  "session_id": "cs-…",          // ottenuto da hello
  "seq": 3,
  "payload": {
    "technician_pin": "……",       // OBBLIGATORIO (vedi §2)
    "supabase_url": "https://xxxx.supabase.co",
    "supabase_anon_key": "eyJ…",
    "tailscale_host": "100.x.y.z",
    "tailscale_port": 8787,
    "sala": "Lido",               // opzionale
    "label": "SGM ingresso 1"     // opzionale (diventa anche nome adv BLE, §4)
  }
}
```
Tutti i campi payload sono opzionali TRANNE `technician_pin`: mandate solo quelli
da (ri)scrivere, gli assenti restano invariati → **patch, non replace**.

**Reply (su REPLY `C09A0002`):**
```json
{ "ack": true, "status": "ok",
  "applied":  ["supabase_url","supabase_anon_key","tailscale_host","tailscale_port","label"],
  "effective": { "kiosk_id": "…", "tailscale_host": "100.x.y.z",
                 "tailscale_port": 8787, "ble_adv_name": "SGM-…" },
  "restart_required": true }
```
in errore:
```json
{ "ack": false, "status": "error", "reason": "invalid_technician_pin" }
```
`reason` possibili: `technician_pin_not_set_on_machine`, `technician_pin_required`,
`invalid_technician_pin`, `invalid_url`, `invalid_port`, `write_failed`,
`unsupported schema_version`.

**Comportamento della macchina alla ricezione:**
1. Verifica `technician_pin` (stesso gate di bootstrap_sala/reset_sala).
2. Valida i campi (URL ben formato, porta 1–65535).
3. Scrive la MachineConfig su `config.json` + `apply_to_env()`.
4. Risponde `ack` con `applied` (cosa ha scritto) e `effective` (inclusi
   `kiosk_id` e `ble_adv_name`).
5. **Auto-registrazione** nel registro Supabase (§3) usando il Supabase appena
   impostato.
6. `restart_required`: alcuni parametri (client Supabase, nome adv BLE) si
   applicano appieno solo dopo il riavvio del servizio. Ritorniamo il flag; il
   riavvio lo fa Hu Leo/OpenClaw sul posto (regola: nessun restart remoto dal
   vostro lato).

---

## 2. Autorizzazione

`set_config` è protetto dallo **stesso technician PIN** di bootstrap_sala/
reset_sala: campo `payload.technician_pin`. Il PIN reale sta solo sulla macchina
(mai sul telefono). Se sul dispositivo non è impostato →
`technician_pin_not_set_on_machine` (va impostato una volta dal touch macchina).

---

## 3. Registro macchine (registry §2.1 + domande 1–2)

Stato onesto: **SGM/Windows NON si auto-registra ancora** in una tabella-registro
(scrive chiusure/movimenti/incidenti, ma non una riga "questa macchina esiste").
Va costruito, ed è fattibile: la macchina conosce già tutto — `kiosk_id` (UUID
auto-generato al primo avvio), `label`, `sala`, `tailscale_host/port`,
`ble_adv_name` (= label).

Proposta schema (riuso `kiosk_dispositivi`, che l'app legge già, + 3 colonne):
```
tabella: kiosk_dispositivi
  kiosk_id        text  PK
  nome            text          // "SGM …"
  sala            text
  tipo_kiosk      text          // vedi §5
  tailscale_host  text          // NUOVA colonna
  tailscale_port  int           // NUOVA colonna
  ble_adv_name    text          // NUOVA colonna
  updated_at      timestamptz
```
- **Domanda 1 (tabella):** propongo di riusare `kiosk_dispositivi` + 3 colonne
  nuove, così l'app cambia il minimo. Confermate voi/Hu Leo (o ditemi la tabella
  nuova che preferite con i nomi esatti).
- **Domanda 2 (auto-register): sì, fattibile.** La lego a `set_config`: appena la
  macchina riceve Supabase+Tailscale fa l'upsert della propria riga; in più
  upsert all'avvio, così `updated_at`/endpoint restano freschi. (Se preferite che
  la riga la crei il tecnico dall'app, funziona lo stesso — supportiamo entrambi.)

---

## 4. Nome adv BLE `VNE-*` → `SGM-*` (registry §2.2, domanda 3)

Oggi il nome pubblicitario BLE **= `cfg.kiosk_label`** (default "VNE-Sala1"). Per
rinominare basta impostare la label a `SGM-…` — dal touch macchina o via
`set_config` (campo `label`). Formato proposto: **`SGM-<sala>-<n>`** (es.
`SGM-Lido-1`). Dato che l'app accetta già qualsiasi `SGM-*`, adotto questo salvo
vostra preferenza. La config sul touch macchina resta la sorgente autorevole del
nome.

---

## 5. "SGM" nei dati Supabase / `tipo_kiosk` (registry §2.3)

`tipo_kiosk="vne_plus"`: se Hu Leo vuole rinominarlo (es. `"sgm"`), lato
SGM/Windows lo scriviamo con lo stesso valore — ma **coordiniamoci**, così
cambiamo insieme e voi aggiornate il filtro `FineTurnoView` (o accettate entrambi
in transizione) per non svuotare la lista. Per ora non urgente.

---

## 6. Supabase dedicato futuro (registry §2.4)

Confermato: quando Hu Leo passa a un Supabase nuovo dedicato, SGM scrive lo
STESSO progetto. Con `set_config` diventa banale — l'app scrive il nuovo URL+key
sulla macchina e la macchina si riallinea. North-star confermata: SGM locale =
verità, Supabase = sync/backup dati app.

---

## Riepilogo / cosa serve da voi

1. OK a `set_config` su Connect `C09A0000` col framing del §1? Per me è congelato
   lato SGM → potete sbloccare il tasto "Provision" su questo contratto.
2. Conferma registro: riuso `kiosk_dispositivi` + 3 colonne (`tailscale_host`,
   `tailscale_port`, `ble_adv_name`), e chi crea la riga (auto vs tecnico).
3. Conferma formato nome adv `SGM-<sala>-<n>`.

L'implementazione lato SGM (handler `set_config` + auto-register) parte appena
confermate tabella/schema; il **contratto BLE del §1 non cambia**.
