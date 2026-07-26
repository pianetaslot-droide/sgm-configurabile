# SGM/Windows → App iOS — RISPOSTA: sorgente dati home + rename + label (2026-07-26)

Grazie per la conferma E2E del provisioning. Rispondo ai 3 punti.

## 1. Sorgente dati HOME — è (A), con una precisazione

**Risposta: (A).** La verità cassa NON dipende da Supabase. Nel codice
(`DashboardMetrics`, costruito con `local_ledger=local_first_ledger`):

- **Importi e conteggi** (CAMBIO F1/F2, SNAI/BETTING F3, TITO/VLT F4, TOTALE EROGATO)
  vengono dal **ledger LOCALE** (SQLite Pi-local) — è la source of truth. Le vecchie
  tabelle `pagamenti_betting` / `pagamenti_tito` restano solo **fallback/proiezione**
  per il reporting, usate soltanto se il ledger locale non è presente (qui è sempre
  presente).
- Durante un pagamento in corso la home passa a `_fetch_local_only_sync` → **solo
  dati locali**, Supabase non viene nemmeno interrogato.
- Se Supabase è lento/irraggiungibile, la fetch va in timeout a 1,5 s e usa
  l'ultimo risultato in cache: **gli importi non si azzerano** per colpa del cloud.

**Perché la home compariva solo DOPO `set_config`:** due motivi, nessuno dei quali è
"la cassa legge da Supabase":
1. **Gating "macchina configurata"**: senza Supabase configurato la macchina non
   entrava in modalità operativa, quindi la home operativa non veniva mostrata.
2. **Confini del periodo di visualizzazione** (ultima *chiusura* di sala + *turno*
   corrente): questi due oggetti — che sono concetti gestiti lato iOS — oggi vengono
   letti da Supabase (`chiusure_contabilita`, `turni`). Servono solo a definire la
   *finestra temporale* ("da quando" sommare); gli **importi dentro la finestra
   restano locali**.

Quindi: north-star rispettata sugli importi. L'unica dipendenza residua da Supabase è
la **definizione della finestra turno/chiusura**. Se volete chiudere anche quella,
possiamo spostare la sorgente dei confini turno/chiusura su API Pi-local (quando l'app
sarà pronta a scriverli localmente): a quel punto la home è 100% local-first anche
sui confini di periodo, non solo sugli importi. Diteci se lo mettiamo in roadmap.

## 2. Rename UI macchina VNE → SGM — FATTO

Rimossi tutti i default/label "VNE" dalla UI touch della macchina:
- Titolo header: era **"VNE Plus Change — SGM"** → ora **"SGM"**.
- Etichetta dispositivo di default: era **"VNE-Sala1"** → ora **"SGM"** in tutti i
  fallback (config, display, bridge env, nome adv BLE di default).

Da build corrente in poi la UI non mostra più "VNE". Dove è impostata una `label`
esplicita da `set_config`, viene mostrata quella (vedi punto 3).

## 3. Label da `set_config` sul display — sì, dopo restart del servizio

Confermato: la `label` inviata con `set_config` viene scritta nella config macchina e
usata sia come **titolo/etichetta sul display** sia come **nome adv BLE**. Si applica
**dopo il riavvio del servizio SGM** (`restart_required: true`, già nel reply di
`set_config`). Finché il servizio non riparte, il display mostra la label precedente.

**Cosa dire all'operatore nel wizard:** dopo aver salvato la configurazione, la nuova
etichetta compare su display e nel nome BLE **al riavvio della macchina/servizio**.

Contratto BLE invariato. Grazie.
