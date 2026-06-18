# QM5_10090_mql5-harami-h1 - Strategy Spec

**EA ID:** QM5_10090
**Slug:** `mql5-harami-h1`
**Source:** `a120af9a-fb72-526c-bb80-d1d098a617b5` (see `strategy-seeds/sources/a120af9a-fb72-526c-bb80-d1d098a617b5/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

The EA evaluates completed H1 candles only. It buys when a bearish mother candle is followed by a bullish child candle whose body is fully inside the mother body, with the mother candle closing below the prior context close and RSI below 40. It sells on the inverse bearish Harami setup with RSI above 60. Positions have a 2.0 ATR(14) protective stop and no fixed take-profit; exits occur when RSI crosses back down through 70 or 30 for longs, or back up through 30 or 70 for shorts.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 1+ | RSI lookback used for entry confirmation and exit crosses. The card names RSI(1), while the DWX build invariant flags period 1 as degenerate. |
| `strategy_buy_rsi_max` | 40.0 | 0-100 | Maximum RSI value allowed for long entries. |
| `strategy_sell_rsi_min` | 60.0 | 0-100 | Minimum RSI value allowed for short entries. |
| `strategy_atr_period` | 14 | 1+ | ATR lookback for the protective stop. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiplier for the protective stop. |
| `strategy_context_bars` | 1 | 1-20 | Number of pre-mother bars used to define upward/downward context. |
| `strategy_min_mother_body_points` | 0.0 | 0+ | Optional minimum mother candle body size in points; 0 disables it. |
| `strategy_max_spread_points` | 0.0 | 0+ | Optional maximum spread in points; 0 disables it. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-stated liquid FX major with OHLC and RSI data in the DWX matrix.
- `GBPUSD.DWX` - card-stated liquid FX major with OHLC and RSI data in the DWX matrix.
- `USDJPY.DWX` - card-stated liquid FX major with OHLC and RSI data in the DWX matrix.
- `XAUUSD.DWX` - card-stated gold symbol with OHLC and RSI data in the DWX matrix.

**Explicitly NOT for:**
- Any `.DWX` symbol outside the four card-stated targets - no symbol-agnostic expansion was authorized.

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
| Trades / year / symbol | 80 |
| Expected trade frequency | Not separately specified in frontmatter; implied moderate H1 cadence from 80 trades/year/symbol. |
| Typical hold time | Not specified in frontmatter; RSI-cross exit implies hours to days. |
| Expected drawdown profile | Bounded by V5 fixed-risk stops in backtest. |
| Regime preference | Mean-reversion candlestick reversal after local upward/downward context. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `a120af9a-fb72-526c-bb80-d1d098a617b5`
**Source type:** article
**Pointer:** Artyom Trishkin, "Deconstructing examples of trading strategies in the client terminal", MQL5 Articles, 2025-02-13.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10090_mql5-harami-h1.md`

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
| v1 | 2026-06-09 | Initial build from card | c54aeb45-cbe3-4da0-8d2d-8fffe4f7ce6c |
| v2 | 2026-06-18 | Rebuild from card | ef57e38d-95c5-42ab-8133-f73926ccec80 |
