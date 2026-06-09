# QM5_10224_tv-viop-atr-snipe - Strategy Spec

**EA ID:** QM5_10224
**Slug:** `tv-viop-atr-snipe`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

This EA trades closed-bar intraday momentum. It goes long when the fast EMA is above the slow EMA, the EMA spread is widening, RSI is inside the configured long band, the latest closed bar closes above the prior close, ADX is above the strength threshold, and the close is above the WMA trend line. It goes short on the mirrored conditions. Entries use a fixed ATR stop and a take-profit set from the configured reward/risk ratio; an open position is closed if the opposite signal appears before SL or TP.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_fast_ema_period` | 9 | 1-500 | Fast EMA period for direction and momentum. |
| `strategy_slow_ema_period` | 21 | 1-500 | Slow EMA period for direction and momentum. |
| `strategy_min_ema_diff_pts` | 0.0 | 0-100000 | Minimum fast-slow EMA spread in points. |
| `strategy_rsi_period` | 14 | 1-500 | RSI period. |
| `strategy_rsi_long_min` | 50.0 | 0-100 | Lower RSI bound for long entries. |
| `strategy_rsi_long_max` | 80.0 | 0-100 | Upper RSI bound for long entries. |
| `strategy_rsi_short_min` | 20.0 | 0-100 | Lower RSI bound for short entries. |
| `strategy_rsi_short_max` | 50.0 | 0-100 | Upper RSI bound for short entries. |
| `strategy_adx_period` | 14 | 1-500 | ADX period. |
| `strategy_adx_min` | 20.0 | 0-100 | Minimum ADX trend strength. |
| `strategy_wma_period` | 50 | 1-500 | WMA trend-line period. |
| `strategy_atr_period` | 14 | 1-500 | ATR period for initial stop. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-20 | ATR multiplier for initial stop distance. |
| `strategy_rr_target` | 1.5 | 0.1-20 | Take-profit distance as R multiple of stop distance. |
| `strategy_no_trade_enabled` | true | true/false | Enables the source no-trade session. |
| `strategy_no_trade_start_h` | 22 | 0-23 | Broker-hour start of no-trade window. |
| `strategy_no_trade_end_h` | 1 | 0-23 | Broker-hour end of no-trade window. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - canonical DWX DAX index port for the card's GER40 target.
- `NDX.DWX` - liquid US index CFD fitting the intraday momentum rule set.
- `WS30.DWX` - liquid US index CFD fitting the intraday momentum rule set.
- `XAUUSD.DWX` - liquid gold CFD named by the card.
- `EURUSD.DWX` - liquid forex major named by the card.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - no verified DWX data route.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5 / M15` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework entry gate; exit also checks new bars only while a position is open) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `180` |
| Typical hold time | intraday minutes to hours |
| Expected drawdown profile | moderate scalping drawdown with ATR-defined per-trade risk |
| Regime preference | trend-following intraday momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView script
**Pointer:** TradingView script `VIOP Scalping - ATR SNIPER`, author handle `mehmettopbas_`, published 2026-01-04, https://www.tradingview.com/script/R0CTM8NR-VIOP-Scalping-ATR-SNIPER/
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10224_tv-viop-atr-snipe.md`

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
| v1 | 2026-06-09 | Initial build from card | 88e72e6b-44e0-42b5-9d41-4be794edded5 |
