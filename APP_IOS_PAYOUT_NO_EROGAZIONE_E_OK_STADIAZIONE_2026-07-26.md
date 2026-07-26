# App iOS → SGM/Windows — payout: nessuna erogazione + OK stadiazione confini (2026-07-26)

## Payout — confermato: la macchina NON eroga (cash-safe, ma il payout Legacy non è attivo)
Hu Leo ha verificato sul posto: sui test (€15 e €10,25) **la macchina NON ha erogato nulla**
(niente banconote uscite). Quindi:

- Nessun rischio doppio pagamento (bene): non è "paga ma non risponde".
- Il problema è a monte: dopo AUTH OK + ORDER_WRITE, la macchina **non esegue il payout** →
  niente erogazione, niente ORDER_STATUS → l'app va in timeout.

Conclusione: sulla macchina SGM/Windows il **flusso payout Legacy `a1000000` (ORDER_WRITE →
esecuzione/erogazione F53/hopper → ORDER_STATUS su `a1000003`) NON è ancora attivo/implementato**,
mentre AUTH `a1000001` e Connect/set_config funzionano. Lato app è tutto pronto (auth passa,
ordine inviato nel formato Legacy esistente): manca l'esecuzione + la notify di stato lato macchina.

Domande:
1. Confermate che il payout Legacy (esecuzione + ORDER_STATUS) va implementato/attivato su
   SGM/Windows? In quale build lo prevedete?
2. Il formato ORDER_WRITE che l'app invia (invariato dal Game manager legacy) è quello che vi
   aspettate, o su SGM/Windows il payout passa da un canale/azione diversa (es. `pay_operation`
   su Connect invece di ORDER_WRITE su Legacy)? Se è cambiato, diteci il flusso e adeguiamo l'app.

## Confini turno/chiusura — OK alla vostra stadiazione
Va bene: **interim = SGM legge i confini da Supabase come replica** (ora affidabile col fix
`inizio_turno DEFAULT`), **full local-first in futuro = l'app spinge i confini via azione locale
`set_turno`/`set_chiusura`** (open/close + timestamp) sul canale Connect, SGM valida e persiste.
Concordi anche sul non scrivere il DB locale SGM da fuori. Nessuna fretta: quando pianificate il
passaggio, definiamo insieme il payload di `set_turno`/`set_chiusura`. Grazie.
