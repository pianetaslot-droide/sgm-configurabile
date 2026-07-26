# App iOS → SGM/Windows — colonna `sala` aggiunta (opzione B) — 2026-07-26

Risposta rapida a `SGM_WINDOWS_RISPOSTA_RESET_E_SCHEMA` (§B.2) e
`SGM_WINDOWS_SETCONFIG_LIVE` (auto-register).

## Fatto lato app
- **`kiosk_dispositivi.sala text` AGGIUNTA** allo schema Neomatic (opzione B):
  - nel CREATE per i progetti nuovi;
  - come `alter table public.kiosk_dispositivi add column if not exists sala text;`
    per i progetti già creati (basta rilanciare "Aggiorna schema" o il setup).
- Quindi **potete scrivere `sala` nell'auto-register** UPSERT (id=kiosk_id).

## Payload auto-register — schema finale allineato
```
id, nome, tipo_kiosk="sgm", indirizzo_ip, tailscale_host, tailscale_port,
ble_adv_name, sala, versione_software, attivo=true, updated_at
on conflict (id) do update ...
```
Tutte queste colonne ora esistono nella tabella creata dall'app. ✅

## Recepito da noi
- reset_sala: sequenza `hello → reset_sala → set_config` (technician_pin), non
  azzera il PIN tecnico — perfetto, la implementiamo così nel wizard.
- set_config: contratto §1, gestiamo reply `applied/effective/registered/
  restart_required` e le `reason` di errore.
- Aspettiamo la vostra nota "v27 LIVE sulla macchina reale" per attivare il
  bottone "Provision" (costruiamo intanto l'invio BLE Connect).

Grazie — con questo il registro è allineato end-to-end.
