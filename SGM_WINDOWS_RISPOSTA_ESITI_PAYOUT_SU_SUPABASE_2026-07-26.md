# SGM/Windows → App iOS — Esiti payout su Supabase (l'app li legge da lì, non dal BLE) (2026-07-26)

Direzione condivisa (Hu Leo): **solo il COMANDO di pagamento va in BLE; l'esito lo legge
l'app da Supabase.** Così i risultati lunghi (residuo / revisione) non vengono più troncati
dai ~180 byte della notify BLE (il vostro caso reale: reply `operator_review_required` da
**183 byte** persa). Ecco cosa abbiamo fatto lato SGM (build **v43**) e cosa serve lato app.

## Cosa cambia lato SGM (v43)

Il ledger locale è già la verità; ora l'esito **confermato** di ogni payout local-first viene
**mirrorato nelle tabelle Supabase che l'app già legge** (idempotente, per-kiosk). Abbiamo
sganciato il mirror dalla RPC dedicata `sgm_ledger_sync_operation` (**non è deployata** — era
il motivo per cui NULLA si sincronizzava: 63 operazioni erano tutte `cloud_sync_status=pending`).
Ora il mirror scrive **direttamente** nelle tabelle legacy. Abilitazione con un **toggle da
touchscreen** (Impostazioni BLE → "Esiti pagamento → Supabase"); il worker gira sempre e si
attiva dal vivo, senza secondo riavvio.

## Tabelle / chiavi / stati che l'app deve leggere

| Flow | Tabella | Chiave (reference) | tipo_gioco |
|---|---|---|---|
| `tito_payout`, `novomatic_manuale_payout` | **pagamenti_tito** | `ticket_barcode` | — (fornitore) |
| `snai_betting_payout`, `snai_fastbet_payout` | **pagamenti_betting** | `riferimento_vincita` | snai_betting / snai_fastbet |
| `cambio_customer` | **cambio_operazioni** | `sessione_id` | — |

**Campo di JOIN consigliato: `sessione_id` = l'`operation_id` che avete inviato nel
`pay_operation`.** Così matchate l'esito con la richiesta senza ambiguità (meglio del barcode).

Colonne d'esito da leggere:
- `stato`: **`completato`** (pagato) | **`fallito`** (residuo aperto da gestire).
- `importo_pagato` (EUR erogati), `manual_cents` (residuo in cent, se `fallito`),
  `motivo_fallimento` (se residuo), `valuta_erogata` (breakdown tagli), `completato_at`.

Mappatura stato locale → mirror:
- `completed` / `completed_with_non_erogabile` → **completato**.
- `residual_open` / `partial_confirmed_residual_open` → **fallito** + `manual_cents` = residuo
  + `motivo_fallimento`. (Poi quando l'operatore fa PAGATO A MANO l'operazione diventa
  `completed` → il mirror si aggiorna a **completato**.)

## ⚠ Da decidere INSIEME (cash-safety): esito INCERTO e annullato

Due stati **NON** vengono mirrorati oggi, di proposito:
- `operator_review_required` = **esito INCERTO** (es. cassetto assente: non sappiamo se/quanto
  è uscito). Marcarlo `fallito` sarebbe **pericoloso**: se l'app lo tratta come "non pagato" e
  lascia ri-erogare, si rischia **doppio pagamento** su un'operazione dove il contante POTREBBE
  essere uscito. Quindi resta locale finché l'operatore non lo risolve fisicamente.
- `cancelled` = risolto come "nessun contante mosso".

**Proposta**: introduciamo uno stato distinto **`in_revisione`** (NON `fallito`) su
pagamenti_tito/pagamenti_betting, così l'app può mostrare "in verifica, NON ri-pagare" senza
innescare retry; e mirroriamo `cancelled` come segnale esplicito di "chiuso, biglietto ancora
dovuto/ri-pagabile". **Confermate**: (1) l'app gestisce uno stato `in_revisione` che blocca il
re-pay? (2) volete anche `cancelled` mirrorato? Appena confermate lo implemento.

## Ordine di rollout (per non rompere i pagamenti in produzione)

1. **Ora (v43)**: SGM scrive gli esiti su Supabase (toggle ON). Il reply BLE resta com'è.
2. **App**: iniziate a leggere l'esito da pagamenti_tito / pagamenti_betting (join su
   `sessione_id`), in parallelo al reply BLE. Verificate su un payout reale.
3. **Solo DOPO** che l'app legge l'esito da Supabase: snelliamo il reply BLE a un **ack
   minimale** (operation_id + stato breve), così non supera mai la MTU. Questo passo è
   coordinato: se lo facciamo prima, l'app resta senza esito. Ditemi quando siete pronti.

## Note

- Cash-safety invariata: il mirror segue SEMPRE i fatti di cassa locali confermati; non decide
  pagamenti, non tocca il ledger. Idempotente su (kiosk_id, chiave).
- Nessuna RPC/tabella nuova da creare lato Supabase: usiamo pagamenti_tito / pagamenti_betting /
  cambio_operazioni che già leggete.
