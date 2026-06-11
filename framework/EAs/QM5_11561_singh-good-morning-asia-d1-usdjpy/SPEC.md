# QM5_11561_singh-good-morning-asia-d1-usdjpy - Strategy Spec

**EA ID:** QM5_11561
**Slug:** `singh-good-morning-asia-d1-usdjpy`
**Source:** `a655746e-8011-56d9-8d9b-0020a8a2ae89` (see `sources/singh-mario-17-proven-currency-trading-strategies`)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA trades USDJPY.DWX on D1. On the first tick of each new D1 bar, it reads the prior completed D1 candle: if that candle closed above its open, it buys; if it closed below its open, it sells. The stop is based on the prior day's low for longs or high for shorts, with a 30 pip minimum distance and an 80 pip P2 cap. The take-profit is placed at 0.5 times the stop distance on the profit side; there is no discretionary close beyond SL, TP, and the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_min_sl_pips` | 30 | 1-200 | Minimum stop distance in pips when the prior-day structure is closer than the floor. |
| `strategy_max_sl_pips` | 80 | 30-300 | Maximum stop distance in pips for the P2-capped build. |
| `strategy_tp_ratio` | 0.5 | 0.1-3.0 | Take-profit distance as a multiple of the final stop distance. |
| `strategy_spread_cap_pips` | 15.0 | 0.0-50.0 | Blocks new entries when spread is above this pip threshold. |
| `strategy_skip_friday_entry` | true | true/false | Blocks Friday entries while still leaving framework Friday-close handling enabled. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - the source strategy is explicitly USDJPY-only and R3 PASS names D1 USDJPY.DWX.

**Explicitly NOT for:**
- Other forex `.DWX` symbols - the card does not authorize portability beyond USDJPY.
- Index, metal, energy, or crypto `.DWX` symbols - the source edge is a USDJPY Asian-session continuation pattern.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default framework gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | Intraday to several days, depending on whether the 0.5R TP or SL is reached first. |
| Expected drawdown profile | Frequent fixed-risk daily entries with capped D1 stop distance; drawdown comes from clusters of failed continuation days. |
| Regime preference | Momentum continuation after a directional prior USDJPY day. |
| Win rate target (qualitative) | High, because the source accepts 0.5:1 reward-to-risk. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `a655746e-8011-56d9-8d9b-0020a8a2ae89`
**Source type:** book
**Pointer:** Mario Singh, "17 Proven Currency Trading Strategies", Strategy #17 "Good Morning Asia"
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11561_singh-good-morning-asia-d1-usdjpy.md`

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
| v1 | 2026-06-11 | Initial build from card | 6d016973-7f66-4d50-a56c-eafb6b0e79c8 |
