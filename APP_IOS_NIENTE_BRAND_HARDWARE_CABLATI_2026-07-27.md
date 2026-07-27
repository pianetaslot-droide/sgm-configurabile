# App iOS → SGM/Windows — produzione di massa: NIENTE brand/modello hardware cablati (usare FUNZIONE) (2026-07-27)

## Regola (Hu Leo, ferrea)
Siamo in **PRODUZIONE DI MASSA**: macchine diverse montano hardware diverso. Da nessuna parte —
UI **né dati** — vanno scritti a mano brand/modelli specifici e vecchi (`F53`, `Fujitsu F53`, `iPRO`,
`JCM iPRO`, `CDM`, `CDM6240N`, `VNE`, `Comestero`). Si usano SOLO nomi di **FUNZIONE / ruolo**:
- `banknote_dispenser` → «Erogatore banconote»
- `bill_acceptor`      → «Accettatore / Lettore banconote»
- `coin_hopper`        → «Hopper monete»
- reject box           → «Scarto»

Il **modello reale** si mostra SOLO se quell'hardware è davvero montato, e SOLO **sincronizzato** da
`get_hardware.model` (es. `grg_cdm6240n`, `jcm_ipro`). Mai indovinato/cablato.

## Cosa abbiamo già fatto lato app
Ripulito TUTTA la UI dai brand (F53/iPRO/Fujitsu/JCM/CDM → funzione). Le righe hardware della
Dashboard usano la funzione + il modello da get_hardware quando è live.

## Cosa chiediamo a voi (SGM)
1. **`descrizione` in `kiosk_livelli_cash`**: l'app, se la riga ha `descrizione` valorizzata, la
   MOSTRA così com'è. Quindi **NON** scriveteci brand (es. "Cassetto F53 #1", "Scarto F53",
   "Accettatore iPRO"). O lasciate `descrizione = NULL` (l'app deriva un'etichetta di funzione da
   `unita`: Cassetto #1, Scarto banconote, ecc.), oppure usate nomi di funzione, mai il brand.
2. Idem per qualsiasi **label/testo** che spingete verso l'app (eventi, note, ecc.): funzione, non brand.
3. Il brand/modello reale va **solo** in `get_hardware.model` — lì va benissimo (è la verità
   sincronizzata, per quello serve).
4. Le `key`/`tipo`/`ruolo` di contratto (`f53`/`ipro`/`hopper`/`cctalk`) restano come sono (sono
   identificatori tecnici, non display) — no problem.

Obiettivo: una macchina con un dispenser diverso (non-CDM) o un acceptor diverso (non-iPRO) NON deve
far comparire nomi sbagliati. Tutto guidato da funzione + get_hardware. Grazie.
