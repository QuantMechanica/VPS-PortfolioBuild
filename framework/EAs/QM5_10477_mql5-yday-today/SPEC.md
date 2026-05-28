# QM5_10477_mql5-yday-today - Strategy Spec

**EA ID:** QM5_10477
**Slug:** `mql5-yday-today`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades a prior-day breakout. It reads yesterday's D1 high and low, buys when the current ask trades above yesterday's high, and sells when the current bid trades below yesterday's low. The stop is 0.75 times the prior-day range, capped at 1.5 times D1 ATR(14), and the take-profit is 2R. Open positions are closed after the trading day changes if neither stop nor target has been hit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period_d1` | 14 | 2-100 | D1 ATR period used for the stop cap. |
| `strategy_range_sl_mult` | 0.75 | 0.1-5.0 | Fraction of yesterday's D1 range used as the baseline stop distance. |
| `strategy_atr_sl_cap_mult` | 1.5 | 0.1-10.0 | Maximum stop distance as a multiple of D1 ATR. |
| `strategy_reward_risk` | 2.0 | 0.1-10.0 | Take-profit multiple of initial risk. |
| `strategy_rollover_skip_min` | 5 | 0-240 | Minutes after broker-day rollover when new entries are blocked. |
| `strategy_max_spread_points` | 250 | 0-10000 | Maximum allowed spread in points; 0 disables the strategy spread guard. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with DWX intraday and D1 OHLC coverage.
- `GBPUSD.DWX` - liquid FX major with DWX intraday and D1 OHLC coverage.
- `USDJPY.DWX` - liquid FX major with DWX intraday and D1 OHLC coverage.
- `USDCHF.DWX` - liquid FX major with DWX intraday and D1 OHLC coverage.
- `USDCAD.DWX` - liquid FX major with DWX intraday and D1 OHLC coverage.
- `AUDUSD.DWX` - liquid FX major with DWX intraday and D1 OHLC coverage.
- `NZDUSD.DWX` - liquid FX major with DWX intraday and D1 OHLC coverage.
- `XAUUSD.DWX` - liquid gold CFD with DWX intraday and D1 OHLC coverage.
- `SP500.DWX` - liquid S&P 500 custom symbol for backtest-only index coverage.
- `NDX.DWX` - liquid Nasdaq 100 CFD for US index breakout coverage.
- `WS30.DWX` - liquid Dow 30 CFD for US index breakout coverage.
- `GDAXI.DWX` - liquid DAX index CFD for European index breakout coverage.
- `UK100.DWX` - liquid FTSE 100 CFD for European index breakout coverage.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` - the build cannot register or backtest unavailable broker/custom symbols.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `PERIOD_D1` for yesterday high, yesterday low, and ATR(14) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `80` |
| Typical hold time | `intraday, closed by end of trading day if SL/TP not reached` |
| Expected drawdown profile | `Breakout losses cluster during false-breakout and low-follow-through regimes.` |
| Regime preference | `breakout / volatility-expansion` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/23155`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10477_mql5-yday-today.md`

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
| v1 | 2026-05-28 | Initial build from card | 115859ac-5c2c-45e9-ac96-eee0dd0e2b1c |
