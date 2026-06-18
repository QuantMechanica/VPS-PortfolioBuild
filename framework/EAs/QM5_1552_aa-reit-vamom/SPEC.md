# QM5_1552_aa-reit-vamom - Strategy Spec

**EA ID:** QM5_1552
**Slug:** aa-reit-vamom
**Source:** ede348b4-0fa7-5be1-baa8-09e9089b67b7 (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Once per new calendar month, the EA ranks the registered equity-index proxy basket by 12-month daily return divided by realized daily volatility over the same window. The baseline selects the top three ranked symbols, but only enters a long position for a selected symbol when that symbol's own 12-month return is positive. Positions are closed on the monthly rebalance when the symbol drops out of the top three or its 12-month return turns non-positive. The initial stop is 3.0 times ATR(20) on D1; there is no fixed profit target or intra-month trailing rule.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_momentum_days` | 260 | 126-300 | D1 bars used for the 12-month return proxy. |
| `strategy_volatility_days` | 260 | 126-300 | D1 bars used for realized-volatility denominator. |
| `strategy_top_n` | 3 | 1-5 | Number of highest-scoring symbols selected in the baseline. |
| `strategy_min_daily_bars` | 260 | 260+ | Minimum D1 bars required before ranking a symbol. |
| `strategy_atr_period` | 20 | 5-60 | D1 ATR period used for the initial stop. |
| `strategy_atr_sl_mult` | 3.0 | 1.0-6.0 | ATR multiple for the initial stop loss. |
| `strategy_max_spread_points` | 0.0 | 0+ | Optional extra spread cap; 0 disables the strategy-level cap. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` - do NOT re-document
> them here. Only list strategy-specific inputs.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 proxy for the US country/region sleeve; valid backtest-only custom symbol.
- `NDX.DWX` - Nasdaq 100 proxy for liquid US growth equity exposure.
- `WS30.DWX` - Dow 30 proxy for liquid US large-cap equity exposure.
- `GDAXI.DWX` - DAX proxy for Germany/continental Europe country risk.
- `UK100.DWX` - FTSE 100 proxy for UK country risk.

**Explicitly NOT for:**
- `FCHI.DWX` - named in the card universe but absent from `dwx_symbol_matrix.csv`.
- `JPN225.DWX` - named in the card universe but absent from `dwx_symbol_matrix.csv`.
- Non-index forex and commodity symbols - the source concept is country REIT/index rotation, not FX or commodities.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_D1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `100` |
| Typical hold time | days to months; revalidated monthly |
| Expected drawdown profile | trend-following sleeve with ATR catastrophic stops and rotation exits |
| Regime preference | cross-sectional momentum with positive trend |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ede348b4-0fa7-5be1-baa8-09e9089b67b7
**Source type:** blog / academic paper summary
**Pointer:** Wesley Gray, PhD, "Trend Following and Momentum Strategies for Global REITs", 2015-11-20, https://alphaarchitect.com/trend-following-momentum-strategies-global-reits/
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1552_aa-reit-vamom.md`

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
| v1 | 2026-06-18 | Initial build from card | 093f8f3a-04f9-4434-8422-70c4e4dcd4de |
