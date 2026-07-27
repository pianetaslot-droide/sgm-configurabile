# App iOS → SGM/Windows — fast-path comandi admin: l'app non può autenticarsi su RemoteOpsApi (token) → chiediamo `/connect/command` (session_id) (2026-07-27)

## Problema (misurato oggi)
Abbiamo cablato nella Dashboard il pattern **快路+队列兜底**: i comandi admin (`ping`/`status`,
`restart_sgm`, `reboot`) provano prima la via veloce Tailscale, poi ripiegano sulla coda
`kiosk_comandi`. Ma la via veloce oggi **non passa mai**:

```
curl http://100.110.231.41:8787/health                                  → 200  (raggiungibile)
curl http://100.110.231.41:8787/status  -H "Authorization: Bearer <default>"  → 401 {"ok":false,"error":"unauthorized"}
```

Confermato: **l'app NON ha il token di RemoteOpsApi** (come già diceva il vostro STATUS 2026-07-26:
"l'app NON conosce il token di RemoteOpsApi" — per questo `get_cash_levels` è passato a
`/connect/command` con session_id). Quindi il fast-path admin fa **401 → ripiega sulla coda** =
funziona ma è **no-op** (i comandi vanno sempre sulla coda con polling ~30s, nessuno speedup).

## Richiesta (preferita): aggiungere gli admin a `/connect/command` (session_id)
Come avete già fatto per `get_cash_levels`/`list_roles` (e ora `get_hardware`): aggiungete a
**`NETWORK_ALLOWED_ACTIONS`** anche i comandi admin, autenticati col **session_id** (continuità
della sessione BLE, già raggiungibile in rete) invece del token RemoteOpsApi che l'app non ha:

- `restart_sgm`  (restart del processo self-game-manager)
- `reboot`       (reboot del Pi — voi lo chiamate `reboot_pi` su RemoteOpsApi: confermate la stringa)
- `status`       (snapshot stato hardware; per noi equivale al `ping`/refresh della Dashboard)

Così l'app li invia sullo STESSO canale di get_cash_levels/get_hardware, senza token separato.
Comportamento risultante: quando c'è un session_id valido (in sala via BLE, o entro le 2h idle in
rete) → **fast-path immediato**; altrimenti resta la coda `kiosk_comandi` come fallback durevole
(va benissimo, è il tanto-per-cambiare "兜底").

## Alternativa (se preferite tenere gli admin dietro il token RemoteOpsApi)
Capiamo che restart/reboot sono operazioni admin e le avete messe su RemoteOpsApi con bearer token
**apposta** (auth più forte). Se non volete abbassare l'auth a session_id: datene all'app un modo
sicuro di **ottenere `SGM_REMOTE_OPS_TOKEN`** — es. esposto nell'hello/INFO DOPO l'auth BLE, oppure
scritto durante il provisioning (`set_config`) nella config della macchina. L'app lo salverebbe in
Keychain e lo userebbe sul canale RemoteOps. Va bene anche questa via — scegliete voi quale.

## Da confermare
1. Quale delle due vie (session_id whitelist **oppure** token esposto all'app).
2. Se session_id: le **stringhe esatte** delle azioni admin (`restart_sgm`, `reboot`/`reboot_pi`,
   `status`) e se richiedono un ruolo minimo (es. solo direttore/supremo).
3. Capability: come annunciate quali admin sono network-allowed (hello/INFO capability list?), così
   la UI mostra il fast-path solo quando supportato.

Nessuna fretta lato cash-safety: sono solo stato + restart/reboot, nessuna erogazione. La coda
resta il fallback finché non è pronto.
