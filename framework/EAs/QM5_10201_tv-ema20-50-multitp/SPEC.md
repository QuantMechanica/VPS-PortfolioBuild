# QM5_10201_tv-ema20-50-multitp - Strategy Spec

**EA ID:** QM5_10201
**Slug:** `tv-ema20-50-multitp`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades an H1 EMA crossover. It opens long when EMA(20) crosses above EMA(50) on the last closed H1 bar, and opens short when EMA(20) crosses below EMA(50). Each entry uses a full-position bracket: TP is one previous-candle range from entry, and SL is the tighter of 3% from entry and 2.0 ATR(14), floored at 1.0 ATR(14). If the opposite EMA crossover appears while a position is open, the EA closes the position and waits one bar before allowing the reversal entry.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | MT5 timeframe enum | Timeframe used for EMA, ATR, and previous-candle range. |
| `strategy_fast_ema_period` | `20` | `>= 1` and `< strategy_slow_ema_period` | Fast EMA period for crossover direction. |
| `strategy_slow_ema_period` | `50` | `> strategy_fast_ema_period` | Slow EMA period for crossover direction. |
| `strategy_atr_period` | `14` | `>= 1` | ATR period used for stop sizing. |
| `strategy_atr_sl_mult` | `2.0` | `> 0` | ATR multiple used as the volatility stop candidate. |
| `strategy_atr_floor_mult` | `1.0` | `> 0` | Minimum ATR multiple allowed for the stop distance. |
| `strategy_percent_sl` | `3.0` | `> 0` | Percent-of-entry stop candidate. |
| `strategy_tp_range_mult` | `1.0` | `> 0` | Multiplier on the previous H1 candle range for TP. |
| `strategy_max_spread_stop_fraction` | `0.15` | `>= 0` | Blocks entries when spread exceeds this fraction of stop distance. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed portable FX baseline symbol for EMA crossover testing.
- `GBPUSD.DWX` - card-listed portable FX baseline symbol for EMA crossover testing.
- `XAUUSD.DWX` - card-listed gold baseline symbol for EMA crossover testing.
- `XTIUSD.DWX` - card-listed crude oil baseline symbol for EMA crossover testing.
- `NDX.DWX` - card-listed US index baseline symbol for EMA crossover testing.

**Explicitly NOT for:**
- Symbols outside the five registered `.DWX` rows above - not listed by the approved card for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | not specified in card frontmatter; bounded by H1 bracket exit or opposite H1 crossover |
| Expected drawdown profile | fixed-risk trend-following bracket strategy; no card-specific drawdown target |
| Regime preference | trend-following / moving-average-crossover regimes |
| Win rate target (qualitative) | not specified in card frontmatter |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** `TradingView script`
**Pointer:** `https://www.tradingview.com/script/B7umqU7W-EMA-Crossover-Strategy-with-Take-Profit-and-Candle-Highlighting/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10201_tv-ema20-50-multitp.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-09 | Initial build from card | c3bd4b5a-7109-4207-b39b-955ee62f66a2 |
