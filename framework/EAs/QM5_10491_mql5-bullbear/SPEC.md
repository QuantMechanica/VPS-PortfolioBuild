# QM5_10491_mql5-bullbear - Strategy Spec

**EA ID:** QM5_10491
**Slug:** `mql5-bullbear`
**Source:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2` (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades the MQL5 MySystem Bulls/Bears Power slope rule on closed M15 bars. It computes Bulls Power as high minus EMA(close) and Bears Power as low minus EMA(close), then averages the two values for the latest closed bar and the previous closed bar. It opens long when the average rises while still below zero, and opens short when the average falls while still above zero. It exits on the opposite average signal, at a 1.5 x ATR(14) protective stop, at a 2.0R target, or after 64 M15 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bullbear_period` | 13 | 2-100 | EMA period used by the Bulls Power and Bears Power formula. |
| `strategy_atr_period` | 14 | 1-100 | ATR period for the protective stop. |
| `strategy_atr_sl_mult` | 1.5 | 0.1-10.0 | ATR multiplier for the protective stop. |
| `strategy_tp_rr` | 2.0 | 0.1-10.0 | Take-profit multiple of the initial stop risk. |
| `strategy_max_hold_bars` | 64 | 1-1000 | Maximum M15 bars to hold a position. |
| `strategy_max_spread_points` | 30 | 0-10000 | Maximum allowed spread in broker points; 0 disables the strategy spread gate. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary source example is EURUSD M15 and the indicator is OHLC-derived.
- `GBPUSD.DWX` - liquid FX major with the same M15 OHLC data requirements.
- `USDJPY.DWX` - liquid FX major with the same M15 OHLC data requirements.
- `XAUUSD.DWX` - liquid metal symbol in the approved R3 portable basket.

**Explicitly NOT for:**
- Symbols outside `dwx_symbol_matrix.csv` - the build registers only the approved DWX basket from the card.

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
| Trades / year / symbol | `100` |
| Typical hold time | Up to 64 M15 bars, with earlier opposite-signal or SL/TP exits. |
| Expected drawdown profile | Oscillator slope entries with fixed ATR risk should have clustered losses in choppy regimes. |
| Regime preference | Momentum-slope reversal/continuation around the zero line. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `b8b5125a-c67f-5bbc-baff-33456e08f5b2`
**Source type:** MQL5 CodeBase
**Pointer:** Collector idea, Vladimir Karputov code, "MySystem", MQL5 CodeBase, published 2018-10-25, https://www.mql5.com/en/code/22016
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10491_mql5-bullbear.md`

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
| v1 | 2026-05-28 | Initial build from card | ea16e0eb-a63d-446a-b6af-2710cb996ba2 |
