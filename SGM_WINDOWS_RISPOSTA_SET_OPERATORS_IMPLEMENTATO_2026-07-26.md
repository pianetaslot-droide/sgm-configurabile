# SGM/Windows → App iOS — set_operators IMPLEMENTATO (build v44) (2026-07-26)

Ricevuto il vostro CONFERME (§1 Connect C09A, §2 pbkdf2 verbatim). **Implementato e testato.**
Nella build **v44**. Ecco il contratto esatto così l'app spinge senza tentativi.

## Azione: `set_operators` (Connect C09A, technician_pin-gated, full-replace)

Annunciata in `INFO.capabilities` (hello). Stessa famiglia di `set_config`.

**REQUEST** (payload):
```json
{
  "action": "set_operators",
  "session_id": "<sessione Connect>",
  "payload": {
    "technician_pin": "<PIN tecnico macchina>",
    "operators": [
      { "id": "<uuid>", "nome": "Mario Rossi", "ruolo": "supremo",   "pin_hash": "pbkdf2$200000$<salt_hex>$<hash_hex>" },
      { "id": "<uuid>", "nome": "Anna Bianchi","ruolo": "direttore", "pin_hash": "pbkdf2$200000$<salt_hex>$<hash_hex>" },
      { "id": "<uuid>", "nome": "Luca Verdi",  "ruolo": "commesso",  "pin_hash": "pbkdf2$200000$<salt_hex>$<hash_hex>" }
    ]
  }
}
```
- `ruolo` ∈ {**supremo, direttore, commesso**} (case-insensitive). SGM mappa → level 0/1/2 +
  permessi. `config` NON va incluso (non è un operatore touch).
- `pin_hash` = la vostra stringa pbkdf2 **verbatim** (`pbkdf2$<iter>$<salt_hex>$<hash_hex>`).
  SGM ne valida solo la forma e la salva così com'è; il login la verifica con `verify_pin`
  esistente. Il PIN in chiaro non lo vediamo mai.
- **Full-replace atomico**: `connect_roles` viene svuotata e ricreata dallo snapshot in UNA
  transazione; le sessioni autenticate vengono invalidate. Validazione all-or-nothing: se un
  operatore è invalido, NIENTE viene applicato (nessun replace parziale).

**REPLY** (ok):
```json
{ "ack": true, "status": "ok",
  "payload": { "applied_count": 3, "removed_count": 5, "snapshot_hash": "<sha256>", "supremo_count": 1 } }
```
- `snapshot_hash` = sha256 su `(id, nome, level, pin_hash)` ordinato, **order-independent** →
  confrontatelo col vostro per confermare che è atterrato ESATTAMENTE quello snapshot e
  azzerare il dirty flag.
- `supremo_count` informativo: 0 è ammesso (vedi sotto), ma potete avvisare se una sala resta
  senza supremo.

**REPLY errori** (ack=false, reason=…): `technician_pin_required` / `invalid_technician_pin` /
`technician_pin_not_set_on_machine`, `operators_required` (non è una lista), `invalid_operator`,
`operator_id_required`, `duplicate_operator_id:<id>`, `operator_name_required`,
`invalid_ruolo:<x>`, `invalid_pin_hash`.

## Touch login → autentica contro lo snapshot (con fallback sicuro)

Confermato §4: il touch ora autentica **prima** contro lo snapshot locale (`connect_roles`,
offline, senza rete). Se il PIN non è nello snapshot, fallback su Supabase `app_users`. Non
è bloccante: gli operatori pushati via `set_operators` funzionano SENZA rete; prima del primo
push `connect_roles` è vuota → puro Supabase = esattamente il comportamento di oggi. Man mano
che spingete lo snapshot, il touch diventa offline-capace.

## Cash-safety / mai brick (§5)

- Snapshot **vuoto o senza supremo = AMMESSO** (non rifiutato): il **PIN tecnico/master**
  (oggi `111111`) funziona SEMPRE come supremo, quindi il touch non si blocca mai.
- Il PIN tecnico NON è nello snapshot e non viene toccato da `set_operators`.
- Bypass di test `"000000"` = supremo: lo lascio, lo **gate a debug** in una prossima build
  (come chiesto), così non è un buco in produzione.

## Note

- `full-replace` rimuove gli operatori non più nello snapshot: assicurate ≥1 supremo negli
  snapshot normali (il tecnico resta come rete di sicurezza).
- Potete spingere `set_operators` ad ogni cambio `app_users` (è idempotente sul contenuto: se
  lo snapshot non cambia, `snapshot_hash` è identico).
- Consegno v44 (include anche il backfill Flussi di oggi, handoff separato).
