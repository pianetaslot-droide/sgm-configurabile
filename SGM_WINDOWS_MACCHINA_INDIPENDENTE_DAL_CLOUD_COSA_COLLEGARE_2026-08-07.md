# SGM/Windows → app iOS — la macchina diventa indipendente dal cloud: cosa dovete collegare (2026-08-07)

Decisione di Hu Leo, senza mezze misure: **la macchina non deve dipendere da Supabase.**
Non "meno dipendente" — indipendente. Questo documento dice cosa è già disponibile, cosa
cambia per voi, e l'unica cosa che dobbiamo ancora concordare.

Il mirror **resta**, ma solo in scrittura: oggi è l'unica copia dei dati di cassa fuori dalla
macchina (un disco, nessun backup), quindi non lo spegniamo — semplicemente la macchina non lo
**legge** più per prendere una decisione. Lettura = ledger locale, sempre.

---

## 1. Già disponibile ORA (v79, installata)

| cosa | dove |
|---|---|
| Dettaglio operazioni (i 5 elenchi Flussi) | `get_operations` su `/connect/command` |
| Livelli per cassetta | `get_cash_levels` |
| Inventario hardware | `get_hardware` |
| Stato / riavvio / reboot | `status`, `restart_sgm`, `reboot` |
| Operatori | si creano **sulla macchina** (Admin → Operatori), niente push necessario |

Per i Flussi usate `source: "sgm_local_ledger"` presente nella risposta come etichetta UI,
invece di dedurre lo stato dalla rete.

## 2. Cosa cambia nella prossima build — **azione richiesta**

### 2.1 `kiosk_comandi` verrà spento

I comandi remoti passano da un interruttore (`SUPABASE_COMMAND_ADAPTER_ENABLED`). Quando è
off la macchina **non fa più polling** della coda cloud.

**Cosa dovete fare:** instradare riavvio/reboot/stato sulla **fast-path `/connect/command`**,
che ci avete già detto essere cablata. Se avete ancora percorsi che scrivono in
`kiosk_comandi` aspettandosi che vengano eseguiti, quelli smetteranno di funzionare — non in
silenzio: semplicemente il comando resta `pending` e voi lo vedete.

### 2.2 Confini periodo: **smettiamo di leggerli dal cloud**

Oggi la home legge da Supabase l'ultima `chiusure_contabilita` e il `turni` aperto per
decidere la finestra "dall'ultima chiusura". Gli importi sono già locali; i confini no, ed è
l'ultima dipendenza cloud rimasta in quella schermata.

Dalla prossima build i confini vivono **sulla macchina**. Se nessuno li imposta, la finestra
è **tutto lo storico** — l'unica risposta onesta, meglio di una finestra inventata.

**Qui serve un accordo, perché il turno è vostro, non nostro.** `turni` è un concetto di SALA
(aggrega VLT, AWP, bar, betting: cose che questa macchina non conosce e non deve inventarsi).
Quindi non lo gestiamo noi: ce lo dite voi.

**Proposta di contratto** (implementiamo noi, ditecelo se preferite un'altra forma):

```
action:  "set_period_boundaries"        canale: /connect/command (session_id)
gate:    direttore+                     nessun movimento di cassa
payload: {
  "chiusura_at":  "<iso8601>" | null,   // ultima chiusura contabile di sala
  "turno_id":     "<uuid>"   | null,    // turno corrente (informativo)
  "turno_inizio": "<iso8601>" | null    // inizio del turno corrente
}
```

Semantica che proponiamo, tutta esplicita perché è il tipo di cosa che si dimentica:
- **`null` non significa "non cambiare"**: significa "nessun confine", cioè finestra aperta.
  Per non toccare un campo, ometterlo.
- Idempotente: rimandare gli stessi valori non cambia nulla.
- Solo visualizzazione: non tocca operazioni, importi, livelli o contabilità.
- Persistente: sopravvive al riavvio, così la home non torna "tutto lo storico" al reboot.

**Quando chiamarla:** all'apertura turno, alla chiusura contabile, e (per sicurezza) alla
prima connessione dopo un riavvio della macchina. Se non la chiamate mai, la macchina
funziona lo stesso: mostra tutto lo storico.

## 3. Cosa NON cambia

- **I pagamenti**: erano già locali e non toccano Supabase. Nessun impatto.
- **Il mirror**: resta acceso in scrittura (`SUPABASE_MIRROR_ENABLED`), quindi le vostre viste
  storiche/archivio continuano a funzionare quando il cloud c'è. Con il cloud spento la coda
  si accumula e recupera da sola alla riaccensione — come avete già visto nel test.
- **`set_operators`**: resta, con la protezione di v78 (rifiuta se cancellerebbe operatori
  creati sulla macchina, salvo `force`).

## 4. Domande per voi

1. Il contratto `set_period_boundaries` vi va, o preferite forma/nomi diversi? Per noi
   cambiarlo adesso costa poco, fra un mese no.
2. Confermate che riavvio/reboot passano già da `/connect/command` e che possiamo spegnere il
   polling `kiosk_comandi` senza togliervi nulla?
3. C'è qualche altro punto dell'app che **legge** da Supabase dati che la macchina possiede?
   Se sì ditecelo: aggiungiamo l'azione locale come abbiamo fatto per i Flussi. La regola che
   stiamo seguendo è semplice — se il dato nasce sulla macchina, la macchina deve saperlo dire.

---

Nota di trasparenza: i punti della sezione 2 sono **in lavorazione, non ancora consegnati**.
Vi scriviamo adesso perché il contratto della 2.2 conviene concordarlo prima che sia scritto,
non dopo. Vi diremo con quale build arrivano.
