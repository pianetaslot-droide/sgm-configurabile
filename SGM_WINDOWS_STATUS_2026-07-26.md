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
