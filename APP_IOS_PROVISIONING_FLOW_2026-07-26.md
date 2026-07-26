# App iOS → SGM/Windows — provisioning macchina nuova (BLE set_config) — 2026-07-26

Segue `APP_IOS_NUOVO_PAIRING_REGISTRY_E_RENAME_SGM_2026-07-26.md`. Hu Leo ha
deciso il flusso di **setup di fabbrica di una macchina nuova**: l'app è il
**centro di configurazione** e **scrive la config sulla macchina via BLE**.

## Flusso deciso (wizard nell'app, fatto dal tecnico sul posto)

```
1. Pairing Bluetooth       → l'app trova e si connette alla macchina nuova
                             (Legacy a1000000, scan nome "SGM-*"/"VNE-*")
2. Inserisci Tailscale      → host + porta di QUESTA macchina
3. Inserisci Supabase       → URL progetto + anon key (sync dati app)
4. Provision (app → macchina, via BLE)
                             → la macchina PERSISTE la config, la APPLICA,
                               e si auto-registra nel registro
```

I dati **finiscono sulla macchina** (non solo nell'app): così la macchina sa a
quale Supabase sincronizzare e con quale endpoint Tailscale è raggiungibile, e
può auto-registrarsi nel registro (vedi handoff precedente).

## Cosa serve dal lato SGM/Windows: un comando BLE "set_config"

Serve un'azione BLE con cui l'app scrive la config sulla macchina e la macchina
la **salva su disco + la applica**. Payload che l'app vuole inviare:

```json
{
  "action": "set_config",
  "payload": {
    "tailscale_host": "100.x.y.z",
    "tailscale_port": 8787,
    "supabase_url": "https://xxxx.supabase.co",
    "supabase_anon_key": "eyJ...",
    "sala": "Lido",            // opzionale
    "label": "SGM ingresso 1"  // opzionale
  }
}
```
Comportamento atteso della macchina alla ricezione:
- persiste i valori (config file/.env) e li applica (riavvio servizio se serve);
- risponde `ack=true` (o `ack=false` + reason: `invalid_url`, `unauthorized`,
  `write_failed`, …);
- **si auto-registra/aggiorna nel registro** con `kiosk_id · sala · label ·
  tailscale_host/port · ble_adv_name` (usando il NUOVO supabase appena impostato).

## Domande per voi (decidete voi il meccanismo, conoscete il vostro BLE server)

1. **Su quale canale** mettete `set_config`?
   - sul **Legacy `a1000000`** (write char `a1000002`), aggiungendo l'azione
     `set_config` al framing esistente; **oppure**
   - sul **Connect `C09A0000`** (envelope JSON già pronto, tipo un `bootstrap`).
   Per l'app va bene entrambi — ditemi quale, e il **framing esatto** (come per
   `set_config` incapsulate il JSON e come leggiamo la reply). NB: nel percorso
   quotidiano NON usiamo più la pairing mode; se `set_config` sta su Connect e
   richiede la pairing mode, per noi va bene SOLO perché è un'azione di fabbrica
   una-tantum col tecnico davanti (non quotidiana).
2. **Autorizzazione**: `set_config` va protetto? (es. PIN tecnico nel payload,
   come `bootstrap_sala`). Diteci il campo.
3. **Supabase sul Pi**: oggi il Pi ha l'URL/key hardcoded (`fzgxqqjvpzqtdhdqupfw`).
   Con `set_config` che li sovrascrive, il Pi deve leggerli da config runtime
   invece che hardcoded — è fattibile lato vostro?
4. **Tailscale host/port**: la macchina lo conosce già da sé (è sul tailnet).
   Preferite che sia l'app a scriverlo (come sopra) o che la macchina lo
   auto-riporti e l'app lo legga soltanto? Per noi va bene o l'uno o l'altro —
   scegliete voi; se lo auto-riporta, l'app lo mostra in sola lettura nel wizard.

## Cosa facciamo lato app nel frattempo

Costruiamo il **wizard UI** (pairing BLE → form Tailscale → form Supabase →
schermata "Provision"). La chiamata di provisioning la agganciamo al **framing
che deciderete al punto 1**: finché non è congelato, il tasto "Provision" resta
disabilitato/stub. Gli ingressi Tailscale/Supabase esistono già come config
app-level (Impostazioni → Dati & Sync); li riusiamo nel wizard per-macchina.

Ditemi canale + framing + autorizzazione e chiudiamo il giro.
