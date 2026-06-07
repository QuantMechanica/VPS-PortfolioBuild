# QM5_11195_ft-cdlwave - Strategy Spec

**EA ID:** QM5_11195
**Slug:** ft-cdlwave
**Source:** 1580128f-e465-5454-bb97-a7572a6cfd6d (see `strategy-seeds/sources/1580128f-e465-5454-bb97-a7572a6cfd6d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-08

---

## 1. Strategy Logic

This EA trades long on D1 closed bars when the last completed candle matches the TA-Lib CDLHIGHWAVE pattern value configured by the card, defaulting to `-100`. The high-wave test requires a short real body versus the prior 10 real bodies and both shadows longer than twice the current real body. Entries are market buys at the next bar, protected by an ATR(14) stop at 2.5x ATR. Exits are the source ROI ladder, source trailing-stop rule, broker stop loss, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_pattern` | `CDLHIGHWAVE` | `CDLHIGHWAVE` | Fixed source candlestick pattern selector. |
| `strategy_pattern_value` | `-100` | `-100` or `100` | TA-Lib pattern output required for long entry. |
| `strategy_cdl_body_period` | `10` | `1+` | Prior real-body sample count for the short-body test. |
| `strategy_atr_period` | `14` | `1+` | ATR period for the protective stop. |
| `strategy_atr_stop_mult` | `2.5` | `2.0-3.0` | ATR multiplier for initial stop distance. |
| `strategy_max_spread_stop_pct` | `8.0` | `0+` | Maximum spread as percent of planned stop distance. |
| `strategy_trailing_offset_pct` | `8.4` | `4.0-12.0` | Profit percent required before source trailing activates. |
| `strategy_trailing_positive_pct` | `3.2` | `0+` | Trailing distance from current market price once active. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid major FX pair in the card's R3 portable basket.
- `GBPUSD.DWX` - liquid major FX pair in the card's R3 portable basket.
- `USDJPY.DWX` - liquid major FX pair in the card's R3 portable basket.
- `XAUUSD.DWX` - liquid metal symbol in the card's R3 portable basket.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - not available for DWX backtesting.
- Crypto spot symbols - the source was ported to DWX FX/metals for available OHLC data.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `35` |
| Typical hold time | source comment average `7 days, 11:54:00` |
| Expected drawdown profile | medium; exact drawdown TBD by Q02/Q03 |
| Regime preference | mean-revert / candlestick reversal |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 1580128f-e465-5454-bb97-a7572a6cfd6d
**Source type:** GitHub strategy source
**Pointer:** `https://github.com/freqtrade/freqtrade-strategies/blob/main/user_data/strategies/PatternRecognition.py`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11195_ft-cdlwave.md`

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
| v1 | 2026-06-08 | Initial build from card | e9a1b45e-6e0d-461a-bc5e-65e79387c478 |
