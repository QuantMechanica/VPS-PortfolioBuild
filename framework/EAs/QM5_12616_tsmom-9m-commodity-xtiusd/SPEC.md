# QM5_12616_tsmom-9m-commodity-xtiusd - Strategy Spec

**EA ID:** QM5_12616
**Slug:** `tsmom-9m-commodity-xtiusd`
**Source:** `MOP-TSMOM-2012`
**Author of this spec:** Codex
**Last revised:** 2026-06-27

## 1. Strategy Logic

This EA implements a low-frequency WTI intermediate time-series-momentum sleeve
on `XTIUSD.DWX`. On the first D1 bar of each broker-calendar month, it computes
the prior 9-month log return from completed D1 closes and requires the prior
3-month log return to confirm the same direction. A positive confirmed trend
opens a monthly long package; a negative confirmed trend opens a monthly short
package. Any open package is flattened on the next monthly rebalance or by the
max-hold stale-position guard.

The strategy differs from the existing WTI book because it is not a calendar,
inventory, hurricane, refinery, OPEC, expiry, or reversal setup. It also differs
from `QM5_12603_wti-tsmom12m` by using an intermediate 9-month horizon plus a
3-month confirmation filter.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_lookback_d1` | 189 | 168-210 | Completed D1 bars used for the 9-month return-sign signal |
| `strategy_confirm_lookback_d1` | 63 | 42-84 | Completed D1 bars used for same-sign confirmation |
| `strategy_min_abs_return_pct` | 1.5 | 0.5-3.0 | Neutral band around the 9-month trailing return |
| `strategy_confirm_min_abs_return_pct` | 0.5 | 0.0-1.0 | Neutral band around the 3-month confirmation return |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 3.0 | 2.5-4.0 | ATR hard-stop distance multiplier |
| `strategy_max_hold_days` | 31 | 21-45 | Calendar-day stale-position guard |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - WTI crude-oil CFD proxy named in the approved card and present
  in the DWX symbol matrix.

**Explicitly NOT for:**
- `XBRUSD.DWX` - not present in the canonical DWX symbol matrix for this build.
- `XNGUSD.DWX` - natural-gas exposure already has separate XNG cards.
- `XAUUSD.DWX` and `XAGUSD.DWX` - metal sleeves are outside this WTI card.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | about 5-10 |
| Typical hold time | one monthly package, capped at 31 calendar days |
| Expected drawdown profile | medium-high crude-oil trend reversals bounded by ATR stop |
| Regime preference | intermediate WTI trend persistence |
| Win rate target (qualitative) | medium |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `MOP-TSMOM-2012`
**Source type:** `paper`
**Pointer:** `strategy-seeds/sources/MOP-TSMOM-2012/`
**R1-R4 verdict (Q00):** all PASS / see `strategy-seeds/cards/approved/QM5_12616_tsmom-9m-commodity-xtiusd_card.md`

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV->mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). No live manifest, `T_Live` file, portfolio
gate, or AutoTrading setting is touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-27 | Initial build from card | branch-local build |
