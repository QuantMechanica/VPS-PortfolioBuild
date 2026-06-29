# QM5_12807_xng-52w-anchor - Strategy Spec

**EA ID:** QM5_12807
**Slug:** `xng-52w-anchor`
**Source:** `BIANCHI-COMM-52W-2016`
**Author of this spec:** Codex
**Last revised:** 2026-06-29

## 1. Strategy Logic

This EA implements a low-frequency structural natural gas 52-week anchor momentum
sleeve on `XNGUSD.DWX`. On the first D1 bar of each broker-calendar month, it
computes the prior close's location versus the 252-D1 closing high and low,
then requires a same-direction 63-D1 return confirmation. A close near the
252-D1 high opens a monthly long package; a close near the 252-D1 low opens a
monthly short package. Any open package is flattened on the next monthly
rebalance or by the max-hold stale-position guard.

The strategy differs from the existing natural-gas book because it is not raw
12-month return-sign TSMOM, not four-week reversal, not XNG seasonality,
storage, freeze, hurricane, LNG, shoulder-season, weekend-gap, or EIA event
logic, and not an XTI/XNG relative-value basket. It is also distinct from the
WTI 52-week-anchor build because the traded exposure is `XNGUSD.DWX`.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_anchor_lookback_d1` | 252 | 189-315 | Completed D1 closes used for the 52-week high/low anchor |
| `strategy_confirm_lookback_d1` | 63 | 42-84 | Completed D1 closes used for same-direction confirmation |
| `strategy_anchor_long_min` | 0.90 | 0.86-0.94 | Minimum close/high ratio for long anchor |
| `strategy_anchor_short_max` | 1.15 | 1.10-1.20 | Maximum close/low ratio for short anchor |
| `strategy_confirm_min_return_pct` | 5.0 | 3.0-7.5 | Minimum absolute 63-D1 confirmation return |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 3.75 | 2.5-5.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 31 | 21-45 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1500 | 1000-2500 | Entry spread cap |

## 3. Symbol Universe

**Designed for:**
- `XNGUSD.DWX` - natural-gas CFD proxy available in the DWX symbol matrix.

**Explicitly NOT for:**
- `XTIUSD.DWX` - WTI has separate 52-week-anchor and event sleeves.
- `XAUUSD.DWX` and `XAGUSD.DWX` - metal sleeves are outside this natural gas card.
- Equity index symbols - the mission is commodity/energy exposure.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 4-10 |
| Typical hold time | one monthly package, capped at 31 calendar days |
| Expected drawdown profile | medium-high natural-gas trend reversals bounded by ATR stop |
| Regime preference | natural-gas continuation when price is anchored near its 52-week high or low |
| Win rate target | medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `BIANCHI-COMM-52W-2016`
**Source type:** paper
**Pointer:** `strategy-seeds/sources/BIANCHI-COMM-52W-2016/`
**R1-R4 verdict (Q00):** all PASS / see
`artifacts/cards_approved/QM5_12807_xng-52w-anchor.md`

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV->mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). No live manifest, `T_Live` file, portfolio
gate, or AutoTrading setting is touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-29 | Initial build from card | branch-local build |
