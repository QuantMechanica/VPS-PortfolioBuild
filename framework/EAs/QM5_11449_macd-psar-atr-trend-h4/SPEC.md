# QM5_11449_macd-psar-atr-trend-h4 — Strategy Spec

**EA ID:** QM5_11449
**Slug:** `macd-psar-atr-trend-h4`
**Source:** `f66dfd8d-c60a-59be-b542-a70b8b41c17a`
**Author of this spec:** Codex
**Last revised:** 2026-08-02

---

## 1. Strategy Logic

On each new H4 bar, the EA buys when the closed MACD main buffer is positive and either crossed above zero or crossed above its signal line, provided the Parabolic SAR dot is below that bar's low. It sells under the mirrored conditions: negative MACD with a fresh zero or signal-line cross and a Parabolic SAR dot above the bar's high. The P2 implementation opens one unit with a 1.5× ATR(14) stop capped at 100 pips and a 2× ATR(14) target; there are no partial exits or strategy-level trailing rules.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_macd_fast` | 12 | 8, 12, or 19 | Fast EMA period in MACD. |
| `strategy_macd_slow` | 26 | 17, 26, or 39 | Slow EMA period in MACD. |
| `strategy_macd_signal` | 9 | fixed | MACD signal-line period. |
| `strategy_psar_step` | 0.02 | 0.01, 0.02, or 0.03 | Parabolic SAR acceleration step. |
| `strategy_psar_maximum` | 0.20 | fixed | Parabolic SAR maximum acceleration. |
| `strategy_atr_period` | 14 | fixed | Closed-bar ATR period used for stop and target distances. |
| `strategy_atr_sl_mult` | 1.50 | fixed for P2 | Stop distance as a multiple of ATR(14). |
| `strategy_atr_tp_mult` | 2.00 | 1.5, 2.0, or 3.0 | Profit-target distance as a multiple of ATR(14). |
| `strategy_sl_cap_pips` | 100 | fixed | Maximum P2 stop distance, converted from pips by the framework. |
| `strategy_spread_cap_pips` | 20 | fixed | Blocks a genuinely positive spread above 20 pips; zero tester spread passes. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid major FX pair explicitly listed by the approved card.
- `GBPUSD.DWX` — liquid major FX pair explicitly listed by the approved card.
- `USDJPY.DWX` — liquid major FX pair explicitly listed by the approved card.
- `AUDUSD.DWX` — liquid major FX pair explicitly listed by the approved card.
- `USDCAD.DWX` — liquid major FX pair explicitly listed by the approved card.

**Explicitly NOT for:**

- Non-FX instruments — the approved card limits this baseline to the five named major FX symbols.
- FX pairs outside the list above — they were not authorized in the card's instrument universe.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` from the canonical skeleton; P2 setfiles run H4 |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 35 |
| Expected trade frequency | About three trades per month per symbol, derived from the card's annual estimate. |
| Typical hold time | Multiple H4 bars, ending at the ATR stop/target or framework Friday close. |
| Expected drawdown profile | Losses may cluster when sideways price action repeatedly reverses momentum shifts. |
| Regime preference | H4 trend-following and momentum expansion. |
| Win rate target (qualitative) | Not specified by the card; Q02 evidence is required. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `f66dfd8d-c60a-59be-b542-a70b8b41c17a`
**Source type:** anonymous online PDF
**Pointer:** `D:\QM\strategy_farm\artifacts\source_notes\f66dfd8d-c60a-59be-b542-a70b8b41c17a.md` and `640322690-MACD-Trender-Forex-Trading-Strategy.pdf`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11449_macd-psar-atr-trend-h4.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-02 | Initial build from card | 68e39098-cf8b-4c82-b32e-38d8cd8e367e |
