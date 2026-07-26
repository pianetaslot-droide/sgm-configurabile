# SGM/Windows → App iOS — RISPOSTA: no_50_partial_cents (root cause + fix, build v42) (2026-07-26)

Confermato il vostro report: il campo **arrivava alla macchina ma NON veniva applicato**
dalla pianificazione. Trovata la causa esatta, corretta e testata. Sarà nella **build v42**.

## Causa: c'erano DUE executor, quello VIVO non leggeva il campo

Il campo `no_50_partial_cents` era già letto da `local_first_tito_real.py`
(`TitoRealLiveExecutor`) — ma **quello non è l'executor che gira sulla macchina reale**.
Il payout reale sul CDM6240N è eseguito da **`local_first_cdm6240n.py`
(`CDM6240NPayoutExecutor`)**, che pianificava con un greedy "taglio più grande prima"
(`plan_cdm_notes`) e **non leggeva affatto** `no_50_partial_cents`. Di fatto `_execute`
non riceveva nemmeno il `request`. → tutto in €50.

Prova dal ledger locale del vostro test €150,25 (`ios-tito-065803723548660479-...`):
- **request_json**: `... "no_50_partial_cents": 5000 ...` → **il campo È arrivato** (byte 421 vs ~393 senza).
- **result_json**: `"actual_f53_units": {"cass_4": 3}` → **3× €50** (cass_4 = €50). Campo ignorato. Confermato.

## Le vostre 4 domande

1. **Il handler pay_operation legge `no_50_partial_cents`?**
   Il messaggio lo consegna (è in `request_json`, vedi sopra). Ma l'executor CDM live
   **non lo leggeva**. → **Ora sì**: aggiunto `_no_50_cents_from(operation, request)`
   (guarda il request live e, in fallback, il `request_json` dell'operazione preparata).

2. **La pianificazione applica il vincolo "questa parte senza €50"?**
   Prima **no**. → **Ora sì**: nuova `plan_cdm_notes_no_50(importo, stock, no_50_cents)`
   a due fasi — la quota `no_50_cents` è pianificata **solo da €20/€10/€5** (cass_3/2/1),
   il resto usa tutte le cassette (€50 incluso, cass_4/5). Vale anche nel loop di
   ri-pianificazione (residuo dopo cassetta esaurita) tramite un budget no-€50 residuo.

3. **Log del pagamento €150: è arrivato `no_50_partial_cents=5000`? Come ha pianificato?**
   Sì (5000). Ha pianificato 3× €50 (greedy, campo ignorato) — il bug. → Ora la macchina
   **logga esplicitamente** la preferenza e l'esito:
   ```
   CDM payout preferenza no-€50: no_50_cents=5000 amount=15025 op=... stock={...}
   CDM payout no-€50 esito: op=... no_50_cents=5000 paid_no_50=5000 dispensato={cass_3:2,cass_2:1,cass_4:2} paid=15000 residuo=25
   ```

4. **Se la parte senza €50 non è componibile (mancano €20/€10/€5), cosa fa?**
   **Definito così** (best-effort, cliente sempre pagato per intero quando lo stock lo permette):
   la quota no-€50 non componibile con i tagli piccoli **confluisce nel resto**, che PUÒ
   usare €50. Nessun blocco, nessun errore: la preferenza è rispettata *fin dove lo stock
   di €5/€10/€20 arriva*, poi si completa con €50. Se manca stock totale → residuo, come
   per qualsiasi payout. (Scelta: preferenza tagli < pagare il cliente. Se preferite invece
   che il "senza €50" non componibile diventi residuo esplicito da gestire a mano, ditelo e
   lo rendiamo configurabile.)

## Comportamento verificato (stessi input del vostro test)

Layout cassette CDM: cass_1=€5, cass_2=€10, cass_3=€20, cass_4=€50, cass_5=€50.

| Caso | Prima (bug) | Dopo (v42) |
|---|---|---|
| €150,25 · no_50=€50 | 3× €50 | **2×€20 + 1×€10 + 2×€50** = €50 piccoli + €100 |
| €150,00 · no_50=€50 | 3× €50 | **2×€20 + 1×€10 + 2×€50** (= vostro atteso) |
| €150 · no_50=€150 (tutto senza €50) | 3× €50 | **7×€20 + 1×€10**, zero €50 |
| no_50=0 | 3× €50 | 3× €50 (invariato, retro-compatibile) |
| piccoli scarsi (max €40 senza €50) | 3× €50 | €40 piccoli + €50 sul resto, eccedenza→residuo |

Il residuo sotto taglio (es. i €0,25 su €150,25, o l'eccedenza cambio) resta come oggi:
carta €50-esclusa dove richiesto, il centesimo/moneta va a residuo/PAGATO A MANO.

## Note

- Cash-safety invariata: cambia **solo la composizione dei tagli**, mai il totale. Nessun
  rischio doppio pagamento.
- Fix isolato a `services/local_first_cdm6240n.py` (motore CDM reale); vale per tutti i
  flow gestiti dal CDM (tito_payout, snai_*, novomatic_manuale, residual).
- Allineato alla stessa build che porta lo speed-up dashboard (v41) → **v42**.

## Prossimo passo

Consegno **v42** (deploy: sovrascrivere `Desktop\SGM-Windows\`, riavviare SGM). Ripetete il
test €150 con chip €50: atteso €50 in €20/€10 + €100 in 2×€50, e nei log le due righe
"preferenza no-€50" / "no-€50 esito".
