# XAU-Verbesserung H1 — headless Sonnet: ADX-gefilterte turtle + Regime-Map (A2b)

**Rolle:** headless Sonnet. **PM:** Claude. **Worktree:** `agents/sonnet-xau-adx-turtle`
(nie main, nie T_Live, nie T1-T7). **Ad-hoc-Backtests NUR auf geparkten T8/T9/T10** (meine Lane;
T1-T7 = Factory). **Non-live, reversibel, reine Research.**
Kontext: `docs/ops/MASTER_EA_XAU_IMPROVEMENT_PLAN_2026-07-13.md` (Phase B, Hypothese 1 + A2b).

## Befund (aus Phase A)
turtle (`QM5_10403_et-turtle20x`) treibt die 26-Monats-DD (2021-10..2023-11) des XAU-Masters:
kurzgehaltene Trades (1–3 Tage) sind **False-Breakout-Whipsaws in Ranges** (avgNet −$105,
38% win), lange Trades (4d+) gewinnen (+$322, 60% win). Hypothese: ein **ADX/Range-Entry-Filter**
eliminiert die Whipsaws (Trendfolger sollen strukturell keine Ranges traden).

## Aufgabe

### 1. Research-EA bauen: `et-turtle20x-adx`
Basis = der committete Standalone `framework/EAs/QM5_10403_et-turtle20x/QM5_10403_et-turtle20x.mq5`
(die exakte turtle-Logik; du hast sie schon als `QM_Mod_EtTurtle20x.mqh` portiert). Ergänze
**einen ADX(14)-Regime-Filter**: Entry NUR wenn `iADX(_Symbol, PERIOD_D1, 14) >= adx_min`.
- `adx_min` = **INPUT**, Default **22** (struktureller Range/Trend-Schwellwert; NICHT auf 2021-23
  fitten). Sonst turtle 1:1 unverändert.

### 2. A2b — Regime-Map loggen
Bei JEDER Kandidaten-Entry (bevor der Filter greift): logge `{ts, adx_value, taken:bool}`. Nach
dem Lauf: Verteilung des ADX-at-Entry für **genommene vs. gefilterte** Trades + deren Outcome.
Ziel: bestätigt datenbasiert, dass turtles Verlierer bei niedrigem ADX clustern → die Schwelle.

### 3. Walkforward-Vergleich (der Overfit-Test) — original turtle vs. ADX-turtle
XAUUSD.DWX **D1, Model 4**, auf geparktem T8/T9/T10. RISK_FIXED=1000 (backtest), fixe Params:
- **DEV 2017.01.01–2021.09.30** · **OOS 2021.10.01–2025.12.31** (das OOS enthält bewusst die
  26-Monats-DD-Phase). `adx_min` NUR auf DEV wählen (falls du optimierst), dann OOS fix bewerten.
- Metriken je Lauf (beide EAs, beide Fenster): Trades, Net, **MaxDD**, Sharpe, Profit-Factor,
  und speziell **MaxDD im OOS** (2021-10..2025).
- **Gate/Erfolg:** ADX-turtle reduziert die **OOS-MaxDD** deutlich, OHNE das OOS-Net zu gutten
  (idealerweise Net ~gleich/besser bei weniger DD). Wenn der Filter das Net stark schneidet =
  kein Win.

## Scope-Grenzen
NUR turtle + ADX-Filter. KEINE anderen Strategien, KEIN Master-Change, KEINE Framework-Kern-
Änderung. KEINE Registry-/Pipeline-Integration (das kommt erst, wenn der Walkforward gewinnt).

## Prozess-Pflicht (Headless-Lektion)
Backtests SYNCHRON, nichts backgrounden. .ex5 vor jedem Smoke ins Ziel-Terminal deployen.
**Committen vor exit** — auch bei Negativ-Ergebnis (das ist auch ein valides Resultat). Uncommittet = Fail.

## Deliverable
PR auf `agents/sonnet-xau-adx-turtle`: der ADX-turtle-EA, die Regime-Map (ADX-Verteilung
Gewinner/Verlierer), die Walkforward-Tabelle (turtle vs ADX-turtle, DEV/OOS, MaxDD im Fokus),
Design-Notiz + Verdikt (Win/kein Win). Claude reviewt + entscheidet über Pipeline-Vollvalidierung
+ Master-Integration (turtle-v2).
