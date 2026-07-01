# QM5_12859_brent-52w-anchor - Strategy Spec

**EA ID:** QM5_12859
**Slug:** `brent-52w-anchor`
**Source:** `BIANCHI-COMM-52W-2016_BRENT_S03`
**Author of this spec:** Codex
**Last revised:** 2026-07-01

## 1. Strategy Logic

This EA implements a low-frequency structural Brent 52-week-anchor momentum
sleeve on `XBRUSD.DWX`. On the first D1 bar of each broker-calendar month, it
computes whether the prior completed close is near its own 252-D1 closing high
or low and whether the 63-D1 log return confirms that direction. A confirmed
high-anchor state opens a long package; a confirmed low-anchor state opens a
short package. Any open package is flattened on the next monthly rebalance or
by the max-hold stale-position guard.

The strategy differs from the existing Brent family because it is not raw
12-month return-sign TSMOM, not a weekday or month-only calendar sleeve, and
not a Brent/WTI or XBR/XNG basket. It also avoids XNG, XAU/XAG, and index
exposure in the current certified book.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_anchor_lookback_d1` | 252 | 189-315 | Completed D1 closes used for the 52-week high/low anchor |
| `strategy_confirm_lookback_d1` | 63 | 42-84 | Shorter D1 return confirmation lookback |
| `strategy_anchor_long_min` | 0.94 | 0.92-0.96 | Minimum ratio of recent close to 252-D1 close high for long entries |
| `strategy_anchor_short_max` | 1.08 | 1.05-1.12 | Maximum ratio of recent close to 252-D1 close low for short entries |
| `strategy_confirm_min_return_pct` | 2.0 | 1.0-3.0 | Minimum absolute 63-D1 log return confirmation in percent |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 3.25 | 2.5-4.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 31 | 21-45 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1200 | 800-1800 | Entry spread cap |

## 3. Symbol Universe

- `XBRUSD.DWX` - Brent crude-oil CFD proxy, magic slot 0.

Explicitly not for:

- `XTIUSD.DWX` - WTI already has its own 52-week-anchor build.
- `XNGUSD.DWX` - natural-gas sleeves already exist and are not the target
  exposure here.
- `XAUUSD.DWX`, `XAGUSD.DWX`, indices, and FX symbols.

## 4. Timeframe

- Base timeframe: D1.
- Multi-timeframe refs: none.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-10.
- Typical hold: one monthly package, capped at 31 calendar days by default.
- Regime preference: Brent continuation when price is anchored near its own
  52-week high or low.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Bianchi, R. J., Drew, M. E. and Fan, J. H., "Commodities momentum: A
behavioural perspective", Journal of Banking and Finance, 2016, DOI
https://doi.org/10.1016/j.jbankfin.2016.06.010. Runtime card:
`artifacts/cards_approved/QM5_12859_brent-52w-anchor.md`.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.
