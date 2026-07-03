# T-WIN (QM5_12821) — Abschluss-Dossier

**Datum:** 2026-07-03 (Nacht) · **Autor:** Claude · **Status:** ENTSCHEIDUNGSREIF (OWNER-Sign-off ausstehend)

## Testumfang

18 Matrix-Zellen auf 100% realen Darwinex-Ticks, 28-Paar-Basket, alle auf dem
fidelity-verifizierten Rebuild (Entries 6-fach video-belegt, Exits per agy-Recheck
korrigiert, Shift-Bug gefixt, Divergenz-Filter nachgerüstet, 1%-Cluster-Sizing implementiert).

## Ergebnis-Matrix (PF gross / Trades)

### Continuation (seine Richtung, video-verifiziert)
| Konfiguration | 2018–2024 | 2024 | 2023 |
|---|---|---|---|
| Basis (v1 as-built) | **0.51** / 1797 | — | — |
| v3/v5 Exit-korrigiert | — | 0.56–0.61 / 233–252 | 0.60 / 190 |
| + Exhaustion 0.6→2.0% | — | 0.56 → 0.52 → 0.38 → **0.33** (monoton) | — |
| + Divergenz 5.10 (sein Filter) | — | **0.22** / 38 | 0.64 / 27 |
| + Divergenz 8.50 / 12.75 | — | PF 0 / 8 Tr · 0 Tr | 1 Tr · 0 Tr |

### Fade (Reverse)
| Konfiguration | 2024 | 2023 |
|---|---|---|
| Exhaustion 2.0% | **1.63** / 88 | 1.01 / 91 |
| Exhaustion 1.5% | **1.61** / 171 | 0.83 / 126 |
| + Divergenz 5.10 | 0 Trades (Anomalie, nicht weiterverfolgt) | 1.00 / 31 |

## Kernbefunde

1. **Continuation ist in jeder Zelle negativ**, und JEDE Selektionsdimension
   (Exhaustion-Level, Matrix-Divergenz) verschlechtert sie **monoton** — zwei
   unabhängige Dosis-Wirkungs-Kurven in dieselbe Richtung. Das ist kein
   Kalibrierproblem, sondern ein invertiertes Selektionsprinzip: Nach starken
   Tagesbewegungen mean-reverten FX-Paare (akademisch dokumentierte
   Short-Term-Reversal-Anomalie).
2. **Der Fade trägt nur im Schock-Regime** (2024 = BoJ-Interventionsjahr).
   2023 flach bis negativ → kein eigenständiger Buch-Sleeve, dokumentiert als
   möglicher Krisen-Satellit.
3. **Haltedauer-Gradient** (v1: 12–24h-Kohorte 88–94% Win) entsteht durch
   Survivorship stabiler Ranking-Tage — er war der verführerische Köder, kein
   nutzbarer Filter (die Stabilität ist ex-ante nicht erkennbar; alle
   ex-ante-Filter versagen s.o.).
4. **Erklärung der YouTube-Profite:** Demo-Konten, extremes Sizing (7 Lots/50k),
   selektive Präsentation und der vom Trader selbst bezifferte **20–25%
   Diskretions-Anteil** — der nicht mechanisierbare Rest ist der Träger.

## Verwertbares Erbe

- **Primitive** (bleiben im Framework): QM_BasketEquityStop (tick-geprüfter
  Cluster-Stop), Pending-Re-Projektion, Divergenz-Gate, Raw-CSM-Accessor,
  Equity-proportionales Cluster-Sizing, Multi-Symbol-Serialisierung.
- **Infra-Fixes des Tages**: Watchdog-Multisym-Guard, Purge-Schutz,
  Stale-Summary-Ablehnung, Basket-Timeout-Kette, Resolver-Regen-Lektion.
- **Fade-Schock-Play**: Set-Dateien + Evidenz archiviert; Reaktivierung nur
  als bewusste Regime-Wette (OWNER-Entscheid), nicht als Dauer-Sleeve.

## Empfehlung

**Archivieren.** Q02-Requeues stoppen, Karte auf ARCHIVED-EVIDENCE setzen,
Ressourcen vollständig auf die Swing-Initiative (bereits erste Q04-Passage
in derselben Nacht: QM5_12915).

---
**OWNER SIGN-OFF: 2026-07-03 (morgens) — Archivierung ratifiziert.** Requeues gesperrt (requeue_excluded), work items retired, Primitive verbleiben im Framework, Fade-Schock-Satellit dokumentiert reaktivierbar.
