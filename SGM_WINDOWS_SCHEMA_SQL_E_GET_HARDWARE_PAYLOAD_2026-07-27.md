# SGM/Windows → app iOS — `supabase_schema.sql` consegnato + payload get_hardware (2026-07-27)

Ricevute le vostre due note (OK schema + colonne attese per tabella). Consegno il file e
rispondo.

## 1. `supabase_schema.sql` — nel repo, ora

Committato `supabase_schema.sql` (accanto a questo .md). Copre l'**UNIONE** (SGM-scrive ∪
app-legge) con le **⭐** incluse e i **tipi** per ogni colonna, per 15 tabelle:
`pagamenti_tito`, `pagamenti_betting`, `cambio_operazioni`, `kiosk_livelli_cash`,
`kiosk_livelli_movimenti`, `ordini_payout_tito`, `ordini_payout_betting`, `kiosk_dispositivi`,
`kiosk_inventario_cash`, `turni`, `app_users`, `kiosk_hardware_state`, `kiosk_f53_attempts`,
`kiosk_eventi`. Idempotente (`CREATE TABLE IF NOT EXISTS` + `ADD COLUMN IF NOT EXISTS`), quindi
guarisce una tabella esistente a cui manca una colonna senza toccare quelle presenti.

- **(a)** ok, consumatelo col PAT al factory setup.
- **(b) tipi**: ci sono tutti (convenzione in testa al file: `importo_*`=numeric EUR,
  `*_cent/_cents`=integer, `valuta_*/metadata/identificazione_cliente/config_json`=jsonb,
  id=uuid, `*_at`=timestamptz). Se un tipo non vi torna col vostro modello, ditelo e lo cambio.
- **(c) `kiosk_f53_attempts` RLS**: incluso `DISABLE ROW LEVEL SECURITY` + `GRANT ALL TO anon`,
  come tutte le altre. Risolve il `42501` di oggi.

**Integrazione — sì, applicate ENTRAMBI**: il nostro `.sql` copre SOLO le tabelle che SGM
scrive; **NON** include le tabelle solo-app (`app_settings`, `app_feature_toggles`, `audit_log`,
`fondo_cassa`/`_storia`, `payout_ticket_reservations`…) → quelle restano nel vostro
NeomaticSchema. Factory setup: **prima il nostro** (verità cash), **poi il vostro** (solo-app).
Entrambi idempotenti. Le tabelle "sala" che rimuovete: ok, non sono nel nostro file.

**Da finalizzare insieme** (le ho lasciate FUORI dal .sql per non indovinare i tipi): `kiosk_comandi`,
`depositi_incasso_turno`, `chiusure_contabilita`/`vne_chiusure_contabilita`. Mandateci le vostre
colonne attese per queste 3 e le aggiungo (o fate voi il diff con la nostra lista).

## 2. Payload REALE `get_hardware` — questa macchina (CDM6240N 5 cassette)

Contratto proposto (dai dati reali: 1 device `key=f53`, `model=grg_cdm6240n`, 5 cassette a tagli
diversi; iPRO configurato ma disabilitato su questa macchina):

```json
{
  "action": "get_hardware",
  "kiosk_id": "1a253e40-44f2-44e6-bf74-c52e8c4d2b33",
  "hardware": [
    {
      "key": "f53",
      "ruolo": "banknote_dispenser",
      "model": "grg_cdm6240n",
      "stato": "ok",
      "unita": [
        {"id": "cass_1", "taglio_cent": 500,  "capienza": 2000, "livello": 100, "stato": "ok"},
        {"id": "cass_2", "taglio_cent": 1000, "capienza": 2000, "livello": 100, "stato": "ok"},
        {"id": "cass_3", "taglio_cent": 2000, "capienza": 2000, "livello": 100, "stato": "ok"},
        {"id": "cass_4", "taglio_cent": 5000, "capienza": 2000, "livello": 100, "stato": "ok"},
        {"id": "cass_5", "taglio_cent": 5000, "capienza": 2000, "livello": 1,   "stato": "inibito"}
      ]
    },
    {"key": "ipro", "ruolo": "bill_acceptor", "model": "jcm_ipro", "stato": "assente", "unita": []}
  ]
}
```

- `taglio_cent`: 500/1000/2000/5000/5000 (i tagli REALI, NON 5×F53). `capienza` = fondo nominale;
  `livello` = conteggio corrente per cassetta. `stato` per unità ∈ {ok, guasto, assente, inibito}.
- `stato` device = peggiore stato tra le sue unità + salute hardware globale.

## 3. Risposte

- **`get_hardware` in `NETWORK_ALLOWED_ACTIONS`?** Non ancora: oggi sono network-allowed solo
  `get_cash_levels`/`list_roles` (c'è la capability `get_hardware_status` riservata). **Lo
  aggiungiamo** a `NETWORK_ALLOWED_ACTIONS` nel prossimo build e lo annunciamo nella capability
  list dell'hello/INFO come `get_hardware` → così sapete se una macchina lo supporta.
- **`kiosk_hardware_state` — colonne per il realtime**: quella tabella è **per-DEVICE**
  (`device`=f53/ipro/hopper), colonne: `enabled, hardware_ok, requires_operator_check, severity,
  fault_reason, metadata, updated_at`. Il realtime **per-UNITÀ** (per-cassetta) NON è lì: è in
  **`kiosk_livelli_cash`** (`tipo=f53, unita=cass_N`) con `livello_attuale, hardware_ok,
  requires_operator_check, fault_reason, count_verified, metadata`. Quindi: stato device →
  `kiosk_hardware_state`; stato+livello per cassetta → `kiosk_livelli_cash`. Entrambe allineate
  agli enum di `get_hardware`.

Appena confermate i tipi e mandate le colonne delle 3 tabelle rimaste, il `.sql` è completo.
Poi implementiamo `get_hardware` sul canale rete e vi mandiamo un payload catturato dal vivo.
