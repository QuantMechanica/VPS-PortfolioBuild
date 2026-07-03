# QM5_13007_eurnzd-tsmom-pb - Strategy Spec

**EA ID:** QM5_13007
**Slug:** `eurnzd-tsmom-pb`
**Source:** `MOP-TSMOM-2012-EURNZD-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA applies the Moskowitz, Ooi, and Pedersen time-series momentum structure
to EURNZD.DWX. On the first new D1 bar of each broker-calendar month, it
compares the last completed close with the closes 126 and 252 D1 bars earlier.
If both return signs are positive, the EA holds or opens long; if both are
negative, it holds or opens short. If the two horizons disagree, it closes any
open position and stays flat. Each new entry receives an ATR(14) x 3.0 hard stop.

The EA uses only Darwinex MT5 price history and broker calendar timing. It does
not use macro files, external APIs, machine learning, grids, martingale sizing,
pyramiding, trailing stops, or partial closes.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_mid_lookback_d1_bars` | 126 | 105-147 | Completed D1 bars used for the 6-month sign signal |
| `strategy_long_lookback_d1_bars` | 252 | 210-294 | Completed D1 bars used for the 12-month sign signal |
| `strategy_atr_period` | 14 | 10-20 | ATR period for the hard protective stop |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | ATR hard-stop distance multiplier |
| `strategy_max_spread_points` | 80 | 50-120 | Maximum positive current spread allowed for new entries |

## 3. Symbol Universe

**Designed for:**
- `EURNZD.DWX` - an uncovered Darwinex FX cross with D1 history from 2017
  through 2026, used here for a dedicated low-frequency diversity sleeve.

**Explicitly NOT for:**
- Other FX pairs - they require separate source mapping, magic rows, and Q02
  evidence because cross-specific behavior can differ materially.
- Indices, metals, and energy symbols - they are already represented by other
  momentum and structural sleeves and are outside this card's diversity target.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` plus `QM_CalendarPeriodKey(PERIOD_MN1)` monthly key |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 6 direction or flat-state changes from 12 monthly checks |
| Typical hold time | one or more calendar months while both horizons agree |
| Expected drawdown profile | medium-high FX trend drawdown with flat exposure during horizon disagreement |
| Regime preference | persistent EURNZD trends confirmed by both 6-month and 12-month returns |
| Win rate target (qualitative) | medium-low; trend-following payoff should come from larger winners |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `MOP-TSMOM-2012-EURNZD-2026`
**Source type:** paper
**Pointer:** `strategy-seeds/sources/MOP-TSMOM-2012/source.md` and approved
card `strategy-seeds/cards/approved/QM5_13007_eurnzd-tsmom-pb_card.md`
**R1-R4 verdict (Q00):** all PASS per the approved card.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). This build does not touch live manifests,
`T_Live`, AutoTrading, or portfolio admission gates.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-03 | Initial build from approved EURNZD persistent-bias TSMOM card | Build task created by farmctl |
