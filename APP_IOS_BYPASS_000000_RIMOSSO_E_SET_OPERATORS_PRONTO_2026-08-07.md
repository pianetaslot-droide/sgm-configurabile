# App iOS → SGM/Windows — bypass 000000 RIMOSSO + set_operators ora inviabile dall'app (2026-08-07)

Ricevuto "test col Supabase spento". Fatte entrambe le cose che ci riguardavano.

## 1. ⚠️ Bypass PIN `000000` — CONFERMATO e RIMOSSO anche lato app
Avevate ragione: esisteva anche nell'app. In `loginWithPin` un ramo speciale intercettava
`pin == "000000"` **prima di qualsiasi verifica** e restituiva un supremo sintetico (`testUser`,
ruolo supremo). Su un iPhone in sala = account supremo per chiunque conosca il codice.
**Rimosso**: via il ramo e via l'utente fittizio. Nessun residuo (`grep testUser|"000000"` = 0).
Per i test si crea un utente VERO dal pannello operatori, come suggerite. Grazie della segnalazione.

## 2. `set_operators` — l'app ora può inviarlo (nuova UI)
Il client c'era già (`OperatorSyncService`: full-replace, `pin_hash` pbkdf2 200k, `config` escluso,
safety "almeno un supremo"), ma era invocato **solo dal wizard di provisioning di fabbrica** →
se la macchina non era stata provisionata da questa app, o se gli operatori sono cambiati dopo,
`connect_roles` restava vuoto/vecchio. **Esattamente il vostro caso (0 righe).**

Aggiunto: **Pannello Kiosk → Impostazioni → «Operatori sulla macchina»** (BLE, technician_pin),
con badge arancione quando ci sono modifiche non ancora inviate (dirty flag già settato ad ogni
create/update/delete di `app_users`). Da lì Hu Leo può rinviare lo snapshot quando vuole —
**lo faremo prima di spegnere il cloud**. Payload come da contratto: `{technician_pin, operators:[{id,nome,ruolo,pin_hash}]}`.

## 3. Sul resto del test — ok, allineati
- Pagamenti/livelli/`/connect/command` locali: perfetto, è quello che ci serve.
- `kiosk_comandi` fermo col cloud spento: atteso. Per pilotare la macchina useremo la fast-path
  `/connect/command` (già cablata lato app per status/restart_sgm/reboot + get_hardware).
- `kiosk_livelli_cash`/Flussi congelati e riallineati dalla coda: chiaro, non li leggeremo come "macchina ferma".
- Grazie per il fix del timeout 120s→5s sulla lettura `kiosk_hardware_state` pre-erogazione.

## 4. v64 livelli — confermiamo il vostro fix, e una nota
Il mirror che ripubblicava lo storico più vecchio (3708 arretrati) spiega **esattamente** quello che
vedevamo (cloud `0/100/100/100/1` vs reale `5/38/47/94/1`). Con v64 (solo ultimo valore per cassetta
+ auto-seed righe + `descrizione` NULL) l'app legge il livello reale senza fare nulla: 👍.
Nota: l'app oggi, quando ha una sessione, chiama `get_hardware` e riporta `unita[].livello` in
`kiosk_livelli_cash` (solo `livello_attuale`/`denom_cent`, mai soglie/enabled). Con v64 diventa
ridondante ma innocuo (stessa fonte). Se preferite che l'app NON scriva affatto quei campi — così la
scrittura resta solo vostra — ditecelo e lo togliamo: per noi va bene, è più pulito.

## 5. Confini periodo (turno/chiusura) su API locale
Sì, ci interessa — ma non blocca questo test. Proponetelo pure quando volete affrontarlo.
