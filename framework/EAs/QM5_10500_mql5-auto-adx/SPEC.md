# QM5_10500_mql5-auto-adx - Strategy Spec

**EA ID:** QM5_10500
**Slug:** mql5-auto-adx
**Source:** b8b5125a-c67f-5bbc-baff-33456e08f5b2 (see MQL5 CodeBase citation in approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

This EA trades the H1 ADX trend-state rule from the approved Auto ADX card. On each new closed bar it opens long when +DI(14) is above -DI(14), ADX(14) is above 30, and ADX is rising versus the prior closed bar. It opens short when +DI(14) is below -DI(14), ADX(14) is below 30, and ADX is falling versus the prior closed bar. If reverse close is enabled, an open long closes when DI reverses or ADX stops rising, and an open short closes when DI reverses or ADX starts rising.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_adx_period | 14 | >= 2 | ADX and DI smoothing period. |
| strategy_adx_level | 30.0 | > 0 | ADX threshold from the source/default card rule. |
| strategy_atr_period | 14 | >= 1 | ATR period for the P2 baseline hard stop. |
| strategy_atr_sl_mult | 1.5 | > 0 | ATR multiple used for the stop loss. |
| strategy_rr_target | 2.0 | > 0 | Take-profit distance as a multiple of initial risk. |
| strategy_reverse_close | true | true/false | Enables the card's reverse DI/ADX discretionary close. |

> Note: framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*)
> are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - primary FX pair named in the card's R3 P2 basket.
- GBPUSD.DWX - FX pair named in the card's R3 P2 basket.
- USDCAD.DWX - FX pair named in the card's R3 P2 basket.
- USDJPY.DWX - FX pair named in the card's R3 P2 basket.

**Explicitly NOT for:**
- Non-DWX symbols - V5 build and backtest artifacts must use broker/custom `.DWX` symbols only.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Not specified in card frontmatter; governed by reverse DI/ADX close, 1.5x ATR stop, 2.0R target, and Friday close. |
| Expected drawdown profile | Trend-state FX system with fixed per-trade risk and ATR-normalized stops. |
| Regime preference | ADX/DI trend-state movement. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b8b5125a-c67f-5bbc-baff-33456e08f5b2
**Source type:** MQL5 CodeBase strategy source
**Pointer:** https://www.mql5.com/en/code/21299 and `artifacts/cards_approved/QM5_10500_mql5-auto-adx.md`
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10500_mql5-auto-adx.md`

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
| v1 | 2026-06-13 | Initial build from card | b7d458b3-9b67-4cba-aa45-c7b9e084dc0a |

