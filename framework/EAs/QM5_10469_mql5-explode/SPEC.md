# QM5_10469_mql5-explode - Strategy Spec

**EA ID:** QM5_10469
**Slug:** mql5-explode
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-28

---

## 1. Strategy Logic

The EA trades a closed candle whose high-low range is greater than the prior candle range multiplied by `strategy_ratio`. If that explosion candle closes above its open, the EA opens long on the next bar; if it closes below its open, the EA opens short on the next bar. The stop distance is the greater of the source 20-point stop, 1.0 x ATR(14), and the broker minimum stop distance. The take profit is placed at 2R, and an open position closes early when an opposite explosion signal appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ratio` | 1.6 | > 0 | Closed candle range must exceed prior range multiplied by this value. |
| `strategy_atr_period` | 14 | >= 1 | ATR period used for the normalized minimum stop distance. |
| `strategy_atr_sl_mult` | 1.0 | > 0 | ATR multiplier for the volatility stop floor. |
| `strategy_source_stop_points` | 20 | >= 1 | Source fixed stop in raw symbol points before ATR normalization. |
| `strategy_tp_r_multiple` | 2.0 | > 0 | Take-profit distance as an R multiple of the selected stop distance. |
| `strategy_close_opposite` | true | true/false | Close an open position when a reverse explosion candle appears. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major with DWX OHLC coverage.
- `GBPUSD.DWX` - liquid FX major with DWX OHLC coverage.
- `USDJPY.DWX` - liquid FX major with DWX OHLC coverage.
- `USDCHF.DWX` - liquid FX major with DWX OHLC coverage.
- `USDCAD.DWX` - liquid FX major with DWX OHLC coverage.
- `AUDUSD.DWX` - liquid FX major with DWX OHLC coverage.
- `NZDUSD.DWX` - liquid FX major with DWX OHLC coverage.
- `XAUUSD.DWX` - gold CFD named directly in the card's baseline universe.
- `XTIUSD.DWX` - available DWX oil CFD for the card's oil exposure.
- `SP500.DWX` - available S&P 500 custom symbol for index CFD exposure.
- `NDX.DWX` - available Nasdaq 100 index CFD exposure.
- `WS30.DWX` - available Dow 30 index CFD exposure.
- `GDAXI.DWX` - available DAX index CFD exposure.
- `UK100.DWX` - available FTSE 100 index CFD exposure.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - no verified DWX data source.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Typical hold time | hours to days |
| Expected drawdown profile | Momentum-breakout losses cluster in non-expanding ranges. |
| Regime preference | volatility-expansion / breakout |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase page
**Pointer:** `https://www.mql5.com/en/code/25009` and `artifacts/cards_approved/QM5_10469_mql5-explode.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10469_mql5-explode.md`

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
| v1 | 2026-05-28 | Initial build from card | d1307ccb-06c0-40cd-aa61-07a5c86e523e |
