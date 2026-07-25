# SGM (Windows/Python) — stato Fase 0 (2026-07-25)

Aggiornamento rispetto a `SGM_WINDOWS_STATUS_HANDOFF_2026-07-24.md` (non
sostituito, quel documento resta valido per tutto il resto — Livelli cassa,
incasso, residuo, bug font UI). Questo file copre SOLO l'esecuzione di
`SGM_ORDINE_LAVORO_WINDOWS_2026-07-25.md` Fase 0.

## Fatto

- **W0.1 — Pairing mode**: implementato. Causa radice confermata su
  hardware reale (log macchina, riavvii multipli): l'adattatore Bluetooth
  trasmette un solo GATT service alla volta; il service legacy vince sempre
  per default (`advertisement_status=2`), il service SGM Connect resta a
  `advertisement_status=3` (mai avviato). Nuovo toggle sul touch macchina
  (menu admin → BLE (App) → "Modalità pairing →") che per 5 minuti ferma
  l'advertising legacy e avvia quello di SGM Connect, poi torna
  automaticamente al legacy. File: `services/ble_server.py`
  (`enter_pairing_mode`/`exit_pairing_mode`/`get_pairing_status`),
  `ui/display.py` (nuova schermata `_render_ble_pairing_screen`).
  **Non ancora verificato end-to-end con un telefono reale** — vedi
  "Cosa manca" sotto.
- **W0.2 — INFO esteso**: `contract_version=1`, `capabilities=["hello"]`
  aggiunti al payload INFO. `capabilities` riflette esattamente cosa questa
  macchina implementa ORA (solo `hello`) — le 5 azioni ruoli non ci sono
  finché non sono davvero implementate, niente promesse premature. File:
  `services/connect_ble_protocol.py` (costanti `CONTRACT_VERSION`/
  `CAPABILITIES`), `services/ble_server.py` (`_connect_info_payload`).
- **W0.3 — Log di connessione**: la lettura di INFO ora logga
  esplicitamente ("client connected and is querying identity") — è il primo
  segnale osservabile che un telefono ha raggiunto la macchina, utile per il
  test congiunto W0.4. Le richieste REQUEST/hello erano già loggate.

## Non toccato in questo giro (di proposito)

- Ruoli/PIN locali (`bootstrap_sala`/`login`/`list_roles`/`upsert_role`/
  `remove_role`) — Fase 1, bloccata sulla spec campi da congelare nel
  contratto, come da piano.
- Operazioni cassa — Fase 2.
- Nessun cambio al protocollo legacy (TITO/Snai): resta il default
  all'avvio, non modificato.

## Cosa manca prima che Fase 0 possa dirsi chiusa (DoD)

- **W0.4, test congiunto**: il meccanismo di pairing mode usa le stesse
  primitive WinRT che bless usa internamente per l'advertising legacy (già
  provate, sempre affidabili sui riavvii osservati), ma lo scambio
  effettivo dello slot radio (stop legacy → start Connect) non è ancora
  stato osservato con un vero scan da iPhone — solo con test
  unitari/di import isolati (niente hardware BLE reale coinvolto in quei
  test). Prossimo passo naturale, quando entrambi i lati sono pronti:
  sessione live sull'happy path del piano §4 (scan filtrato → connect →
  discoverServices → read INFO → hello → salva).
- Non ho potuto testare dal vivo lo scambio radio in questo giro perché la
  macchina reale era già in uso (SGM in esecuzione) mentre lavoravo — avviare
  un secondo processo BLE di test in parallelo avrebbe potuto interferire
  con l'app in uso, quindi ho evitato.

## Build

Pacchettizzato e distribuito (stessa disciplina di sempre — vedi
`FIX_NOTES.txt` nello zip). Non auto-testato dopo il packaging (per
convenzione di progetto, il test del build finale spetta all'operatore).
