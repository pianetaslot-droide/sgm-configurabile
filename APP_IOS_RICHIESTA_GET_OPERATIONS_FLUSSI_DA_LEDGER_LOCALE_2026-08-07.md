# App iOS → SGM/Windows — richiesta: leggere i FLUSSI dal ledger locale, non solo dal mirror cloud (2026-08-07)

Durante il test col cloud spento Hu Leo ha posto la domanda giusta:

> perché l'app non legge i dati dal server SGM?

Abbiamo verificato: **ha ragione, ed è una lacuna nostra + un'azione che vi manca.**

## Stato attuale

I 5 elenchi del tab **Flussi** (TITO, Betting, Cambio, Depositi, Refill) leggono **solo da
Supabase** (`pagamenti_tito`, `pagamenti_betting`, `cambio_operazioni`, depositi, movimenti
refill). Col cloud spento non c'è nessuna sorgente alternativa → lista vuota.

Dal vostro lato oggi esistono, sul canale locale:
- `get_cash_levels` → livelli per cassetta ✅
- `get_hardware` → inventario ✅
- `get_dashboard_summary` (BLE) → **solo aggregati** (totale, conteggio operazioni)

Manca **il dettaglio delle operazioni**. Eppure il ledger locale è, come ripetete giustamente,
**la fonte autoritativa**: le operazioni ci sono, sono lì, e restano lì anche a cloud spento
(più la `sync_outbox` con quelle non ancora specchiate).

Il risultato pratico è paradossale: la macchina sta lavorando e ha i dati, ma l'app mostra una
lista vuota perché sa guardare solo lo specchio.

## Richiesta

Un'azione su `/connect/command` (session_id) per leggere le operazioni dal ledger locale.
Proposta, adattatela a come avete i dati:

```
action: "get_operations"
payload: { "from": "<iso8601>", "to": "<iso8601>",
           "tipo": "tito|betting|cambio|deposito|refill|all",
           "limit": 200, "offset": 0 }
```

Risposta: una entry per operazione con almeno — `id` (lo stesso che finisce su Supabase, così
non duplichiamo quando il mirror recupera), `tipo`, `timestamp`, `importo_cent`,
`stato/esito`, e il riferimento del ticket dove ha senso. Se avete già una struttura interna,
mandate quella: ci adattiamo noi.

Se il volume è un problema, ci basta anche solo **l'ultimo periodo** (es. ultimi 7 giorni o
ultime N operazioni): serve a far vedere all'operatore cosa sta succedendo *adesso*, non a
sostituire lo storico.

## Come lo useremmo
Se il cloud risponde → leggiamo Supabase (storico completo, più periodi).
Se il cloud non risponde → leggiamo dalla macchina e lo diciamo esplicitamente in UI
("dati dalla macchina, cloud non raggiungibile"). Nessuna scrittura, sola lettura.

## Nel frattempo (lato app, già fatto)
Abbiamo smesso di mostrare il gergo HTTP: col cloud in pausa Supabase risponde **540
"Project paused"**, che finiva testualmente in faccia all'operatore. Ora quella condizione
viene riconosciuta come "cloud non raggiungibile" e l'elenco dice che i dati non sono
disponibili offline e si riallineeranno — invece di lasciar credere che la macchina sia ferma.
(Avevamo già gestito 521/522/523/524 e i timeout; 540 mancava.)

## Domanda
Vi torna? C'è già qualcosa di simile che non abbiamo visto nel contratto? Se preferite un
formato diverso (o un `since_id` invece del range temporale) va benissimo: l'importante è
avere una via locale per il dettaglio, non solo per gli aggregati.
