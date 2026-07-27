# SGM/Windows → app iOS — get_hardware + admin fast-path LIVE (v62) + payload reale (2026-07-27)

Implementato e buildato (v62). Le 4 azioni sono su `/connect/command` (session_id), in
`NETWORK_ALLOWED_ACTIONS` e annunciate nella capability list dell'hello/INFO.

## Azioni network-live (canale session_id, NO token RemoteOps)

| action | ruolo minimo | note |
|---|---|---|
| `get_hardware` | qualsiasi autenticato (viewMonitoring) | inventario dinamico, sola lettura |
| `status` | qualsiasi autenticato | ping/refresh: `{ok, ts, hardware[]}` |
| `restart_sgm` | direttore+ | riavvia il processo SGM |
| `reboot` | supremo | riavvia la macchina (Windows: `shutdown /r`) |

- Capability list ora include: `get_hardware`, `status`, `restart_sgm`, `reboot` → mostrate il
  fast-path solo quando la macchina le annuncia.
- Role-gating enforced lato SGM (non solo UI): `restart_sgm` < commesso → `not_authorized`;
  `reboot` solo supremo. Reply immediata `{scheduled, delay_s}`; l'azione OS parte dopo il delay
  (l'ack arriva prima). Fallback coda `kiosk_comandi` resta valido quando non c'è session_id.

## Payload REALE `get_hardware` (catturato ora da questa macchina)

```json
{
  "action": "get_hardware",
  "kiosk_id": "1a253e40-44f2-44e6-bf74-c52e8c4d2b33",
  "hardware": [
    {
      "key": "f53", "ruolo": "banknote_dispenser", "model": "grg_cdm6240n", "stato": "ok",
      "unita": [
        {"id": "cass_1", "taglio_cent": 500,  "capienza": null, "livello": 5,  "stato": "ok"},
        {"id": "cass_2", "taglio_cent": 1000, "capienza": null, "livello": 38, "stato": "ok"},
        {"id": "cass_3", "taglio_cent": 2000, "capienza": null, "livello": 47, "stato": "ok"},
        {"id": "cass_4", "taglio_cent": 5000, "capienza": null, "livello": 94, "stato": "ok"},
        {"id": "cass_5", "taglio_cent": 5000, "capienza": null, "livello": 1,  "stato": "ok"}
      ]
    },
    {"key": "ipro",   "ruolo": "bill_acceptor", "model": "jcm_ipro", "stato": "assente", "unita": []},
    {"key": "hopper", "ruolo": "coin_hopper",   "model": "",         "stato": "assente", "unita": []},
    {"key": "cctalk", "ruolo": "coin_acceptor", "model": "",         "stato": "assente", "unita": []}
  ]
}
```

Note sul payload (dai dati reali, NON cablato):
- `hardware[]` viene da `config.json` (device abilitati/model) — device non configurati/disabilitati
  → `stato:"assente"`, `unita:[]` (nascondeteli in Dashboard, come già fate).
- `unita[]` = cassette del CDM6240N con `taglio_cent` REALI (500/1000/2000/5000/5000) e `livello`
  dal ledger locale autoritativo. `stato` unità ∈ {ok, inibito}. `capienza` = `null` finché il fondo
  nominale non è provisionato (per ora non lo forziamo — "mai un finto valore").
- `stato` device ∈ {ok, assente}. (guasto/inibito li aggiungiamo quando il device espone un fault
  reale; oggi è ok se abilitato.)

## Enum (come concordato)
`ruolo` ∈ {banknote_dispenser, coin_hopper, bill_acceptor, coin_acceptor};
`stato` device/unità ∈ {ok, guasto, assente, inibito}.

## Realtime
Invariato: stato per-device → `kiosk_hardware_state`; livello+taglio per-cassetta →
`kiosk_livelli_cash`. `get_hardware` è lo snapshot inventario on-demand.

Provate pure a instradare get_hardware/status/admin su `/connect/command`. Fateci sapere se il
generatore livelli/righe torna coerente col payload sopra per l'E2E.
