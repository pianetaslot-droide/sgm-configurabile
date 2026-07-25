# Cartella condivisa — coordinamento SGM Connect (app iOS) ↔ SGM (Windows/Python)

Repo GitHub: **https://github.com/pianetaslot-droide/sgm-configurabile** (privato,
account `pianetaslot-droide`, stesso usato per `SalaScommessa`).

Cartella/repo accessibile a ENTRAMBE le sessioni Claude che lavorano su questo
progetto (lato app in `../SGMConnect/`, lato macchina in
`../sgm-windows-simulator-source/`), per sincronizzarsi senza passare da
copie manuali su Desktop ogni volta (Hu Leo, 2026-07-25 — prima versione era
solo una cartella locale, poi promossa a repo GitHub dedicato per avere
storia/versioning veri e non dipendere dal fatto che le due sessioni girino
sullo stesso Mac).

**Convenzione**: PRIMA di iniziare a lavorare, `git pull`. DOPO ogni
aggiornamento rilevante ai documenti qui dentro, `git add`/`commit`/`push`
subito — questa cartella è utile solo se resta sincronizzata, non se resta
un'istantanea vecchia sul disco locale.

## Regole

1. **`BLE_PROTOCOL_CONTRACT.md` qui dentro è l'UNICA fonte di verità del
   protocollo.** Le copie nei singoli repo sono mirror — se aggiorni il
   protocollo, aggiorna QUESTO file per primo (bump `contract_version` se
   cambia la forma dei messaggi/campi), poi propaga la copia nel tuo repo.
   Nessuno dei due lati modifica il contratto unilateralmente per l'ALTRO
   lato — solo la propria colonna nella matrice di stato.
2. **La verità su cosa una macchina supporta davvero è a runtime**
   (`INFO.capabilities`), non sui documenti. I documenti descrivono
   l'intenzione; la macchina conferma la realtà.
3. Prima di iniziare una sessione di lavoro su questo progetto (da
   entrambi i lati), leggere qui dentro lo stato più recente invece di
   fidarsi solo della propria memoria/contesto — evita di ripetere il
   disallineamento scoperto il 2026-07-25 (vedi `SGM_PIANO_GENERALE_2026-07-25.md`).
4. Quando una fase del piano si chiude o lo stato cambia in modo rilevante,
   aggiornare qui il documento di stato pertinente (non lasciare solo sul
   Desktop — questa cartella è quella persistente/condivisa).

## Contenuto

- `BLE_PROTOCOL_CONTRACT.md` — contratto canonico, versionato.
- `SGM_PIANO_GENERALE_2026-07-25.md` — piano master (fasi 0/1/2, principi
  anti-drift).
- `SGM_ORDINE_LAVORO_APP_IOS_2026-07-25.md` — task concreti lato app.
- `SGM_ORDINE_LAVORO_WINDOWS_2026-07-25.md` — task concreti lato SGM.
- `SGM_CONNECT_APP_STATUS_2026-07-25.md` — stato dettagliato lato app.
- `SGM_WINDOWS_STATUS_HANDOFF_2026-07-24.md` — stato dettagliato lato SGM.

I documenti di stato sono fotografie di un momento — quando lo stato cambia
molto, sostituirli o aggiungerne di nuovi (con data), non editarli in modo
da nascondere la storia recente.
