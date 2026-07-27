# App iOS → SGM/Windows — Hardware DINAMICO: la macchina deve dichiarare il suo hardware (2026-07-26)

## Obiettivo (Hu Leo)
Oggi l'app **assume un hardware FISSO**: il bootstrap livelli è cablato (5 cassette F53 +
3 hopper), e la logica ha assunzioni `tipo=="f53"`. In produzione le macchine avranno
**config diverse** (numero cassette/hopper diverso, modelli diversi) e un hardware può
**guastarsi o mancare**. Vogliamo che l'app si **adatti dinamicamente** all'hardware REALMENTE
presente e disponibile — niente più valori cablati.

**Prerequisito**: la verità dell'hardware sta sulla MACCHINA. L'app non può indovinare cosa c'è
montato → serve che SGM **dichiari il proprio hardware** (inventario + stato) via BLE.

## Proposta contratto: la macchina dichiara `hardware[]`
Dove: nel **hello / KIOSK_INFO** (letto a ogni connessione) — o azione dedicata `get_hardware`
se preferite. Serve **inventario** (cosa è montato) + **stato** (disponibilità corrente).

```json
"hardware": [
  { "ruolo": "banknote_dispenser", "modello": "F53", "presente": true, "stato": "ok",
    "unita": [
      { "id": "cass_1", "denominazione_cent": 500,  "stato": "ok" },
      { "id": "cass_2", "denominazione_cent": 1000, "stato": "ok" },
      { "id": "cass_3", "denominazione_cent": 2000, "stato": "ok" }
    ] },
  { "ruolo": "coin_hopper",  "modello": "...",  "presente": true, "stato": "ok",
    "unita": [ { "id": "h1", "denominazione_cent": 200, "stato": "ok" } ] },
  { "ruolo": "bill_acceptor", "modello": "iPRO", "presente": true, "stato": "ok" },
  { "ruolo": "reject_box",    "modello": "-",    "presente": true, "stato": "ok" }
]
```
- `ruolo` = FUNZIONE (il modello è solo display): `banknote_dispenser` / `coin_hopper` /
  `bill_acceptor` / `coin_acceptor` / `reject_box`.
- `presente`: montato o no su QUESTA macchina.
- `stato`: `ok` / `guasto` / `assente` / `inibito` → guida payout/UI (disponibilità corrente).
- `unita`: sotto-unità che erogano (cassette F53, hopper), ognuna con `denominazione_cent` +
  `stato`. **L'app genera i livelli DA QUI**, non più 5F53+3hopper cablati.

## Come lo usa l'app
- **Livelli / bootstrap**: righe generate da `hardware[].unita` (numero e denominazioni REALI).
- **Payout routing**: sceglie le unità per `ruolo` + `stato=ok`; se un dispenser è `guasto`,
  fallback (es. hopper giù → banconote + residuo, già discusso).
- **UI**: mostra `modello` + `stato`; nasconde ciò che non è `presente`.

## Domande a voi
1. La macchina **conosce** già la sua config hardware (`config.json`: n. cassette F53 +
   denominazioni, n. hopper, modello acceptor)? Potete esporla?
2. **Dove** dichiararla: `hello`/KIOSK_INFO (preferito) o azione `get_hardware`?
3. **Stato realtime**: se un hardware si guasta a runtime (jam F53, hopper vuoto), come lo sa
   l'app? snapshot nell'hello + **notify** su cambio stato? o polling di `hardware_state`?
   (Serve per l'adattamento "usa solo ciò che è disponibile".)
4. **Enum esatti** `ruolo` / `stato`: confermate le stringhe così mappo senza ambiguità.
5. Avete già `kiosk_hardware_state` (a schema): contiene inventario+stato o solo stato? Meglio
   riusarlo o canale nuovo?

## Contesto
Grosso refactor lato app (~600 riferimenti cablati a f53/ipro/hopper) → a fasi DOPO che il
contratto è congelato. Cash-safety: l'hardware resta gestito dalla macchina; l'app legge solo
inventario+stato e adatta UI/routing, **non tocca l'erogazione**.
