# DL-071 — Q04 Walk-Forward: net-positive-with-variance verdict (PASS_SOFT track)

**Date:** 2026-06-09
**Status:** **PROPOSED — awaiting OWNER ratification** (Q04 verdict criterion is hard-bounded; do not implement until ratified)
**Supersedes:** none — recalibrates the `aggregate_verdict` logic in `framework/scripts/q04_walkforward.py`
**Related:** `framework/scripts/q04_walkforward.py` (aggregate_verdict), DL-070 (Q08 swing/low-freq track), DL-064 (portfolio-construction layer / soft-fail → portfolio admission), `docs/research/EDGE_QUALITY_RESEARCH_SYNTHESIS_2026-06-09.md`, deep-research run `wakdgb7gi` (practitioner-setup evidence, pending)

## Kontext (OWNER 2026-06-09)

OWNER: Leute bestehen FTMO-Challenges mit ORB, ICT Silver Bullet, Judas Swing, Turnaround
Tuesday usw. — Setups, die „vielleicht nur in 10 von 12 Monaten funktionieren, aber sie
funktionieren!" Der Maßstab ist **Netto-Erwartungswert + Risk-Management**, nicht
Jeder-Periode-Perfektion. Hedge-Funds fahren genau solche Calendar/STR-Effekte professionell.

**Befund (verifiziert im Code):** `aggregate_verdict` vergibt **PASS nur, wenn JEDER der 3
anchored OOS-Folds (2023/2024/2025) PF-net > 1.0** hat. Ein einziger Fold ≤ 1.0 → **FAIL**
(→ FAIL_HARD). Das ist der strengstmögliche Konsistenz-Anspruch — „funktioniert in jedem
einzelnen Jahr" — und er **verwirft genau die netto-positiv-mit-Varianz-Edges**, die in der
Praxis Geld verdienen und Prop-Challenges bestehen. Das ist plausibel ein **größerer
Yield-Killer als Edge-Knappheit**: ~88% sterben an Q04, und unser einziger Survivor (QM5_10692)
*ist* ein Liquidity-Sweep/Structure-Setup — dieselbe Praktiker-Familie.

## Evidenz — wie viele FAILs wären netto-positiv? (Recovery-Analyse 2026-06-09)

174 (EA × Symbol)-Paare mit lesbaren Q04-Folds. Aktuell PASS (jeder Fold > 1.0): **22**.
Unter „≥2/3 Folds > 1.0 **UND** Mittel-PF-net > 1.05 **UND** kein Fold < 0.80": **+7 neu**
(= **+32%** Q04-Survivor), exakt das beschriebene Profil:

| EA | Symbol | Fold PF-net (2023/24/25) | warum aktuell FAIL |
|---|---|---|---|
| QM5_10026 | NDX | 2.82 / 0.92 / 1.61 | ein 0.92-Jahr (Mittel ~1.78, klar netto-positiv) |
| QM5_1050 (smc-order-blocks) | USDJPY | 1.26 / 0.86 / 1.60 | ein 0.86-Jahr — **ICT/SMC-Setup** |
| QM5_10035 | NDX | 0.83 / 1.41 / 1.18 | ein 0.83-Jahr |
| QM5_10115 | XAUUSD | 0.81 / 1.13 / 1.37 | ein 0.81-Jahr |
| QM5_10494 | XAUUSD | 0.92 / 1.64 / 1.31 | ein 0.92-Jahr |
| QM5_10076 | GDAXI | 1.16 / 1.13 / 0.93 | ein 0.93-Jahr |
| QM5_10554 | EURJPY | 0.97 / 1.04 / 1.29 | ein 0.97-Jahr |

Untertrieben: viele Q04-Folds waren German-Locale-0-Trade-Phantome (jetzt gefixt) → echte
Recovery nach Re-Run höher.

## Entscheidung (vorgeschlagen)

Q04-Verdict um eine **PASS_SOFT**-Stufe erweitern — architektonisch analog zu Q08 SOFT/HARD +
der Portfolio-Admission (DL-064/070), wo Soft-Passer in den diversifizierten Portfolio-Track
gehen (genau richtig: ein streaky Einzel-Edge + andere streaky Edges = glatteres Portfolio):

- **PASS (hard/clean):** alle 3 Folds PF-net > 1.0 (heutiger Bar — unverändert, bleibt das
  Gütesiegel).
- **PASS_SOFT (netto-positiv mit kontrollierter Varianz):** **≥ 2/3 Folds PF-net > 1.0** UND
  **Mittel-PF-net > 1.10** UND **min Fold-PF-net ≥ 0.80** (kein katastrophaler Fold). Advanced
  wie ein Q08-Soft-Pass in den Portfolio-Kandidaten-Track, mit `q04_tier=SOFT`-Flag.
- **FAIL:** sonst (≤1/3 Folds positiv, oder ein katastrophaler Fold < 0.80, oder Mittel ≤ 1.10).

**Guardrails gegen Lucky-Overfits** (damit es *nicht* zu locker wird): ≥2/3-Mehrheit + Mittel-
Schwelle + No-Catastrophic-Fold + (downstream, bereits vorhanden) die FTMO-DD-Box ≤10% an
Q08 8.10 / der Design-Box. Schwellen (2/3, 1.10, 0.80) sind kalibrierbar — bei der Recovery-
Analyse oben war Mittel-Schwelle 1.05; 1.10 ist die konservativere Wahl.

## Umsetzungsplan (nach Ratifizierung)

1. `aggregate_verdict` um den SOFT-Zweig erweitern (PASS / PASS_SOFT / FAIL); `q04_tier` ins
   Aggregat schreiben. Bestehende Cascade/Promotion: PASS_SOFT advanced nach Q05 (oder direkt
   in den Portfolio-Track, je nach DL-064-Wiring).
2. **Re-grade statt Re-run** für die +7 (Folds existieren schon) → sofortige Yield-Recovery,
   keine Backtest-Kosten.
3. German-Locale-betroffene Q04-FAILs (0-Trade-Phantome) re-queuen (Parser-Fix + English
   terminals) → weitere Recovery.
4. Die ORB/ICT/Session-Cards (reservoir-reich, meist unbuilt) per `force_build` force-forwarden
   (DL-… / Edge-Quality-Initiative), damit sie das rekalibrierte Gate durchlaufen.

## Caveat (Ehrlichkeit)

Q04-Strenge war *gewollte* Robustheit (kein „funktionierte nur 2024"). Die Lockerung ist eine
**Rekalibrierung auf das echte Ziel** (netto-positiv-tradeable / Prop-Challenge-tauglich), keine
blinde Aufweichung — die Guardrails verhindern Single-Year-Wonder und katastrophale Folds. Die
Praktiker-Evidenz (ORB/ICT/Turnaround-Tuesday-Expektanz, realistische Jahres-Varianz) liefert
der laufende Deep-Research-Lauf `wakdgb7gi` und wird hier angehängt, bevor OWNER ratifiziert.
