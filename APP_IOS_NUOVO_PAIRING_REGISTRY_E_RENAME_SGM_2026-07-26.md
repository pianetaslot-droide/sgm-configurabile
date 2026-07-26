# App iOS → SGM/Windows — nuovo modello pairing/connessione + rename "SGM" (2026-07-26)

Aggiornamento dopo i due scambi precedenti (`APP_IOS_NEOMATIC_PIVOT_E_PAIRING`,
`SGM_WINDOWS_RISPOSTA_NEOMATIC_PAIRING`, `APP_IOS_RISPOSTA_SCAN_UUID`). Grazie
per aver chiarito il punto chiave (un solo BlessServer, entrambi i service sulla
stessa connessione; l'advertising limita solo la scoperta). Su quella base
abbiamo **ripensato pairing/connessione** e serve un po' di coordinamento.

---

## 1. Cosa è cambiato lato app (deciso con Hu Leo)

- La **prima UI di pairing (canale Connect `C09A0000` + pairing mode) è stata
  RIMOSSA** dall'app: a Hu Leo non piaceva il flusso a due canali con la pairing
  mode. Niente più `_SGMConnect`, niente MachineStore, niente pairing mode nel
  percorso app.
- **Nuovo modello (scope: `supremo` gestisce PIÙ sale, PIÙ macchine):**
  - **Lista macchine = registro su Supabase.** Ogni macchina è una riga con
    `kiosk_id · label · sala · endpoint Tailscale · nome BLE`. Anche le macchine
    di sale remote compaiono (sono nel registro), non solo quelle in portata BLE.
  - **On-site: scoperta/connessione via BLE Legacy `a1000000`** (sempre in
    advertising, NIENTE pairing mode). L'app scansiona, elenca le macchine
    vicine, le abbina per `kiosk_id` al registro.
  - **Da remoto: Tailscale** (host/porta della singola macchina, dal registro).
  - L'app sceglie il canale da sola: BLE se vicino, altrimenti Tailscale.
- **Rename "SGM": la macchina non si chiama più "VNE".** Lato app tutto il testo
  visibile è già "SGM". **Lo scan BLE ora accetta il nome pubblicitario sia
  `SGM-*` (nuovo) sia `VNE-*` (transizione)** — quindi potete rinominare quando
  volete senza rompere l'app.

## 2. Cosa serve dal lato SGM/Windows (Pi)

**2.1 — Auto-registrazione della macchina nel registro Supabase.**
Alla configurazione di fabbrica (wizard tecnico), la macchina dovrebbe
**scrivere/aggiornare la propria riga** nel registro con almeno:
```
kiosk_id (uuid macchina)   label/nome   sala
tailscale_host   tailscale_port          ble_adv_name ("SGM-xxxx")
```
Va bene la tabella esistente `kiosk_dispositivi` (l'app già la legge) o una
nuova tabella registro — ditemi quale preferite e lo schema esatto dei campi,
così l'app legge gli stessi nomi. In particolare ci serve **l'endpoint
Tailscale PER MACCHINA** (ora nel client è un default globale `100.85.24.30:8787`;
con più sale ogni macchina ha il suo IP). Se la macchina lo auto-riporta nel
registro, l'app non deve farlo digitare a mano (resta comunque un campo
editabile dal tecnico come fallback).

**2.2 — Nome pubblicitario BLE: `VNE-*` → `SGM-*`.**
L'app già accetta entrambi. Quando rinominate l'advertising a `SGM-<id>` va bene;
ditemi il formato esatto che userete.

**2.3 — "SGM" ovunque anche nei DATI Supabase.**
Lato app abbiamo rinominato tutto il testo visibile. Restano lato dato:
- `kiosk_dispositivi.nome` es. "VNE Plus Change — Sala 1" → un nome "SGM …";
- `kiosk_dispositivi.tipo_kiosk = "vne_plus"` (l'app filtra su questo valore in
  `FineTurnoView`, con fallback a "tutti gli attivi"). Se volete rinominare il
  tipo (es. `"sgm"`), fatelo pure ma **avvisatemi**: aggiorno il filtro lato app
  in modo che accetti il nuovo valore (o entrambi durante la transizione), così
  non svuotiamo la lista.

**2.4 — Progetto Supabase condiviso (quando si cambia).**
North-star confermata: SGM locale (BLE + Tailscale) = verità; **Supabase = solo
sync/backup dati app**. L'app ha già un ingresso di configurazione (Impostazioni
→ Dati & Sync) dove il supremo inserisce **URL + anon key Supabase** e
**host/porta Tailscale**. Quando Hu Leo deciderà di spostare l'app su un
**Supabase dedicato nuovo** (oggi è ancora `fzgxqqjvpzqtdhdqupfw`, condiviso con
Game manager + Pi), **il Pi dovrà scrivere lo STESSO progetto** — altrimenti app
e Pi si separano. Non è urgente; vi avviso con URL/ref quando si decide, così
allineate la config del Pi.

## 3. Contratto lato app, così com'è ORA (per riferimento)

- Scan BLE: `scanForPeripherals(withServices: [a1000000])`, poi gate sul nome
  `hasPrefix("SGM-") || hasPrefix("VNE-")`.
- INFO Legacy `a1000004` (no-auth): campi operativi (kiosk_id, name, version,
  wifi_online, queue_size, …) — **non** ha `tailscale_host/port`. Per l'endpoint
  remoto per-macchina useremo il **registro Supabase** (punto 2.1), non la INFO
  BLE, a meno che non preferiate aggiungerlo alla INFO.
- Remote Ops: `POST http://<host>:<port>/command` (host/porta da config; default
  `100.85.24.30:8787`).

## 4. Domande aperte per voi

1. Registro macchine: usiamo `kiosk_dispositivi` o una tabella nuova? Datemi lo
   **schema dei campi** (soprattutto dove mettete `tailscale_host/port` e
   `ble_adv_name`), così l'app li legge con i nomi giusti.
2. La macchina può **auto-registrarsi** al primo setup? (in alternativa il
   tecnico crea la riga dall'app — noi supportiamo entrambi).
3. Formato del nome pubblicitario `SGM-*` che adotterete.

Nessuna modifica al contratto BLE è richiesta subito: il grosso è **registro +
endpoint Tailscale per-macchina**. Lato app iniziamo a costruire la lista da
registro + scoperta BLE + routing di connessione.
