# QM5_12709_commodity-reversal-1m - Strategy Spec

**EA ID:** QM5_12709
**Slug:** `commodity-reversal-1m`
**Source:** `05abad87-420d-5a51-8a9b-3c35ad795385` (see `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-28

## 1. Strategy Logic

This EA implements a low-frequency market-neutral commodity reversal basket on
`XTIUSD.DWX`, `XNGUSD.DWX`, `XAUUSD.DWX`, and `XAGUSD.DWX`. On the first D1 bar
of each broker-calendar month it ranks all four symbols by prior
`strategy_lookback_d1` log return, buys the weakest performer, and shorts the
strongest performer. Entry requires a minimum return dispersion and at least
one selected energy leg, so the build does not collapse into another XAU/XAG
metal sleeve.

The package exits at the next monthly rebalance, max-hold expiry, Friday close,
broken-package repair, or per-leg ATR hard stop. This is not `QM5_12567`
commodity RSI pullback, not the single-symbol weekly XTI/XNG reversal EAs, not
XTI/XNG relative momentum, and not a gold/silver ratio or breakout basket.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_d1` | 21 | 15-42 | Prior D1 return ranking lookback |
| `strategy_min_return_diff_pct` | 4.0 | 2.0-6.0 | Required best-minus-worst return dispersion |
| `strategy_require_energy_leg` | true | true | Require XTI or XNG in the selected pair |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | Per-leg stop multiplier |
| `strategy_max_hold_days` | 35 | 25-45 | Calendar-day package time stop |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 2500 | 1500-4000 | XNG entry spread cap |
| `strategy_xau_max_spread_pts` | 500 | 300-800 | XAU entry spread cap |
| `strategy_xag_max_spread_pts` | 200 | 100-350 | XAG entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

## 3. Symbol Universe

- `XTIUSD.DWX` - host chart and magic slot 0.
- `XNGUSD.DWX` - magic slot 1.
- `XAUUSD.DWX` - magic slot 2.
- `XAGUSD.DWX` - magic slot 3.
- Logical basket symbol: `QM5_12709_COMM_REV1M_D1`.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()` plus first-bar-of-month gate.

## 5. Expected Behaviour

- Expected basket packages/year: about 5-10.
- Typical hold: one calendar month.
- Regime preference: cross-commodity one-month overreaction with enough
  dispersion and at least one energy leg.
- Risk mode for Q02 backtests: RISK_FIXED.

## 6. Source Citation

This card was mechanised from:

**Source ID:** `05abad87-420d-5a51-8a9b-3c35ad795385`
**Source type:** academic commodity futures paper
**Pointer:** `strategy-seeds/sources/YANG-COMM-REVERSAL-2017/source.md`
**Primary citation:** Yang, Goncu, and Pantelous, "Momentum and Reversal in
Commodity Futures", SSRN, URL
https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253
**R1-R4 verdict (Q00):** all PASS / see
`strategy-seeds/cards/commodity-reversal-1m_card.md`

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live`, AutoTrading, or portfolio-gate file is touched by
this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-28 | Initial basket build from approved card | pending branch commit |
