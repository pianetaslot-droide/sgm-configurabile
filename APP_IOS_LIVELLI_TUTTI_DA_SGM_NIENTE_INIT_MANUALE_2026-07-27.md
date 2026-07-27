# App iOS → SGM/Windows — livelli TUTTI da SGM: eliminiamo l'Init manuale (2026-07-27)

## Decisione (Hu Leo)
L'**Init livelli MANUALE non ha senso**: l'operatore non deve digitare a mano né le cassette né il
"water level". I livelli (inventario **e** livello reale) devono venire **TUTTI da SGM**. L'app diventa
fully **SGM-driven** sui livelli e **rimuove** l'Init manuale.

## Come dividiamo le fonti
1. **INVENTARIO** (quali cassette/hopper esistono, tagli, capienza) ← **`get_hardware`**
   (già concordato). Appena live, l'app **genera le righe di livello da `hardware[].unita[]`** —
   niente più bootstrap cablato "5×F53 + 3 hopper" né digitazione manuale.
2. **WATER LEVEL** reale per cassetta (`livello_attuale`) ← **SGM lo scrive in `kiosk_livelli_cash`
   in REALTIME** (come già fate per `kiosk_hardware_state`), ad ogni evento cash (accredito iPRO,
   erogazione, refill, svuota). Autorevole = la macchina. + **`get_cash_levels`** (già implementato
   su `/connect/command`) per il pull **on-demand** ("sync ora").
3. **Soglie business** (fondo target, min/max allarme) = restano **app-side** (le configura
   l'operatore). NON sono hardware, SGM non le conosce. Solo queste restano configurabili a mano.

## Cosa chiediamo/confermiamo a voi (SGM)
- **(a)** `get_hardware` live + capability nell'hello/INFO — timeline del prossimo build?
- **(b) `kiosk_livelli_cash.livello_attuale`: lo scrivete voi in realtime, per cassetta, ad ogni
  evento cash?** Confermate. Se NON lo fate ancora, **serve** (è la fonte autorevole del water level;
  oggi l'app mostra solo il valore dell'Init manuale → sembra "non sincronizzato").
- **(c)** `get_cash_levels` — confermate il payload (campi per-unità: `unita`, `livello_attuale`,
  `denom_cent`?) così l'app lo consuma per il refresh on-demand.

## Piano app (appena a+b pronti)
- Genera le righe livello da `get_hardware`; legge `livello_attuale` reale da `kiosk_livelli_cash`
  (scritto da voi); pulsante "Sincronizza ora" via `get_cash_levels`; **RIMUOVE l'Init livelli
  manuale**. L'operatore configura solo le soglie business.

Obiettivo: zero digitazione manuale di livelli/cassette. Tutto guidato dalla macchina.
