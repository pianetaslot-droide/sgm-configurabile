# App iOS → SGM/Windows — no_50_partial_cents NON applicato dalla macchina (2026-07-26)

## Sintomo (test reale Hu Leo, app ATTUALE)
Payout TITO da **€150**. In "Taglio pagamento" → **"Senza €50 per una parte"** +
chip **€50** ⇒ `no_50_partial_cents = 5000` (€50).
- **Atteso**: €50 erogati SENZA banconote da €50 (es. €20+€20+€10); il resto €100
  automatico → **2× €50 + €50 in tagli piccoli**.
- **Reale**: la macchina ha erogato **3× €50** (tutto €50) → `no_50_partial_cents`
  **ignorato dalla pianificazione**.

## Lato app: il campo VIENE inviato (verificato a codice, non è un gap app)
`no_50_partial_cents` è nel payload `pay_operation`:
```
BLEKioskService.payViaPayOperation:446   if noFiftyPartialCents > 0 { msg["no_50_partial_cents"] = 5000 }
BLEKioskService.payoutLocalFirst:331     → payViaPayOperation(..., noFiftyPartialCents: …)
```
Lo passano ENTRAMBI i path (pay_operation nuovo + prepare/commit :340/351).
Nota storica nostra (2026-07-04): il campo (migration 013) era letto dal Pi **solo
sul vecchio path a polling Supabase, MAI sul BLE local-first** — l'abbiamo aggiunto
al protocollo BLE proprio per chiudere quel gap. Quindi ORA l'app lo manda davvero.

## Semantica del campo (per allineare l'erogazione)
`no_50_partial_cents = X` (multiplo di €5, 0 < X ≤ importo):
- **X** va erogato SENZA tagli da €50 (solo €5/€10/€20).
- Il **resto** (importo − X) è pianificato in automatico (PUÒ usare €50).
- Es. €150, X=€50 → €50 in piccoli + €100 automatico (2× €50).
- (Se X = importo troncato a €5 ⇒ di fatto "tutto senza €50".)

## Richiesta a voi
1. Il handler `pay_operation` lato SGM/Windows **legge** `no_50_partial_cents`?
2. La pianificazione erogazione (F53/hopper denomination planning) **applica** il
   vincolo "questa parte senza €50"? Oggi sembra ignorarlo (3× €50 su €150).
3. Controllate i **log** di quel pagamento €150: è arrivato `no_50_partial_cents=5000`?
   Come ha pianificato i tagli?
4. Se la macchina non riesce a comporre la parte senza €50 (mancano €20/€10/€5),
   cosa fa? (residuo/parziale?) — meglio definirlo.

## Contesto
Indipendente dal timeout payout (v36) ma tocca la stessa pianificazione erogazione:
se comodo, allineatelo con v36. Cash-safety: nessun rischio doppio pagamento — qui
è solo la COMPOSIZIONE dei tagli a non rispettare la richiesta dell'operatore.
