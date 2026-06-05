# QM5_10831_tv-ref-st-tsl - Strategy Spec

**EA ID:** QM5_10831
**Slug:** `tv-ref-st-tsl`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see `strategy-seeds/sources/d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-06

---

## 1. Strategy Logic

This EA trades the close of a SuperTrend state change on the active chart timeframe. A long entry is allowed when the last closed price crosses above the SuperTrend line, closes above the configured EMA when that filter is enabled, and ADX is above the configured threshold when that filter is enabled. A short entry mirrors the same logic below the SuperTrend line and EMA. Once in a trade, the SuperTrend line is the primary stop, the stop moves to breakeven after the configured ATR checkpoint, and the runner trails at the more protective of the SuperTrend line and the ATR trail.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_supertrend_atr_period` | 10 | 7-14 | ATR length used to construct the SuperTrend line. |
| `strategy_supertrend_factor` | 3.0 | 2.0-4.0 | ATR multiple used in SuperTrend bands. |
| `strategy_use_ema_filter` | true | true/false | Require close to be on the trade side of EMA. |
| `strategy_ema_period` | 200 | 100-200 | EMA period for the trend filter. |
| `strategy_use_adx_filter` | true | true/false | Require ADX filter before entry. |
| `strategy_adx_period` | 14 | 14 | ADX lookback period. |
| `strategy_adx_threshold` | 20.0 | 18.0-25.0 | Minimum ADX value for entries. |
| `strategy_trail_atr_period` | 14 | 14 | ATR period for breakeven and trailing logic. |
| `strategy_atr_trail_mult` | 2.0 | 1.5-2.5 | ATR multiple for the custom trail. |
| `strategy_breakeven_atr_mult` | 1.5 | 0.0-2.0 | ATR profit multiple that moves stop to breakeven; 0 disables. |
| `strategy_use_fixed_target` | true | true/false | Enables the optional full-position ATR target. |
| `strategy_target_atr_mult` | 3.0 | 3.0 | ATR multiple for the optional fixed target. |
| `strategy_use_session_filter` | false | true/false | Enables the optional source session filter. |
| `strategy_session_start_hour` | 0 | 0-23 | Broker-hour start for the optional session filter. |
| `strategy_session_end_hour` | 24 | 0-24 | Broker-hour end for the optional session filter. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` - DWX matrix DAX CFD used as the available port for card-stated `GER40.DWX`.
- `NDX.DWX` - liquid DWX index CFD for trend-following SuperTrend tests.
- `WS30.DWX` - liquid DWX index CFD for trend-following SuperTrend tests.
- `XAUUSD.DWX` - liquid DWX metal CFD with ATR trend behaviour.
- `EURUSD.DWX` - liquid DWX forex CFD with continuous OHLC history.

**Explicitly NOT for:**
- `GER40.DWX` - not present in `framework/registry/dwx_symbol_matrix.csv`; ported to `GDAXI.DWX`.

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
| Trades / year / symbol | `80` |
| Typical hold time | intraday to multi-session, controlled by SuperTrend and ATR trail |
| Expected drawdown profile | whipsaw-sensitive in low-ADX ranging markets |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** `https://www.tradingview.com/script/c1XpwWU4-Refined-Supertrend-ATR-TSL-Filters-Nifty-BankNifty-V2/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10831_tv-ref-st-tsl.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-06 | Initial build from card | b701f31a-a695-444b-a2f2-50d595d783af |
