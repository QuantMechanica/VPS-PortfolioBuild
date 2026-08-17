---
ea_id: QM5_1673
slug: sperandeo-tvii-trendline-failure-h4
type: strategy
source_id: 6e967762-b26d-59a3-b076-35c17f2e7c36
sources:
  - "[[sources/forexfactory-trading-systems]]"
concepts:
  - "[[concepts/trendline-failure-reversal]]"
  - "[[concepts/sperandeo-pivot]]"
indicators:
  - "[[indicators/sperandeo-trendline-2pivot]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; Sperandeo Trader Vic II (Wiley 1994) is a named-author trade-press publication with ISBN."
r2_mechanical: PASS
r2_reasoning: "Pivot detection, 2-point trendline construction, tolerance arithmetic, and 4-bar cancellation-window state machine are fully deterministic with no discretionary steps."
r3_data_available: PASS
r3_reasoning: "Symbol-agnostic OHLC primitive; testable on DWX H4 FX majors, index CFDs, XAUUSD, and SP500.DWX (backtest-only with T6 caveat noted)."
r4_ml_forbidden: PASS
r4_reasoning: "All thresholds are fixed Sperandeo 1994 constants; no adaptive parameters; 1-pos-per-magic; no grid or martingale."
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS: Sperandeo Trader Vic II Wiley 1994 attribution plus FF thread; R2 PASS: deterministic pivots/trendline violation/failure recovery exits; R3 PASS: symbol-agnostic H4 OHLC testable on DWX CFDs; R4 PASS: no ML/grid/martingale, 1-pos-per-magic."
---

# Sperandeo Trader-Vic II — Trendline-Failure Reversal (H4)

## Quelle
- Source: [[sources/forexfactory-trading-systems]] — FF thread/289547 "Trader Vic / Sperandeo methodology" + community-discussed Trader-Vic-II 1994 extended-method-set sub-threads.
- Page / Timestamp: Victor Sperandeo — *Trader Vic II: Principles of Professional Speculation* (Wiley 1994, ISBN 0-471-04953-8) ch. 7 "Trendline Construction and the Trendline-Failure Reversal Pattern" pp. 159-188 (the 1994 sequel volume's specific multi-pattern method-set; primitive-distinct from the 1991 first volume's ch. 4 2B-failure-swing at QM5_1595 and ch. 5 1-2-3 trend-change at QM5_1604). The TV-II trendline-failure-reversal is a **3-step pattern**: (1) construct the trendline using Sperandeo's 2-pivot rule on the prior dominant-trend; (2) wait for a violation-bar that closes through the trendline by more than the Sperandeo-tolerance (= 0.5 × ATR(14)); (3) the *first* reaction bar that fails to recover to the trendline within the Sperandeo-cancellation-window (= 4 bars) triggers the reversal entry. Distinct from the 1991 2B-failure-swing (which works on pivot-extreme, not on a trendline) and from the 1991 1-2-3 trend-change (which requires THREE pivots in sequence including a retest, while THIS pattern requires only ONE pivot-pair + trendline + violation + failure-to-recover).

## Mechanik

The TV-II trendline-failure-reversal primitive (Sperandeo 1994 ch. 7):

- **Sperandeo trendline construction** (2-pivot rule, Sperandeo 1991 ch. 7 + reaffirmed Sperandeo 1994 ch. 7): for a UP-trend, line drawn from a major-low pivot through the *next* major-low pivot; for a DOWN-trend, line drawn from a major-high pivot through the next major-high pivot. Sperandeo uses ZigZag-style pivot detection with a `pivot_strength = 5` bar threshold (5 bars left + 5 bars right of the pivot, all higher or all lower for the pivot to qualify).
- **Trendline violation**: a closing-bar closes through the trendline by more than `tolerance = 0.5 × ATR(14)`.
- **Failure to recover**: within the next `cancellation_window = 4` H4 bars after the violation, **no closing-bar recovers back above (for an up-trend) or below (for a down-trend) the trendline**. The 4-bar Sperandeo-window is the canonical "trendline-break confirmation" threshold from TV-II ch. 7 pp. 174.
- **Entry trigger**: on the bar AT the end of the cancellation window confirming the failure, fire the reversal signal.

Pseudocode:

```
# Pivot detection (Sperandeo 5-bar strength)
pivots = detect_pivots(high, low, strength=5)

# Identify the most recent UP-trendline (2-pivot rule on low-pivots)
up_trendline = compute_up_trendline_from_2_lows(pivots)
# Identify the most recent DOWN-trendline (2-pivot rule on high-pivots)
dn_trendline = compute_dn_trendline_from_2_highs(pivots)

# Trendline projected to current bar
up_trendline_value[i] = project_to(up_trendline, i)
dn_trendline_value[i] = project_to(dn_trendline, i)

tolerance = 0.5 * ATR(14)[i]
cancellation_window = 4

# Violation
up_violated[i] = close[i] < up_trendline_value[i] - tolerance
dn_violated[i] = close[i] > dn_trendline_value[i] + tolerance

# Failure to recover within window
short_entry = exists j in [i-cancellation_window..i] where up_violated[j]
              AND NOT any close[j+1..i] >= up_trendline_value
              AND i == j + cancellation_window
long_entry  = mirror on dn_violated and dn_trendline_value
```

