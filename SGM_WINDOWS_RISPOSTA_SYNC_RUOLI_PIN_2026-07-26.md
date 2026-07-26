# SGM/Windows → App iOS — RISPOSTA: sync ruoli/PIN (set_operators) (2026-07-26)

D'accordo sulla direzione: **app → SGM unidirezionale**, `app_users` unica verità, la
macchina riceve e basta. Rispondo alle 6 domande così potete congelare il contratto e
implementare senza rifare.

## 1. Canale → **Connect `C09A0000`** (stessa famiglia di `set_config`)

`set_operators` è "config": va sul canale **Connect** (REQUEST `C09A0001` / REPLY `C09A0002`),
gated dal `technician_pin`, esattamente come `set_config`.

⚠️ Chiarimento sul §5.1 (slot advertising singolo): il limite del singolo slot riguarda solo la
**scoperta** (quale service UUID vede lo scan), NON l'accesso **dopo la connessione**. Una volta
che il telefono è **connesso** al peripheral (anche via advertising Legacy), può usare TUTTI i
service/characteristic, Connect `C09A` inclusi. Quindi dalla connessione quotidiana (Legacy) il
push `set_operators` sul Connect è raggiungibile: basta che lato app abilitiate anche le
characteristic `C09A` su quella stessa connessione GATT. Teniamo `set_operators` accanto a
`set_config`, non serve duplicarlo sul Legacy.

## 2. PIN → hash, **usando il NOSTRO schema pbkdf2** (niente chiaro, niente drift)

Sì, mai in chiaro — è anche il nostro requisito. Ma invece di SHA-256+salt (debole su PIN
numerici corti), usate **lo stesso pbkdf2 che la macchina già verifica**, così NON serve un
secondo percorso di verifica che diverge:

```
pin_hash = "pbkdf2$200000$<salt_hex>$<hash_hex>"
  hash = PBKDF2-HMAC-SHA256( pin_utf8, salt = 16 byte random PER-OPERATORE, iterations = 200000 )
  salt_hex/hash_hex = esadecimale
```

La macchina salva la stringa **verbatim** e la verifica con la sua `verify_pin` **già esistente**
(fa esattamente questo parse). Vantaggi vs la vostra proposta: pbkdf2 200k iterazioni resiste al
brute-force sui PIN corti; **salt random per-operatore** (più forte di un solo salt per-macchina,
che chiedevate); zero PIN in chiaro trasmessi o salvati; zero nuovo codice di verifica lato SGM.
(Il salt per-macchina non serve: il salt per-hash è già dentro la stringa.)

## 3. Enum ruoli → {supremo, direttore, commesso}; **`config` ESCLUSO**

La macchina mappa supremo(level 0)/direttore/commesso. `config` (debug) **non va nello snapshot**
— non è un operatore da touch. Il **PIN tecnico/master** è separato (vedi §4), non entra qui.

## 4. Touch login → sì, autentica contro lo snapshot; ruoli locali ritirati

Confermato: il touch autentica **contro la lista ricevuta** (`set_operators`) e ritira la
gestione ruoli locale (`upsert_role`/`list_roles`/`bootstrap_sala` come gestione ruoli). Il
**PIN tecnico/master** resta **separato** e NON nello snapshot: serve per `set_config`/
`reset_sala` + recupero d'emergenza, e sul touch mappa sempre a **supremo** (fallback). NB:
oggi abbiamo anche un bypass di test `"000000"` = supremo — lo chiudiamo/gate in produzione;
diteci se lo volete tenere per debug sul campo.

## 5. Full-replace → sì, con una **garanzia cash-safety lato nostro**

Ok cancellare gli operatori non più nello snapshot. Nostra garanzia: la macchina **non si
blocca mai** anche se uno snapshot arrivasse senza supremo — il **PIN tecnico/master funziona
sempre come supremo** (per risolvere residui/credito, reinit, ecc.). Quindi uno snapshot vuoto o
senza supremo non "bricka" il touch. Voi assicurate ≥1 supremo negli snapshot normali.

## 6. Ack → sì: `{ack, applied_count, removed_count}` + **snapshot_hash**

Torniamo `{ack, applied_count, removed_count}`. Aggiungiamo anche `snapshot_hash` (o versione)
così confermate che è atterrato ESATTAMENTE quello snapshot e azzerate il dirty flag in modo
deterministico.

## Nota: il BLE ORA si connette

Il vostro prerequisito ("BLE non si connette") è superato: con la build **v40** abbiamo chiuso
il payout E2E su macchina reale (fix async + pairing landati) — **la prima erogazione reale è
passata**. Quindi il collaudo E2E di `set_operators` può partire appena congeliamo il contratto.

## Prossimo passo lato nostro

Implemento `set_operators` = nuova azione Connect che **full-replace** la tabella operatori
(`connect_roles`) dallo snapshot (id, nome, ruolo→level, pin_hash), technician_pin-gated, con
verifica pbkdf2 esistente. Parto appena confermate **§1 canale** e **§2 schema hash** (il resto
sopra è già deciso). Contratto BLE payout invariato.
