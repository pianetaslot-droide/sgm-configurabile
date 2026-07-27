-- ============================================================================
-- supabase_schema.sql — SGM/Windows canonical schema for the tables SGM WRITES.
-- Idempotent: safe to re-run. Applied by the app's PAT at factory setup, BEFORE
-- the app's own NeomaticSchema (which owns the app-only tables listed at bottom).
--
-- Design:
--   * CREATE TABLE IF NOT EXISTS  -> fresh project bootstrap.
--   * ALTER TABLE ADD COLUMN IF NOT EXISTS -> heals an EXISTING table missing a
--     column (the real drift case: e.g. pagamenti_tito without manual_cents/
--     fornitore). Type applies only when the column is created; if it already
--     exists with another type it is left untouched (no conflict).
--   * Covers the UNION: columns SGM writes  ∪  columns the app reads (⭐ from the
--     app's Swift models, per APP_IOS_COLONNE_ATTESE_2026-07-27).
--   * RLS OFF + GRANT anon on every table (the whole stack uses the anon key).
--
-- Conventions:  importo_* = numeric EUR;  *_cent/*_cents = integer cents;
--   valuta_*/metadata/identificazione_cliente/config_json = jsonb;  ids = uuid;
--   *_at = timestamptz.
-- ============================================================================

-- ---------------------------------------------------------------- pagamenti_tito
create table if not exists pagamenti_tito (id uuid primary key default gen_random_uuid());
alter table pagamenti_tito add column if not exists kiosk_id uuid;
alter table pagamenti_tito add column if not exists ticket_barcode text;
alter table pagamenti_tito add column if not exists ticket_valore numeric;              -- ⭐
alter table pagamenti_tito add column if not exists importo_pagato numeric;
alter table pagamenti_tito add column if not exists valuta_erogata jsonb;
alter table pagamenti_tito add column if not exists stato text;
alter table pagamenti_tito add column if not exists motivo_fallimento text;
alter table pagamenti_tito add column if not exists sessione_id text;
alter table pagamenti_tito add column if not exists operatore_id uuid;
alter table pagamenti_tito add column if not exists created_at timestamptz default now();
alter table pagamenti_tito add column if not exists completato_at timestamptz;
alter table pagamenti_tito add column if not exists fornitore text;
alter table pagamenti_tito add column if not exists identificazione_cliente jsonb;
alter table pagamenti_tito add column if not exists manual_cents integer;
alter table pagamenti_tito add column if not exists manual_confermato_at timestamptz;    -- ⭐
alter table pagamenti_tito add column if not exists manual_confermato_da uuid;            -- ⭐
alter table pagamenti_tito add column if not exists source text;                         -- ⭐
alter table pagamenti_tito add column if not exists operation_id text;                    -- ⭐
alter table pagamenti_tito add column if not exists cloud_sync_status text;               -- ⭐
alter table pagamenti_tito disable row level security;
grant all on pagamenti_tito to anon;

-- ------------------------------------------------------------- pagamenti_betting
create table if not exists pagamenti_betting (id uuid primary key default gen_random_uuid());
alter table pagamenti_betting add column if not exists kiosk_id uuid;
alter table pagamenti_betting add column if not exists riferimento_vincita text;
alter table pagamenti_betting add column if not exists importo_vincita numeric;           -- ⭐
alter table pagamenti_betting add column if not exists importo_pagato numeric;
alter table pagamenti_betting add column if not exists valuta_erogata jsonb;
alter table pagamenti_betting add column if not exists tipo_gioco text;
alter table pagamenti_betting add column if not exists stato text;
alter table pagamenti_betting add column if not exists motivo_fallimento text;
alter table pagamenti_betting add column if not exists sessione_id text;
alter table pagamenti_betting add column if not exists operatore_id uuid;
alter table pagamenti_betting add column if not exists created_at timestamptz default now();
alter table pagamenti_betting add column if not exists completato_at timestamptz;
alter table pagamenti_betting add column if not exists identificazione_cliente jsonb;
alter table pagamenti_betting add column if not exists manual_cents integer;
alter table pagamenti_betting add column if not exists manual_confermato_at timestamptz;  -- ⭐
alter table pagamenti_betting add column if not exists manual_confermato_da uuid;          -- ⭐
alter table pagamenti_betting add column if not exists source text;                        -- ⭐
alter table pagamenti_betting add column if not exists operation_id text;                   -- ⭐
alter table pagamenti_betting add column if not exists cloud_sync_status text;              -- ⭐
alter table pagamenti_betting disable row level security;
grant all on pagamenti_betting to anon;

-- ------------------------------------------------------------ cambio_operazioni
create table if not exists cambio_operazioni (id uuid primary key default gen_random_uuid());
alter table cambio_operazioni add column if not exists kiosk_id uuid;
alter table cambio_operazioni add column if not exists tipo_cambio text;
alter table cambio_operazioni add column if not exists importo_ricevuto numeric;
alter table cambio_operazioni add column if not exists importo_erogato numeric;
alter table cambio_operazioni add column if not exists valuta_ricevuta jsonb;
alter table cambio_operazioni add column if not exists valuta_erogata jsonb;
alter table cambio_operazioni add column if not exists stato text;
alter table cambio_operazioni add column if not exists motivo_fallimento text;
alter table cambio_operazioni add column if not exists sessione_id text;
alter table cambio_operazioni add column if not exists operatore_id uuid;
alter table cambio_operazioni add column if not exists created_at timestamptz default now();
alter table cambio_operazioni add column if not exists completato_at timestamptz;
alter table cambio_operazioni add column if not exists credito_residuo_cent integer;
alter table cambio_operazioni add column if not exists credito_residuo_gestito_at timestamptz;
alter table cambio_operazioni add column if not exists credito_residuo_gestito_note text;
alter table cambio_operazioni add column if not exists credito_residuo_gestito_da uuid;    -- ⭐
alter table cambio_operazioni add column if not exists credito_residuo_gestito_nome text;  -- ⭐
alter table cambio_operazioni add column if not exists credito_residuo_gestito_ruolo text; -- ⭐
alter table cambio_operazioni disable row level security;
grant all on cambio_operazioni to anon;

-- ------------------------------------------------------------- kiosk_livelli_cash
create table if not exists kiosk_livelli_cash (id uuid primary key default gen_random_uuid());
alter table kiosk_livelli_cash add column if not exists kiosk_id uuid;
alter table kiosk_livelli_cash add column if not exists tipo text;                 -- f53|hopper|ipro
alter table kiosk_livelli_cash add column if not exists unita text;                -- cass_1..5 / hopper_x
alter table kiosk_livelli_cash add column if not exists descrizione text;
alter table kiosk_livelli_cash add column if not exists enabled boolean default true;
alter table kiosk_livelli_cash add column if not exists denom_cent integer;
alter table kiosk_livelli_cash add column if not exists fondo_quantita integer;    -- ⭐
alter table kiosk_livelli_cash add column if not exists livello_minimo integer;
alter table kiosk_livelli_cash add column if not exists livello_massimo integer;
alter table kiosk_livelli_cash add column if not exists livello_attuale integer;
alter table kiosk_livelli_cash add column if not exists created_at timestamptz default now();
alter table kiosk_livelli_cash add column if not exists updated_at timestamptz;
alter table kiosk_livelli_cash add column if not exists hardware_ok boolean;                 -- ⭐
alter table kiosk_livelli_cash add column if not exists count_verified boolean;
alter table kiosk_livelli_cash add column if not exists requires_operator_check boolean;     -- ⭐
alter table kiosk_livelli_cash add column if not exists fault_reason text;                    -- ⭐
alter table kiosk_livelli_cash add column if not exists last_hardware_event_at timestamptz;   -- ⭐
alter table kiosk_livelli_cash add column if not exists last_count_verified_at timestamptz;   -- ⭐
alter table kiosk_livelli_cash add column if not exists last_count_verified_by uuid;          -- ⭐
alter table kiosk_livelli_cash add column if not exists metadata jsonb;
alter table kiosk_livelli_cash disable row level security;
grant all on kiosk_livelli_cash to anon;

-- --------------------------------------------------------- kiosk_livelli_movimenti
create table if not exists kiosk_livelli_movimenti (id uuid primary key default gen_random_uuid());
alter table kiosk_livelli_movimenti add column if not exists kiosk_id uuid;
alter table kiosk_livelli_movimenti add column if not exists livello_id uuid;
alter table kiosk_livelli_movimenti add column if not exists tipo text;
alter table kiosk_livelli_movimenti add column if not exists unita text;
alter table kiosk_livelli_movimenti add column if not exists unita_tipo text;
alter table kiosk_livelli_movimenti add column if not exists denom_cent integer;
alter table kiosk_livelli_movimenti add column if not exists quantita_delta integer;
alter table kiosk_livelli_movimenti add column if not exists quantita_prima integer;
alter table kiosk_livelli_movimenti add column if not exists quantita_dopo integer;
alter table kiosk_livelli_movimenti add column if not exists importo_cent integer;
alter table kiosk_livelli_movimenti add column if not exists riferimento_tipo text;
alter table kiosk_livelli_movimenti add column if not exists riferimento_id text;
alter table kiosk_livelli_movimenti add column if not exists riferimento_codice text;
alter table kiosk_livelli_movimenti add column if not exists manual_extra_cent integer;
alter table kiosk_livelli_movimenti add column if not exists reason text;
alter table kiosk_livelli_movimenti add column if not exists note text;
alter table kiosk_livelli_movimenti add column if not exists metadata jsonb;
alter table kiosk_livelli_movimenti add column if not exists operatore_id uuid;
alter table kiosk_livelli_movimenti add column if not exists created_at timestamptz default now();
alter table kiosk_livelli_movimenti disable row level security;
grant all on kiosk_livelli_movimenti to anon;

-- ------------------------------------------------------------ ordini_payout_tito
create table if not exists ordini_payout_tito (id uuid primary key default gen_random_uuid());
alter table ordini_payout_tito add column if not exists kiosk_id uuid;
alter table ordini_payout_tito add column if not exists ticket_barcode text;
alter table ordini_payout_tito add column if not exists importo_eur numeric;
alter table ordini_payout_tito add column if not exists stato text;
alter table ordini_payout_tito add column if not exists motivo_fallimento text;
alter table ordini_payout_tito add column if not exists creato_da uuid;
alter table ordini_payout_tito add column if not exists creato_da_nome text;
alter table ordini_payout_tito add column if not exists preso_in_carico_at timestamptz;
alter table ordini_payout_tito add column if not exists completato_at timestamptz;
alter table ordini_payout_tito add column if not exists created_at timestamptz default now();
alter table ordini_payout_tito add column if not exists origine text;
alter table ordini_payout_tito add column if not exists barcode_lunghezza integer;
alter table ordini_payout_tito add column if not exists fornitore text;
alter table ordini_payout_tito add column if not exists importo_pagato numeric;
alter table ordini_payout_tito add column if not exists manual_cents integer;
alter table ordini_payout_tito add column if not exists valuta_erogata jsonb;
alter table ordini_payout_tito add column if not exists manual_confermato_at timestamptz;
alter table ordini_payout_tito add column if not exists manual_confermato_da uuid;
alter table ordini_payout_tito add column if not exists identificazione_cliente jsonb;
alter table ordini_payout_tito add column if not exists no_50_partial_cents integer;
alter table ordini_payout_tito disable row level security;
grant all on ordini_payout_tito to anon;

-- --------------------------------------------------------- ordini_payout_betting
create table if not exists ordini_payout_betting (id uuid primary key default gen_random_uuid());
alter table ordini_payout_betting add column if not exists kiosk_id uuid;
alter table ordini_payout_betting add column if not exists riferimento_vincita text;
alter table ordini_payout_betting add column if not exists importo_eur numeric;
alter table ordini_payout_betting add column if not exists tipo_gioco text;
alter table ordini_payout_betting add column if not exists stato text;
alter table ordini_payout_betting add column if not exists motivo_fallimento text;
alter table ordini_payout_betting add column if not exists creato_da uuid;
alter table ordini_payout_betting add column if not exists creato_da_nome text;
alter table ordini_payout_betting add column if not exists completato_at timestamptz;
alter table ordini_payout_betting add column if not exists created_at timestamptz default now();
alter table ordini_payout_betting add column if not exists importo_pagato numeric;
alter table ordini_payout_betting add column if not exists manual_cents integer;
alter table ordini_payout_betting add column if not exists valuta_erogata jsonb;
alter table ordini_payout_betting disable row level security;
grant all on ordini_payout_betting to anon;

-- ------------------------------------------------------------- kiosk_dispositivi
create table if not exists kiosk_dispositivi (id uuid primary key default gen_random_uuid());
alter table kiosk_dispositivi add column if not exists nome text;
alter table kiosk_dispositivi add column if not exists location_code text;
alter table kiosk_dispositivi add column if not exists tipo_kiosk text;
alter table kiosk_dispositivi add column if not exists seriale text;
alter table kiosk_dispositivi add column if not exists versione_software text;
alter table kiosk_dispositivi add column if not exists indirizzo_ip text;
alter table kiosk_dispositivi add column if not exists attivo boolean default true;
alter table kiosk_dispositivi add column if not exists note text;
alter table kiosk_dispositivi add column if not exists config_json jsonb;
alter table kiosk_dispositivi add column if not exists sala text;
alter table kiosk_dispositivi add column if not exists tailscale_host text;
alter table kiosk_dispositivi add column if not exists tailscale_port integer;
alter table kiosk_dispositivi add column if not exists ble_adv_name text;
alter table kiosk_dispositivi add column if not exists created_at timestamptz default now();
alter table kiosk_dispositivi disable row level security;
grant all on kiosk_dispositivi to anon;

-- --------------------------------------------------------- kiosk_inventario_cash
create table if not exists kiosk_inventario_cash (id uuid primary key default gen_random_uuid());
alter table kiosk_inventario_cash add column if not exists kiosk_id uuid;
alter table kiosk_inventario_cash add column if not exists tipo_unita text;
alter table kiosk_inventario_cash add column if not exists denominazione_centesimi integer;
alter table kiosk_inventario_cash add column if not exists quantita integer;
alter table kiosk_inventario_cash add column if not exists valore_totale_euro numeric;
alter table kiosk_inventario_cash add column if not exists motivo_aggiornamento text;
alter table kiosk_inventario_cash add column if not exists operazione_id text;
alter table kiosk_inventario_cash add column if not exists created_at timestamptz default now();
alter table kiosk_inventario_cash disable row level security;
grant all on kiosk_inventario_cash to anon;

-- ------------------------------------------------------------------------- turni
create table if not exists turni (id uuid primary key default gen_random_uuid());
alter table turni add column if not exists commesso_id uuid;
alter table turni add column if not exists commesso_nome text;
alter table turni add column if not exists inizio_turno timestamptz default now();
alter table turni add column if not exists fine_turno timestamptz;
alter table turni add column if not exists collega_entrante text;
alter table turni add column if not exists tot_vlt_payout numeric;
alter table turni add column if not exists tot_awp_refill numeric;
alter table turni add column if not exists tot_bet_raccolta numeric;
alter table turni add column if not exists tot_bet_pagamenti numeric;
alter table turni add column if not exists tot_bar numeric;
alter table turni add column if not exists tot_vincite numeric;
alter table turni add column if not exists saldo_inizio numeric;
alter table turni add column if not exists saldo_fine numeric;
alter table turni add column if not exists note text;
alter table turni add column if not exists created_at timestamptz default now();
alter table turni disable row level security;
grant all on turni to anon;

-- -------------------------------------------------------------------- app_users
create table if not exists app_users (id uuid primary key default gen_random_uuid());
alter table app_users add column if not exists nome text;
alter table app_users add column if not exists ruolo text;
alter table app_users add column if not exists pin text;
alter table app_users add column if not exists current_device_id text;
alter table app_users add column if not exists attivo boolean default true;
alter table app_users add column if not exists sala text;
alter table app_users add column if not exists created_at timestamptz default now();
alter table app_users disable row level security;
grant all on app_users to anon;

-- ------------------------------------------------------- kiosk_hardware_state (SGM)
create table if not exists kiosk_hardware_state (id uuid primary key default gen_random_uuid());
alter table kiosk_hardware_state add column if not exists kiosk_id uuid;
alter table kiosk_hardware_state add column if not exists device text;         -- f53|ipro|hopper
alter table kiosk_hardware_state add column if not exists enabled boolean default true;
alter table kiosk_hardware_state add column if not exists hardware_ok boolean;
alter table kiosk_hardware_state add column if not exists requires_operator_check boolean;
alter table kiosk_hardware_state add column if not exists severity text;        -- ok|warning|error
alter table kiosk_hardware_state add column if not exists fault_reason text;
alter table kiosk_hardware_state add column if not exists metadata jsonb;       -- sensor snapshot
alter table kiosk_hardware_state add column if not exists updated_at timestamptz default now();
alter table kiosk_hardware_state add column if not exists updated_by uuid;
alter table kiosk_hardware_state disable row level security;
grant all on kiosk_hardware_state to anon;

-- --------------------------------------------------------- kiosk_f53_attempts (SGM)
-- Per-attempt hardware dispense log. Failing INSERT with 42501 (RLS) today.
create table if not exists kiosk_f53_attempts (id uuid primary key default gen_random_uuid());
alter table kiosk_f53_attempts add column if not exists kiosk_id uuid;
alter table kiosk_f53_attempts add column if not exists unita text;
alter table kiosk_f53_attempts add column if not exists flow text;
alter table kiosk_f53_attempts add column if not exists requested_count integer;
alter table kiosk_f53_attempts add column if not exists confirmed_count integer;
alter table kiosk_f53_attempts add column if not exists result text;
alter table kiosk_f53_attempts add column if not exists error_code text;
alter table kiosk_f53_attempts add column if not exists error_text text;
alter table kiosk_f53_attempts add column if not exists metadata jsonb;
alter table kiosk_f53_attempts add column if not exists created_at timestamptz default now();
alter table kiosk_f53_attempts disable row level security;
grant all on kiosk_f53_attempts to anon;

-- --------------------------------------------------------------- kiosk_eventi (SGM)
create table if not exists kiosk_eventi (id uuid primary key default gen_random_uuid());
alter table kiosk_eventi add column if not exists kiosk_id uuid;
alter table kiosk_eventi add column if not exists tipo_evento text;
alter table kiosk_eventi add column if not exists payload jsonb;
alter table kiosk_eventi add column if not exists created_at timestamptz default now();
alter table kiosk_eventi disable row level security;
grant all on kiosk_eventi to anon;

-- ------------------------------------------------------------- kiosk_comandi
-- Command queue app->Pi; the Pi (SGM) updates stato/preso_in_carico/completato/
-- risposta. Columns from the app model.
create table if not exists kiosk_comandi (id uuid primary key default gen_random_uuid());
alter table kiosk_comandi add column if not exists kiosk_id uuid;
alter table kiosk_comandi add column if not exists comando text;
alter table kiosk_comandi add column if not exists stato text default 'pending';
alter table kiosk_comandi add column if not exists creato_da text;
alter table kiosk_comandi add column if not exists preso_in_carico_at timestamptz;
alter table kiosk_comandi add column if not exists completato_at timestamptz;
alter table kiosk_comandi add column if not exists risposta text;
alter table kiosk_comandi add column if not exists motivo_fallimento text;
alter table kiosk_comandi add column if not exists created_at timestamptz default now();
alter table kiosk_comandi add column if not exists manual_confermato_da uuid;
alter table kiosk_comandi add column if not exists manual_confermato_da_nome text;
alter table kiosk_comandi add column if not exists manual_confermato_at timestamptz;
alter table kiosk_comandi add column if not exists manual_confermato_note text;
-- Drop the LEGACY CHECK constraints on comando/stato: the old ones reject 'ping'
-- and use 'eseguito' instead of 'completato', breaking the app. Enums are enforced
-- in app/SGM code, not a DB CHECK, so future commands/states never get blocked.
do $$
declare c record;
begin
  for c in select conname from pg_constraint
           where conrelid = 'kiosk_comandi'::regclass and contype = 'c'
  loop execute format('alter table kiosk_comandi drop constraint %I', c.conname); end loop;
end $$;
alter table kiosk_comandi disable row level security;
grant all on kiosk_comandi to anon;

-- --------------------------------------------------- depositi_incasso_turno (SGM)
-- iPRO cash-in deposit per shift. SGM writes it; DDL aligned with the app model.
create table if not exists depositi_incasso_turno (id uuid primary key default gen_random_uuid());
alter table depositi_incasso_turno add column if not exists kiosk_id uuid;
alter table depositi_incasso_turno add column if not exists operatore_id uuid;
alter table depositi_incasso_turno add column if not exists operatore_nome text;
alter table depositi_incasso_turno add column if not exists totale_cent integer;
alter table depositi_incasso_turno add column if not exists breakdown jsonb default '{}'::jsonb;
alter table depositi_incasso_turno add column if not exists source text default 'ipro';
alter table depositi_incasso_turno add column if not exists stato text default 'completato';
alter table depositi_incasso_turno add column if not exists note text;
alter table depositi_incasso_turno add column if not exists created_at timestamptz default now();
alter table depositi_incasso_turno add column if not exists completed_at timestamptz default now();
-- totale_eur: generated column only when the table is freshly created (a generated
-- column cannot be added with ADD COLUMN IF NOT EXISTS on an existing table cleanly);
-- if you want it, add it once on the app side. We keep totale_cent as the source.
alter table depositi_incasso_turno disable row level security;
grant all on depositi_incasso_turno to anon;

-- NOTE — deliberately NOT in this SGM schema:
--   * chiusure_contabilita  = SALA accounting closure (P&L), written ONLY by the
--     app (SGM only READS it for dashboard metrics). App-only -> NeomaticSchema.
--   * vne_chiusure_contabilita: SGM's dashboard writes it, but it's derived/legacy;
--     if it ever 42703s tell us and we'll add its columns.
--   * APP-ONLY tables (SGM never writes) stay in the app's NeomaticSchema, applied
--     AFTER this file: app_settings, app_feature_toggles, audit_log,
--     fondo_cassa/_storia, payout_ticket_reservations, etc. The "sala" tables are
--     being REMOVED by the app — not in any schema.
--
-- APP-ONLY tables (SGM never writes) stay in the app's NeomaticSchema, applied
-- AFTER this file at factory setup: app_settings, app_feature_toggles, audit_log,
-- fondo_cassa/_storia, payout_ticket_reservations, etc. The "sala" tables
-- (movimenti_cassa, vincite_biglietti, versamenti_banca, fatture_*, ec_*, bar_*,
-- awp_*, ...) are being REMOVED by the app — not in any schema.
