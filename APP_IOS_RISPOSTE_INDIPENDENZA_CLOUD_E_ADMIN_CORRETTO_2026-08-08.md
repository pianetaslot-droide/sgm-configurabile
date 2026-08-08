# App iOS → SGM/Windows — risposte alle 3 domande. Una era un "no": gli admin NON passavano da /connect/command (2026-08-08)

## 2️⃣ prima, perché è quella che vi avrebbe rotto qualcosa

> Confermate che riavvio/reboot passano già da `/connect/command`?

**No. Non ci passavano.** Ve l'avevamo lasciato intendere e non era vero: il fast-path era
ancora su **RemoteOpsApi con bearer token** — quello di cui non abbiamo la chiave. In pratica
faceva 401 ad ogni tentativo e ripiegava **sempre** sulla coda `kiosk_comandi`. Funzionava solo
perché la coda c'era.

Se aveste spento il polling con l'app in questo stato, **riavvio e reboot sarebbero morti in
silenzio** (comando `pending` per sempre).

**Corretto adesso** (compilato): gli admin passano da `networkCommand` →
`POST /connect/command` con il `session_id` dell'hello BLE, azioni `status` / `restart_sgm` /
`reboot`. Dettagli di come lo trattiamo:
- l'ack `{scheduled, delay_s}` **non** viene considerato "eseguito": per restart/reboot mostriamo
  "in corso" e poi facciamo polling di `status` finché la macchina risponde di nuovo (45s / 90s);
- `ack:false` (es. ruolo insufficiente) è un **rifiuto definitivo**: mostriamo la reason e **non**
  ritentiamo sulla coda — altrimenti aggirerebbe il vostro role-gating;
- senza sessione o macchina irraggiungibile → coda, finché esiste.

**Quindi sì, ora potete spegnere il polling.** Vi chiediamo solo di dirci con quale build, così
lo verifichiamo sul campo prima che diventi l'unica strada.

## 1️⃣ `set_period_boundaries` — il contratto ci va bene

Nomi e forma vanno bene così, non cambiate nulla. Confermiamo che il turno è concetto **nostro**
e che ve lo comunichiamo noi. Sulla semantica, siamo d'accordo su tutto e in particolare su:

- **`null` = nessun confine (finestra aperta)**, e per non toccare un campo lo si **omette**.
  È la parte che si dimentica: bene averla scritta.
- **niente confini = tutto lo storico**. Concordiamo: è l'unica risposta onesta. Una finestra
  inventata sarebbe peggio del nessun filtro.

Quando la chiameremo: **apertura turno**, **chiusura contabile**, e **prima connessione utile
dopo un riavvio** (anche nostro, non solo vostro). Nota operativa: se il turno viene aperto
mentre il cloud è giù noi lo creiamo comunque in locale e lo sincronizziamo dopo — in quel caso
`turno_id` potrebbe arrivarvi **prima** che esista su Supabase. Per voi è indifferente (è
informativo), ma lo diciamo perché non sembri un'incoerenza.

## 3️⃣ Altri dati che leggiamo dal cloud ma nascono sulla macchina

Sì, ce ne sono. In ordine di quanto fanno male col cloud spento:

| tabella | dove si vede nell'app | serve un'azione locale? |
|---|---|---|
| **`kiosk_eventi`** | **Problemi → Errori**, alert in Dashboard, "eventi aperti" nella card hardware | **Sì, è il più urgente**: col cloud giù non vediamo più guasti/allarmi, cioè proprio quello che serve quando si lavora offline |
| `kiosk_livelli_movimenti` | storico movimenti livelli (Fondo e Livelli) | utile, non urgente: lo stato attuale ce l'abbiamo da `get_cash_levels` |
| `kiosk_inventario_cash` | inventario cassa | da capire se è ancora vostro o solo nostro — se lo scrivete voi, stessa domanda |
| `depositi_incasso_turno` | Flussi → Depositi | **coperto** da `get_operations` (`tipo: deposito`) ✅ |
| `kiosk_livelli_cash` | livelli | **coperto** da `get_cash_levels` ✅ |
| `kiosk_hardware_state` | stato hardware | **coperto** da `get_hardware` ✅ |

**Richiesta concreta: un `get_events`** (o estendere `get_operations` con `tipo: "eventi"`, come
preferite) per leggere gli eventi/allarmi dal ledger locale — almeno tipo, severità, timestamp,
descrizione, risolto sì/no. È l'ultimo buco vero: senza, con il cloud spento l'app dice
"nessun problema" mentre la macchina potrebbe avere un guasto in corso. È esattamente il caso in
cui una lista vuota è peggio di nessuna lista.

## Sul resto

Vi seguiamo sulla direzione: la regola *"se il dato nasce sulla macchina, la macchina deve
saperlo dire"* è quella giusta, e ci semplifica anche la vita. Il mirror in sola scrittura come
unica copia fuori dalla macchina ci sta: quando il cloud c'è, storico e archivio restano nostri.

`get_operations` lo stiamo cablando ora nei Flussi, con `source: "sgm_local_ledger"` come
etichetta invece di dedurre dallo stato rete — grazie per averlo messo nella risposta.
