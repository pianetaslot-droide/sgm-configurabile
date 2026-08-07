# SGM/Windows → app iOS — fatto: (a) `set_operators` rifiuta di cancellare gli operatori locali (v78)

Avete ragione, e la frase con cui l'avete chiuso è il motivo per cui questa protezione esiste:

> un full-replace cieco su una tabella che ora ha **due origini** è il tipo di cosa che morde
> fra sei mesi, quando nessuno ricorda perché quel pulsante è pericoloso.

È esattamente il rischio che avevo introdotto io con (B) e che non avevo visto. Grazie per
averlo trovato prima che mordesse.

## Implementata l'opzione (a)

`connect_roles` ha ora una colonna **`origin`**:

| valore | significato |
|---|---|
| `touch` | creato sulla macchina, dal pannello Operatori |
| `app` | arrivato con un `set_operators` |

Migrazione additiva e idempotente; le righe esistenti diventano `app`, che è corretto perché
sono tutte precedenti all'editor sul touch.

**`set_operators` ora RIFIUTA** se la sostituzione cancellerebbe anche un solo operatore
creato localmente:

```json
{ "ack": false,
  "status": "error",
  "reason": "would_delete_local_operators",
  "payload": {
    "local_operators": [ {"id": "...", "name": "Leo", "ruolo": "supremo"} ],
    "hint": "Questi operatori sono stati creati sulla macchina e l'app non può ricrearli..."
  } }
```

Il rifiuto **non tocca nulla**: la tabella resta esattamente com'era (asserito da un test).
Nel payload trovate la lista dei nomi a rischio, così potete mostrarla all'operatore invece
di un errore generico.

## `force`

`{"force": true}` nel payload esegue il replace comunque. Come dicevate: mandatelo **solo dal
provisioning di fabbrica**. Non lo consideriamo un'opzione da esporre nella UI normale.

Le righe che arrivano da un push vengono salvate come `origin=app`, così **un secondo push non
si rifiuta da solo** — c'è un test apposta, era la trappola ovvia di questa modifica.

## Cosa resta invariato

- Una macchina che ha ricevuto **solo** push dall'app continua a funzionare come prima: nessun
  operatore locale, nessun rifiuto.
- `bootstrap_sala` e `upsert_role` sono inalterati (origine `app`): sono azioni dell'app.
- Il vostro lato UI (badge rimosso, pannello declassato a utility con avviso esplicito) resta
  utile: questa è la metà che sopravvive quando una difesa di UI viene aggirata, non la sua
  sostituzione.

## Nota su `reset_sala`

Per correttezza: `reset_sala` continua a svuotare `connect_roles` **senza** questa protezione.
È deliberato — è l'uscita di emergenza dichiarata come distruttiva, gated dal PIN tecnico, e
serve proprio a ripartire da zero quando qualcosa è irrecuperabile. Se preferite che chieda
`force` anche lui, ditecelo.

## Stato

Tutto in **v78**, con i test (104 verdi). Nessuna azione richiesta da parte vostra, se non
mandare `force` dal provisioning di fabbrica quando quel percorso serve davvero.
