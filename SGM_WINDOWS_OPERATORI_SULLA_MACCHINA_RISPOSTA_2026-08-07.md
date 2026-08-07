# SGM/Windows → app iOS — risposta: (B) gli operatori si creano SULLA MACCHINA. Niente push, niente pull (2026-08-07)

Risponde in un colpo solo ai vostri tre documenti (MTU di `set_operators`, proposta
pull+cache, correzione "ogni negozio è indipendente") e alla domanda di chiarimento.

## 1. Il chiarimento che chiedevate: avevate ragione voi, non era vero

> Col PIN tecnico si creano già gli operatori sulla macchina?

**No — non era vero.** L'abbiamo verificato sul codice invece di rispondere a memoria: gli
unici scrittori di `connect_roles` erano tre azioni BLE (`set_operators`, `bootstrap_sala`,
`upsert_role`). Il touch la leggeva soltanto. Quindi una macchina mai raggiunta dall'app
aveva **zero operatori**, e col cloud spento entrava solo il PIN tecnico: esattamente lo
scenario che avevamo descritto entrambi. Non c'erano due insiemi di credenziali, ne mancava
proprio uno.

Grazie per averlo messo in dubbio: se non l'aveste chiesto avremmo "risolto" un problema che
non capivamo.

## 2. Scelta di Hu Leo: **(B)** — gestione operatori sulla macchina. Fatto.

Nuova voce **Admin → «Operatori»** (solo supremo) sul touch: elenco, creazione
(nome / ruolo / PIN da tastierino), modifica, reset PIN, eliminazione. Scrive
`connect_roles` in locale — **nessun cloud, nessun telefono, nessun ordine di operazioni da
rispettare**. Un operatore creato lì entra subito, anche a Supabase spento.

PIN in **pbkdf2** (stesso formato che già accettiamo da `set_operators`), mai in chiaro e mai
rileggibile. Due rifiuti deliberati, perché prevengono vicoli ciechi:
- **PIN non condivisibile fra due operatori** — non è un duplicato, è un login ambiguo: vince
  chi viene verificato per primo e le operazioni di cassa finiscono attribuite alla persona
  sbagliata.
- **L'ultimo supremo non si elimina e non si declassa** — altrimenti si ricrea la tabella
  vuota che questa funzione esiste per risolvere.

La logica sta in **un solo posto** (`operator_store`), usata dal touch e disponibile alle
azioni BLE: una regola sulle credenziali duplicata in due file è due regole.

## 3. Cosa vi chiediamo di fare (poco)

**Rendete la vostra «Gestione utenti» di sola lettura verso `connect_roles`.** Come dicevate
voi: due editor sulla stessa tabella non conviene. `app_users` resta vostra per la parte app;
gli operatori DELLA MACCHINA ora si gestiscono sulla macchina.

`set_operators` **resta** ed è ancora utile (provisioning di fabbrica, o allineare in blocco
una macchina nuova). Non lo togliamo.

## 4. Sull'MTU: non era un mistero, e l'abbiamo corretto noi

Il vostro sospetto era giusto. Dal log della macchina, 21:31, mentre inviavate:

```
reply ... reason=Unterminated string starting at: line 1 column 521
reply ... reason=Expecting value: line 1 column 1 (char 0)
```

La richiesta **arrivava**, spezzata in più write, e il nostro handler trattava **ogni frammento
come un messaggio intero**: il primo è JSON troncato, il secondo non è JSON. Entrambe le
risposte avevano `action=None`, quindi per voi erano indistinguibili dal silenzio.

Corretto lato nostro: la characteristic di richiesta ora **riassembla** i frammenti (lo
speculare di ciò che voi già fate sulle notify di risposta). Nessun cambio di protocollo,
**nessun chunking applicativo da implementare da parte vostra**, e vale per qualunque
richiesta grande, non solo `set_operators`. Il buffer entra in gioco solo quando un frammento
non è JSON valido, quindi una richiesta normale in una singola write è invariata — cosa che ci
importa, perché quello è il canale dei pagamenti.

## 5. Pull+cache di `app_users`: per ora no, e la colonna `pin_hash` non serve

Con (B) la macchina non ha bisogno di leggere gli operatori dal cloud, quindi **non aggiungete
`app_users.pin_hash`** per noi. Se un giorno cambiassimo idea ve lo chiederemmo noi.

Il fallback su `app_users` nella validazione PIN resta dov'è, ma diventa un residuo storico:
la sorgente è locale.

## 6. Sul PIN tecnico `111111`, poiché lo avete sollevato

Registrato come scelta consapevole di Hu Leo, non come svista. Il valore ora è una
**configurazione della macchina** (hashata, modificabile dal pannello) e non più un letterale
nel codice: cambiarlo lo sostituisce davvero. È una differenza reale rispetto al bypass
`000000`, che veniva confrontato dentro il percorso di autenticazione e nessuna configurazione
poteva revocare.

## 7. Stato

Tutto quanto sopra è in **v76**, con i test. Nessuna azione richiesta da parte vostra per il
test col cloud spento: la macchina ora si popola gli operatori da sola.
