# QM5_10540_mql5-boll-rev — Strategy Spec

**EA ID:** QM5_10540
**Slug:** `mql5-boll-rev`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA evaluates closed H1 bars against Bollinger Bands. It buys when the last closed bar closes below the lower band and sells when the last closed bar closes above the upper band. The hard stop is placed beyond the breakout candle extreme by an ATR multiple, the baseline target is 1.5R, and discretionary exits occur on a middle-band touch or after 8 H1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 20, 30, 40 | Bollinger Bands lookback period. |
| `strategy_bb_deviation` | 2.0 | 2.0, 2.5, 3.0 | Bollinger Bands deviation multiplier. |
| `strategy_atr_period` | 14 | 14+ | ATR period used for the hard stop offset. |
| `strategy_atr_sl_mult` | 1.5 | 1.0, 1.5, 2.0 | ATR multiple beyond the breakout candle extreme. |
| `strategy_tp_rr` | 1.5 | 1.5 baseline | Take-profit multiple in R. |
| `strategy_time_stop_bars` | 8 | 1+ | Maximum H1 bars to hold before a time-stop exit. |
| `strategy_middle_exit` | true | true / false | Enables the middle-band touch exit. |
| `strategy_sma200_trend_block` | false | true / false | Optional SMA(200) trend block from the card sweep notes. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` — do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — card-listed DWX major FX symbol with H1 OHLC, Bollinger Bands, and ATR available.
- `GBPUSD.DWX` — card-listed DWX major FX symbol with H1 OHLC, Bollinger Bands, and ATR available.
- `USDJPY.DWX` — card-listed DWX major FX symbol with H1 OHLC, Bollinger Bands, and ATR available.
- `XAUUSD.DWX` — card-listed DWX metal symbol with H1 OHLC, Bollinger Bands, and ATR available.

**Explicitly NOT for:**
- `SPX500.DWX` — not present in `dwx_symbol_matrix.csv`.

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
| Trades / year / symbol | `65` |
| Typical hold time | `up to 8 H1 bars` |
| Expected drawdown profile | `mean-reversion losses cluster during persistent band walks` |
| Regime preference | `mean-revert` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** `MQL5 CodeBase`
**Pointer:** `https://www.mql5.com/en/code/17992`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10540_mql5-boll-rev.md`

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
| v1 | 2026-05-29 | Initial build from card | f6c66ce0-54aa-4dd0-987c-17fce5ef4f07 |
