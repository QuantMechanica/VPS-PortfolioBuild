# Vorlage: DL-082-Ausweitung auf Q08-Sub-Gates 8.5 (Neighborhood) und 8.9 (Runs-Test)

- Date: 2026-09-01 · Author: Claude (Orchestrator, eigene Analyse)
- Trigger: OWNER-Frage zu QM5_12552/USDCAD `Q08 FAIL_HARD` (Cost-Cushion 10.3× PASS,
  gestorben an 8.5 EDGE_HARD + 8.9 EDGE_HARD)
- Decision class: **Gate-Kriterium → ROT → nur OWNER**

## Ausgangslage (historische Daten, vollständiger Scan)

Population: **220 Q08-Aggregate** unter `D:\QM\reports\work_items\*\*\Q08\*\aggregate.json`
(überlebender Bestand; ältere Reports fielen DL-090-Retention/manuellen D:-Aufräumungen
zum Opfer — Abdeckungslücke ehrlich benannt).

| Verdikt | Anzahl |
|---|---:|
| PASS | 80 |
| FAIL_SOFT | 80 |
| **FAIL_HARD** | **29** |
| INVALID / INFRA | 31 |

Sub-Gate-Zustände: 8.5_neighborhood: 162 PASS / **15 EDGE_HARD** / 43 invalid+infra.
8.9_runs_test: 195 PASS / **9 EDGE_HARD** / 16 LOW_SAMPLE.

**Flip-Analyse der 29 FAIL_HARD:** 21 Zeilen (**18 eindeutige Paare**) sind
AUSSCHLIESSLICH durch 8.5/8.9-EDGE_HARD terminal; 8 weitere hängen zusätzlich an
anderen harten Gates (Kosten 5×, Portfolio 5×, 8.2 DSR 4×, 8.8 Edge-Decay 3×, 8.7 PBO 2×)
und blieben unter jeder Variante tot.

## Ehrliche Evidenzgrenze

Es existiert **kein einziges Paar**, das mit 8.5/8.9-Warnung je weitergelaufen ist
(das Gate ist heute binär-hart) → wir haben **null Downstream-Daten** darüber, ob
diese Signale echte spätere Ausfälle prädizieren. Jede Ausweitung ist ein Experiment;
die Optionen unterscheiden sich darin, wie eng man es begrenzt.

## Argumente

**Für Aufweichung:**
- **8.9 (Runs-Test)** bestraft Streakiness — exakt die Eigenschaft, die DL-071
  (Q04 PASS_SOFT, OWNER-ratifiziert 09.06.) für strukturelle/Regime-Edges als
  *by design* anerkannt hat („ORB/structural setups lose in some periods by design").
  Präzedenz existiert also bereits eine Gate-Stufe früher.
- **8.5 (Neighborhood)** misst Parameter-Nachbarschafts-Fragilität. Unsere Parents sind
  **nicht durch Suche gefittet** (mechanisiert aus Quellen) — die Isolated-Peak-als-Overfit-
  Logik ist bei unoptimierten Parametern schwächer. Der frische Q13-EUR-Befund zeigt
  zudem: Auf Low-Frequency-Strategien können Nachbarwerte aus benignen Gründen
  (Aktivitäts-Floor) drastisch abweichen — das Signal ist dort verrauscht.

**Gegen Aufweichung:**
- 8.5/8.9 sind die letzten billigen Statistik-Screens vor teuren Q09+-Ketten.
- Fragilität und Nicht-Zufälligkeit sind reale Live-Risiko-Signale, unabhängig von
  der Parameter-Provenienz.
- Keine Downstream-Daten, die „Fehlalarm" belegen (siehe Evidenzgrenze).

## Optionen

| | Regel | Unlocks | Charakter |
|---|---|---:|---|
| **A** | Status quo | 0 | konservativ, kein Experiment |
| **B** | nur 8.9 EDGE_HARD → FAIL_SOFT | ~7 Paare | minimal, stärkste Präzedenz (DL-071) |
| **C** | 8.5+8.9 EDGE_HARD → FAIL_SOFT, unconditional | 18 Paare | maximal, auch statistisch sonst schwache Fälle |
| **D** | **konditional**: 8.5/8.9-EDGE_HARD → FAIL_SOFT **nur wenn** Cost-Cushion=PASS ∧ 8.2 DSR=PASS ∧ 8.8 Edge-Decay=PASS ∧ 8.7 PBO∈{PASS, EDGE_SOFT} | **13 Paare** | Benefit-of-the-doubt nur für sonst rundum saubere Strategien |

**Option-D-Unlock-Liste (13):** 11421/AUDUSD (Schwester unseres ersten Q14-Paars!),
1567/GBPJPY+GBPNZD+XAGUSD (DeMark-Familie, REQUAL-bewährt), 12552/USDCAD, 1551/USDJPY,
10569/XAUUSD, 11403/EURUSD, 1355/NDX, 11294/NDX, 12474/GBPUSD, 10715/USDJPY, 10476/USDCAD.
(1567/EURGBP fällt raus: 8.7=INVALID; 10916/SP500, 10494, 13147 scheitern an D-Bedingungen.)

## Kosten & Risiko

- Kosten bei D: 13 Paare re-entern die Q09-Baseline-Lane (FAIL_SOFT wird dort per
  v4-Contract legitim akzeptiert) → grob 13× (Q09-Full-History + Q10_NEWS-Zellen),
  einige Dutzend Terminalstunden, gepaced hinter dem Zensus.
- Risiko-Obergrenze: verschwendete Terminalzeit. Q09–Q14 bleiben ungeändert scharf;
  Portfolio-/Live-Admission separat; T_Live unberührt.
- Mechanik: forward-only Kalibrierungsänderung + einmalige append-only Re-Gradierung
  der 13 Zeilen (DL-071-Präzedenzmechanik; keine Verdikt-Überschreibung, alte Zeilen
  bleiben Evidenz).
- Rollback: Kalibrierungskonstante zurücksetzen; re-gradierte Zeilen sind markiert.

## Empfehlung

**Option D.** Begründung: Sie testet die „konservativer-als-real"-Hypothese genau dort,
wo alle übrigen Statistik- und Kosten-Screens sauber sind — d.h. der Fehlalarm-Verdacht
am plausibelsten ist — und hält die reine Fragilitäts-/Schwäche-Kohorte weiter terminal.
13 Paare sind eine gehaltvolle, aber begrenzte Kohorte; mehrere gehören zu bereits
bewährten Familien (11421, 1567). Sollte die Kohorte in Q09/Q10 überdurchschnittlich
sterben, ist das erstmals ECHTE Downstream-Evidenz für den prädiktiven Wert von 8.5/8.9 —
das Experiment liefert also in beide Richtungen Erkenntnis. Fallback bei Minimalpräferenz: B.
