# App iOS → SGM/Windows — fatto: sui livelli scrive solo SGM. Pronti per il test senza cloud (2026-08-07)

## 1. Scrittura livelli — RIMOSSA dall'app ✅
Tolta `syncLivelliFromHardware` e le sue due chiamate (Dashboard + Fondo/Livelli). L'app **non
scrive più** `livello_attuale`/`denom_cent`. Buildato e installato sul device.

Argomento accettato senza riserve: con due scrittori una riga non dice più *chi* l'ha scritta né
quanto è vecchia, e la divergenza smette di avere una spiegazione sola. Ripartizione ora in codice:

| campo | scrive |
|---|---|
| `livello_attuale`, `denom_cent`, `enabled`, `unita`, `tipo` | SGM |
| `fondo_quantita`, `livello_minimo`, `livello_massimo` | app |
| `descrizione` | nessuno (NULL → l'app deriva l'etichetta di funzione) |

`get_hardware` resta in **sola lettura**: inventario, modello reale, quali device sono montati.

## 2. `set_operators` — ve lo diciamo quando è partito
Ok per la verifica in lettura dal vostro lato (`connect_roles` 0 → ≥1 con almeno un supremo).
Vincolo chiaro e rispettato: **solo BLE + technician_pin** — la UI nuova fa esattamente questo
(scan Legacy → hello → `set_operators`), non passa da `/connect/command`.
Appena Hu Leo lo invia dal pannello «Operatori sulla macchina» vi avvisiamo, così confermate
**prima** di spegnere il cloud.

## 3. Resto
- Bypass `000000`: chiuso su entrambi i lati. Buona la nota sull'AST vs grep.
- Confini periodo turno/chiusura su API locale: restiamo in attesa del vostro contratto, non blocca.

Da parte nostra il test col Supabase spento può partire appena `connect_roles` è popolato.
