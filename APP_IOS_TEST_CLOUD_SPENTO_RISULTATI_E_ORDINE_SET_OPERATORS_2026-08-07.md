# App iOS → SGM/Windows — primo test col cloud spento: cosa si è rotto lato app, e un problema di ordine su `set_operators` (2026-08-07)

Hu Leo ha spento Supabase. Riportiamo i risultati reali, non previsioni.

## 1. Confermato: col cloud spento la macchina regge, l'app no (era colpa nostra)

Spegnendo Supabase, il commesso **non riusciva ad aprire il turno**: Cloudflare risponde
**521 `origin_down`** e la nostra `apreTurno` propagava l'errore in un alert → niente turno →
**niente accesso alla schermata Payout**. Cioè: il cloud spento bloccava il lavoro, anche se
— come avete documentato — l'erogazione non dipende affatto da Supabase.

**Corretto lato app** (buildato e installato):
- `apreTurno`, **solo su errori di connettività**, apre il turno **in locale** (id e ora reali) e
  accoda l'operazione; alla riconnessione la riga viene ricreata con `upsert onConflict:id`
  (idempotente: nessun duplicato, nessun timestamp falsato al momento del sync).
- Gli errori **di merito** continuano a propagarsi (es. "turno di un altro commesso ancora
  aperto" resta un blocco vero: è cash-safety, non lo aggiriamo).
- Nuovo classificatore di errori: `URLError` + 5xx di edge (**521/522/523/524**, 502/503/504,
  `origin_down`) = backend non raggiungibile. Il 521 di Cloudflare è esattamente ciò che si
  osserva col progetto Supabase spento.

Se durante il test trovate altri punti dell'app che si piantano col cloud giù, segnalateceli:
applichiamo lo stesso trattamento (accoda e prosegui).

## 2. ⚠️ Problema di ORDINE su `set_operators` — va inviato PRIMA di spegnere

Segnaliamo un vincolo che non avevamo evidenziato e che rende impossibile "rimediare dopo":

**lo snapshot operatori si costruisce leggendo `app_users` da Supabase.** Quindi col cloud
già spento **non possiamo generare né inviare `set_operators`**: la lista non è recuperabile.
È un problema di sequenza, non di trasporto (il trasporto è BLE, e quello funziona).

Conseguenza pratica: **l'ordine corretto è**
1. cloud ACCESO → dall'app «Operatori sulla macchina» → `set_operators` via BLE
2. voi verificate `connect_roles` ≥ 1 con almeno un supremo
3. **poi** si spegne il cloud e parte il test

Con il cloud già spento, l'unica via d'ingresso al touch resta il PIN tecnico — come avevate
previsto. Faremo il push appena Hu Leo riaccende il progetto, e vi avvisiamo per la verifica.

(Nota: stiamo valutando di far costruire lo snapshot anche dalla copia locale cifrata degli
operatori che l'app tiene per il login offline — così `set_operators` sarebbe inviabile anche a
cloud spento. Se lo facciamo ve lo diciamo: il contratto e il trasporto non cambiano.)

## 3. Bypass `000000` — nota operativa
Rimosso anche da noi, come concordato. Effetto collaterale voluto: chi usava `000000` come
"supremo di prova" ora deve entrare con un account supremo vero — quindi alcune voci
riservate al supremo (fra cui proprio «Operatori sulla macchina») non compaiono se si è
loggati con un ruolo inferiore. È il comportamento corretto, lo segnaliamo solo per evitare
diagnosi sbagliate durante il test.

## 4. Invariato
Scrittura livelli: solo SGM (rimossa dall'app). `get_hardware` in sola lettura. Confini
periodo su API locale: restiamo in attesa del vostro contratto.
