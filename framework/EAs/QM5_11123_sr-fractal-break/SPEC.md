# QM5_11123_sr-fractal-break - Strategy Spec

**EA ID:** QM5_11123
**Slug:** sr-fractal-break
**Source:** 0693c604-4f96-56ef-be79-15efe9f48b86 (see `sources/earnforex-github`)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA tracks the most recent confirmed five-bar resistance fractal and support fractal on H4. It opens long when the last completed close moves above the current resistance level while the prior completed close was at or below that same resistance. It opens short when the last completed close moves below the current support level while the prior completed close was at or above that same support. Long positions close if price closes back below the broken resistance, an opposite support break appears, or 16 H4 bars pass; shorts use the symmetric support/resistance rules.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_fractal_lookback_bars | 160 | 5-500 | Maximum closed bars scanned for the latest confirmed support and resistance fractals. |
| strategy_atr_period | 14 | 1-100 | ATR period used for stop distance. |
| strategy_atr_sl_mult | 1.5 | 0.1-10.0 | Stop distance multiplier applied to ATR(14) from the broken source level. |
| strategy_max_hold_bars | 16 | 1-200 | Maximum holding period in H4 bars. |
| strategy_breakout_atr_min_mult | 0.0 | 0.0-5.0 | Optional P3 close-distance requirement beyond the source level, expressed as ATR multiple; 0.0 keeps the P2 baseline off. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - liquid major FX pair with native DWX OHLC history suitable for fractal support/resistance events.
- GBPUSD.DWX - liquid major FX pair from the approved R3 basket.
- USDJPY.DWX - liquid major FX pair from the approved R3 basket.
- XAUUSD.DWX - liquid metal symbol from the approved R3 basket with OHLC data for fractals and ATR.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - the broker/tester data universe does not support them.
- Single-stock or sector symbols - the card approves only the R3 basket above.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 45 |
| Typical hold time | Up to 16 H4 bars, usually hours to a few days. |
| Expected drawdown profile | Breakout strategy with clustered losses around failed support/resistance breaks. |
| Regime preference | breakout / volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 0693c604-4f96-56ef-be79-15efe9f48b86
**Source type:** GitHub repository / public indicator source
**Pointer:** EarnForex Support-and-Resistance source, `Support and Resistance.mq5`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11123_sr-fractal-break.md`

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
| v1 | 2026-06-07 | Initial build from card | b10099c9-3177-43d0-8c84-ec336d275396 |
