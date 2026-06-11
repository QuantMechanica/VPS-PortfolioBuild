# QM5_12415_ger-2macdsto - Strategy Spec

**EA ID:** QM5_12415
**Slug:** ger-2macdsto
**Source:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233 (see approved strategy card)
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

The EA evaluates completed H3 bars. It opens long when the slow MACD is above zero on bar 2, the fast MACD is below zero on bar 2, and Stochastic has crossed upward from an oversold pullback between bars 2 and 1. It opens short when the slow MACD is below zero, the fast MACD is above zero, and Stochastic has crossed downward from an overbought pullback. Exits are by the initial swing stop, fixed 1R take profit, and framework Friday close; there is no discretionary signal-close rule in the card.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| m1_fast | 13 | 8, 13, 21 | Fast MACD fast EMA period. |
| m1_slow | 21 | 21, 34 | Fast MACD slow EMA period. |
| m2_fast | 34 | 21, 34, 55 | Slow MACD fast EMA period. |
| m2_slow | 144 | 89, 144, 200 | Slow MACD slow EMA period. |
| macd_signal_period | 1 | fixed by source | Signal period for both MACD readers. |
| sto_k | 7 | 5, 7, 10 | Stochastic K period. |
| sto_d | 3 | fixed by source | Stochastic D period. |
| sto_slowing | 3 | fixed by source | Stochastic slowing period. |
| sto_oversold | 20.0 | fixed by source | Long pullback threshold. |
| sto_overbought | 80.0 | fixed by source | Short pullback threshold. |
| swing_lookback_bars | 7 | fixed by source | Closed-bar swing window used for stop placement. |
| swing_deviation_points | 60 | fixed by source | Extra stop offset in symbol points beyond the swing. |
| tp_rr | 1.0 | fixed by source | Take profit multiple of entry-to-stop risk. |

Note: framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- NZDUSD.DWX - primary source symbol and DWX forex custom symbol.
- AUDUSD.DWX - R3-approved portable FX symbol with the same indicator mechanics.
- EURUSD.DWX - R3-approved portable FX symbol with the same indicator mechanics.

**Explicitly NOT for:**
- Non-FX index, metal, and energy symbols - the card's R3 basket names only FX pairs.
- FX symbols outside the approved R3 basket - not registered for this EA in Q01.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H3 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (framework default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Typical hold time | Not specified in card frontmatter; expected multi-bar H3 holds until 1R TP or swing SL. |
| Expected drawdown profile | Fixed-risk FX momentum-pullback profile; drawdown driven by failed pullbacks in trend shifts. |
| Regime preference | Trend-pullback with momentum filter. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 041e0d5c-bf76-501d-bee2-31c0f4a6e233
**Source type:** code
**Pointer:** Geraked / Rabist, `2MACDSTO.mq5`, GitHub repository, source location `Experts/2MACDSTO.mq5`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12415_ger-2macdsto.md`

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
| v1 | 2026-06-11 | Initial build from card | cd6c3f54-8a47-4ebd-aa7d-16fc544d1e58 |
