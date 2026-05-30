---
ea_id: QM5_10485
slug: mql5-exec-ac
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
source_citation: "Executer1 / Alex idea, Vladimir Karputov (barabashkakvn) code, Executer AC, MQL5 CodeBase, published 2018-11-20, https://www.mql5.com/en/code/23086"
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/awesome-oscillator]]"
  - "[[concepts/momentum-reversal]]"
indicators: [Acceleration/Deceleration Oscillator]
target_symbols: [EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX]
period: H1
expected_trade_frequency: "AC multi-signal new-bar oscillator system on H1; conservative estimate 40-100 trades/year/symbol."
expected_trades_per_year_per_symbol: 60
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 source URL present; R2 AC sequence entry/exit rules with 40-100 trades/year/symbol; R3 standard oscillator testable on DWX; R4 fixed non-ML one-position rules."
---

# MQL5 Executer AC Momentum Bend

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- Citation: Executer1 / Alex idea, Vladimir Karputov (barabashkakvn) code, "Executer AC", MQL5 CodeBase, published 2018-11-20, URL https://www.mql5.com/en/code/23086.
- Source location: page states the EA uses iAC, operates only on new bars, opens one position at a time, and lists buy/sell conditions based on AC value sequences and zero-crossing states.

## Mechanik

### Entry
- Evaluate only at new-bar open on the selected timeframe.
- Compute AC indicator on closed bars.
- Long signals:
  - AC is above zero on bars 1 and 2 and rises over the last two closed bars: `AC[1] > AC[2] > AC[3]`.
  - Or AC is below zero on bars 1 and 2 and rises over three closed bars: `AC[1] > AC[2] > AC[3] > AC[4]`.
  - Or AC crosses according to the source zero-cross long branch; build should confirm the sign labels because the translated text appears inconsistent.
- Short signals:
  - AC is above zero on bars 1 and 2 and falls over three closed bars: `AC[1] < AC[2] < AC[3] < AC[4]`.
  - Or AC is below zero on bars 1 and 2 and falls over two closed bars: `AC[1] < AC[2] < AC[3]`.
  - Or AC crosses according to the source zero-cross short branch; build should confirm the sign labels.
- No active position for this symbol/magic.

### Exit
- Close on opposite AC signal.
- Protective SL baseline = 1.5 * ATR(14).
- TP baseline = 2.0R.
- Time stop after 72 H1 bars.

### Stop Loss
- ATR stop; source history-based lot calculation is excluded from the signal and mapped to V5 risk.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Live: V5 default risk after approval.

### Zusaetzliche Filter
- One active position per symbol/magic, matching source one-position behavior.
- Disable source history-based lot optimization; use V5 risk only.
- Skip high-impact news windows when QM news filter is active.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full MQL5 CodeBase URL with title, idea author, code author, and publish date. |
| R2 Mechanical | PASS | Source lists explicit AC sequence conditions for buys and sells; zero-cross labels need code confirmation but core rules are mechanical. |
| R3 DWX-testbar | PASS | AC is a standard oscillator derived from OHLC median prices and portable to DWX symbols. |
| R4 No ML | PASS | Fixed oscillator rules, one-position source behavior, no ML/grid/martingale; adaptive lot sizing is excluded. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10481_mql5-exec-ao]] - Awesome Oscillator bend family; this card uses Acceleration/Deceleration Oscillator rules.

## Lessons Learned
- TBD during pipeline run.
