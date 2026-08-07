# SGM/Windows → app iOS — `get_operations` è pronto: i Flussi si leggono dal ledger locale (v79)

Richiesta accolta e implementata. La vostra osservazione è corretta e la formulazione è
quella giusta: la macchina stava lavorando e aveva i dati, l'app mostrava una lista vuota
perché sapeva guardare solo lo specchio.

## Azione

```
action:  "get_operations"          canale: /connect/command (session_id)
gate:    viewMonitoring            sola lettura, nessuna scrittura
payload: { "tipo": "tito|betting|cambio|deposito|refill|all",   (default "all")
           "from": "<iso8601>", "to": "<iso8601>",              (opzionali)
           "limit": 200, "offset": 0 }                          (limit max 1000)
```

È in `NETWORK_ALLOWED_ACTIONS` e **annunciata in `CAPABILITIES`**, così la scoprite
dall'hello/INFO invece di doverlo sapere da questo documento.

## Risposta

```json
{ "ack": true, "status": "ok",
  "payload": {
    "operations": [
      { "id": "ios-tito-078084924807879113-1785182659",
        "tipo": "tito", "flow": "tito_payout",
        "timestamp": "2026-07-27T20:20:49.123456+00:00",
        "importo_cent": 20020, "pagato_cent": 20020,
        "stato": "completed", "riferimento": "36305600489660",
        "operatore": "Tecnico", "cloud_sync": "pending" }
    ],
    "total": 126, "limit": 200, "offset": 0,
    "source": "sgm_local_ledger" } }
```

Note sui campi, tutte volute:

- **`id` è l'`operation_id`**, cioè **lo stesso valore che il mirror scrive come
  `sessione_id`**. Era il vostro requisito e lo confermiamo: potete unire vista locale e
  vista cloud senza duplicare quando il mirror recupera.
- **`importo_cent` vs `pagato_cent`**: il primo è l'importo dell'operazione, il secondo
  quanto è stato realmente erogato (presente quando il risultato lo riporta). Su un residuo
  parziale i due differiscono, ed è esattamente il caso in cui l'operatore vuole vedere la
  differenza.
- **`stato`** è lo stato del ledger (`completed`, `cancelled`,
  `completed_with_non_erogabile`, …), non una traduzione: se vi serve una mappatura verso le
  vostre etichette ditecelo, ma preferiamo darvi il valore vero.
- **`cloud_sync`** vi dice se quella riga è già stata specchiata (`pending`/`synced`/…): utile
  per mostrare "non ancora sincronizzato" senza doverlo dedurre.
- **Le righe dry-run sono escluse**: non hanno mosso contante e non devono comparire come
  attività.

`tipo` sconosciuto → `ack:false`, `reason:"unknown_tipo"` con l'elenco dei validi nel payload.

## Mappatura flow → tipo

Costruita sui flow che questa macchina scrive davvero, non indovinata:

| flow | tipo |
|---|---|
| `tito_payout` | tito |
| `snai_betting_payout`, `snai_fastbet_payout` | betting |
| `cambio`, `cambio_residual` | cambio |
| `deposito_incasso` | deposito |
| `cassette_svuota`, `cassette_svuota_all`, `cassette_carico` | refill |
| altro | `altro` (mai nascosto) |

Se un flow non è mappato **non sparisce**: arriva con `tipo: "altro"` e il suo `flow` reale,
così una lista non vi mente per omissione.

## Verificato sui dati veri

Non su stub — sul ledger di questa macchina: **126 operazioni**, filtro TITO **29**, con
riferimenti biglietto e importi reali. (Abbiamo appena imparato la lezione al contrario su
un'altra schermata: un test con dati finti passava mentre la funzione andava in errore ad
ogni chiamata.)

## Sul vostro uso

Il vostro piano — cloud se risponde, altrimenti macchina e dirlo in UI — ci sembra giusto.
Suggerimento: `source: "sgm_local_ledger"` è nella risposta apposta, usatelo per l'etichetta
invece di dedurlo dallo stato della rete.

Bene anche l'aver smesso di mostrare il gergo HTTP: il **540 "Project paused"** in faccia
all'operatore è esattamente il tipo di messaggio che fa pensare che sia rotta la macchina.

## Stato
In **v79**, con i test (113 verdi). Nessuna azione richiesta da parte vostra oltre a chiamarla.
