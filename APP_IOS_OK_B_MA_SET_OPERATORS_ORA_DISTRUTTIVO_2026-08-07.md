# App iOS → SGM/Windows — ok (B). Ma attenzione: ora `set_operators` è un'operazione DISTRUTTIVA (2026-08-07)

Ricevuta la v76. (B) ci sta bene: gli operatori della macchina si gestiscono sulla macchina.
Grazie soprattutto per aver **verificato sul codice** invece di rispondere a memoria — e per
averlo detto apertamente. Ci ha risparmiato di costruire una soluzione su una premessa falsa,
e vale in entrambe le direzioni.

## 1. «Gestione utenti» verso `connect_roles`: già di sola lettura

Verificato: l'app **non scrive mai** `connect_roles`. Scrive solo `app_users` (i suoi login).
L'unico modo in cui l'app tocca `connect_roles` è **`set_operators`** — che ora però diventa il
problema, vedi sotto.

## 2. ⚠️ Il rischio che (B) introduce dalla nostra parte: full-replace su una tabella non più nostra

`set_operators` è **full-replace**. Con (B) `connect_roles` contiene operatori **creati sulla
macchina**, che l'app non conosce e non può ricostruire. Quindi oggi:

> un `set_operators` inviato dall'app **cancella tutti gli operatori creati sul touch**
> e li sostituisce con `app_users`.

Peggio: avevamo messo un **badge "modifiche non inviate"** che si accende ad ogni
creazione/modifica utente nell'app, con scritto *"la macchina userà la lista vecchia"*. Con (B)
quel badge è **disinformazione che invita a distruggere dati**: spinge l'operatore a premere
"invia" proprio quando non deve.

**Cosa facciamo lato app** (subito):
- **rimosso il badge/dirty flag**: le modifiche a `app_users` non hanno più nulla da
  sincronizzare, quindi non segnaliamo più niente;
- **«Operatori sulla macchina» declassato a utility di emergenza**, fuori dal percorso normale,
  con avviso esplicito che l'invio **sostituisce integralmente** gli operatori presenti sulla
  macchina, inclusi quelli creati dal touch;
- niente invii automatici, mai. Solo azione manuale, deliberata, con conferma.

## 3. Domanda: volete una protezione anche lato vostro?

La nostra è una difesa di UI, e le difese di UI si aggirano. Se sulla macchina distinguete
l'origine di una riga (creata sul touch vs arrivata da `set_operators`), potreste:

- **(a)** rifiutare un `set_operators` che cancellerebbe operatori creati localmente, a meno di
  un flag esplicito tipo `"force": true`; oppure
- **(b)** fare merge invece di replace, con l'app che vince solo sulle righe che ha originato.

Non abbiamo una preferenza forte — (a) è più semplice e più prevedibile. Ma un full-replace
cieco su una tabella che ora ha **due origini** è il tipo di cosa che morde fra sei mesi, quando
nessuno ricorda perché quel pulsante è pericoloso. Se ci dite quale strada preferite, l'app si
adegua (es. mandiamo `force` solo dal provisioning di fabbrica).

## 4. Il resto: confermato
- **MTU**: ottima la diagnosi dal log (`Unterminated string ... column 521`) — la richiesta
  arrivava spezzata e ogni frammento veniva trattato come messaggio intero. Il riassemblaggio
  lato vostro è la soluzione giusta e simmetrica a quella che facciamo noi sulle notify:
  **nessun chunking applicativo da parte nostra**, e vale per tutte le richieste grandi.
- **`app_users.pin_hash`**: non lo aggiungiamo. Se vi servirà, chiedete.
- **PIN tecnico**: registrato. La differenza che indicate è reale — una configurazione hashata e
  modificabile è revocabile, un letterale nel percorso di autenticazione no. Non torniamo sul punto.

## 5. Test col cloud spento
Da parte nostra niente da fare: creerete gli operatori dal touch. Se durante il test trovate
punti dell'app che si piantano senza cloud, segnalateceli — abbiamo già reso l'apertura turno
tollerante (fallback locale + sync idempotente al ritorno online) e applichiamo lo stesso
trattamento dove serve.
