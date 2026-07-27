# SGM/Windows → app iOS — livelli REALTIME corretti + auto-seed (v64) — risponde a "livelli tutti da SGM" + "niente brand" (2026-07-27)

Ottimo la direzione "livelli tutti da SGM, via l'Init manuale": è esattamente dove puntiamo.
Rispondiamo punto per punto e vi segnaliamo un **bug reale che abbiamo trovato e corretto**.

## (a) get_hardware live + capability
**LIVE da v62, confermato in v64.** Azioni `get_hardware`/`status` su `/connect/command`
(session_id), annunciate nella capability list dell'hello/INFO. Payload reale già inviato
(cass_1..5 = 500/1000/2000/5000/5000). Nessuna attesa: è già pronto.

## (b) `kiosk_livelli_cash.livello_attuale` scritto da SGM in realtime? SÌ — e abbiamo corretto un bug
**Sì, lo scriviamo noi**, per cassetta, dal ledger locale autoritativo (ad ogni evento cash).
MA era **rotto**: il mirror rimandava su lo **storico più vecchio** (ORDER BY id, batch da 50)
su un arretrato di **3708 snapshot** → il cloud restava indietro di migliaia di righe.
**Ecco perché vedevate i livelli "non sincronizzati"**: il cloud mostrava i default dell'Init
(`0/100/100/100/1`) mentre il valore reale locale era `5/38/47/94/1`.

**v64 corregge:**
- il mirror ora spinge **solo l'ULTIMO valore per cassetta** (non lo storico) e **svuota
  l'arretrato** → `kiosk_livelli_cash.livello_attuale` = livello reale, in realtime.
- **AUTO-SEED**: se la riga `cass_N` non esiste, la **creiamo noi** dal livello autoritativo
  locale (tipo=`f53`, unita=`cass_1..5`, `denom_cent`, `enabled`). Così **quando togliete
  l'Init manuale le righe compaiono comunque** — non dovete seminarle voi. Le **soglie
  business** (`fondo_quantita`/`livello_minimo`/`livello_massimo`) NON le tocchiamo: restano
  vostre. `descrizione` la lasciamo **NULL** (vedi punto "niente brand").

Dopo il deploy di v64: guardate `kiosk_livelli_cash` per questo kiosk → `livello_attuale` di
`cass_1..5` deve diventare `5/38/47/94/1` (o il valore reale del momento), non più i 100 fissi.

## (c) payload `get_cash_levels` — campi esatti (per il "Sincronizza ora")
`/connect/command` action `get_cash_levels` → `{ "devices": [ ... una entry per cassetta ... ] }`:
```json
{ "device_id": "cdm6240n-primary:1", "label": "00005", "denom_cent": 500,
  "current_level": 5, "nominal_capacity": null, "low_threshold": null,
  "is_low": true, "last_updated": "2026-07-27T18:18:46Z" }
```
Nota naming (importante per l'E2E):
- `get_cash_levels` usa **`current_level`** e **`device_id = "cdm6240n-primary:{slot}"`**.
- Il mirror `kiosk_livelli_cash` usa **`livello_attuale`** e **`unita = "cass_{slot}"`**.
- Mappatura: **slot N ↔ cass_N** (stesso ordine dei tagli). `nominal_capacity`/`low_threshold`
  sono `null` finché non provisionate ("mai un finto valore"); `is_low` è reale.

## "Niente brand hardware cablati" — confermiamo, siamo conformi
- Il mirror livelli **NON scrive `descrizione`** (sul seed la lasciamo NULL → voi derivate
  l'etichetta di FUNZIONE). `unita = cass_N`, `tipo = f53` sono **identificatori tecnici**
  (come da vostro punto 4), non display. Il modello reale sta **solo** in `get_hardware.model`.
- ⚠️ Le righe hopper `h1/h2/h3` oggi in `kiosk_livelli_cash` hanno `descrizione = "Hopper H1 …"`:
  **le ha scritte il vostro Init**, non SGM. Quando rigenerate da `get_hardware`/togliete l'Init
  spariranno. Noi non scriviamo quei testi.

## Riassunto
get_hardware live (a). livello_attuale realtime **corretto** + auto-seed (b): il "non
sincronizzato" era un nostro bug di mirror, ora risolto in v64. Campi get_cash_levels
confermati (c). Zero brand nei dati che spingiamo. Ditecci dopo il deploy se i livelli
in `kiosk_livelli_cash` tornano coerenti col reale per chiudere l'E2E.
