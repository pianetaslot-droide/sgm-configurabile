# SGM/Windows → app iOS — stiamo per testare col Supabase SPENTO: cosa serve da voi (2026-08-07)

Hu Leo vuole provare il kiosk Windows con **Supabase spento**. Abbiamo verificato cosa
regge e cosa no. **C'è UNA cosa che dovete fare prima**, altrimenti l'operatore resta
chiuso fuori dal menu Admin.

---

## 1. ⚠️ AZIONE RICHIESTA — spingeteci gli operatori (`set_operators`)

Il PIN del touch si valida in quest'ordine:

1. PIN tecnico/master locale
2. **snapshot operatori locale (`connect_roles`) ← popolato SOLO da `set_operators`**
3. `app_users` su Supabase (fallback)

**Su questa macchina `connect_roles` ha 0 righe**: `set_operators` non è mai stato
inviato. Quindi col cloud spento **nessun operatore dell'app riesce ad entrare** — resta
solo il PIN tecnico, che non è un modo accettabile di lavorare.

### Contratto (già implementato lato nostro, non serve nulla di nuovo)

| | |
|---|---|
| action | `set_operators` |
| canale | **SOLO BLE** — non è in `NETWORK_ALLOWED_ACTIONS`, su `/connect/command` viene rifiutato |
| gate | technician_pin (come `set_config`) |
| payload | `{"operators": [{"id": "...", "nome": "...", "ruolo": "supremo|direttore|commesso", "pin_hash": "<pbkdf2 dell'app>"}]}` |
| semantica | **FULL-REPLACE** della tabella locale, all-or-nothing (una lista parziale non può lasciare fuori nessuno) |
| `pin_hash` | la vostra stringa pbkdf2, salvata **verbatim** e verificata con il vostro stesso schema — il PIN in chiaro non arriva mai a SGM |
| risposta | `{applied_count, removed_count, snapshot_hash}` |

`config` non è un operatore: escludetelo. Il PIN tecnico è separato e mappa sempre a
supremo, quindi uno snapshot vuoto o senza supremo non blocca mai il touch.

**Quando rimandarlo:** ad ogni modifica degli operatori (aggiunta/rimozione/cambio PIN o
ruolo). È idempotente — rimandare la stessa lista è innocuo.

---

## 2. Cosa CONTINUA a funzionare col cloud spento

Verificato sul codice, non supposto:

- **I pagamenti.** L'esecutore di erogazione e l'adattatore BLE dei pagamenti **non
  toccano il cloud**: lo stock si legge dal ledger LOCALE autoritativo e l'esito si
  scrive in locale. Nessuna decisione di cassa passa da Supabase.
- **I livelli** sul touch e via `get_cash_levels`.
- **`/connect/command`** con session_id: `get_hardware`, `status`, `get_cash_levels`,
  `list_roles`, `restart_sgm`, `reboot` — sono locali.
- **La coda di mirroring**: i risultati si accumulano in `sync_outbox` e vengono
  ripubblicati da soli quando il cloud torna. Non si perde nulla.

## 3. Cosa si FERMA (aspettatevelo, non è un bug)

- **`kiosk_comandi`**: i comandi remoti (riavvia / reboot / ecc.) non arrivano finché il
  cloud è spento. La fast-path `/connect/command` invece continua a funzionare — se
  volete pilotare la macchina durante il test, usate quella.
- **`kiosk_livelli_cash` / `pagamenti_*` / Flussi**: si congelano al momento dello
  spegnimento e si riallineano dopo (coda). Non leggeteli come "la macchina è ferma".
- **Finestra periodo della home**: i confini (ultima `chiusura_contabilita`, `turno`
  corrente) oggi li leggiamo da Supabase. Col cloud spento restano all'ultimo valore
  noto. È esattamente il punto §2 del vostro documento di localizzazione dei confini —
  quando volete affrontarlo, ditecelo e li spostiamo su API locale.

## 4. Ritardo noto (~5 s per pagamento)

Prima di erogare c'è ancora una lettura di `kiosk_hardware_state` su Supabase. Fallisce
in sicurezza (in caso di errore considera l'hardware utilizzabile, quindi **non blocca il
pagamento**) ma col cloud irraggiungibile costa il timeout HTTP, che abbiamo appena
portato da **120 s a 5 s**. Lo rendiamo local-first alla prossima build.

---

## 5. Sicurezza — verificate anche voi

Nel nostro touch c'era un **bypass PIN `000000`** che restituiva un supremo sintetico
*prima* di consultare la cache dei PIN: su una macchina in sala pubblica è un account
supremo per chiunque. **Rimosso** (era in due copie del file; tolto da entrambe, con test
che guardano l'AST e non solo il testo).

Il commento nel codice diceva *"match iOS: PIN 000000 = supremo test user"* — quindi lo
stesso bypass **molto probabilmente esiste anche nell'app**. Il kiosk Pi vi aveva già
segnalato la stessa cosa. Vale la pena verificarlo: un utente di test si crea come utente
vero dal pannello operatori.

---

## Riassunto

Fate `set_operators` via BLE **prima** dello spegnimento e il test è pulito: i pagamenti
non dipendono dal cloud, i comandi remoti passano da `/connect/command`, e il mirroring
recupera da solo alla riaccensione. Se preferite che spostiamo anche i confini
turno/chiusura su API locale prima del test, ditecelo e lo facciamo.
