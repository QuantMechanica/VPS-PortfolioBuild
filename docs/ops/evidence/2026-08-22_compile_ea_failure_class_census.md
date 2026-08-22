# COMPILE_EA-Wellen 1–11: Failure-Klassen-Zensus

Datum: 2026-08-22 · Quelle: `work_items` (phase=COMPILE_EA, status=failed,
verdict=COMPILE_FAIL), Stand nach Release aller 106 governed Rows (11 Wellen;
3 SHA-stale-Rows bleiben korrekt gehalten).

| Klasse (verdict_reason-Marker) | Zeilen |
|---|---:|
| MAE_HOOK_MISSING + TRADE_REQUEST_UNINITIALIZED (+ weitere EA_-Checks) | 33 |
| MAE_HOOK_MISSING + TRADE_REQUEST_UNINITIALIZED + echte COMPILE_ERRORS | 21 |
| MAE_HOOK_MISSING (+ weitere EA_-Checks) | 3 |
| BUILD_CHECK_FAILED (sonstige) | 2 |
| echte COMPILE_ERRORS (±BUILD_CHECK) | 3 |
| CANDIDATE_RECHECK | 1 |
| **Summe** | **63** |

## Lesart

**57/63 (90 %) tragen exakt das Framework-Kontrakt-Doppeldefekt-Muster**
(fehlender MAE-Hook, uninitialisierter Trade-Request) der Alt-Quellen — dieselben
zwei Klassen, die der Gemini-Template-Fix (`8fe2a461`) für Neubauten schließt.
Konsequenz für die Rebuild-Priorisierung: die Masse der 355er-Rebuild-Welle heilt
diese Population über den normalen build_ea-Pfad mit fixem Template; ein
separates Compile-Reparatur-Programm ist NICHT nötig. Nur die ~5 Zeilen mit
echten Compilerfehlern (z. B. QM5_1009 `RoundPips`-Signatur) brauchen
individuelle Quellarbeit.

Der Compile-Zensus hat damit seinen Zweck erfüllt: jede der 106 Zeilen hat eine
explizite, maschinenlesbare Klassifizierung statt eines stillen Nichtzustands.
