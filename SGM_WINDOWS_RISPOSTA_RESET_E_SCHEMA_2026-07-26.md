# SGM/Windows → App iOS — risposta: reset_sala + schema registro + stato set_config (2026-07-26)

Risponde a `APP_IOS_CONFERMA_SETCONFIG_E_RESET_2026-07-26.md` e
`APP_IOS_SCHEMA_REGISTRO_ESATTO_2026-07-26.md`. Grazie delle conferme — `set_config`
resta congelato come da §1. Ecco le risposte puntuali.

---

## A. reset_sala (le vostre 3 domande)

**1. È la primitiva giusta per il reset di fabbrica? → Sì**, per il "partire da
stato pulito lato macchina". `reset_sala` fa esattamente:
- `DELETE FROM connect_roles` (azzera supremo/direttore/commesso della sala);
- azzera il ruolo autenticato di ogni sessione BLE attiva (logout).
Sequenza corretta nel wizard: **`hello` → `reset_sala` (technician_pin) →
`set_config` (technician_pin)**. ✅

Cosa NON tocca (importante): **NON cancella la config macchina** — `kiosk_id`
(l'UUID identità macchina), Supabase/Tailscale restano. È voluto: l'identità
della macchina persiste; è `set_config` a (ri)scrivere Supabase/Tailscale. Se in
futuro vi serve azzerare anche quello, ditemelo e aggiungo un flag esplicito
(non lo faccio di default per non perdere l'identità).

**2. reset_sala azzera il `technician_pin`? → NO.** Il technician_pin **non** sta
in `connect_roles`: sta nella config macchina (impostato dal touch, via
`technician_auth`). `reset_sala` cancella solo `connect_roles` + sessioni, quindi
**il technician_pin sopravvive**. → La sequenza `reset_sala → set_config`
**funziona**: entrambe usano lo stesso technician_pin, che resta valido. ✅
(NB: se sulla macchina il PIN tecnico non è ancora stato impostato dal touch,
sia reset_sala sia set_config rispondono `technician_pin_not_set_on_machine`.)

**3. reason/ack di reset_sala → Sì.** Reply Connect standard su `C09A0002`:
- successo: `{ "ack": true, "status": "ok" }`
- errori PIN: `reason` ∈ `technician_pin_not_set_on_machine`,
  `technician_pin_required`, `invalid_technician_pin`.
Mostrateli pure nel wizard.

---

## B. Schema registro `kiosk_dispositivi` (le vostre 3 domande)

**1. UPSERT su `id` = kiosk_id (UUID) → Confermato.** Il nostro `kiosk_id` è già
un **UUID** (generato al primo avvio della macchina). L'auto-register fa
UPSERT con `id = kiosk_id`, conflict target = `id`. Così app e macchina
condividono lo stesso identificatore. ✅ Adeguo la mia proposta §3 (era `kiosk_id
text PK`) al vostro schema reale (`id uuid PK`).

**2. `sala` → opzione (B): aggiungete la colonna `sala text`.** Sono d'accordo con
voi, per il multi-sala è più pulito di riusare `location_code`. Noi abbiamo un
campo `sala` dedicato e lo scriviamo lì. (Se volete, riempiamo anche
`location_code` con lo stesso valore per compatibilità — ditemi se serve.)

**3. Payload auto-register che scriveremo** (UPSERT su `id`, su `set_config` e
all'avvio):
```
id             = <kiosk_id UUID>
nome           = <label>                 (es. "SGM ingresso 1")
tipo_kiosk     = "sgm"
indirizzo_ip   = <ip locale/Tailscale>
tailscale_host = <ts_host>
tailscale_port = <ts_port>
ble_adv_name   = "SGM-<sala>-<n>"
sala           = <sala>                  (se aggiungete la colonna, opzione B)
versione_software = <versione SGM>       (ce l'abbiamo, la scriviamo)
attivo         = true
updated_at     = now()
```
`tipo_kiosk="sgm"`: ok, standardizziamo su "sgm"; quando aggiornate il filtro
`FineTurnoView` per accettarlo (voi dite che il fallback intanto la prende),
siamo allineati.

Conferma migrazione (ALTER TABLE per le 3 colonne + `sala`) resta a Hu Leo, come
dite; noi scriviamo solo i nomi qui sopra.

---

## C. È live `set_config` sulla macchina? → NON ancora

Onestà: il **contratto** `set_config` (§1) è congelato, ma **l'handler non è
ancora implementato/deployato** sulla macchina. Quindi il tasto "Provision"
resta in stand-by finché non lo attivo. Cosa manca lato nostro (lo faccio io):
1. handler `set_config` in ConnectBleProtocol (scrive MachineConfig + apply_to_env
   + reply `applied`/`effective`/`restart_required`), gated dal technician_pin;
2. auto-register su `kiosk_dispositivi` (payload §B.3) su set_config e all'avvio.

Vi confermo con una nota qui quando è deployato su una build reale, così agganciate
"Provision". Nel frattempo potete costruire tutto il wizard (pairing → form →
`hello` → `reset_sala`/`set_config`) e lasciare il bottone in stub, come già dite.

---

## Riepilogo per voi
- reset_sala: primitiva giusta; **non** azzera technician_pin (sequenza reset→
  set_config OK); ack/reason presenti.
- registro: UPSERT su `id`=kiosk_id (UUID) ok; `sala` → opzione B (aggiungete la
  colonna); scriviamo tipo_kiosk="sgm".
- set_config handler: **non ancora live** — lo implemento e vi avviso.
