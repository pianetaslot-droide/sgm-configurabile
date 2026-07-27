# App iOS → SGM/Windows — confermo: reboot="reboot", ruoli OK; fast-path admin lo attiviamo al vostro prossimo build (2026-07-27)

Ricevuto "3 tabelle chiuse nel .sql + fast-path admin via session_id". Confermo i 2 punti che
chiedevate.

## 1. Stringa reboot = `reboot` (primaria)
Le macchine sono Windows → giusto esporre la neutra **`reboot`** (shutdown /r); NON usiamo
`reboot_pi` (era la stringa Pi/RemoteOps). Mapping app aggiornato: `ping→status`,
`restart_sgm→restart_sgm`, `reboot→reboot`.

## 2. Ruoli OK
Confermati: `status` = qualsiasi ruolo autenticato · `restart_sgm` = direttore+ · `reboot` = supremo.
UI allineata: il pulsante **reboot ora è visibile solo al supremo**; `restart_sgm` resta a
direttore/supremo (il Pannello Kiosk è già ristretto a direttore/supremo — il commesso non lo vede).

## Stato lato app
- **kiosk_comandi**: perfetto aver tolto le CHECK legacy (niente più `eseguito` / manca-`ping`), enum
  validati in codice. Flusso confermato: app INSERT `{kiosk_id, comando, stato='pending', creato_da}`
  → voi aggiornate `stato/preso_in_carico_at/completato_at/risposta/motivo_fallimento`.
- **depositi_incasso_turno**: ok; `totale_eur` GENERATED lo teniamo noi (è nel nostro NeomaticSchema).
- **chiusure_contabilita**: ok app-only, voi la leggete soltanto. Notato: voi scrivete
  `vne_chiusure_contabilita` (derivata/legacy) — se ci servirà leggerla ve lo diciamo; per ora l'app
  non la tocca.

## Fast-path admin — pronti, aspettiamo il vostro build
Oggi il fast-path passa ancora da RemoteOpsService (token → 401) e ripiega sulla coda `kiosk_comandi`
(funziona, solo più lento). **Appena `status`/`restart_sgm`/`reboot` + `get_hardware` sono in
`NETWORK_ALLOWED_ACTIONS` e annunciati nella capability list dell'hello/INFO**, instradiamo gli admin
(e get_hardware) sul canale `/connect/command` (session_id) — niente token. Mandateci il `get_hardware`
catturato dal vivo quando è pronto, così validiamo E2E il generatore livelli/righe.

Contratto allineato, grazie.
