# SGM/Windows → app iOS — sì, toglietela: sui livelli scrive SOLO SGM (2026-08-07)

Grazie per aver chiuso entrambi i punti, e per aver confermato il bypass `000000` anche
lato vostro. Rispondiamo alla domanda del vostro §4 e chiudiamo il resto.

## 1. `kiosk_livelli_cash` — sì, toglietela: unico scrittore

**Sì, toglietela.** L'app non scriva più `livello_attuale` / `denom_cent`: da v64 quei
campi li scrive SGM dal ledger locale autoritativo.

Il motivo non è l'eleganza, è la diagnosticabilità — ed è la lezione di ieri sera. Quando
un numero ha **due scrittori** non si riesce più a dire, guardando la riga, *chi* l'ha
scritta e *quanto è vecchia*: abbiamo perso ore a capire se `0/100/100/100/1` fosse un
mirror indietro o un valore riscritto da qualcuno. Con un solo scrittore, una divergenza
ha una sola spiegazione possibile e si trova subito.

C'è anche un motivo di merito: l'autorità sul livello è **la macchina** (è il device che
lo osserva). Il giro `get_hardware` → app → `kiosk_livelli_cash` riscrive la stessa
sorgente passando da fuori: non aggiunge informazione e aggiunge un modo di sbagliare.

Confermiamo la ripartizione, che resta quella concordata:

| campo | scrive |
|---|---|
| `livello_attuale`, `denom_cent`, `enabled`, `unita`, `tipo` | **SGM** (ledger locale) |
| `fondo_quantita`, `livello_minimo`, `livello_massimo` (soglie business) | **app** |
| `descrizione` | nessuno dei due la scrive con un brand — SGM la lascia NULL |

Continuate pure a **leggere** `get_hardware` per l'inventario e per il refresh on-demand:
è quello per cui esiste.

## 2. `set_operators` — come verifichiamo che sia arrivato

Perfetto il pannello «Operatori sulla macchina» con il badge dirty.

Quando lo inviate, ditecelo (o inviatelo e basta): **noi possiamo verificarlo dal nostro
lato in lettura** — oggi `connect_roles` su questa macchina ha **0 righe**, quindi la
conferma è semplicemente che diventi ≥ 1 con i vostri operatori e almeno un supremo.
Vi confermiamo noi l'esito prima che Hu Leo spenga il cloud, così nessuno lo spegne
"sperando" che il login regga.

Promemoria del vincolo, non per dubbio ma perché è la causa di errore più probabile:
`set_operators` è **solo BLE** (su `/connect/command` viene rifiutato) e richiede il
technician_pin.

## 3. Bypass `000000` — chiuso su entrambi i lati

Confermato: rimosso da entrambe le copie del nostro touch (quella viva e un gemello
legacy) con test che ispezionano l'AST, non il testo — un `grep` avrebbe trovato anche
l'UUID tutto-zeri e avrebbe mancato un `"0"*6`. Il vostro `grep testUser|"000000"` = 0 ci
va benissimo come conferma, e siamo d'accordo sul principio: un utente di test è un
utente vero creato dal pannello operatori.

## 4. Confini periodo (turno / chiusura) su API locale

Registrato come vostro sì, non bloccante per questo test. Ve lo proporremo come contratto
a parte quando lo affrontiamo — è l'ultima dipendenza cloud rimasta nella home.
