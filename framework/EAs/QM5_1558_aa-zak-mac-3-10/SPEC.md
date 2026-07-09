# QM5_1558_aa-zak-mac-3-10 - Strategy Spec

**EA ID:** QM5_1558
**Slug:** `aa-zak-mac-3-10`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic

This EA implements the monthly Zakamulin moving-average-crossover rule from the approved card. It is long-only and otherwise sits in cash.

On each new D1 bar the EA rebuilds the completed monthly price series from completed D1 bars, because the `.DWX` custom-symbol tester path does not reliably expose native monthly bars. It calculates SMA(3) and SMA(10) on completed monthly closes. A long entry is allowed when SMA(3) is greater than SMA(10), at least 11 completed months are available, no position already exists for the symbol and magic number, and the dead-range filter is satisfied. The dead-range filter requires monthly ATR(6) to be at least 50% of the median monthly ATR over the prior 36 months.

The EA exits the open long when the completed-month signal turns bearish, meaning SMA(3) is less than or equal to SMA(10). Each new trade also receives an initial catastrophic stop at 3.0 times ATR(20,D1). There is no take-profit and no short side.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_fast_sma_months` | 3 | 2-6 | Short monthly SMA lookback used in the crossover signal. |
| `strategy_slow_sma_months` | 10 | 7-18 | Long monthly SMA lookback used in the crossover signal. |
| `strategy_min_completed_months` | 11 | 10-60 | Minimum completed monthly bars required before signal evaluation. |
| `strategy_atr_period_d1` | 20 | 5-60 | D1 ATR period used for initial stop distance. |
| `strategy_atr_sl_mult` | 3.0 | 1.0-8.0 | Multiplier applied to ATR(20,D1) for the initial stop loss. |
| `strategy_use_dead_atr_filter` | true | true/false | Enables the monthly dead-range ATR filter before new entries. |
| `strategy_monthly_atr_period` | 6 | 3-18 | Monthly ATR period used by the dead-range filter. |
| `strategy_atr_median_months` | 36 | 12-84 | Median lookback for the monthly ATR baseline. |
| `strategy_min_atr_median_ratio` | 0.50 | 0.20-1.00 | Minimum monthly ATR to median ATR ratio required for entry. |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - original source illustration is S&P 500 trend timing; tester-only caveat remains from the approved card.
- `NDX.DWX` - liquid equity-index trend proxy for parallel validation.
- `WS30.DWX` - liquid equity-index trend proxy for parallel validation.
- `GDAXI.DWX` - non-US equity-index trend proxy for index diversity.
- `XAUUSD.DWX` - macro-sensitive metal with long-horizon trend behavior.
- `XTIUSD.DWX` - DWX crude-oil proxy used because `USOIL.DWX` is not available in the DWX matrix.
- `EURUSD.DWX` - major FX pair for instrument diversity.
- `GBPUSD.DWX` - major FX pair for instrument diversity.
- `USDJPY.DWX` - major FX pair for instrument diversity.

**Explicitly NOT for:**
- `USOIL.DWX` - excluded only because it is not present in `framework/registry/dwx_symbol_matrix.csv`; the build ports the card's oil sleeve to `XTIUSD.DWX`.
- Intraday-only or spread-only synthetic symbols - the rule depends on stable completed daily bars aggregated into monthly closes.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | Completed monthly bars aggregated from D1 OHLC; ATR(20) on D1 for stop distance. |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` with the backtest setfiles fixed to D1. |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | About 12 signal evaluations per year; actual entries are lower because the rule is monthly long/cash and does not pyramid. |
| Typical hold time | Weeks to months. |
| Expected drawdown profile | Trend-following equity curve with occasional large giveback before monthly exit or ATR stop. |
| Regime preference | Long-horizon trend continuation with sufficient monthly range. |
| Win rate target (qualitative) | Medium; payoff should come from larger winning trends rather than high turnover. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** blog
**Pointer:** Valeriy Zakamulin, "Trend-Following with Valeriy Zakamulin: Technical Trading Rules (Part 3)", Alpha Architect, 2017-08-11, https://alphaarchitect.com/trend-following-valeriy-zakamulin-technical-trading-rules-part-3/
**R1-R4 verdict (Q00):** all PASS; see `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1558_aa-zak-mac-3-10.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio, typically 0.3% - 0.5% |

ENV to mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-09 | Initial build from approved card | Build task `67ab1a3d-5baa-4191-a334-783a31a19f0b`; USOIL card sleeve ported to XTIUSD DWX proxy. |
