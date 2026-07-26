# SGM/Windows → App iOS — confini turno/chiusura: preferenza + nota turni (2026-07-26)

Ricevuto il vostro OK. Rispondo alla domanda su COME l'app ci comunica i confini periodo, e
confermo di aver recepito il fix `turni.inizio_turno`.

## Preferenza sui confini turno/chiusura (nessuna urgenza)

Preferenza SGM, in due tempi:

- **Ora (interim, zero lavoro app):** SGM continua a **leggere i confini da Supabase come
  replica** (`turni` / `chiusure_contabilita`) e li proietta in locale (già li cachiamo:
  `_cached_turno_id` / `_cached_chiusura_at`). Gli **importi sono già 100% locali**; l'unica
  cosa che tocca Supabase è la *finestra*. Con il vostro fix `inizio_turno DEFAULT now()` questa
  lettura è ora affidabile (grazie — era proprio il valore NULL a darci fastidio nella finestra).

- **Full local-first (quando facciamo il passaggio):** preferiamo che **l'app spinga i confini
  a SGM sul canale locale** già esistente (BLE/Tailscale, SGM Connect) con una piccola azione
  dedicata tipo `set_turno` / `set_chiusura` (open/close + timestamp). Così SGM non dipende più
  da Supabase nemmeno per la finestra e la home resta operativa **offline**. È la strada
  coerente con la north-star (locale = verità, Supabase = replica/backup).

Motivo per cui NON scegliamo "l'app scrive i confini direttamente nel DB locale di SGM": il DB
locale (SQLite su ProgramData) è di proprietà di SGM e non va scritto da fuori; meglio un
messaggio sul protocollo, che SGM valida e persiste lui.

Proposta operativa: teniamo l'interim (Supabase-replica) finché non pianifichiamo il passaggio;
quando lo facciamo, definiamo insieme il payload di `set_turno`/`set_chiusura`. Nessuna fretta —
ditemi se siete d'accordo con questa stadiazione.

## Fix `turni.inizio_turno` — recepito

Perfetto, con `inizio_turno` sempre valorizzato la nostra finestra home lo legge senza il caso
NULL. Nessuna azione richiesta da parte nostra. Grazie.
