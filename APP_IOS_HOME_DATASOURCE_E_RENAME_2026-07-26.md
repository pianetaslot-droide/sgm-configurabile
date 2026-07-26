# App iOS → SGM/Windows — sorgente dati home + rename VNE→SGM + label (2026-07-26)

Provisioning testato E2E con successo: `set_config` dall'app ha scritto il nuovo Supabase sulla
macchina → la macchina è passata da NON configurata a configurata → la **home operativa è
comparsa** (prima non mostrava dati), puntando al Supabase nuovo. 🎉 Grazie, il flusso funziona.

Tre domande / richieste emerse dal test.

## 1. Sorgente dati della HOME macchina (⭐ verifica north-star)

Osservazione: **prima** di `set_config` la home NON mostrava dati; **dopo** mostra i riquadri a
€0,00 (CAMBIO F1/F2, SNAI BETTING F3, TITO/VLT F4, TOTALE EROGATO). Il fatto che compaiano solo
DOPO aver configurato il Supabase fa sospettare che la home **legga da Supabase**.

Domanda: i totali/contatori della home vengono da:
- (A) il **ledger LOCALE** della macchina (SQLite) — e la home appare solo perché la macchina
  entra in "modalità configurata"? → coerente con la north-star (cash = verità locale, Supabase
  = solo sync/backup); oppure
- (B) la home **legge direttamente da Supabase** i totali cassa?

Se è (B), è un problema di north-star: la verità cassa NON dovrebbe dipendere da Supabase
(dev'essere locale, Supabase è solo replica). Confermateci quale delle due, e se è (B) valutiamo
di spostare la fonte sui dati locali. (Se è (A), tutto ok — era solo il gating "configurata".)

## 2. Rename UI macchina: VNE → SGM

La home mostra ancora **"VNE Plus Change — SGM"** nel titolo e **"VNE SALA 1"**. Come concordato
(la macchina si chiama **SGM**, non VNE), potete rinominare la UI touch della macchina? Lato app
il rename è già fatto ovunque; manca la UI della macchina.

## 3. Label da set_config: quando si applica sul display

In `set_config` inviamo `label` (es. la sala/etichetta scelta nel wizard), e voi la scrivete anche
come `ble_adv_name`. Ma il display macchina mostra ancora "VNE SALA 1" (label vecchia). Domanda:
il nuovo `label` sul display (e sul nome adv BLE) si applica **dopo il riavvio del servizio**
(`restart_required`)? Confermate così sappiamo cosa dire all'operatore nel wizard.

Nessuna urgenza sul contratto BLE (invariato). Grazie.
