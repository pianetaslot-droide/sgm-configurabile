# SGM Connect — Piano Generale (blueprint condiviso)

Data: 2026-07-25 · Autore: sessione di pianificazione (per Hu Leo)
Fonti: `SGM_WINDOWS_STATUS_HANDOFF_2026-07-24.md` (lato Python/Windows) +
`SGM_CONNECT_APP_STATUS_2026-07-25.md` (lato iOS).

Questo è il documento **master**. I due ordini di lavoro operativi lo attuano:
- `SGM_ORDINE_LAVORO_WINDOWS_2026-07-25.md` (lato macchina, Python/Windows)
- `SGM_ORDINE_LAVORO_APP_IOS_2026-07-25.md` (lato app, Swift/iOS)

Regola d'oro: **nessuno dei due lati modifica il contratto BLE da solo.** Le
modifiche al contratto passano da questo piano e dal file di contratto
versionato (vedi §3).

---

## 1. Perché oggi i due lati "non si agganciano"

Il problema NON è mancanza di funzioni. È che i due lati sono stati
sviluppati a colpi di patch indipendenti, senza una fonte di verità unica e
imposta. Il sintomo più chiaro del drift:

- Il documento app dice: «Azioni implementate lato SGM: `hello`,
  `bootstrap_sala`, `login`, `list_roles`, `upsert_role`, `remove_role`».
- Il documento Windows dice: «Ruoli/PIN localizzati (`bootstrap_sala`/
  `login`/`list_roles`) **non ancora fatti**; implementati solo `hello` +
  INFO».

Le due sessioni hanno letto lo stesso contratto ma hanno un'idea diversa di
cosa esiste davvero. Questo è il vero difetto di processo da chiudere per
primo, altrimenti ogni fase successiva erediterà lo stesso disallineamento.

A questo si sommano tre blocchi tecnici che impediscono anche un solo
pairing reale end-to-end:

