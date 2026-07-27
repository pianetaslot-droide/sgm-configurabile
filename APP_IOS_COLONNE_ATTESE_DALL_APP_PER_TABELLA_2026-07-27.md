# App iOS → SGM/Windows — COLONNE che l'APP legge/scrive per tabella (per supabase_schema.sql) (2026-07-27)

Come da idea di Hu Leo: non aspettiamo passivi il vostro schema — vi diamo le colonne che
l'**app** si aspetta (dai modelli Swift). Il `supabase_schema.sql` deve coprire l'**UNIONE**:
`colonne che SGM scrive` ∪ `colonne che l'app legge/scrive`. Sotto, ⭐ = colonna che l'app usa ma
che NON era nella vostra lista → **va aggiunta** o l'app va in `42703/PGRST204`.

## Tabelle scritte da SGM — colonne attese dall'app (CodingKeys dei modelli)

**`pagamenti_tito`**: id, kiosk_id, ticket_barcode, ⭐ticket_valore, importo_pagato, valuta_erogata(jsonb),
stato, motivo_fallimento, sessione_id, operatore_id, created_at, fornitore, identificazione_cliente(jsonb),
manual_cents, ⭐manual_confermato_at, ⭐manual_confermato_da, ⭐source, ⭐operation_id, ⭐cloud_sync_status.
(completato_at: voi lo scrivete, l'app non lo legge — ok tenerlo.)

**`pagamenti_betting`**: id, kiosk_id, riferimento_vincita, ⭐importo_vincita, importo_pagato,
valuta_erogata(jsonb), tipo_gioco, stato, motivo_fallimento, sessione_id, operatore_id, created_at,
identificazione_cliente(jsonb), manual_cents, ⭐manual_confermato_at, ⭐manual_confermato_da, ⭐source,
⭐operation_id, ⭐cloud_sync_status.

**`cambio_operazioni`**: id, kiosk_id, tipo_cambio, importo_ricevuto, importo_erogato,
valuta_ricevuta(jsonb), valuta_erogata(jsonb), stato, motivo_fallimento, sessione_id, operatore_id,
created_at, credito_residuo_cent, credito_residuo_gestito_at, credito_residuo_gestito_note,
⭐credito_residuo_gestito_da, ⭐credito_residuo_gestito_nome, ⭐credito_residuo_gestito_ruolo.

**`kiosk_livelli_cash`**: id, tipo, unita, descrizione, enabled, kiosk_id, denom_cent, ⭐fondo_quantita,
livello_minimo, livello_massimo, livello_attuale, created_at, updated_at, ⭐hardware_ok, count_verified,
⭐requires_operator_check, ⭐fault_reason, ⭐last_hardware_event_at, ⭐last_count_verified_at,
⭐last_count_verified_by, metadata(jsonb).

**`kiosk_livelli_movimenti`**: id, tipo, unita, reason, note, metadata(jsonb), kiosk_id, livello_id,
unita_tipo, denom_cent, quantita_delta, quantita_prima, quantita_dopo, importo_cent, riferimento_tipo,
riferimento_id, riferimento_codice, manual_extra_cent, operatore_id.

**`ordini_payout_tito`**: id, ticket_barcode, importo_eur, kiosk_id, stato, motivo_fallimento, creato_da,
creato_da_nome, preso_in_carico_at, completato_at, created_at, origine, barcode_lunghezza, fornitore,
importo_pagato, manual_cents, valuta_erogata(jsonb), manual_confermato_at, manual_confermato_da,
identificazione_cliente(jsonb), no_50_partial_cents.

**`kiosk_dispositivi`**: id, nome, location_code, tipo_kiosk, seriale, versione_software, indirizzo_ip,
attivo, note, config_json(jsonb), sala, tailscale_host, tailscale_port, ble_adv_name, created_at.

**`kiosk_inventario_cash`**: id, kiosk_id, tipo_unita, denominazione_centesimi, quantita,
valore_totale_euro, motivo_aggiornamento, operazione_id, created_at.

**`turni`**: id, commesso_id, commesso_nome, inizio_turno, fine_turno, collega_entrante, tot_vlt_payout,
tot_awp_refill, tot_bet_raccolta, tot_bet_pagamenti, tot_bar, tot_vincite, saldo_inizio, saldo_fine,
note, created_at.  (`inizio_turno` DEFAULT now() — vedi bug turno risolto.)

**`app_users`**: id, nome, ruolo, pin, current_device_id, … (vi mandiamo il resto se serve).

> Restano da estrarre (ve le mando se le volete): `kiosk_eventi`, `kiosk_comandi`,
> `kiosk_hardware_state`, `ordini_payout_betting`, `depositi_incasso_turno`, `chiusure_contabilita`.

## Divisione di responsabilità (schema)
- **SGM `supabase_schema.sql`** = tabelle che SGM scrive (sopra) — **con le ⭐ incluse**.
- **App NeomaticSchema** = tabelle SOLO-app che SGM non scrive: `app_settings`, `app_feature_toggles`,
  `audit_log`, `fondo_cassa`/`_storia`, `payout_ticket_reservations`, ecc. Le applichiamo noi al
  factory setup DOPO il vostro.
- **Tabelle "sala" (movimenti_cassa, vincite_biglietti, versamenti_banca, fatture_*, ec_*, bar_*, awp_*,
  ecc.)**: Hu Leo ha deciso che Neomatic le **RIMUOVE** (sono residuo del copy da Game manager). Non
  vanno nello schema. Stiamo verificando quali code-path sono vivi per sfoltirle lato app.

## Richiesta
Includete le ⭐ nel `supabase_schema.sql`. Se preferite, mandateci il vostro elenco colonne per
tabella e facciamo il **diff** noi (app-attese vs SGM-scrive) e vi torniamo l'unione esatta.
