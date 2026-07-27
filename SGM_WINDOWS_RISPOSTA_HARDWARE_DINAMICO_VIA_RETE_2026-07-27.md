# SGM/Windows → app iOS — hardware dinamico: SÌ, ma via RETE (non BLE) (2026-07-27)

D'accordo sul principio: la macchina dichiara il suo hardware reale (inventario + stato) e
l'app genera livelli/routing da lì, invece dei `5×F53 + 3×hopper` cablati.

## Decisione di Hu Leo: hardware via RETE, non via BLE

L'inventario/stato hardware **NON** va su `hello`/`KIOSK_INFO` (BLE). Coerente con
l'architettura: **BLE = solo comandi di pagamento**; tutto il resto (livelli, ruoli, e ora
hardware) va sul **canale di rete** (RemoteOps/Tailscale) + Supabase.

## Come lo esponiamo

1. **Inventario/snapshot on-demand → azione `get_hardware` sul canale di RETE**
   (RemoteOps API, la stessa via Tailscale di `get_cash_levels`; la aggiungiamo a
   `NETWORK_ALLOWED_ACTIONS`). C'è già la capability `get_hardware_status` prevista. NON su BLE.
2. **Stato realtime → Supabase `kiosk_hardware_state`** (che SGM GIÀ scrive per F53 e iPRO ad
   ogni cambio stato). L'app legge il realtime da lì; `get_hardware` serve per lo snapshot
   inventario on-demand.

## Risposte alle vostre domande

1. **La macchina conosce il suo hardware?** SÌ. Fonte = `config.json → devices` (per ogni
   device: `key` f53/ipro/hopper/cctalk, `model` es. `grg_cdm6240n`, `enabled`, `params` con
   le **cassette `taglio€:numero`** = tagli + capienza) + `hardware_registry` + stato live dal
   driver. Es. questa macchina: 1 device `key=f53` ma `model=grg_cdm6240n` = **CDM6240N a 5
   cassette** (NON 5×F53): tagli cass_1=5€, cass_2=10€, cass_3=20€, cass_4/5=50€.
2. **Dove/formato** → `get_hardware` (rete) restituisce un array `hardware[]`, un elemento per
   unità erogante/accettante con: `key`, `ruolo`, `model`, `stato`, e per gli erogatori le
   `unita` (cassette/hopper) con `taglio_cent` + `capienza`/`livello`.
3. **Realtime** → `kiosk_hardware_state` su Supabase (già scritto da SGM). Nessuna notify BLE.
4. **Enum proposti** (da confermare):
   - `ruolo`: `banknote_dispenser` (f53/cdm) · `coin_hopper` (hopper) · `bill_acceptor` (ipro)
     · `coin_acceptor` (cctalk).
   - `stato`: `ok` · `guasto` · `assente` · `inibito` (allineati a `kiosk_hardware_state`).
5. **`kiosk_hardware_state`** → resta per lo STATO realtime (SGM lo aggiorna). L'INVENTARIO
   (montaggio + tagli) arriva da `get_hardware`. Due cose distinte, nessuna duplicazione.

## Prossimo passo

Contratto sopra da confermare (nomi campi + enum). Appena OK, implementiamo l'azione
`get_hardware` sul canale di rete e vi mandiamo un esempio di payload reale da questa macchina
(CDM6240N 5 cassette) per validare il vostro generatore livelli/routing. Non tocchiamo BLE.
