# SGM/Windows → app iOS — riavvio/reboot da kiosk_comandi ora funziona su Windows (v63, 2026-07-27)

Il direttore premeva **riavvia** dall'app e non succedeva niente. Trovata e corretta
la causa reale (con dati veri dalla macchina di Lido), non una supposizione.

## Perché non funzionava (3 cause, tutte confermate dai log/DB reali)

1. **Handler Windows rotto.** `kiosk_lifecycle` eseguiva `restart_sgm`/`reboot` con codice
   **solo-Linux**: `restart_sgm` faceva `throw RuntimeError("service restart unsupported on
   Windows simulator")`, `reboot` chiamava `sudo shutdown -r +0` (inesistente su Windows).
   Nei log: `Esecuzione comando fallita: service restart unsupported on Windows simulator`.

2. **Lo stato del comando non si salvava mai.** Il codice scriveva su `kiosk_comandi`
   colonne che **nella tabella reale non esistono** (`preso_in_carico_at`, `completato_at`,
   `risposta`, `motivo_fallimento`) → ogni UPDATE falliva con **42703** → il comando restava
   **`pending`** → veniva ri-preso ad ogni polling = **tempesta di retry**. Verificato: le
   colonne reali sono solo `{id, kiosk_id, comando, stato, creato_da, created_at, eseguito_at,
   payload, dati_tecnici}`, e i 3 comandi in coda (2×`restart_sgm` + 1×`reboot`) erano tutti
   bloccati `pending`, `in_progress`/`completato`/`fallito` = **0**.

3. **Rischio loop.** Una volta fatto funzionare il restart, se lo stato non si salva il
   processo riparte, ri-legge lo stesso `pending` e **si riavvia all'infinito**.

## Cosa fa v63 (buildato + testato — 29/29 test verdi, nessun riavvio reale nei test)

- **Esecuzione reale su Windows.** reboot = `shutdown /r`; restart_sgm = taskkill del PID +
  rilancio dell'exe (detached). Stesso identico codice della fast-path `/connect/command`
  (modulo condiviso `system_control`) → le due strade **non divergeranno più**.
- **Scrittura stato robusta.** Scriviamo SOLO colonne reali: `stato` + `eseguito_at`, con
  `risposta`/`motivo_fallimento` dentro `dati_tecnici` (jsonb). Se la tabella ha schema
  diverso (colonna assente → 42703/PGRST204) la colonna viene **scartata e si riprova**; se
  un **CHECK legacy** rifiuta `completato`/`fallito`/`annullato`, si ripiega su **`eseguito`**.
  → lo stato **esce sempre da `pending`**, con o senza la vostra migration.
- **Gate anti-loop.** L'azione OS parte **solo dopo** che lo stato terminale è stato salvato.
  Se non riusciamo a salvarlo → NON riavviamo (log esplicito), niente loop.
- **Guardia anti-comando-vecchio.** Un `reboot`/`restart` più vecchio di
  `SGM_COMANDO_MAX_AGE_S` (default **300 s**) viene **annullato senza eseguire**. Così i 3
  comandi bloccati da stamattina **NON** riavvieranno la macchina al primo avvio di v63:
  verranno messi a `annullato`. (Diteci se 300 s va bene o preferite altro.)

## Cosa vi serve sapere lato app

- **State machine kiosk_comandi:** SGM ora scrive `in_progress` → poi `completato` /
  `fallito` / `annullato` (+ `eseguito_at`, + `dati_tecnici.risposta` / `.motivo_fallimento`).
  Se leggete `stato` per mostrare l'esito, questi sono i valori.
- **CHECK legacy:** finché non applicate `supabase_schema.sql` (che **droppa il CHECK legacy**
  e aggiunge le colonne), potreste vedere `eseguito` al posto di `completato`. Consigliato
  applicarlo — ma **non è più bloccante**, il riavvio funziona comunque.
- **Canale:** oggi mandate `restart_sgm`/`reboot` sulla **coda `kiosk_comandi`** (non ancora
  la fast-path). Va benissimo: quel canale ora funziona su Windows. Quando passerete a
  `/connect/command` avrete lo stesso comportamento (stesso `system_control`), solo istantaneo.
- **Ruoli:** sulla fast-path enforced lato SGM (`restart_sgm` = direttore+, `reboot` = supremo).
  Sulla coda `kiosk_comandi` il gate ruoli è dove lo mettete voi (l'inserimento comando).

Dopo il deploy di v63: premete di nuovo **riavvia** e stavolta il processo SGM riparte
(reboot per il riavvio macchina). Fateci sapere l'esito e se volete cambiare la finestra 300 s.
