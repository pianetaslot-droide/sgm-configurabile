# SGM (Windows/Python) — stato 2026-07-26

Aggiornamento rispetto a `SGM_WINDOWS_STATUS_2026-07-25.md` (non sostituito,
resta valido per Fase 0/Fase 1). Copre due cose fatte oggi lato SGM.

## `reset_sala` implementato — E un mio errore di tempistica

Implementato esattamente contro la spec che Hu Leo ha proposto in
`BLE_PROTOCOL_CONTRACT.md` (stessa forma request/reply/reason), gated solo
dal PIN tecnico reale della macchina, senza richiedere un login esistente
(è il meccanismo di recupero per quando NESSUNO riesce più a loggarsi).
Test unitari completi: bootstrap → "PIN perso" simulato → reset con PIN
sbagliato rifiutato senza toccare i dati → reset con PIN corretto → nuovo
bootstrap con PIN noto → login riuscito.

**Errore fatto**: ho letto il blocco "PIN del supremo perso" nel contratto
(commit `afab4de`) e ho ESEGUITO `reset_sala` su questa macchina reale
prima di fare un altro `git pull` — quindi prima di vedere che quel blocco
era già stato corretto (falso allarme, problema di riconnessione lato app)
e che Fase 1 era già stata chiusa con successo usando proprio quel ruolo.
Il reset ha quindi cancellato un ruolo supremo già validato e in uso, non
uno davvero perso. Vedi l'avviso in cima a `BLE_PROTOCOL_CONTRACT.md` per
il dettaglio completo rivolto al lato app.

Lezione applicata da qui in avanti: `git pull` immediatamente prima di
qualunque azione che tocca lo stato della macchina condivisa, non solo
all'inizio della sessione di lavoro.

## Batch 1 redesign UI (fornito da Hu Leo via GPT, integrato oggi)

Revisionato riga per riga prima di integrare (diff `display.py.patch` +
`themes.py.patch` + 3 file nuovi `layout.py`/`type.py`/`adaptive_admin.py`).
Entrambi i patch si applicano puliti (`patch --dry-run`, zero fuzzy/reject)
contro il mio codice attuale — buon segno di allineamento con l'ultima
versione della sorgente.

Cosa fa: introduce un sistema di layout basato sulla risoluzione fisica
reale dello schermo (non più il canvas fisso 1024×768) con una regola
tipografica che forza `line_box >= 1.35 × size` — proprio la classe di bug
di sovrapposizione font segnalata in
`SGM_WINDOWS_STATUS_HANDOFF_2026-07-24.md` §4.1. Applicato SOLO a due
schermi già approvati: "Stato macchina" (S3) e "Deposito — Riconciliazione"
(S4c) — quelli con la sovrapposizione confermata. Tutti gli altri schermi
(Hardware, CDM6240N, BLE, Impostazioni, teorico deposito, ecc.) restano sul
canvas legacy, invariati. Temi ridotti a due ufficiali: Apple (chiaro) e
Casino (verde notte/champagne); i vecchi villa/glass/pastel restano nel
codice ma non più selezionabili, con migrazione automatica a Apple per chi
li aveva già scelti.

Verificato con la mia suite di test completa (Fase 0, Fase 1, hardware
menu, deposito) più nuovi test dedicati al routing adattivo — tutto verde,
nessuna regressione sugli altri schermi. **Non verificato l'aspetto visivo
reale su schermo fisico** — solo hit-test/logica, il rendering vero va
controllato da voi sul touch.

## `get_cash_levels` (Fase 2, prima azione cassa) implementato

Contro la spec §11 del contratto, congelata oggi con due correzioni (vedi
il changelog del contratto per il dettaglio): `device_id` per-cassetta
invece del device fisico ripetuto 5 volte, e `nominal_capacity`/
`low_threshold` documentati come sempre `null` per ora (mai scritti da
`provision_cdm6240n_sync`) con `is_low` aggiunto come segnale reale
alternativo per "cassetta in esaurimento". Gate su permesso
`viewMonitoring` (stesso schema di autenticazione di sessione di Fase 1).
Sorgente dati: le stesse tabelle `cash_unit_config`/`cash_unit_snapshots`
già usate da "Stato macchina" sul touch — nessuno schema nuovo.

Test unitari completi (gate di permesso, tutti e 5 gli slot sempre
presenti, slot mai osservato → null non un finto 0). Non testato su BLE
reale — serve l'implementazione app per la verifica congiunta.
Pacchettizzato in `SGM-Windows-CDM6240N-Management-20260726-v12.zip`.

Ho anche visto la nuova proposta §12 (pagamento ticket TITO/Betting,
rischio ALTO). Non l'ho toccata — resta "NIENTE codice" finché non è
congelata, come dichiarato nel documento stesso, ed essendo denaro reale
è comunque una decisione che aspetto da Hu Leo prima di procedere anche
solo con la revisione tecnica.
