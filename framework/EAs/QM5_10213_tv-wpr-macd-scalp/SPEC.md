# QM5_10213_tv-wpr-macd-scalp - Strategy Spec

**EA ID:** QM5_10213
**Slug:** `tv-wpr-macd-scalp`
**Source:** `30591366-874b-5bee-b47c-da2fca20b728` (see `strategy-seeds/sources/30591366-874b-5bee-b47c-da2fca20b728/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-09

---

## 1. Strategy Logic

The EA trades the M1 Williams %R, MACD histogram, and SMA scalping rules from the approved card. A long setup becomes active when Williams %R(140) crosses upward through -94, then a long entry opens when the MACD(24,52,9) histogram flips from negative to positive and the latest closed price is above SMA(7). A short setup becomes active when Williams %R crosses downward through -6, then a short entry opens when the MACD histogram flips from positive to negative and price is below SMA(7). Open positions close when the MACD histogram reverses against the position with worsening momentum, or when the 90-minute maximum hold time is reached; every entry carries a 1.2 * ATR(14) emergency stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_wpr_length` | 140 | 2-300 | Williams %R lookback length. |
| `strategy_wpr_long_level` | -94.0 | -100 to 0 | Long setup activation level crossed upward. |
| `strategy_wpr_short_level` | -6.0 | -100 to 0 | Short setup activation level crossed downward. |
| `strategy_wpr_long_reset` | -40.0 | -100 to 0 | Deactivates an unfilled long setup when crossed upward. |
| `strategy_wpr_short_reset` | -60.0 | -100 to 0 | Deactivates an unfilled short setup when crossed downward. |
| `strategy_macd_fast` | 24 | 2-100 | MACD fast EMA period. |
| `strategy_macd_slow` | 52 | 3-200 | MACD slow EMA period. |
| `strategy_macd_signal` | 9 | 2-50 | MACD signal period. |
| `strategy_sma_period` | 7 | 2-100 | SMA trend confirmation period. |
| `strategy_atr_period` | 14 | 2-100 | ATR period for the emergency stop and spread filter. |
| `strategy_atr_sl_mult` | 1.2 | 0.1-10.0 | ATR multiplier for the emergency stop. |
| `strategy_max_hold_minutes` | 90 | 1-1440 | Maximum position holding time. |
| `strategy_max_spread_stop_fraction` | 0.20 | 0.01-1.00 | Blocks entries when spread exceeds this fraction of the stop distance. |
| `strategy_fx_session_start_hour` | 7 | 0-23 | Broker-hour start for FX and gold trading. |
| `strategy_fx_session_end_hour` | 21 | 0-23 | Broker-hour end for FX and gold trading. |
| `strategy_index_session_start_hour` | 14 | 0-23 | Broker-hour start for index cash-session overlap. |
| `strategy_index_session_end_hour` | 18 | 0-23 | Broker-hour end for index cash-session overlap. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card target; liquid major FX pair suitable for London/New York M1 scalping.
- `GBPUSD.DWX` - card target; liquid major FX pair suitable for London/New York M1 scalping.
- `XAUUSD.DWX` - card target; liquid gold CFD with DWX OHLC data for WPR, MACD, SMA, and ATR.
- `GDAXI.DWX` - DAX 40 DWX matrix equivalent for card target `GER40.DWX`, which is not in the matrix.
- `NDX.DWX` - card target; liquid US index CFD suitable for cash-session overlap tests.

**Explicitly NOT for:**
- Symbols outside the registered list above - no implicit universe expansion at runtime.
- `GER40.DWX` - card-stated alias is not present in `dwx_symbol_matrix.csv`; `GDAXI.DWX` is the registered DAX equivalent.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default; setfiles use M1) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 320 |
| Typical hold time | M1 scalps, capped at 90 minutes |
| Expected drawdown profile | High-cadence fixed-risk scalper, bounded by ATR emergency stop and framework risk controls |
| Regime preference | Liquid-session momentum reversal with MACD confirmation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `30591366-874b-5bee-b47c-da2fca20b728`
**Source type:** TradingView open-source script
**Pointer:** `https://www.tradingview.com/script/975ByLQ5-Scalping-with-Williams-R-MACD-and-SMA-1m/`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10213_tv-wpr-macd-scalp.md`

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
| v1 | 2026-06-09 | Initial build from card | fb690cb5-8787-4013-9e3c-db4451f68e7a |
