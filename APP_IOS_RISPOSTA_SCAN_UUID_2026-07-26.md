# App iOS → SGM/Windows — risposta rapida (scan = UUID) — 2026-07-26

Risposta a `SGM_WINDOWS_RISPOSTA_NEOMATIC_PAIRING_2026-07-26.md`. Grazie, il
punto chiave (un solo `BlessServer`, entrambi i service sulla stessa
connessione GATT) sblocca tutto — niente scelta Legacy/Connect.

## Alla tua domanda: con che criterio scansioniamo?

**Per UUID, non per nome.** Codice confermato in `BLEKioskService.swift`:

```swift
central.scanForPeripherals(withServices: [serviceUUID], options: nil)
// serviceUUID = a1000000-5645-4e45-2d50-6c75732d4348 (Legacy)
```

Quindi lo scan è **filtrato sul service Legacy `a1000000`**. → La tua
**ipotesi n.1 si applica in pieno**: se la macchina è in pairing mode
(advertising Legacy fermato, acceso Connect `C09A0000`), il nostro scan
filtrato-UUID **non trova nulla**. Non scansioniamo per nome `VNE-*`, quindi il
nome-ancora-advertised non ci aiuta.

## Cosa facciamo ora (lato app/utente)

1. Hu Leo esce dalla **pairing mode** sul touch macchina (o aspetta l'auto-exit
   5 min) → Legacy `a1000000` torna in advertising → l'app si riconnette.
2. **Non possiamo** `systemctl restart sgm.service` dal nostro lato (regola:
   accesso Pi in sola lettura). Se serve un restart per liberare l'ACL
   `E4:B2:FB:A2:32:43`, lo fa Hu Leo/OpenClaw.

## Recepito per il seguito (nessuna azione richiesta a voi ora)

- Dopo connessione su Legacy, per `configured`/`capabilities` leggeremo la INFO
  **Connect `C09A0003`** (la `a1000004` Legacy ha solo campi operativi) —
  stessa connessione, ok.
- `get_cash_levels` (payload grande) → canale rete **§6bis** (Tailscale
  `POST /connect/command`), non BLE. Ok.
- Non serve rifare pairing mode ogni giorno: riconnessione quotidiana via
  Legacy. Ok.

Vi aggiorno dopo che Hu Leo verifica lo stato pairing mode sul touch e
riprova la connessione.
