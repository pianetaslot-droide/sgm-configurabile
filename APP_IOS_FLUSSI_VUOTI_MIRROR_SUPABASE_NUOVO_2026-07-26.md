# App iOS → SGM/Windows — Flussi VUOTI: i pagamenti non arrivano al Supabase NUOVO (mirror?) (2026-07-26)

## Sintomo (confermato Hu Leo)
Pannello Kiosk → Flussi (TITO, Oggi): **0 record** ("Nessun pagamento TITO", Totale €0,00).
MA **oggi sulla macchina ci sono MOLTI pagamenti** (con v40 il payout reale gira). Quindi i
pagamenti ESISTONO sulla macchina ma **non compaiono sul Supabase nuovo** che l'app legge.
→ Non è "nessun dato": è un problema di **mirror/upload verso il progetto Supabase nuovo**.

## Lato app (verificato a codice)
Flussi TITO legge SOLO da Supabase, tabella `pagamenti_tito`:
```
SupabaseService.fetchPagamentiTitoRecenti → supabase.from("pagamenti_tito")
   .gte("created_at", oggi).lte(...).order("created_at", desc)
```
- `pagamenti_tito` **esiste** nel nuovo schema (NeomaticSchema, 31 tabelle). Query corretta.
- L'app **NON scrive** questa tabella. Come da vostra nota (SupabaseService:1412
  "SGM mirror-a qui i payout BLE"), **è SGM a fare il mirror** dei payout su `pagamenti_tito`.
→ Flussi vuoto = il mirror non ha scritto sul Supabase **nuovo**.

## Domande (priorità ALTA — senza questo Flussi/Livelli/Dashboard restano vuoti)
1. **Target del mirror**: dopo il provisioning (`set_config` con `supabase_url`+`anon_key`
   NUOVI), il mirror scrive sul **Supabase nuovo** o sta ancora scrivendo sul **vecchio**
   progetto? Sospetto forte: il mirror usa ancora la vecchia config e non quella di
   `set_config`. Va ri-puntato alla config di `set_config`.
2. **Tabelle mirrorate**: quali tabelle SGM mirrora su Supabase (`pagamenti_tito`,
   `pagamenti_betting`, `ordini_payout_tito`, `kiosk_eventi`, `kiosk_livelli_*`, dashboard…)?
   Così sappiamo cosa aspettarci in Flussi/Livelli/Dashboard sul nuovo progetto.
3. **Backfill di OGGI**: i pagamenti già sulla macchina vengono **ri-mirati** (retry dei
   record locali non sincronizzati) sul nuovo Supabase, o solo i nuovi da adesso? Ci
   servono anche gli storici di oggi.
4. **Cadenza/trigger** del mirror (a fine payout? batch periodico?) e come gestite il
   record "pagato ma non ancora mirato" (coda/retry) → rilevante per la quadratura.

## Contesto
North-star: SGM locale = verità, Supabase nuovo = sync/backup. Ma se il mirror punta al
progetto VECCHIO, l'app (che legge il NUOVO) non vedrà mai nulla — anche a payout perfetto.
Verosimilmente basta ri-puntare il mirror alle credenziali di `set_config`. Cash-safety:
i soldi sono usciti (v40) e il ledger locale ce l'ha; qui manca solo la replica sul DB che
guarda l'app.
