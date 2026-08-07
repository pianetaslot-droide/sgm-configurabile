# App iOS → SGM/Windows — `set_operators` va in timeout: sospetto MTU sulla WRITE (la macchina non risponde) (2026-08-07)

Hu Leo ha provato l'invio dal pannello «Operatori sulla macchina». Esito:

- BLE: scan + connect + **hello OK** (la sessione si stabilisce, quindi il canale funziona)
- `set_operators` → **nessuna risposta**, timeout lato app ("La macchina non ha risposto in tempo")

Non è un rifiuto (`ack:false` + reason), è **silenzio totale**.

## Ipotesi principale: la richiesta supera l'MTU in scrittura

`set_operators` è la nostra richiesta più grossa: ogni operatore porta un `pin_hash` pbkdf2
(`pbkdf2$200000$<32 hex>$<64 hex>` ≈ **110 caratteri**) più id UUID, nome e ruolo → **~180+ byte
per operatore**. Con pochi operatori si superano facilmente diverse centinaia di byte in un
singolo `writeValue`.

Nel nostro client la **reply** viene riassemblata su più notify (lo facevamo già), ma la
**richiesta** è una singola write. È esattamente il problema che avevate diagnosticato voi su
`get_cash_levels` ("payload oltre l'MTU BLE") — solo che quello l'avete potuto spostare sul
canale di rete, mentre `set_operators` è **solo BLE** per scelta di sicurezza.

Abbiamo appena installato una build che misura e mostra `byte richiesta` vs
`maximumWriteValueLength`: vi confermiamo il dato appena Hu Leo ripete la prova. Ma intanto ci
serve sapere da voi:

## Domande (lato vostro)

1. **La vostra characteristic di richiesta accetta il "long write" ATT** (Prepare Write +
   Execute Write, che iOS usa in automatico con `.withResponse` quando il payload supera l'MTU)?
   Lo stack BLE su **Windows** si comporta come quello Pi/Linux su questo punto? Se il long write
   non è supportato, la write arriva troncata e il vostro parser semplicemente non trova un JSON
   valido → nessuna risposta, che è quello che vediamo.
2. Se NON è supportato: definiamo un **chunking applicativo**? Proposta minima, retro-compatibile:
   `set_operators` con `{chunk_index, chunk_total, chunk_data}` e applicazione atomica solo
   all'ultimo chunk (il full-replace resta all-or-nothing). Ditecelo e lo implementiamo noi lato
   app secondo il formato che preferite.
3. In alternativa: accettate `set_operators` **anche su `/connect/command`** (session_id) con il
   technician_pin nel payload? Capiamo la scelta "solo BLE" e non insistiamo se è una decisione di
   sicurezza — ma con session_id + technician_pin il livello di autorizzazione resterebbe quello.
4. Domanda di controllo, per escludere la pista sbagliata: **l'azione `set_operators` è presente e
   attiva nella build corrente (v62/v63/v64)?** Se il nome o il gate fossero cambiati, il silenzio
   avrebbe un'altra causa e l'MTU sarebbe un falso indizio. Se la macchina logga le richieste
   ricevute, un'occhiata al log al momento del tentativo (21:32) chiarirebbe subito se la
   richiesta è arrivata (e come).

## Nel frattempo
Il test col cloud spento resta bloccato su questo: senza `set_operators`, `connect_roles` resta a
0 righe e sul touch entra solo il PIN tecnico. Per noi è la priorità.
