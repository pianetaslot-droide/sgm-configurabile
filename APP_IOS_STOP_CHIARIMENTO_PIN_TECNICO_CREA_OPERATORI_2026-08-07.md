# App iOS → SGM/Windows — STOP: forse non serve niente. Hu Leo dice che col PIN tecnico si creano già gli operatori sulla macchina (2026-08-07)

Fermate qualsiasi lavoro sulle due proposte precedenti (pull+cache / gestione operatori):
prima chiariamo un punto, perché **potrebbero essere entrambe inutili**.

## Quello che ci dice Hu Leo

> Non serve il cloud: il PIN tecnico di SGM è `111111` di default e **con quello si creano
> direttamente gli altri PIN** sulla macchina.

Se è così, il problema che avevamo entrambi descritto ("col cloud spento nessun operatore entra
nel menu Admin") **non esiste**: l'operatore lo si crea sul posto, in locale, senza cloud e
senza push dall'app.

## Dove non torna, e cosa vi chiediamo di chiarire

Il vostro documento diceva:

> Il PIN del touch si valida in quest'ordine: 1) PIN tecnico/master locale — 2) snapshot
> operatori locale (`connect_roles`) ← popolato SOLO da `set_operators` — 3) `app_users` su Supabase
> ... Su questa macchina `connect_roles` ha 0 righe, quindi col cloud spento nessun operatore
> dell'app riesce ad entrare.

Le due affermazioni convivono solo se ci sono **due insiemi distinti** di credenziali locali:

- **(a)** i PIN creati sulla macchina dal menu tecnico (quelli di cui parla Hu Leo) — che
  evidentemente vivono da qualche altra parte, non in `connect_roles`;
- **(b)** `connect_roles`, cioè lo specchio degli operatori dell'app, popolato solo da
  `set_operators`.

**Domande:**
1. È corretto? Col PIN tecnico `111111` si possono creare/modificare operatori locali sulla
   macchina, che funzionano **senza cloud e senza `set_operators`**?
2. Se sì: dove vivono, e con che ruoli/permessi? Sono equivalenti agli operatori
   dell'app (supremo/direttore/commesso) o è un'altra cosa (solo accesso al menu tecnico)?
3. Se sì: **`connect_roles` a 0 righe è davvero un problema, o no?** Cioè, per lavorare col
   cloud spento basta creare gli operatori sul touch e amen?

## Nota di sicurezza, una volta sola e poi non insistiamo
`111111` uguale su tutte le macchine e noto significa che chiunque lo conosca può creare
operatori (quindi accessi) su qualsiasi macchina. Se per voi è una scelta consapevole va bene,
è il vostro dominio — lo segnaliamo perché è la stessa classe di problema del bypass `000000`
che avete giustamente fatto rimuovere a noi, e ci sembrava disonesto non dirlo.

## Cosa facciamo lato app
Niente, in attesa della vostra risposta. Il pannello «Operatori sulla macchina» resta installato
ma non lo consideriamo più il percorso normale; se confermate il punto 3, smettiamo di
inseguire l'MTU di `set_operators` e lo teniamo solo come utility.
