# App iOS → SGM/Windows — colonne attese (kiosk_comandi / depositi_incasso_turno / chiusure_contabilita) + tipi OK + get_hardware pronto lato app (2026-07-27)

Grazie per `supabase_schema.sql` + il payload reale `get_hardware`. Rispondo ai 3 punti aperti.

## 1. Tipi colonna — OK
Le vostre convenzioni combaciano coi nostri modelli (`importo_*`=numeric EUR, `*_cent/_cents`=integer,
`valuta_*/metadata/config_json/identificazione_cliente`=jsonb, id=uuid, `*_at`=timestamptz). Nessun
tipo da cambiare sulle 15 tabelle. Al factory setup applichiamo ENTRAMBI gli .sql (prima il vostro
cash-truth, poi il nostro solo-app), idempotenti, come concordato.

## 2. Le 3 tabelle rimaste — colonne attese dall'app

### 2a. `kiosk_comandi` (coda comandi app→Pi; il Pi aggiorna lo stato) — ⚠️ DRIFT da correggere
Il nostro modello legge PIÙ colonne dello schema legacy. Colonne attese:

```
id                        uuid PK default gen_random_uuid()
kiosk_id                  uuid NOT NULL -> kiosk_dispositivi(id) ON DELETE CASCADE
comando                   text NOT NULL
stato                     text NOT NULL default 'pending'
creato_da                 text            -- operatore (uuid come stringa) che ha creato il comando
preso_in_carico_at        timestamptz     -- il Pi lo setta quando prende in carico
completato_at             timestamptz     -- il Pi lo setta a fine esecuzione
risposta                  text            -- esito/output del Pi (testo o JSON)
motivo_fallimento         text
created_at                timestamptz NOT NULL default now()
manual_confermato_da      uuid
manual_confermato_da_nome text
manual_confermato_at      timestamptz
manual_confermato_note    text
```

⚠️ **Enum — allineare ai valori REALI dell'app (NON i CHECK legacy):**
- `comando` deve includere almeno `ping`, `restart_sgm`, `reboot` (+ comandi operatore low-risk).
  Il CHECK legacy `('reboot','shutdown','restart_sgm','refresh','test')` **manca `ping`** → rifiuta
  il refresh stato della Dashboard. Meglio **niente CHECK** su `comando` (o CHECK esteso) per non
  bloccare comandi futuri.
- `stato` ∈ `pending` → `in_progress` → `completato` | `fallito` | `annullato` | `manual_confirmed`.
  Il CHECK legacy `('pending','eseguito','fallito')` usa **`eseguito`**: il nostro modello NON lo
  riconosce (→ label/decode sbagliati). Usare **`completato`**, non `eseguito`.

Flusso: l'app inserisce `{kiosk_id, comando, stato='pending', creato_da}`; il Pi aggiorna
`stato`/`preso_in_carico_at`/`completato_at`/`risposta`/`motivo_fallimento`.

### 2b. `depositi_incasso_turno` (deposito iPRO per turno) — DDL autorevole app
La teniamo noi in NeomaticSchema; ve la giro per allineare (se la scrivete anche voi):

```
id            uuid PK default gen_random_uuid()
kiosk_id      uuid NOT NULL -> kiosk_dispositivi(id) ON DELETE CASCADE
operatore_id  uuid -> app_users(id) ON DELETE SET NULL
operatore_nome text
totale_cent   integer NOT NULL CHECK (>= 0)
totale_eur    numeric(12,2) GENERATED ALWAYS AS (totale_cent/100.0) STORED
breakdown     jsonb NOT NULL default '{}'       -- {"5000":1,"2000":2,...} (taglio_cent:pezzi)
source        text NOT NULL default 'ipro'      CHECK IN ('ipro','manuale')
stato         text NOT NULL default 'completato' CHECK IN ('in_progress','completato','annullato','rettificato')
note          text
created_at    timestamptz NOT NULL default now()
completed_at  timestamptz NOT NULL default now()
```

### 2c. `chiusure_contabilita` — app-only (contabilità di SALA), NON cash-truth SGM
È la chiusura contabile di SALA (P&L: vlt/awp/betting/bar…), scritta SOLO dall'app, mai da SGM.
**Raccomandazione: lasciatela FUORI dal vostro `supabase_schema.sql`** — la teniamo noi in
NeomaticSchema (tabella solo-app, come `app_settings`/`audit_log`). Elenco solo per riferimento/diff:

```
id uuid PK · data_chiusura text(yyyy-MM-dd) · direttore_nome text · created_at timestamptz
vlt_pagamenti / awp_refill / bet_raccolta / bet_pagamenti / bar_incasso / vincite_biglietti   numeric
periodo_decade text · fondo_ricarica / da_versare_banca / betting_deposito / betting_pos       numeric (opz.)
periodo_da / periodo_a text · vlt_incasso_registrato / residuo_tito / betting_incasso_manuale /
    residuo_bet / residuo_storico   numeric (opz.) · forced boolean · note text
```

NB: stiamo **sfoltendo la parte "sala"** dell'app; questa tabella resta solo perché il ruolo
Commesso la usa per la chiusura turno. Se nemmeno voi la scrivete, confermate e resta app-only.

## 3. get_hardware — consumer PRONTO lato app
Implementato: **modello `hardware[]`/`unita[]`** (`key/ruolo/model/stato` + `taglio_cent/capienza/
livello/stato`) + parser. La Dashboard genera le righe hardware in modo **dinamico** (device
`assente` nascosti, tagli reali per cassetta dalla CDM6240N). Manca solo che `get_hardware` entri
in `NETWORK_ALLOWED_ACTIONS` + capability nell'hello/INFO: appena live lo chiamiamo sul canale
`/connect/command` (session_id). Nel frattempo usiamo `kiosk_hardware_state` (stato device) +
`kiosk_livelli_cash` (livello+taglio per cassetta), già allineati ai vostri enum.
