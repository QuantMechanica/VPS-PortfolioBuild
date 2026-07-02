# QM5_12913_xti-12m-carry - Strategy Spec

**EA ID:** QM5_12913  
**Slug:** `xti-12m-carry`  
**Source:** `KOIJEN-CARRY-2018`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-02

## 1. Strategy Logic

This EA implements a structural WTI carry sleeve on `XTIUSD.DWX`.
Once per configured broker weekday on D1, it compares the broker's long and
short swap values and enters the side with better carry. If `.DWX` backtest
symbols expose both swap fields as zero, the EA uses a documented structural
short-carry fallback so the test harness does not collapse to zero trades. A
12-month D1 return guard blocks long carry after extreme negative drift and
short carry after extreme positive drift, so price history is a risk guard, not
the signal source.

The strategy is intentionally not a duplicate of the existing XTI family:
`QM5_12567` uses cumulative RSI/pullback logic, `QM5_12603` and `QM5_12616`
use time-series momentum as the direction source, `QM5_12780` uses a 52-week
anchor, and WTI inventory/weather/calendar/roll/refinery/event sleeves use
date or event timing rather than broker-swap carry.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rebalance_weekday` | 1 | 1 | Broker weekday for weekly package entry; Monday=1 |
| `strategy_return_lookback_d1` | 252 | 189-315 | D1 return lookback for adverse-drift guard |
| `strategy_max_adverse_return_pct` | 25.0 | 15-40 | Max adverse 12M drift allowed against carry side |
| `strategy_min_swap_advantage` | 0.0 | 0 | Minimum long-vs-short swap edge |
| `strategy_zero_swap_fallback_direction` | -1 | -1/0/1 | Direction used when tester swap fields are tied at zero |
| `strategy_atr_period` | 20 | 14-30 | ATR period for hard stop |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | ATR stop distance multiplier |
| `strategy_max_hold_days` | 5 | 3-7 | Stale-position time exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Bar gating: `QM_IsNewBar()`.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 35-52.
- Typical hold: one broker week, subject to Friday close.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Koijen, R. S. J., Moskowitz, T. J., Pedersen, L. H. and Vrugt, E. B. (2018).
"Carry." Journal of Financial Economics, 127(2), 197-225.
DOI: https://doi.org/10.1016/j.jfineco.2017.11.002.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-02 | Initial build from card | Enqueue Q02 |

