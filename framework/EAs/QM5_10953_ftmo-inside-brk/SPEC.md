# QM5_10953_ftmo-inside-brk - Strategy Spec

**EA ID:** QM5_10953
**Slug:** `ftmo-inside-brk`
**Source:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f` (see `strategy-seeds/sources/c11dc4d3-bdfb-5076-aeed-5d943e9ef03f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

The EA evaluates each completed H4 bar for an inside bar, where the last closed bar's high is below the prior bar's high and its low is above the prior bar's low. The prior mother bar must have a range greater than 1.2 times ATR(14), and the inside-bar close must be above EMA(50) for a long setup or below EMA(50) for a short setup. A long setup places a buy-stop above the inside-bar high plus 0.10 ATR; a short setup places a sell-stop below the inside-bar low minus 0.10 ATR. Stops sit beyond the inside-bar extreme with a 0.05 ATR buffer, TP is 2R, pending orders expire after 3 H4 bars, and an opposite inside-bar breakout signal closes an open position.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR period for momentum range, buffers, and trailing. |
| `strategy_ema_period` | 50 | 5-300 | EMA period for trend direction on H4 closes. |
| `strategy_mother_atr_mult` | 1.20 | 0.5-5.0 | Minimum mother-bar range as a multiple of ATR. |
| `strategy_entry_atr_buffer` | 0.10 | 0.0-1.0 | Stop-entry offset beyond the inside-bar high or low. |
| `strategy_stop_atr_buffer` | 0.05 | 0.0-1.0 | Stop-loss buffer beyond the inside-bar high or low. |
| `strategy_tp_rr` | 2.00 | 0.5-5.0 | Take-profit reward/risk multiple. |
| `strategy_trailing_enabled` | true | true/false | Enables ATR trailing after the profit trigger. |
| `strategy_trail_trigger_rr` | 1.50 | 0.5-5.0 | Profit in R before ATR trailing starts. |
| `strategy_trail_atr_mult` | 1.00 | 0.25-5.0 | ATR multiple for trailing stop. |
| `strategy_pending_expiry_bars` | 3 | 1-10 | Number of H4 bars before an unfilled stop order expires. |
| `strategy_range_lookback_bars` | 20 | 5-100 | Recent range window used to reject narrow-range false breakouts. |
| `strategy_min_range_atr_mult` | 1.50 | 0.5-10.0 | Minimum 20-bar range width as a multiple of ATR. |
| `strategy_max_spread_stop_pct` | 0.10 | 0.01-0.50 | Maximum allowed spread as a fraction of stop distance. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed major FX market with H4 OHLC and EMA coverage.
- `GBPUSD.DWX` - card-listed major FX market with H4 OHLC and EMA coverage.
- `AUDJPY.DWX` - card-listed FX cross with H4 OHLC and EMA coverage.
- `NDX.DWX` - card-listed liquid index market with H4 OHLC and EMA coverage.

**Explicitly NOT for:**
- Non-DWX symbols - build and pipeline artifacts must use broker-verified `.DWX` symbols only.
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no tick-data evidence for P2/P3.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `30` |
| Typical hold time | H4 to multi-day, depending on breakout follow-through and TP/trailing. |
| Expected drawdown profile | Moderate clustered losses during false-breakout or compression regimes. |
| Regime preference | breakout / trend continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `c11dc4d3-bdfb-5076-aeed-5d943e9ef03f`
**Source type:** blog
**Pointer:** FTMO, "Inside Bar Strategy: A Simple Yet Powerful Trading Technique for All Markets", 2025-08-29, https://ftmo.com/en/blog/inside-bar-strategy-a-simple-yet-powerful-trading-technique-for-all-markets/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10953_ftmo-inside-brk.md`

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
| v1 | 2026-06-06 | Initial build from card | 3be94c5f-2b6b-4909-8182-b9c99590ab66 |
