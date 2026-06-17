# QM5_1096_unger-donchian-channel-tf - Strategy Spec

**EA ID:** QM5_1096
**Slug:** unger-donchian-channel-tf
**Source:** eb97a148-0af9-5b9c-878c-25fb5dfa34f9 (see `sources/unger-robbins-cup`)
**Author of this spec:** Codex
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

This EA trades a D1 Donchian channel breakout. On each new closed bar, it compares the prior close with the channel made from the preceding 20 daily highs and lows. A close above the upper channel opens long, and a close below the lower channel opens short. Open trades exit on the opposite channel break or through the ATR-based stop and trailing logic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_donchian_period` | 20 | 1-500 | Number of completed daily bars used for the Donchian channel. |
| `strategy_atr_period` | 20 | 1-500 | ATR period for initial stop and trailing stop distance. |
| `strategy_atr_sl_mult` | 2.5 | >0 | ATR multiple for initial stop and trailing stop. |
| `strategy_vol_floor_ratio` | 0.004 | >=0 | Minimum ATR divided by close required for entry. |
| `strategy_spread_median_days` | 20 | 1-64 | Number of daily spread samples used for the median spread filter. |
| `strategy_spread_median_mult` | 2.0 | >0 | Maximum current spread as a multiple of median spread. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` - gold CFD with trend-following behaviour suited to Donchian breakouts.
- `XAGUSD.DWX` - silver CFD with similar metals trend and volatility profile.
- `XTIUSD.DWX` - crude oil CFD with persistent commodity trend regimes.
- `NDX.DWX` - Nasdaq 100 index CFD with strong equity-index momentum regimes.
- `WS30.DWX` - Dow 30 index CFD for diversified US large-cap exposure.
- `GDAXI.DWX` - DAX index CFD for European equity-index trend exposure.

**Explicitly NOT for:**
- `SP500.DWX` - not listed in the approved card universe for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 50 |
| Typical hold time | days to weeks |
| Expected drawdown profile | Trend-following losses are bounded by the initial ATR stop, with occasional extended drawdowns during range-bound markets. |
| Regime preference | trend / breakout / volatility-expansion |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** eb97a148-0af9-5b9c-878c-25fb5dfa34f9
**Source type:** article / book
**Pointer:** Unger Academy article and *The Unger Method* via `sources/unger-robbins-cup`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_1096_unger-donchian-channel-tf.md`

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
| v1 | 2026-06-17 | Initial build from card | a3e90991-1ab0-4971-b099-8a6294add9b4 |
