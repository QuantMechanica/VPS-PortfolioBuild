# QM5_10230_tv-ema-stoch-atr - Strategy Spec

**EA ID:** QM5_10230
**Slug:** `tv-ema-stoch-atr`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (TradingView script page)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades pullback continuation on the close of the H1 bar. Long entries require EMA50 above EMA200, the closed-bar price below EMA50, recent Stochastic RSI below 20, and a Stochastic RSI bullish cross whose K value is higher than the prior bullish cross value. Short entries mirror this with EMA50 below EMA200, price above EMA50, recent Stochastic RSI above 80, and a bearish cross whose K value is lower than the prior bearish cross value. Entries use an ATR(14) stop at 1.5x ATR and a fixed 2R target; no discretionary close is used beyond optional source-authorized break-even and framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_signal_tf` | `PERIOD_H1` | MT5 timeframe enum | Timeframe for EMA and Stochastic RSI signal reads. |
| `strategy_ema_fast` | 50 | `> 0` | Fast EMA period for trend state. |
| `strategy_ema_slow` | 200 | `> strategy_ema_fast` | Slow EMA period for trend state. |
| `strategy_rsi_period` | 14 | `> 0` | RSI period used inside Stochastic RSI. |
| `strategy_stoch_rsi_lookback` | 14 | `> 1` | Lookback window for Stochastic RSI min/max normalization. |
| `strategy_stoch_k_smooth` | 3 | `> 0` | K smoothing length for Stochastic RSI. |
| `strategy_stoch_d_smooth` | 3 | `> 0` | D smoothing length for Stochastic RSI. |
| `strategy_recent_extreme_bars` | 5 | `> 0` | Recent window for the below-20 or above-80 pullback check. |
| `strategy_atr_period` | 14 | `> 0` | ATR period for the initial stop. |
| `strategy_atr_sl_mult` | 1.5 | `> 0` | ATR multiplier for the initial stop. |
| `strategy_rr_target` | 2.0 | `> 0` | Take-profit as an R multiple of initial stop distance. |
| `strategy_break_even_enabled` | `false` | `true/false` | Optional source-authorized break-even management. |
| `strategy_break_even_trigger_r` | 1.0 | `> 0` | Break-even trigger measured in initial R. |
| `strategy_break_even_buffer_pts` | 0 | `>= 0` | Point buffer added when moving SL to break-even. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - card-listed liquid metal CFD with clean EMA/Stochastic RSI/ATR data.
- `NDX.DWX` - card-listed US index CFD with trend-pullback suitability.
- `GDAXI.DWX` - canonical DWX DAX symbol used for the card's `GER40.DWX` target.
- `GBPJPY.DWX` - card-listed volatile FX pair suitable for pullback continuation testing.
- `EURUSD.DWX` - card-listed major FX pair suitable for baseline cross-asset testing.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no DWX data guarantee.
- `GER40.DWX` - not present in the DWX matrix; use `GDAXI.DWX`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none by default; `strategy_signal_tf` is `PERIOD_H1` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | hours to several days, bounded by 2R bracket/Friday close |
| Expected drawdown profile | fixed-risk pullback trend strategy, bounded by V5 risk controls |
| Regime preference | trend-following pullback continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** `https://www.tradingview.com/script/BUsgoYjm-TradePro-s-2-EMA-Stoch-RSI-ATR-Strategy/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10230_tv-ema-stoch-atr.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-09 | Initial build from card | 15dc43ce-01a5-430a-af99-c10fda2a9876 |