### Entry
- On each newly-closed H4 bar, evaluate trendline-violation + cancellation-window failure-to-recover
- **Short**: `short_entry == true` AND `close < SMA(200, D1)`
  → market-sell at next H4 bar open
- **Long**: `long_entry == true` AND `close > SMA(200, D1)` (down-trendline failed → bullish reversal)
- Magic = ea_id × 10000 + slot

### Exit
- **Profit-target**: prior-trend-range × 50% — Sperandeo 1994 ch. 7 published expected reversal-target = 50% retracement of the prior dominant-trend's price range (measured from the trendline-construction-start pivot to the most recent extreme before violation)
- **Time-stop**: 30 H4 bars (Sperandeo-1994 ch. 7 trendline-failure reversals tend to resolve quickly; longer holds turn into general trend-following)
- **Trailing**: at +1.5 × ATR(14) profit, move SL to break-even + spread; at +50% of profit-target reached, close 50% of position
- **Counter-signal exit**: opposite-direction trendline-failure signal → close immediately

### Stop Loss
- Structural: `SL = the most recent pre-violation extreme + 0.5 × ATR(14)` (i.e., re-entering the trendline + tolerance buffer would invalidate the failure-to-recover thesis)
- ATR-cap: max SL = 3.0 × ATR(14)

### Position Sizing
- P2-baseline: RISK_FIXED = $1.000 per HR4
- T6-live: RISK_PERCENT = 0.5

### Zusätzliche Filter
- One position per magic at a time (HR14)
- Spread filter: skip entry if spread > 0.3 × ATR(14)
- News filter: standard QM news-calendar pause
- D1 SMA(200) regime gate is mandatory
- Cooldown: no re-entry on same direction within 18 H4 bars
- Trendline-staleness: trendline construction-pivots cannot be older than 144 H4 bars (Sperandeo 1994 ch. 7 — older trendlines have lower reliability)
- P3 sweep grids: tolerance ∈ {0.25, 0.5, 0.75, 1.0} × ATR(14), cancellation_window ∈ {3, 4, 5, 6} bars, pivot_strength ∈ {3, 5, 7}, time-stop ∈ {20, 30, 40, 60} bars, target ∈ {0.382, 0.50, 0.618} retracement, ATR-SL-cap ∈ {2.0, 3.0, 4.0}

## Concepts (was ist das für eine Strategie)
- [[concepts/trendline-failure-reversal]] — primary (2-pivot trendline construction + tolerance-violation + failure-to-recover within cancellation window)
- [[concepts/sperandeo-pivot]] — secondary (Sperandeo 5-bar strength pivot detection methodology shared across the Sperandeo card-family)

## R1–R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PENDING | Victor Sperandeo — *Trader Vic II: Principles of Professional Speculation* (Wiley 1994, ISBN 0-471-04953-8) ch. 7 canonical. Sperandeo is a published-Wiley financial trade author (Trader Vic I 1991 ISBN 0-471-53578-0 + TV-II 1994); multi-decade Wall Street trader cited extensively in technical-analysis literature. FF thread/289547. R1 PASS per QB 2026-05-15 relaxed criteria. |
| R2 Mechanical | PENDING | Fully mechanical: ZigZag-style pivot detection with fixed strength, 2-point line-construction arithmetic, projection to current bar, tolerance arithmetic, boolean cancellation-window state machine. Deterministic, no discretion. |
| R3 Data Available | PENDING | Symbol-agnostic OHLC primitive. Port to DWX H4: FX majors, index CFDs (NDX.DWX, WS30.DWX, GDAXI, UK100, FCHI), XAUUSD, XTIUSD. SP500.DWX backtest-only with T6-gate caveat. |
| R4 ML Forbidden | PENDING | All thresholds (pivot_strength=5, tolerance=0.5×ATR, cancellation_window=4, time-stop=30, cooldown=18, target=0.50-retracement, ATR-SL-cap=3.0, trendline-staleness=144) are FIXED constants from Sperandeo 1994 ch. 7 published rule-set. P3 sweep grids bounded. No online learning. 1-pos-per-magic; no grid; no martingale. R4 PASS HR14. |

## R3 (porting / instrument)
Symbol-agnostic. **SP500.DWX backtest-only**: testable; **T6 live-promotion gate**: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. This is Board Advisor's T6-gate enforcement.

## Pipeline-Verlauf
- G0: PENDING (Batch 42 draft 2026-05-19)
- P1: —
- P2: —

## Verwandte Strategien
- [[strategies/QM5_1595_sperandeo-2b-pivot-h4]] — 2B failure-swing on pivot-extreme (no trendline); Sperandeo 1991 ch. 4.
- [[strategies/QM5_1604_sperandeo-123-reversal-h4]] — 1-2-3 trend-change requires THREE sequential pivots + trendline-break + failed-retest; Sperandeo 1991 ch. 5.
- [[strategies/QM5_1583_sperandeo-tlb-refinement-h4]] — Three-Line-Break with Sperandeo 2B refinement; Sperandeo TV-II 1994 ch. 10.
- THIS card (1673): TV-II ch. 7 trendline-failure-reversal — uses 2-pivot trendline + tolerance-violation + cancellation-window-failure. Primitive-distinct from 1595 (pivot, no trendline), 1604 (3-pivot sequence + retest, not failure-to-recover), 1583 (TLB construction, not trendline).

## Lessons Learned (während Pipeline-Lauf)
- (none yet)

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
