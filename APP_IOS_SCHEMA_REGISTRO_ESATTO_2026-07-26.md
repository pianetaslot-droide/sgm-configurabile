# App iOS → SGM/Windows — schema registro ESATTO per l'auto-register (2026-07-26)

Update operativo dopo `APP_IOS_CONFERMA_SETCONFIG_E_RESET`. **Novità: l'app ora
CREA lo schema** sul progetto Supabase nuovo durante il setup iniziale (via
Management API, testato e funzionante). Quindi la tabella `kiosk_dispositivi`
esiste con colonne PRECISE — ve le do così l'auto-register scrive nei nomi giusti.

## `kiosk_dispositivi` — colonne REALI create dall'app

```
id                uuid        primary key default gen_random_uuid()
nome              text        not null
location_code     text        unique
tipo_kiosk        text
seriale           text
versione_software text
indirizzo_ip      text
attivo            boolean     not null default true
note              text
inserito_da       uuid
tailscale_host    text        -- ⭐ per-macchina
tailscale_port    integer     -- ⭐ per-macchina
ble_adv_name      text        -- ⭐ es. "SGM-Lido-1"
created_at        timestamptz not null default now()
updated_at        timestamptz not null default now()
```
RLS OFF + `grant all to anon, authenticated` (l'app usa solo l'anon key).

## Differenze rispetto alla vostra proposta (§3 della vostra risposta) → da allineare

1. **PK**: la vostra proposta aveva `kiosk_id text PK`; la tabella reale ha
   **`id uuid PK`**. → Nell'auto-register fate **UPSERT con `id` = il kiosk_id
   (UUID) della macchina** (conflict target = `id`). Così l'app (che legge
   `KioskDispositivo.id`) e la macchina parlano dello stesso identificatore.
2. **`sala`**: la vostra proposta aveva una colonna `sala`; la tabella reale
   **non ce l'ha** (ha `location_code`). Ditemi cosa preferite:
   - (A) uso `location_code` come "sala" (nessuna modifica schema), oppure
   - (B) **aggiungo una colonna `sala text`** allo schema (un `alter table
     add column if not exists sala text` — facile lato mio).
   Per il multi-sala nell'app un campo `sala` dedicato è più pulito → propendo per
   (B), ma decidete voi e lo aggiungo.
3. Campi extra utili se li avete: `versione_software`, `indirizzo_ip`,
   `tipo_kiosk` (valore es. `"sgm"` — vedi nota tipo_kiosk più sotto).

## Auto-register: payload consigliato (UPSERT su `id`)

```sql
insert into public.kiosk_dispositivi
  (id, nome, tipo_kiosk, indirizzo_ip, tailscale_host, tailscale_port,
   ble_adv_name, attivo, updated_at)
values (<kiosk_id>, <label>, 'sgm', <ip>, <ts_host>, <ts_port>,
        <adv_name>, true, now())
on conflict (id) do update set
  nome=excluded.nome, indirizzo_ip=excluded.indirizzo_ip,
  tailscale_host=excluded.tailscale_host, tailscale_port=excluded.tailscale_port,
  ble_adv_name=excluded.ble_adv_name, updated_at=now();
```
(+ `sala` se scegliamo (B)). Lo fate su `set_config` e all'avvio, come avevate
proposto.

## Nota `tipo_kiosk`

L'app filtra ancora su `tipo_kiosk = "vne_plus"` in un punto (`FineTurnoView`,
con fallback a "tutti gli attivi"). Se scrivete `tipo_kiosk = "sgm"`, quel filtro
non troverà la riga ma il fallback la prende comunque. Quando volete standardizzare
su `"sgm"`, ditemelo e aggiorno il filtro (accetterà entrambi in transizione).

## Stato lato app (per contesto)

- Setup iniziale FUNZIONA: crea le 30 tabelle (incl. `kiosk_dispositivi` sopra) +
  il primo Supremo, via Management API. Nessun Supabase hardcoded.
- `set_config` (Connect `C09A0000`): layer di invio ancora da agganciare lato
  app (aspettiamo conferma che il vostro handler è live). Appena `set_config` è
  attivo sulla macchina, agganciamo il tasto "Provision" del wizard.
- Resta aperta la mia domanda su **`reset_sala`** (ordine reset→set_config, se
  azzera il technician_pin) — vedi `APP_IOS_CONFERMA_SETCONFIG_E_RESET`.

Ditemi: (1) va bene UPSERT su `id`=kiosk_id, (2) `sala` opzione A o B, (3) è live
il vostro handler `set_config`?
