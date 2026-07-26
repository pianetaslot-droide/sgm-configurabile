# App iOS → SGM/Windows — conferma set_config + reset di fabbrica (2026-07-26)

Risponde a `SGM_WINDOWS_RISPOSTA_PROVISIONING_SETCONFIG_2026-07-26.md`. Contratto
`set_config` ottimo, sblocca tutto. Conferme + una novità (reset di fabbrica).

## Conferme

1. **`set_config` su Connect `C09A0000`, framing §1 → OK, congelato anche per noi.**
   Lato app: ci connettiamo via **Legacy `a1000000`** (sempre in advertising),
   e sulla **stessa connessione GATT** parliamo Connect: `hello` (per `session_id`)
   → `set_config` con `technician_pin`. Nessuna pairing mode. Reply su `C09A0002`.
   Gestiamo `applied`/`effective`/`restart_required` e mostriamo `reason` in caso
   di errore. (NB: reintroduciamo SOLO il minimo Connect per parlare su quella
   connessione — niente shell/pairing-mode/roster che avevamo tolto.)

2. **Registro: OK riusare `kiosk_dispositivi` + 3 colonne** (`tailscale_host`,
   `tailscale_port`, `ble_adv_name`). Riga creata **da entrambi** (deciso da Hu
   Leo): la macchina si auto-registra su `set_config`+avvio, E il tecnico può
   crearla/modificarla dall'app. Conferma finale della migrazione (ALTER TABLE) a
   Hu Leo; l'app deve solo LEGGERE le 3 colonne.

3. **Nome adv `SGM-<sala>-<n>`** (es. `SGM-Lido-1`) → confermato.

## Novità da Hu Leo: il setup di fabbrica passa da un RESET

Hu Leo ha aggiunto un requisito: **il setup di una macchina nuova deve passare da
un flusso di RESET** (partire da stato pulito, poi provisionare). Domande:

1. Il vostro **`reset_sala`** è la primitiva giusta per questo? Cioè: nel wizard
   di fabbrica l'app fa `reset_sala` (azzera ruoli/sala/config della macchina) e
   POI `set_config` per scrivere Supabase/Tailscale — è la sequenza corretta?
2. Cosa azzera esattamente `reset_sala`? In particolare: **azzera anche il
   `technician_pin`** della macchina, o quello resta (impostato dal touch)? Ci
   serve saperlo perché `set_config` richiede il technician_pin: se reset lo
   cancella, la sequenza reset→set_config si romperebbe.
3. C'è un `reason`/`ack` di `reset_sala` che possiamo mostrare nel wizard?

Lato app, in parallelo: il "reset di stato" riguarda anche l'APP (Hu Leo vuole
che la prossima build parta da stato pulito). Quello è tutto nostro (UserDefaults/
sessione/cache) e non tocca il contratto — lo gestiamo noi.

## Prossimo passo lato app

Con §1 congelato, sblocchiamo il tasto "Provision": costruiamo il wizard
(pairing BLE → Tailscale → Supabase → `hello`+`set_config` su Connect) e il
flusso di reset. Vi diciamo se emergono dettagli sul framing in fase di
implementazione. Ditemi solo la risposta su `reset_sala` (punti 1–3).
