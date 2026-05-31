# QM5_10581_mql5-lr-slope - Strategy Spec

**EA ID:** QM5_10581
**Slug:** mql5-lr-slope
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see `strategy-seeds/sources/b8b5125a-c67f-5bbc-baff-33456e08f5b2/`)
**Author of this spec:** Codex
**Last revised:** 2026-05-29

---

## 1. Strategy Logic

The EA trades closed-bar crosses between a linear-regression-slope oscillator and its signal average. A long signal occurs when the latest closed bar's slope crosses above the signal line; a short signal occurs when it crosses below. Existing positions are closed on the opposite closed-bar cross, while hard stop, target, Friday close, news exits, and kill-switch handling remain in the V5 framework. The P2 baseline uses ATR(14) 2.0 stop distance and 1.5R target.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_lr_period` | 25 | >=2 | Number of closed bars used in the linear regression slope calculation. |
| `strategy_signal_period` | 9 | >=1 | SMA length applied to the slope oscillator as the signal line. |
| `strategy_atr_period` | 14 | >=1 | ATR period for hard stop sizing. |
| `strategy_atr_sl_mult` | 2.0 | >0 | ATR multiplier for the hard stop. |
| `strategy_take_profit_rr` | 1.5 | >0 | Reward-to-risk target multiple. |
| `strategy_max_spread_points` | 40 | >=0 | Spread ceiling in points; zero disables the spread filter. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not re-documented here.

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - Card primary/source-test style FX market and DWX-available.
- `EURUSD.DWX` - Liquid major FX pair suitable for portable OHLC oscillator logic.
- `GBPJPY.DWX` - Cross FX pair included in the card's portable P2 basket.
- `XAUUSD.DWX` - DWX metal symbol included in the card's portable P2 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not available for DWX backtest registration.

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
| Trades / year / symbol | 40 |
| Typical hold time | H4 closed-bar oscillator holds; hours to days depending on cross cadence |
| Expected drawdown profile | Fixed ATR stop and 1.5R target should bound individual trade loss while allowing oscillator reversals. |
| Regime preference | Linear-regression-slope momentum and trend-turn regimes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase EA
**Pointer:** https://www.mql5.com/en/code/14009
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_10581_mql5-lr-slope.md`

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
| v1 | 2026-05-29 | Initial build from card | 700cd1a2-0074-48f7-a3fa-52c034a4bf34 |
