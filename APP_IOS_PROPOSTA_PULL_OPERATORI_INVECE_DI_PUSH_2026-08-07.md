# App iOS → SGM/Windows — proposta: NON serve che l'app pushi gli operatori. Cacheate voi `app_users` in `connect_roles` (2026-08-07)

Sostituisce, come priorità, la richiesta del documento precedente sull'MTU di `set_operators`.
Quella resta valida come bug, ma probabilmente **non ci serve più risolverla**.

## Il punto sollevato da Hu Leo

> Perché deve essere l'app a mandarvi i dati degli operatori? Non basta che li gestiate voi e
> li sincronizziate?

Domanda giusta, e guardando il vostro stesso flusso la risposta è: **non serve nessun push**.

## L'osservazione chiave (dal vostro documento)

Il vostro ordine di validazione del PIN touch è:

1. PIN tecnico/master locale
2. snapshot locale `connect_roles` ← oggi popolato SOLO da `set_operators`
3. **`app_users` su Supabase (fallback)** ← *sapete già leggerli*

Cioè: **la macchina sa già leggere gli operatori dal cloud.** Quello che manca non è la
lettura, è la **persistenza**: quando il cloud è raggiungibile leggete e basta, non conservate.
Poi il cloud si spegne e `connect_roles` è vuoto.

## Proposta: la macchina fa PULL e cachea (niente push dall'app)

Quando la macchina legge `app_users` da Supabase (o periodicamente, o all'avvio, o dopo ogni
login riuscito col fallback), **scrive lo stesso contenuto in `connect_roles`**. Fine.
Con il cloud spento il touch trova lo snapshot già pronto.

Vantaggi rispetto al push via BLE:
- **Sparisce il problema MTU**: niente payload grosso su BLE, niente chunking da inventare.
- **Sparisce la dipendenza dall'ordine** (il nostro documento precedente: "inviare PRIMA di
  spegnere"). La cache si popola da sola, ogni volta che la macchina è online.
- **Niente technician_pin, niente stare vicino alla macchina** con l'iPhone.
- **Scala alla produzione**: gli operatori si gestiscono in UN posto (`app_users`) e ogni
  macchina si allinea da sé. Con decine di macchine, un push per-macchina — o peggio, una
  gestione operatori sul touch di ogni macchina — non è praticabile: creare un dipendente o
  cambiargli il PIN significherebbe farlo su ogni macchina.

## Sul PIN: vi serve l'hash, non il PIN in chiaro

Unico punto di attenzione. Oggi `app_users.pin` è il PIN in chiaro (storia dell'app, non una
scelta di questo ciclo). Se preferite non leggerlo, aggiungiamo noi una colonna
`app_users.pin_hash` con lo **stesso identico formato pbkdf2** che già accettate in
`set_operators` (`pbkdf2$200000$<salt_hex>$<hash_hex>`), popolata dall'app ad ogni
creazione/modifica PIN. Voi cachereste quella, e la verifica resta identica a quella che avete
già implementato. Diteci se la volete e la aggiungiamo allo schema.

## `set_operators` resta utile come fallback manuale

Non chiediamo di rimuoverlo: per una macchina che non ha MAI visto il cloud (primo giorno,
provisioning in laboratorio senza rete) il push BLE resta l'unica via. Se ci confermate questa
direzione, teniamo il pannello «Operatori sulla macchina» come strumento di emergenza e
smettiamo di considerarlo il percorso normale — nel qual caso l'MTU diventa un problema a
bassa priorità (e se serve implementiamo il chunking con calma).

## Domande
1. Vi torna il pull+cache lato macchina? Ci sono controindicazioni che non vediamo (es. non
   volete che la macchina scriva su `connect_roles` fuori da `set_operators`)?
2. Volete la colonna `app_users.pin_hash` (pbkdf2, stesso formato) invece del PIN in chiaro?
3. Se sì a entrambe: per il test col cloud spento basta che la macchina resti online qualche
   minuto prima dello spegnimento, giusto?
