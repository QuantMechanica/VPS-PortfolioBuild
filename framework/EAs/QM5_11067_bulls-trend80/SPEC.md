# QM5_11067_bulls-trend80 - Strategy Spec

**EA ID:** QM5_11067
**Slug:** bulls-trend80
**Source:** 429e4612-2e1d-57be-b12e-ff8b94d42117 (see approved card frontmatter)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

The EA trades EURUSD.DWX on M5 using Bulls Power, defined as the closed-bar high minus EMA(close, 13). A long signal requires Bulls Power to rise versus the value three bars earlier, the Bulls Power z-score to be above the magnitude threshold, and the close to be above EMA(13). A short signal uses the opposite slope, z-score, and EMA-position tests. Entries are market orders on the next bar after signal close, with fixed 40-pip stop loss and fixed 80-pip take profit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_ema_period | 13 | 2-200 | EMA(close) period used in Bulls Power. |
| strategy_slope_lookback | 3 | 1-50 | Bars between current closed Bulls Power and comparison value. |
| strategy_z_lookback | 96 | 10-500 | Closed bars used to estimate Bulls Power standard deviation. |
| strategy_slope_thresh | 0.0 | 0.0+ | Minimum Bulls Power slope magnitude in price units. |
| strategy_magnitude_thresh | 1.0 | 0.0+ | Minimum absolute Bulls Power z-score for entry. |
| strategy_sl_pips | 40 | 1-500 | Fixed broker stop loss in pips. |
| strategy_tp_pips | 80 | 1-1000 | Fixed broker take profit in pips. |
| strategy_atr_period | 14 | 2-200 | ATR period for the liquidity/noise floor. |
| strategy_atr_floor_pips | 5 | 0+ | Minimum ATR value in pips required for entry. |
| strategy_spread_pct_of_stop | 25.0 | 0.0+ | Maximum modeled spread as a percent of stop distance. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - the card maps EURUSD directly to EURUSD.DWX in R3.

**Explicitly NOT for:**
- Index and commodity `.DWX` symbols - the approved R3 row names only EURUSD.DWX.
- Other forex `.DWX` symbols - not included in the card's R3 portable basket.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none in baseline; H1 confirmation is left for sweep variants |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 180 |
| Typical hold time | Intraday; fixed SL/TP bracket on M5 signals |
| Expected drawdown profile | Trend/momentum system with fixed 2:1 reward-to-risk and EURUSD noise-floor filter |
| Regime preference | trend / oscillator-momentum |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 429e4612-2e1d-57be-b12e-ff8b94d42117
**Source type:** MQL5 article interview
**Pointer:** https://www.mql5.com/en/articles/537 and `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11067_bulls-trend80.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11067_bulls-trend80.md`

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
| v1 | 2026-06-23 | Initial build from card | 7243a67c-cbe0-4530-9c86-bb7363c11fbe |
