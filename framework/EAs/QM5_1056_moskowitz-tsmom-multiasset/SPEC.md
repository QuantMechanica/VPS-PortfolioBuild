# QM5_1056_moskowitz-tsmom-multiasset - Strategy Spec

**EA ID:** QM5_1056
**Slug:** moskowitz-tsmom-multiasset
**Source:** 7ede58dd-d184-5099-9d48-7a65de230853 (see `strategy-seeds/sources/7ede58dd-d184-5099-9d48-7a65de230853/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades a monthly time-series momentum rule on D1 bars. On the first tick after a month-end D1 candle closes, it compares the latest closed D1 close with the close 252 D1 bars earlier. It opens long when the 12-month return is positive and short when the 12-month return is negative. Existing positions are closed at each monthly rebalance and reopened if the signal remains non-zero, with a hard 4 x ATR(20) stop and no trailing or take-profit rule.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lookback_d1_bars` | 252 | 1-500 | D1 bars used for the trailing return sign. |
| `strategy_min_d1_bars` | 275 | 260-600 | Minimum D1 history required before signals are allowed. |
| `strategy_atr_period` | 20 | 1-100 | ATR period for the hard stop. |
| `strategy_atr_sl_mult` | 4.0 | 0.1-20.0 | ATR multiple used for the hard stop distance. |
| `strategy_spread_days` | 20 | 1-64 | D1 spread samples used for the median spread filter. |
| `strategy_spread_mult` | 3.0 | 0.1-20.0 | Maximum current spread as a multiple of median spread. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - FX major from the card universe.
- `GBPUSD.DWX` - FX major from the card universe.
- `USDJPY.DWX` - FX major from the card universe.
- `AUDUSD.DWX` - FX major from the card universe.
- `USDCAD.DWX` - FX major from the card universe.
- `XAUUSD.DWX` - gold exposure from the card universe.
- `XTIUSD.DWX` - matrix-listed WTI crude oil equivalent.
- `NDX.DWX` - Nasdaq 100 index exposure from the card universe.
- `WS30.DWX` - Dow 30 index exposure from the card universe.
- `GDAXI.DWX` - matrix-listed DAX equivalent for the card-stated German index sleeve.

**Explicitly NOT for:**
- `SP500.DWX` - explicitly excluded by the card.
- `GER40.DWX` - not present in `dwx_symbol_matrix.csv`; DAX exposure uses `GDAXI.DWX`.
- `WTI.DWX` - not present in `dwx_symbol_matrix.csv`; crude oil exposure uses `XTIUSD.DWX`.

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
| Trades / year / symbol | `12` |
| Typical hold time | about one month |
| Expected drawdown profile | trend-following drawdowns during choppy reversals, bounded by hard ATR stop |
| Regime preference | trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 7ede58dd-d184-5099-9d48-7a65de230853
**Source type:** paper / encyclopedia
**Pointer:** Quantpedia Time-Series Momentum Effect entry and Moskowitz, Ooi, Pedersen (2012), `artifacts/cards_approved/QM5_1056_moskowitz-tsmom-multiasset.md`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1056_moskowitz-tsmom-multiasset.md`

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
| v1 | 2026-06-13 | Initial build from card | 6f9753e2-4656-470b-ac06-e2fa2129465c |
