# SGM (Windows/Python) — stato Fase 0 + Fase 1 (2026-07-25, aggiornato notte)

Copre l'esecuzione di `SGM_ORDINE_LAVORO_WINDOWS_2026-07-25.md` (W0.1-W0.3,
poi le 5 azioni ruoli di Fase 1 contro la spec congelata in
`BLE_PROTOCOL_CONTRACT.md` §9). Non sostituisce
`SGM_WINDOWS_STATUS_HANDOFF_2026-07-24.md`, che resta valido per tutto il
resto (Livelli cassa, incasso, residuo, bug font UI touch).

## Fase 0 — fatto, confermato funzionante dall'app su hardware reale

W0.1 (pairing mode)/W0.2 (INFO esteso)/W0.3 (log connessione) implementati
come nel precedente aggiornamento. L'app ha confermato un pairing end-to-end
riuscito su iPhone fisico lo stesso giorno — vedi header di
`BLE_PROTOCOL_CONTRACT.md`. Non ancora verificata la ripetibilità 3x della
DoD formale.

## Fase 1 — le 5 azioni ruoli, implementate

Contro la spec §9 congelata dall'app (nessuna variante necessaria — i campi
proposti erano già coerenti con l'architettura lato SGM):

- **`bootstrap_sala`**: crea la sala + il primo ruolo "Supremo" (level 0,
  tutti i permessi) su QUESTA macchina. Gated dietro il PIN tecnico reale
  della macchina (`setup/technician_auth.py`, verificato via hash pbkdf2 —
  il telefono non lo conosce/salva mai). Rifiutata se la macchina non ha un
  PIN tecnico impostato, se il PIN è sbagliato, o se un bootstrap è già
  avvenuto (una sola "prima volta" per macchina; ruoli aggiuntivi passano
  da `upsert_role`).
- **`login`**: verifica il PIN contro TUTTI i ruoli salvati (i PIN sono
  hashati con salt casuale, quindi non si può cercare per uguaglianza — si
  verifica il candidato contro ogni hash finché non matcha; a questa scala,
  pochi ruoli per sala fisica, è banale). Autentica SOLO la sessione BLE
  corrente (`device_sessions.authenticated_role_id`) — un nuovo `hello`
  azzera sempre l'autenticazione, verificato con test (due `hello` dallo
  stesso `app_device_id` revocano la sessione precedente, comportamento
  preesistente riusato qui).
- **`list_roles` / `upsert_role` / `remove_role`**: richiedono che la
  sessione corrente abbia già fatto `login` con un ruolo che ha
  `manageRoles`, altrimenti `not_authorized`. `upsert_role` richiede un PIN
  per un ruolo NUOVO, lo rende opzionale per uno esistente (assente = non
  cambia); valida che `permissions` contenga solo le 5 stringhe esatte del
  contratto.

**Storage**: nuova tabella locale `connect_roles` in LocalLedger (id, sala,
name, level, permissions_json, pin_hash, timestamps) — mai sul cloud, mai
sul telefono. L'hashing PIN è stato estratto in un modulo condiviso
(`services/pin_hash.py`, stesso schema pbkdf2/200k iterazioni di prima) così
il PIN tecnico e i PIN dei ruoli usano un'unica implementazione invece di
due copie che potrebbero divergere.

**`INFO.configured`**: ora significa "questa macchina ha almeno un ruolo
sala bootstrappato" (query su `connect_roles`), non più "il wizard hardware
è stato completato" — sono condizioni diverse e la seconda non è il segnale
giusto per far apparire il flusso di bootstrap sull'app.

**`INFO.capabilities`**: ora `["hello", "bootstrap_sala", "login",
"list_roles", "upsert_role", "remove_role"]`.

## Cosa NON è ancora verificato

- **Nessun test su hardware reale con un iPhone.** Solo test unitari/di
  import isolati (nessun bluetooth reale coinvolto) — bootstrap → login →
  list/upsert/remove → verifica che un nuovo hello azzeri l'auth, tutti
  verdi in isolamento. Il prossimo passo naturale è una sessione di test
  congiunta contro la macchina reale, ora che c'è un build aggiornato con
  `capabilities` estese da leggere.
- Non ho toccato il login PIN del touch macchina (`on_pin_attempt` in
  `main.py`, che oggi interroga ancora Supabase `app_users` in chiaro per i
  ruoli commesso/direttore/supremo) — restano due sistemi paralleli
  (touch → cloud, BLE → locale). L'unificazione discussa in precedenza
  (stesso store locale per entrambi) non è stata fatta in questo giro: FASE 1
  del piano riguardava solo le azioni BLE, non ho voluto allargare lo scope
  senza che fosse richiesto esplicitamente. Prossimo passo naturale se/quando
  serve.

## Build

Pacchettizzato e distribuito (v8, `FIX_NOTES.txt` nello zip). Non
auto-testato dopo il packaging, per convenzione di progetto.
