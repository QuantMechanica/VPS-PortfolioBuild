# QM5_12957_commodity-reversal-1m-card - Strategy Spec

**EA ID:** QM5_12957
**Slug:** `commodity-reversal-1m-card`
**Source:** `05abad87-420d-5a51-8a9b-3c35ad795385`
**Author of this spec:** Codex
**Last revised:** 2026-07-03

## 1. Strategy Logic

This EA implements a low-frequency monthly commodity reversal basket on
`XTIUSD.DWX`, `XNGUSD.DWX`, `XAUUSD.DWX`, and `XAGUSD.DWX`. On the first D1
bar of a new broker-calendar month it ranks the four symbols by prior
`strategy_lookback_d1` log return, buys the worst performer, and shorts the
best performer when the return gap exceeds `strategy_min_return_diff_pct`.
The package exits on the next monthly rebalance, max-hold expiry, Friday
close, broken-package repair, or per-leg ATR hard stop.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_d1` | 21 | 15-42 | Prior D1 return ranking lookback |
| `strategy_min_return_diff_pct` | 4.0 | 2.0-6.0 | Required best-minus-worst return gap before entry |
| `strategy_require_energy_leg` | true | true | Require XTI or XNG in the selected long/short pair |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg stop multiplier |
| `strategy_max_hold_days` | 35 | 25-45 | Calendar-day package time stop |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 2500 | 1500-4000 | XNG entry spread cap |
| `strategy_xau_max_spread_pts` | 500 | 300-800 | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 200 | 100-350 | XAG entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - WTI host chart, energy leg, and magic slot 0.
- `XNGUSD.DWX` - natural gas energy leg and magic slot 1.
- `XAUUSD.DWX` - gold commodity leg and magic slot 2.
- `XAGUSD.DWX` - silver commodity leg and magic slot 3.

**Explicitly NOT for:**
- Non-DWX futures, spot indices, and external commodity curves - the EA reads only Darwinex MT5 OHLC.
- Single-symbol commodity timing - this is a two-leg monthly basket package.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` plus first-bar-of-month gate |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 8 basket packages/year |
| Typical hold time | one calendar month or up to 35 days |
| Expected drawdown profile | medium-high drawdown from commodity reversal tails |
| Regime preference | monthly cross-sectional mean reversion after commodity overreaction |
| Win rate target (qualitative) | medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `05abad87-420d-5a51-8a9b-3c35ad795385`
**Source type:** paper
**Pointer:** Yang, Goncu, and Pantelous, "Momentum and Reversal in Commodity Futures", SSRN.
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12957_commodity-reversal-1m-card.md`

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-03 | Initial build from approved card | build task `4fd2b036-e31f-4609-afc9-82fa5a6ddbb9` |