1. **Discovery / identità** — La macchina SGM (bless/WinRT lato Windows)
   pubblicizza SENZA nome e la scheda Bluetooth riesce a fare advertising di
   **un solo GATT service alla volta** (vecchio protocollo TITO/Snai e nuovo
   "SGM Connect" non coesistono nell'advertisement). Risultato: l'app vede
   ~10 dispositivi anonimi e non sa quale sia la macchina.
2. **Connessione** — Lato iOS il primo step di `connect()` non ha timeout:
   se CoreBluetooth non richiama né `didConnect` né `didFailToConnect`, lo
   spinner gira all'infinito. Non è mai stato confermato un connect GATT
   reale, quindi nessuno sa se il tubo funziona davvero.
3. **Contratto desincronizzato** — vedi sopra: le liste di azioni
   implementate non coincidono.

---

## 2. Principio guida

Due principi risolvono la causa radice, non solo i sintomi:

**A. Fonte di verità unica e versionata.** Esiste UN file di contratto,
`BLE_PROTOCOL_CONTRACT.md`, con un `contract_version` esplicito e una
**matrice di stato di implementazione** (azione → stato lato SGM → stato lato
app). Un solo repo lo possiede (proposta: il repo Windows/SGM, che è il lato
che *implementa* il server GATT); l'altro lo consuma. Ogni handoff che tocca
il protocollo incrementa la versione.

**B. Negoziazione delle capacità a runtime.** Non ci fidiamo più del mirror
manuale dei documenti per sapere cosa la macchina supporta. La macchina lo
**dichiara lei stessa** nella caratteristica INFO (letta senza autenticazione,
già prevista dal contratto). L'app legge `contract_version` e l'elenco delle
azioni supportate, e abilita/disabilita le funzioni di conseguenza. Così il
drift tra documenti non può più causare un bug: la verità è la macchina.

Questo è il cuore del piano: **INFO diventa il punto di aggancio autorevole.**
Risolve insieme il problema di identità (§1.1) e quello di desync (§1.3).

---

## 3. Architettura target del contratto

Il contratto GATT resta quello già concordato, con **una estensione della
caratteristica INFO**.

```
Service   C09A0000-1B2C-4A9E-8F3D-53474D434E31   (SGM Connect)
  Char    C09A0001-...  REQUEST (write)
  Char    C09A0002-...  REPLY   (notify)
  Char    C09A0003-...  INFO    (read, nessuna auth)
```

Envelope invariati:
- Request: `{schema_version, action, session_id, seq, payload}`
- Reply:   `{ack, action, seq, status, reason, payload}`

**INFO — payload esteso (nuovo campo obbligatorio):**

```json
{
  "kiosk_id": "…",
  "label": "…",
  "sala": "…",
  "configured": true,
  "contract_version": 1,
  "capabilities": ["hello", "bootstrap_sala", "login", "list_roles",
                   "upsert_role", "remove_role"]
}
```

- `contract_version`: intero. Se app e macchina divergono di major, l'app
  mostra un avviso invece di fallire in modo opaco.
- `capabilities`: elenco delle azioni che QUELLA macchina implementa davvero
  in questo momento. È l'unica fonte autorevole; i documenti sono solo
  descrittivi.

**Advertising:** in "modalità pairing" la macchina pubblicizza il **service
UUID SGM Connect** nella lista service dell'advertisement, così l'app può
filtrare (`scanForPeripherals(withServices:)`). Questo riduce i candidati da
~10 anonimi a pochi. L'identità definitiva resta però confermata da INFO dopo
il connect (una macchina è "vera SGM" se e solo se INFO risponde con un
payload valido).

**Matrice di stato (da tenere aggiornata nel file di contratto):**

| Azione          | Lato SGM (Windows) | Lato App (iOS) | Fase |
|-----------------|--------------------|----------------|------|
| `hello`         | ✅ fatto           | ✅ codice      | 0    |
| INFO (read)     | ✅ base, ⚠️ estendere | ✅ leggere estesa | 0 |
| `bootstrap_sala`| ❌ da fare         | ✅ codice, mai eseguito | 1 |
| `login`         | ❌ da fare         | ✅ codice, mai eseguito | 1 |
| `list_roles`    | ❌ da fare         | ✅ codice, mai eseguito | 1 |
| `upsert_role`   | ❌ da fare         | ✅ codice, mai eseguito | 1 |
| `remove_role`   | ❌ da fare         | ✅ codice, mai eseguito | 1 |
| operazioni cassa| ❌ placeholder     | ❌ placeholder | 2 |

> Nota importante: la lista `capabilities` di INFO deve riflettere questa
> colonna "Lato SGM". Finché i ruoli non sono implementati sulla macchina,
> `capabilities` NON deve elencarli, e l'app deve nascondere/disabilitare le
> relative schermate. Questo elimina alla radice il disallineamento del §1.

---

## 4. Roadmap a fasi

Le fasi sono sequenziali per dipendenza: non ha senso testare i ruoli se il
tubo (pairing) non regge, né la cassa se i ruoli (auth) non esistono.

### Fase 0 — Pairing minimo reale end-to-end (LO SBLOCCO)

Obiettivo unico: dimostrare su hardware reale che il tubo funziona. Nessun
ruolo, nessuna cassa. Happy path esatto che entrambi i lati testano insieme:

```
scan (filtrato per service UUID)
  → connect (CON timeout)
  → discoverServices
  → read INFO  (verifica identità + contract_version + capabilities)
  → hello      (REQUEST → REPLY)
  → salva macchina in MachineStore
```

Dipendenze incrociate: l'app non può filtrare per service UUID finché la
macchina non lo pubblicizza; la macchina non serve a niente se l'app va in
timeout infinito. Quindi Fase 0 richiede lavoro coordinato sui DUE lati prima
di poter chiudere (vedi §5).

**Definition of done Fase 0:** su iPhone fisico + macchina reale, un pairing
completo che finisce con la macchina salvata nella lista, ripetibile 3 volte
di fila, con un errore chiaro e visibile (non spinner infinito) in ogni caso
di fallimento.

### Fase 1 — Ruoli-sala sulla macchina

Precondizione: Fase 0 chiusa. Prima di scrivere codice, **congelare la
specifica dei campi** delle azioni ruoli nel contratto (oggi è il vero blocco:
il lato SGM aspetta la spec, che è responsabilità dell'app definire perché è
lei a modellare la UI). Poi: SGM implementa `bootstrap_sala`/`login`/
`list_roles`/`upsert_role`/`remove_role` riusando `technician_auth.py`
(pbkdf2) come paradigma già esistente; aggiunge le azioni a `capabilities` in INFO;
l'app le abilita solo se presenti in `capabilities`.

Modello confermato (da §3 del doc app, validato da Hu Leo): i ruoli vivono
SULLA macchina, nessun login globale, il PIN tecnico fa solo il bootstrap del
primo "supremo", che poi decide livelli/permessi. Numero di livelli NON
cablato.

**Definition of done Fase 1:** bootstrap del primo supremo via PIN tecnico su
macchina reale; login con PIN ruolo; creazione/rimozione di un ruolo, con
verifica che i dati vivano sulla macchina e nulla di ruolo/PIN persista sul
telefono.

### Fase 2 — Operazioni cassa

Precondizione: Fase 1 chiusa (le operazioni cassa richiedono un ruolo
autenticato). Oggi entrambi i lati sono placeholder onesti. Prima si scrive il
**contratto** delle azioni cassa (deposito/incasso, dispensa, lettura livelli),
riusando la logica di calcolo autorevole già presente lato SGM
(`local_ledger.py`, stessa usata dal flusso deposito touch). Poi
implementazione lato SGM → `capabilities` → UI app.

**Definition of done Fase 2:** almeno una operazione cassa (proposta: lettura
livelli, la più a basso rischio) eseguita end-to-end dall'app contro macchina
reale, con i numeri che coincidono con quelli mostrati sul touch della
macchina.

---

## 5. Chi fa cosa (matrice per fase)

| | Lato SGM / Windows | Lato App / iOS | Congiunto |
|---|---|---|---|
| **Fase 0** | Pubblicizzare il service UUID SGM Connect in pairing mode; garantire UN solo service in advertising; estendere INFO con `contract_version`+`capabilities`; verificare che il peripheral accetti connessioni stabili | Timeout su ogni step di `connect()`; scan filtrato per service UUID + fallback; verifica identità via INFO; ordinamento candidati per RSSI; messaggi d'errore visibili | Sessione di test congiunta su hardware reale sull'happy path esatto §4 |
| **Fase 1** | Implementare le 5 azioni ruoli (riuso `technician_auth.py`); esporle in `capabilities` | Abilitare le schermate ruoli solo se presenti in `capabilities`; eseguirle contro macchina reale | Congelare la spec campi ruoli nel contratto PRIMA di scrivere codice |
| **Fase 2** | Implementare azioni cassa su `local_ledger.py`; esporle in `capabilities` | Sostituire il placeholder `CashOperationsView` con la UI reale | Definire il contratto cassa; test end-to-end |
| **Trasversale** | Possiede e versiona `BLE_PROTOCOL_CONTRACT.md`; traccia parallela: bug font touch (§4.1 doc Windows) | Consuma il contratto; non lo modifica da sola | Ogni handoff bumpa `contract_version` e aggiorna la matrice §3 |

---

## 6. Processo anti-drift (la parte che evita di ritrovarsi qui tra un mese)

1. **Un solo proprietario del contratto.** Il repo Windows/SGM possiede
   `BLE_PROTOCOL_CONTRACT.md`. Il lato app lo legge come dipendenza; se serve
   una modifica, la propone ma non la scrive da solo.
2. **Verità a runtime, non su carta.** L'app non assume MAI che un'azione
   esista: la abilita solo se compare in `INFO.capabilities`. I documenti
   possono sbagliare; la macchina no.
3. **Versione + matrice ad ogni handoff.** Ogni volta che un lato cambia il
   protocollo: bumpa `contract_version`, aggiorna la matrice §3, scrive una
   riga di changelog. Niente modifiche silenziose.
4. **Definition of done = testato su hardware reale.** "Compila" non è "fatto".
   Il doc app lo dimostra già bene: i bug §7 erano visibili SOLO su device
   fisico. Ogni fase si chiude solo con un test su iPhone reale + macchina
   reale.

---

## 7. Sintesi operativa (cosa chiedere ai due lati, in una riga)

- **Al lato SGM/Windows:** «Fai in modo che in pairing mode la macchina
  pubblicizzi il service UUID SGM Connect (un solo service), ed estendi INFO
  con `contract_version` e `capabilities`. Poi ci fermiamo e testiamo il
  pairing insieme, prima di toccare ruoli e cassa.»
- **Al lato App/iOS:** «Metti un timeout su ogni step di `connect()` così non
  c'è più lo spinner infinito, filtra lo scan per service UUID, conferma
  l'identità della macchina leggendo INFO, e abilita le funzioni solo in base
  a `capabilities`. Poi testiamo il pairing insieme.»

Le prossime azioni concrete e ordinate sono nei due ordini di lavoro.
