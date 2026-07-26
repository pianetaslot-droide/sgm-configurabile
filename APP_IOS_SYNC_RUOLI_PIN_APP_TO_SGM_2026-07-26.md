# App iOS → SGM/Windows — sync ruoli/PIN (app → SGM, UNIDIREZIONALE) (2026-07-26)

## Contesto: gap lasciato dal pivot Neomatic
Col pivot a Neomatic, ruoli/account/autenticazione sono diventati **NATIVI dell'app**
(tabella `app_users`: `id`, `nome`, `ruolo` ∈ {supremo,direttore,commesso,config}, `pin`).
Da SGM Connect abbiamo tenuto **solo il protocollo pairing** — le UI/azioni ruoli
(`bootstrap_sala`/`login`/`list_roles`/`upsert_role`) lato app sono state **ELIMINATE**.

Risultato oggi: **due set di PIN scollegati**
- app: `app_users` (verità)
- macchina SGM: i suoi ruoli/PIN locali (vecchio modello "ruoli sulla macchina")
→ un PIN creato/cambiato in app **NON** esiste sul touch della macchina, e viceversa.
Questo è il "ruoli/PIN non sincronizzati" segnalato da Hu Leo.

## Decisione presa (Hu Leo)
- **Direzione: app → SGM, UNIDIREZIONALE.** `app_users` è l'**unica** verità; la
  macchina RICEVE e basta (non gestisce più ruoli propri).
- **Ambito: TUTTI i ruoli** (supremo/direttore/commesso/config).
- **Trigger: al provisioning + push ad ogni create/modifica PIN in app**
  (se BLE non connesso → flag "dirty" lato app → push al primo hello utile).

## Proposta di contratto: nuova azione `set_operators` (full-replace)
```json
{ "action": "set_operators",
  "operators": [
    {"id":"<uuid>","nome":"Mario","ruolo":"commesso","pin_hash":"<hex>","attivo":true},
    {"id":"<uuid>","nome":"Anna","ruolo":"supremo","pin_hash":"<hex>","attivo":true}
  ],
  "replace": true }
```
Semantica: la macchina **sostituisce integralmente** la sua tabella operatori con
questo snapshot. Il touch autentica confrontando col `pin_hash` ricevuto.

## Domande a voi (servono per implementare lato app SENZA rifare)
1. **Canale**: `set_operators` su quale GATT? Connect `C09A0000` (coerente con
   `set_config`, "config") o Legacy `a1000000` (la connessione di TUTTI i giorni su
   cui gira il payout)? È legato a §5.1 (convivenza Legacy/Connect su una radio):
   il push "ad ogni cambio PIN" avviene nell'**app quotidiana**, connessa al
   **Legacy** — quindi ci servirebbe l'azione **sul Legacy**, a meno che Connect
   non resti disponibile sulla stessa connessione GATT. **Ditecelo voi.**
2. **PIN: hash o chiaro?** In `app_users` il PIN oggi è in **CHIARO**. Preferiamo
   **non** trasmettere/salvare PIN in chiaro sulla macchina: proponiamo
   `pin_hash = SHA-256(salt || pin)` con **salt per-macchina** che ci fornite voi
   (i PIN sono numerici corti → senza salt sono forzabili). Il vostro touch può
   autenticare **per hash**? Se il touch DEVE gestire il PIN numerico in chiaro,
   ditecelo e rivalutiamo. **Qual è il vostro requisito di sicurezza?**
3. **Enum ruoli**: i ruoli-macchina accettano {supremo/direttore/commesso/config}?
   `config` è un ruolo di **debug**: lo volete sul touch o lo escludiamo dal push?
4. **Touch login**: confermate che il touch passa a "autentica contro la lista
   ricevuta da app" e **dismette** il vecchio sistema ruoli locale
   (list_roles/upsert_role)? Il **PIN tecnico di bootstrap** (per set_config/
   reset_sala) resta **separato** e non entra in questo snapshot, giusto?
5. **Full-replace**: ok cancellare gli operatori non più presenti nello snapshot
   (utente rimosso in app → sparisce dal touch)? O preferite un merge?
6. **Ack**: la reply di `set_operators` deve tornare `{ack, applied_count,
   removed_count}` così l'app conferma la sync e azzera il flag dirty. Va bene?

## Prerequisito noto
Il BLE oggi **non si connette** (§7 slot advertising singolo + build **v36** in
arrivo). Lato app implementiamo preparazione dati + trigger + flag dirty; il
**collaudo E2E** avverrà quando il BLE si riconnette. Nessuna fretta sul vostro
lato finché non congeliamo il contratto sopra (specie **canale** e **hash PIN**).
