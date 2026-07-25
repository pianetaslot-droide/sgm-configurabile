# Ordine di lavoro — lato SGM / Windows (Python)

Data: 2026-07-25 · Attua: `SGM_PIANO_GENERALE_2026-07-25.md`
Repo: `sgm-windows` su `pianetaslot-droide/SalaScommessa`
Riferimenti file: vedi §5 del doc di handoff Windows.

Regola: **non modificare il contratto BLE da solo.** Il repo Windows *possiede*
`BLE_PROTOCOL_CONTRACT.md`, ma le modifiche al protocollo passano dal piano
generale e vanno registrate con `contract_version` + changelog + matrice.

I task sono in ordine di priorità. Non passare alla fase successiva finché la
Definition of Done della fase precedente non è verde su hardware reale.

---

## FASE 0 — Sbloccare il pairing (priorità massima)

### W0.1 — Advertising: un solo service, e pubblicizzare il service UUID
La scheda Bluetooth fa advertising di un solo GATT service alla volta (radice
già individuata). Il vecchio protocollo TITO/Snai e il nuovo SGM Connect non
coesistono nell'advertisement, e oggi la macchina appare SENZA nome.

- Introdurre una **"modalità pairing"** (toggle, riusabile dal menu admin
  `ble` già esistente in `display.py`): quando attiva, il `GattServiceProvider`
  pubblicizza SOLO il service SGM Connect
  `C09A0000-1B2C-4A9E-8F3D-53474D434E31` e lo **include nella lista service
  UUID dell'advertisement**, così l'app può filtrare lo scan.
- Verificare cosa espone davvero l'API bless/WinRT usata: se non può mettere
  il service UUID in advertising, valutare l'alternativa di esporre almeno un
  `localName` stabile e riconoscibile (es. `SGM-<kiosk_id>`) come fallback di
  identità. Documentare l'esito nel contratto.
- File coinvolti: `services/ble_server.py` (i due service coesistenti oggi),
  `services/connect_ble_protocol.py`.

### W0.2 — Estendere la caratteristica INFO
INFO è letta senza auth ed è il punto di aggancio autorevole (piano §3).
Aggiungere al payload:

```json
{ "kiosk_id": "...", "label": "...", "sala": "...", "configured": true,
  "contract_version": 1,
  "capabilities": ["hello"] }
```

- `capabilities` deve elencare **solo** le azioni realmente implementate ORA
  sulla macchina. In Fase 0 è `["hello"]` (più INFO implicita). NON elencare
  le azioni ruoli finché non sono davvero implementate (W1.x): è esattamente
  il disallineamento da eliminare.
- `contract_version = 1`.
- File: `services/connect_ble_protocol.py` (dove è definito il payload INFO).

### W0.3 — Stabilità della connessione GATT
L'app non ha mai completato un connect reale. Verificare dal lato macchina che
non sia il server a rifiutare/non-accettare:

- Confermare che il peripheral resti `is_connectable` e accetti la connessione
  GATT (non solo `is_discoverable`).
- Loggare lato server ogni tentativo di connessione in arrivo, così durante il
  test congiunto si vede se la richiesta dell'iPhone arriva alla macchina.

### W0.4 — Test congiunto (con il lato app)
Sessione su hardware reale sull'happy path esatto del piano §4: scan filtrato →
connect → discoverServices → read INFO → hello → salva. Chiudere solo quando il
pairing riesce 3 volte di fila.

**DoD Fase 0:** l'app salva la macchina reale in lista, ripetibile, e in ogni
fallimento la macchina ha loggato cosa ha ricevuto.

---

## FASE 1 — Ruoli-sala sulla macchina

> Precondizione: Fase 0 chiusa. E prima di scrivere codice, la **spec dei campi**
> delle azioni ruoli va congelata nel contratto (la definisce il lato app perché
> modella la UI; tu la implementi). Non iniziare a indovinare i campi: è ciò che
> ha già causato rework.

### W1.1 — Implementare le 5 azioni ruoli
`bootstrap_sala`, `login`, `list_roles`, `upsert_role`, `remove_role` sopra il
layer REQUEST/REPLY.

- Riusare `setup/technician_auth.py` (hash PIN pbkdf2) come paradigma già pronto per
  la persistenza sicura dei PIN.
- Modello (confermato da Hu Leo): ruoli vivono sulla macchina; il PIN tecnico
  fa SOLO il bootstrap del primo `supremo`; da lì il supremo decide numero di
  livelli e permessi (NON cablare i livelli). Nessun dato di ruolo esce verso
  cloud o telefono.
- Persistenza locale: valutare la tabella sessioni BLE già presente in
  `local_ledger.py`.

### W1.2 — Esporre i ruoli in `capabilities`
Solo dopo che W1.1 funziona, aggiungere le 5 azioni a `INFO.capabilities` e
bumpare `contract_version` se cambiano i campi. Aggiornare la matrice §3 del
piano.

**DoD Fase 1:** su macchina reale — bootstrap primo supremo con PIN tecnico,
login con PIN ruolo, upsert+remove di un ruolo. Verificato che nulla persista
sul telefono.

---

## FASE 2 — Operazioni cassa

> Precondizione: Fase 1 chiusa (la cassa richiede ruolo autenticato).

### W2.1 — Contratto azioni cassa (congiunto)
Definire con il lato app le azioni: proposta minima iniziale = **lettura
livelli** (basso rischio), poi deposito/incasso e dispensa.

### W2.2 — Implementare le azioni cassa
Riusare la logica di calcolo autorevole già esistente (`local_ledger.py`,
stessa del flusso "Deposita incasso" del touch — così i numeri sul telefono
coincidono con quelli sulla macchina per costruzione). Esporre in
`capabilities`.

**DoD Fase 2:** lettura livelli eseguita dall'app contro macchina reale, numeri
identici a quelli del touch.

---

## Traccia parallela (NON blocca il pairing) — bug UI touch

Indipendente dall'aggancio con l'app; portala avanti quando l'app è in attesa
di test. Dal §4.1 del doc Windows, causa radice confermata: font "card" 52px
usato in righe con interlinea 50–60px → sovrapposizione garantita.

- `_render_cash_levels_grid` (`display.py:2971`): card da 72px con 3 righe, la
  riga valore a 52px copre le altre.
- `_render_deposito_riconciliazione`: righe "teorico"/"contanti" a 52px con
  interlinea 60px, rischio sovrapposizione con la riga sottostante.
- **Decisione da prendere (piano, non solo patch):** prima di aggiustare le
  singole coordinate, definire una convenzione minima "altezza riga / taglia
  font" per la UI pygame (che è tutta a coordinate pixel hardcoded, senza
  layout engine né collision detection). Poi valutare se fare un passaggio
  sistematico su tutte le nuove schermate o solo sulle 2 confermate.

---

## Nota su artefatti e packaging
Ogni giro di modifiche ripacchettizza con `packaging/windows/sgm_windows.spec`,
versione incrementale, changelog in `FIX_NOTES.txt`. Mantenere questa
disciplina anche per le modifiche BLE di Fase 0, così il lato app sa quale
build sta testando.
