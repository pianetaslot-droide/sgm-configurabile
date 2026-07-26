# App iOS → SGM/Windows — CONFERME: canale+hash ruoli, no_50 bordo, bypass (2026-07-26)

Ricevute le tre grandi notizie: **BLE/v40 payout reale ✅**, **no_50 v42 ✅**,
**contratto ruoli ✅**. Rispondo così sbloccate l'implementazione.

## set_operators — confermo §1 e §2 → PROCEDETE pure
- **§1 Canale: Connect `C09A0000`** ✅. L'app spinge `set_operators` sulla stessa
  connessione GATT (dopo il connect abilitiamo le characteristic C09A), technician_pin-gated.
- **§2 Hash: pbkdf2, schema VOSTRO verbatim** ✅:
  `pbkdf2$200000$<salt_hex>$<hash_hex>` — PBKDF2-HMAC-SHA256, salt 16 byte random
  **per-operatore**, 200k iter. La macchina verifica con `verify_pin` esistente.
- Resto già deciso da voi (config ESCLUSO, full-replace + technician fallback, ack +
  snapshot_hash). Implementate pure `connect_roles` full-replace. **Lato app INIZIO ORA**
  a scrivere il push (pbkdf2 + snapshot da `app_users` + invio Connect + dirty flag +
  trigger provision/cambio-PIN).

## no_50 (vostra domanda 4) → **best-effort, confluisce nel resto** ✅
Teniamo il vostro default: la quota "senza €50" non componibile coi tagli piccoli
**confluisce nel resto (può usare €50)**; cliente sempre pagato per intero. NON serve
residuo esplicito. (Priorità: pagare il cliente > preferenza tagli.)

## bypass "000000" = supremo → **tenetelo, ma GATED a debug**
Hu Leo lo vuole per il debug sul campo. Tenetelo, ma con **gate esplicito** (attivo solo
in modalità debug/config, non in esercizio normale, non evidente sul touch), così non è un
buco in produzione.

## Pendenti collegati
- **v42**: consegnate pure; poi ripetiamo il test €150·€50 (atteso 2×€20+1×€10+2×€50).
- **Flussi vuoti**: vedi handoff separato `APP_IOS_FLUSSI_VUOTI_MIRROR_SUPABASE_NUOVO`
  — sospetto il mirror punti ancora al Supabase VECCHIO invece che a quello di
  `set_config`. Priorità alta: senza, Flussi/Livelli/Dashboard restano vuoti anche a
  payout perfetto (v40).
