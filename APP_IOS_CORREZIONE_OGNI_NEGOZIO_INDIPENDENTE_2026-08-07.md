# App iOS → SGM/Windows — CORREZIONE: un mio argomento era sbagliato (ogni negozio è indipendente) (2026-08-07)

Rettifico il documento precedente sulla proposta pull+cache: conteneva **un'affermazione errata**,
e visto che vi chiedevo una decisione su quella base la correggo subito.

## Cosa avevo scritto di sbagliato

Avevo motivato il "niente gestione operatori sulla macchina" dicendo che in produzione un
dipendente andrebbe creato su decine di macchine, e un cambio PIN ripetuto ovunque.
**Non è così**, me l'ha chiarito Hu Leo:

- **ogni negozio è indipendente**: una macchina ↔ un progetto Supabase ↔ i suoi operatori.
  Gli operatori di un negozio non esistono sugli altri, quindi **non c'è nessuna duplicazione**
  da evitare. (Coerente col nostro FirstRunSetup: ogni installazione configura il proprio
  backend e crea il proprio primo Supremo.)
- il **PIN tecnico è `111111` su tutte le macchine** ed è noto: quindi, col cloud spento,
  l'accesso al menu Admin **non è realmente bloccato** — resta comunque il PIN tecnico.
  Il vostro "non è un modo accettabile di lavorare" resta valido come ergonomia, ma la
  situazione è meno urgente di come l'avevamo dipinta entrambi.

Quindi: l'argomento "scala a molte macchine" **cade**. Mi scuso, era una mia inferenza non
verificata.

## Cosa resta valido (e la richiesta di Hu Leo)

La proposta operativa non cambia, ma per motivi diversi e più semplici:

**Hu Leo preferisce che l'app NON debba spingervi i dati degli operatori.** La sua indicazione
testuale: gestirli da voi e sincronizzarli, invece del push BLE.

Sul "come", due strade — decidete voi quale vi costa meno, per noi vanno bene entrambe:

**(A) La macchina cachea `app_users` in `connect_roles`** *(la nostra preferenza, zero lavoro per
entrambi)*. Voi **già leggete** `app_users` come terzo passo della validazione: basta
**persistere** ciò che leggete. Nessun push, nessun MTU, nessun ordine di operazioni da
rispettare, e la gestione utenti resta nella UI che l'app ha già (creare/modificare/cambiare PIN
da touch è scomodo).

**(B) Gestione operatori sul vostro lato, con scrittura su `app_users`.** Se preferite avere il
menu di creazione/modifica sulla macchina, va bene: l'importante è che scriviate in `app_users`
sul Supabase di quel negozio, così l'app li vede. In tal caso ditecelo e noi rendiamo la nostra
"Gestione utenti" di sola lettura, per non avere due editor sulla stessa tabella.

In entrambi i casi `set_operators` resta come strumento di emergenza (macchina che non ha mai
visto il cloud) e il problema MTU scende di priorità.

## Domanda sul PIN (invariata)
Se cacheate `app_users`, vi serve il PIN: oggi la colonna `pin` è **in chiaro**. Possiamo
aggiungere `app_users.pin_hash` in formato pbkdf2 identico a quello di `set_operators`,
popolato dall'app. Ditecelo e lo mettiamo nello schema.
