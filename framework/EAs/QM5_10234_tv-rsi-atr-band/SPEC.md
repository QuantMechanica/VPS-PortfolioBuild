# QM5_10234_tv-rsi-atr-band - Strategy Spec

**EA ID:** QM5_10234
**Slug:** tv-rsi-atr-band
**Source:** 30591366-874b-5bee-b47c-da2fca20b728 (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades confirmed M15 Heikin-Ashi close reversals through an RSI/ATR-derived band. It rebuilds a bounded Heikin-Ashi source window on each closed bar, computes RSI and ATR from that window, tracks the highest and lowest source values since the last reconstructed cross, and forms mirrored upper and lower bands scaled by ATR and inverse RSI pressure. A long opens when the source crosses upward through the active lower band, and a short opens when the source crosses downward through the active upper band. Existing positions close on an opposite confirmed band cross, or through the broker SL/TP brackets derived from the active band with the card's fallback minimum distance.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_timeframe` | `PERIOD_M15` | M1-MN1 | Execution and signal timeframe from the card. |
| `strategy_rsi_period` | `14` | `2+` | RSI period computed on Heikin-Ashi close. |
| `strategy_atr_period` | `14` | `2+` | ATR period computed on Heikin-Ashi OHLC. |
| `strategy_band_atr_mult` | `2.0` | `>0` | ATR multiplier used to offset the reversal bands. |
| `strategy_min_rsi_pressure` | `0.10` | `0.00-0.50` | Floor for RSI pressure scaling so bands cannot collapse to zero width. |
| `strategy_state_lookback` | `120` | `10+` | Bounded bar window used to reconstruct the last cross state. |
| `strategy_min_diff_pct` | `2.0` | `>0` | Minimum SL/TP distance for index symbols, expressed as percent of entry. |
| `strategy_atr_emergency_mult` | `2.0` | `>0` | Emergency minimum SL/TP distance for gold and other non-index symbols. |
| `strategy_max_spread_atr_pct` | `10.0` | `>=0` | Blocks entries when spread exceeds this percent of ATR; zero disables. |
| `strategy_longs_enabled` | `true` | `true/false` | Enables long entries. |
| `strategy_shorts_enabled` | `true` | `true/false` | Enables short entries. |

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - card-listed liquid Nasdaq 100 CFD proxy for the original large-cap equity source.
- `WS30.DWX` - card-listed liquid Dow 30 CFD proxy for US large-cap reversal behaviour.
- `SP500.DWX` - card-listed S&P 500 custom symbol; valid for backtest registration with T6 live caveat.
- `XAUUSD.DWX` - card-listed gold CFD with ATR emergency fallback for bracket distance.

**Explicitly NOT for:**
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX` - not canonical DWX symbols in the matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | intraday to multi-hour; card does not specify an exact hold-time target |
| Expected drawdown profile | reversal-band strategy with SL/TP bracket containment |
| Regime preference | trend-reversal with volatility-band confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 30591366-874b-5bee-b47c-da2fca20b728
**Source type:** TradingView script page
**Pointer:** https://www.tradingview.com/script/hZLgJ29l-RSI-and-ATR-Trend-Reversal-SL-TP/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10234_tv-rsi-atr-band.md`

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
| v1 | 2026-06-12 | Initial build from card | 578565cf-a3ca-42a6-9fdb-85fe65bf51fb |
