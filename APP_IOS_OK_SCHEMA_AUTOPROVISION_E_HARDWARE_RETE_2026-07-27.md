# App iOS → SGM/Windows — OK schema auto-provision + hardware via RETE: confermo, mandate i file (2026-07-27)

Hu Leo ha deciso: **(1) adottiamo il vostro `supabase_schema.sql` (lo applica il nostro PAT al
factory setup); (2) hardware dinamico via RETE — partiamo, confermate il contratto.**

## 1. Schema auto-provision — SÌ (a/b/c)
- **(a) SÌ**: consumiamo un `supabase_schema.sql` idempotente dal repo e lo applichiamo col PAT al
  factory setup. Il flusso Management API esiste già (FirstRunSetup/ConfigurazioneBackend oggi
  applica il NOSTRO NeomaticSchema) → lo sostituiamo/affianchiamo col vostro.
- **(b) Vogliamo i tipi colonna ESATTI per TUTTE le tabelle che scrivete** (estraeteli dal codice),
  non solo le critiche → così il drift non ricapita. Meglio troppo che troppo poco.
- **(c) `kiosk_f53_attempts` RLS**: tutto il nostro schema gira **RLS OFF + GRANT anon** (l'app usa
  l'anon key). Quindi allineate f53_attempts: `DISABLE ROW LEVEL SECURITY` + `GRANT ALL TO anon`
  come le altre (oppure, se tenete RLS ON, una policy `INSERT ... WITH CHECK (true)` per anon).
  Includetelo nel .sql.

**Integrazione (importante)**: il vostro `supabase_schema.sql` copre le tabelle che SGM scrive
(cash/reporting + app_users + kiosk_*). Ma ci sono tabelle **SOLO-app** che SGM non scrive
(`app_settings`, `app_feature_toggles`, `audit_log`, `fondo_cassa`/`_storia`, `payout_ticket_reservations`…):
quelle le teniamo noi in NeomaticSchema. Al factory setup applichiamo **ENTRAMBI** (idempotenti):
prima il vostro (verità cash), poi il nostro per le solo-app. Ok? O il vostro .sql le include già?

## 2. Hardware dinamico via RETE — contratto CONFERMATO, mandate esempio
Confermo tutto:
- **`get_hardware` sul canale RETE** (RemoteOps/Tailscale, come get_cash_levels), NON BLE. ✓
- **Realtime da `kiosk_hardware_state`** (Supabase); inventario da `get_hardware`. ✓
- **enum**: `ruolo` ∈ {banknote_dispenser, coin_hopper, bill_acceptor, coin_acceptor};
  `stato` ∈ {ok, guasto, assente, inibito}. ✓
- Caso CDM6240N (1 device key=f53, model=grg_cdm6240n, 5 cassette con tagli diversi): l'app genera
  i livelli dalle `unita[]` con `taglio_cent` REALI, non da 5×F53. ✓ (Proprio il motivo del refactor.)

**Mandateci il payload REALE di `get_hardware`** da questa macchina (CDM6240N 5 cassette + iPRO):
campi esatti di `hardware[]` e `unita[]` (`taglio_cent`, `capienza`, `livello`, `stato`,
`id`/`key` unità). Con quello costruiamo il generatore livelli/routing e validiamo E2E.

Domande:
- `get_hardware` è già in `NETWORK_ALLOWED_ACTIONS` o lo aggiungete ora? Come sappiamo se una
  macchina lo supporta (capability)?
- `kiosk_hardware_state`: quali colonne leggo per il realtime per-unità (`ruolo`/`unita.id`/`stato`)?
  Allineate a `get_hardware`?
