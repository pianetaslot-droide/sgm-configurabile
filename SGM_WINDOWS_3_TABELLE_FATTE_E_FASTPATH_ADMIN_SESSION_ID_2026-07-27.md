# SGM/Windows → app iOS — 3 tabelle chiuse nel .sql + fast-path admin: OK via session_id (2026-07-27)

## 1. Le 3 tabelle — fatte in `supabase_schema.sql` (aggiornato, stesso file)

- **`kiosk_comandi`**: aggiunta con le vostre colonne (id, kiosk_id, comando, stato, creato_da,
  preso_in_carico_at, completato_at, risposta, motivo_fallimento, created_at, manual_confermato_*).
  ⚠️ **Rimosse le CHECK legacy** su `comando`/`stato` con un blocco `DO` (droppa ogni CHECK sulla
  tabella): così `ping` non viene più rifiutato e gli stati sono i vostri
  (`pending→in_progress→completato|fallito|annullato|manual_confirmed`), niente più `eseguito`. Gli
  enum li validiamo in codice (app+SGM), NON in DB, così nessun comando/stato futuro resta bloccato.
  Confermo il flusso: app INSERT `{kiosk_id, comando, stato='pending', creato_da}` → SGM aggiorna
  `stato/preso_in_carico_at/completato_at/risposta/motivo_fallimento`.
- **`depositi_incasso_turno`**: aggiunta (SGM la scrive) con la vostra DDL — totale_cent, breakdown,
  source, stato, note, created_at, completed_at, operatore_*. Nota: `totale_eur` GENERATED lo lascio
  a voi (una generated column non si aggiunge pulita con ADD COLUMN IF NOT EXISTS su tabella già
  esistente); `totale_cent` è la fonte.
- **`chiusure_contabilita`**: **lasciata FUORI**, come raccomandate — è chiusura di SALA scritta solo
  dall'app; SGM la **legge** soltanto (dashboard). Resta nel vostro NeomaticSchema (app-only). (SGM
  scrive invece `vne_chiusure_contabilita`, derivata/legacy: se mai vi dà 42703 ve la aggiungo.)

Tipi OK confermati da voi → il `.sql` è **completo per le tabelle che SGM scrive**. Al factory setup:
prima il nostro (cash-truth), poi il vostro (solo-app), entrambi idempotenti.

## 2. Fast-path admin — OK, **via session_id** (scelta A)

Confermo la vostra opzione preferita: **niente token RemoteOps all'app**. Aggiungiamo i comandi admin
al canale `/connect/command` (session_id), come get_cash_levels/list_roles/get_hardware — cioè in
**`NETWORK_ALLOWED_ACTIONS`**. Motivo: sono stato + restart/reboot, nessuna erogazione → il session_id
(continuità della sessione BLE, valido in rete entro l'idle) è auth adeguata; il token separato che
non avete non serve.

**Stringhe azione (confermate)** — sul canale `/connect/command`:
- `status`       → snapshot stato hardware (= il vostro ping/refresh Dashboard). Ruolo: qualsiasi
  ruolo autenticato.
- `restart_sgm`  → restart del processo SGM. Ruolo minimo: **direttore/supremo**.
- `reboot`       → riavvio della macchina. Ruolo minimo: **supremo**. ⚠️ Nota OS: su RemoteOps la
  stringa era `reboot_pi` (`systemctl reboot`, Pi/Linux). Queste macchine sono **Windows**: il
  comando reale sarà `shutdown /r`. Esponiamo l'azione come **`reboot`** (neutra); accettiamo anche
  l'alias `reboot_pi` per compatibilità. Confermate quale stringa mandate.

**Capability**: le azioni network-allowed vengono annunciate nella **capability list dell'hello/INFO**
(oggi c'è già `get_hardware_status` riservata; aggiungeremo `get_hardware`, `status`, `restart_sgm`,
`reboot`) → la UISce mostra il fast-path solo quando la macchina lo supporta.

**Fallback**: la coda `kiosk_comandi` resta il fallback durevole quando non c'è session_id valido —
perfetto, nessuna fretta cash-safety.

## 3. get_hardware — ricevuto, consumer vostro pronto ✓

Bene. Da fare lato nostro (prossimo build, insieme al fast-path admin): mettere `get_hardware` +
`status`/`restart_sgm`/`reboot` in `NETWORK_ALLOWED_ACTIONS` + capability, implementare l'handler
`get_hardware` (payload come l'esempio già mandato) e i 3 admin sul `/connect/command`. Appena live vi
mando un `get_hardware` catturato dal vivo per la validazione E2E. Nel frattempo usate
`kiosk_hardware_state` + `kiosk_livelli_cash` come già allineato.

## Da confermare (voi)
- Stringa reboot: `reboot` o `reboot_pi`? (accettiamo entrambe, ma ditemi la primaria).
- Ruoli minimi ok così (status=tutti, restart_sgm=direttore+, reboot=supremo)?
