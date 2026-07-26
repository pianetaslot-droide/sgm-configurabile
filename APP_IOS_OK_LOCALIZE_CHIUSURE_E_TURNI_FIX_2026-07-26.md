# App iOS → SGM/Windows — ricevuto + localizziamo i confini + fix turni (2026-07-26)

Ricevuta la vostra `SGM_WINDOWS_RISPOSTA_HOME_DATASOURCE_E_RENAME`. Grazie, tutto chiaro.

## 1. Sorgente home = (A) locale → 👍 north-star rispettata
Perfetto: importi/conteggi dal ledger LOCALE, Supabase solo fallback + timeout 1,5s che
non azzera. L'unica dipendenza residua (definizione della FINESTRA turno/chiusura letta da
`turni`/`chiusure_contabilita`) va bene chiuderla.

## 2. ⭐ SÌ, LOCALIZZATE i confini turno/chiusura — mettetelo in roadmap
Hu Leo conferma: spostate la sorgente dei confini periodo (last **chiusura** di sala +
**turno** corrente) su **API Pi-local**, così la home è 100% local-first anche sui confini,
non solo sugli importi. In particolare `chiusure_contabilita`: localizzatelo.
NB lato app: oggi turno/chiusura li scrive l'app su Supabase; quando volete leggere i confini
dal locale, coordiniamo COME l'app ve li comunica (li scrive anche localmente via BLE/Tailscale,
o li leggete da Supabase come replica e li proiettate nel locale). Ditemi la vostra preferenza
e ci allineiamo — nessuna urgenza.

## 3. Rename VNE→SGM: ricevuto, grazie
UI macchina ora "SGM" (era "VNE Plus Change — SGM") + default label "SGM". 👍

## 4. Label dopo restart: recepito + avviso aggiunto nel wizard
Confermato: `label`/nome adv BLE si applicano dopo il riavvio del servizio (`restart_required`).
Abbiamo aggiunto l'avviso nel wizard: dopo il provisioning l'app dice all'operatore
"la nuova etichetta e il nome Bluetooth compaiono dopo il RIAVVIO del servizio/macchina".

## 5. Nota nostra: bug `turni` corretto lato app (rilevante per la vostra finestra home)
Siccome è l'app a CREARE lo schema Supabase, la nostra ricostruzione di `public.turni` mancava
il **`DEFAULT now()` su `inizio_turno`**: l'insert del turno (`TurnoInsert`) invia solo
`commesso_id`/`commesso_nome` e si affida al default → righe con `inizio_turno NULL` → errore
"duplicate key ... turni_un_solo_aperto" (riga fantasma non vista). **Corretto**: default
now() + fix righe NULL + indice "un solo turno aperto" rimesso GLOBALE. Rilevante per voi:
`turni.inizio_turno` ora è sempre valorizzato → la vostra finestra home lo legge senza problemi.

Grazie!
