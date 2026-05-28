# QM5_10482_mql5-secwenta - Strategy Spec

**EA ID:** QM5_10482
**Slug:** `mql5-secwenta`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

At each new H1 bar, the EA counts the latest completed candles. It buys after three consecutive bullish candles where close is above open, and sells after three consecutive bearish candles where close is below open. Doji candles do not count toward either row. The stop is the wider of 1.25 x ATR(14) or the far side of the completed candle row, capped at 2.5 x ATR(14); the target is 2R. The EA closes on an opposite row signal or after 10 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_work_tf` | `PERIOD_H1` | M15-H1 baseline | Timeframe used for candle-row signals, ATR, and time-stop bar counting. |
| `strategy_bull_bars` | 3 | 1-20 | Number of consecutive bullish closed bars required for a long signal. |
| `strategy_bear_bars` | 3 | 1-20 | Number of consecutive bearish closed bars required for a short signal. |
| `strategy_atr_period` | 14 | 2-100 | ATR period used for stop distance and cap. |
| `strategy_atr_sl_mult` | 1.25 | 0.1-10.0 | Minimum stop distance as an ATR multiple. |
| `strategy_atr_cap_mult` | 2.5 | 0.1-20.0 | Maximum stop distance as an ATR multiple. |
| `strategy_target_rr` | 2.0 | 0.5-10.0 | Take-profit multiple of initial risk. |
| `strategy_time_stop_bars` | 10 | 1-500 | Maximum number of working-timeframe bars to hold a trade. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` -- do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with DWX OHLC and ATR support.
- `GBPUSD.DWX` - liquid FX major with DWX OHLC and ATR support.
- `USDJPY.DWX` - liquid FX major with DWX OHLC and ATR support.
- `USDCHF.DWX` - liquid FX major with DWX OHLC and ATR support.
- `USDCAD.DWX` - liquid FX major with DWX OHLC and ATR support.
- `AUDUSD.DWX` - liquid FX major with DWX OHLC and ATR support.
- `NZDUSD.DWX` - liquid FX major with DWX OHLC and ATR support.
- `XAUUSD.DWX` - card-stated gold exposure with DWX OHLC and ATR support.
- `XTIUSD.DWX` - card-stated oil exposure with DWX OHLC and ATR support.
- `SP500.DWX` - liquid US large-cap index CFD equivalent, backtest-only custom symbol.
- `NDX.DWX` - liquid Nasdaq 100 index CFD equivalent.
- `WS30.DWX` - liquid Dow 30 index CFD equivalent.
- `GDAXI.DWX` - liquid DAX index CFD equivalent.
- `UK100.DWX` - liquid FTSE 100 index CFD equivalent.

**Explicitly NOT for:**
- Non-DWX symbols - registry and backtest artifacts require canonical `.DWX` symbols.
- Unavailable index or ETF aliases such as `SPY.DWX`, `SPX500.DWX`, and `ES.DWX` - they are not in the DWX symbol matrix.
- Illiquid or non-registered symbols outside the current DWX matrix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `150` |
| Typical hold time | `up to 10 H1 bars` |
| Expected drawdown profile | `frequent continuation entries with fixed ATR risk and 2R target` |
| Regime preference | `trend-continuation / candle-row momentum` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `forum / codebase`
**Pointer:** `https://www.mql5.com/en/code/22977`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10482_mql5-secwenta.md`

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
| v1 | 2026-05-28 | Initial build from card | f77ea3d0-586d-4ce9-a9cf-5a6ff474cda9 |
