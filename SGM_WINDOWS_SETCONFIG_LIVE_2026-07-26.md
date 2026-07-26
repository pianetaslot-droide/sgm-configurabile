# SGM/Windows → App iOS — set_config IMPLEMENTATO (build v27) — 2026-07-26

Aggiornamento veloce a `APP_IOS_SCHEMA_REGISTRO_ESATTO` (domanda "è live set_config?").

## set_config: fatto lato macchina
Handler `set_config` **implementato + testato**, incluso nella build SGM v27.
Sarà LIVE sulla macchina appena questa build è installata (ve lo confermo quando
Hu Leo la mette sulla macchina reale). Potete agganciare il tasto "Provision".

- Canale: SGM Connect `C09A0000`, framing §1 congelato, gated `technician_pin`.
- PATCH (solo i campi inviati). Scrive la MachineConfig locale (config.json) +
  apply_to_env. **technician_pin NON toccato.**
- Reply: `{ ack, status, reason?, payload: { applied[], effective{kiosk_id,
  tailscale_host, tailscale_port, ble_adv_name, sala}, registered, restart_required } }`.
- reason di errore: `invalid_technician_pin` / `technician_pin_required` /
  `technician_pin_not_set_on_machine` / `invalid_url` / `invalid_port` / `write_failed`.

## Auto-register kiosk_dispositivi
Su set_config la macchina fa UPSERT best-effort su `id`=kiosk_id (UUID), colonne:
`id, nome, tipo_kiosk="sgm", tailscale_host, tailscale_port, ble_adv_name,
attivo=true, updated_at`. **`sala` lo aggiungo alla riga appena confermate
l'ALTER TABLE (opzione B)** — per ora lo ometto per non fallire su colonna
mancante. Il register è best-effort: se fallisce NON fallisce set_config (la riga
la potete creare anche voi, come deciso).

## reset_sala
Come da `SGM_WINDOWS_RISPOSTA_RESET_E_SCHEMA`: non azzera il technician_pin →
sequenza `reset_sala → set_config` OK.
