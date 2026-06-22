# QM5_11737_rfs-adx-momentum-m5 - Strategy Spec

**EA ID:** QM5_11737
**Slug:** rfs-adx-momentum-m5
**Source:** b5a932a2-40b6-5628-840b-d5069ac35c4a (see `sources/rfs-robo-forex-strategy-compilation`)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades a M5 trend-following scalp on liquid FX pairs. A long entry is allowed when ADX(14) is above 25, DI+ is above 25 and greater than DI-, Momentum(14) is above 100, and the closed bar is above EMA(55) when the EMA filter is enabled. A short entry mirrors the rule with DI- dominance, Momentum(14) below 100, and the closed bar below EMA(55). Exits are the fixed 6-pip stop, 15-pip equivalent take profit, framework Friday close, or an opposite closed-bar signal before SL/TP.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_adx_period | 14 | 1+ | Period for ADX, DI+, and DI-. |
| strategy_adx_threshold | 25.0 | 0+ | Minimum ADX main value for trend strength. |
| strategy_di_threshold | 25.0 | 0+ | Minimum dominant DI value. |
| strategy_momentum_period | 14 | 1+ | Period for Momentum. |
| strategy_momentum_level | 100.0 | 0+ | Momentum threshold separating bullish from bearish state. |
| strategy_use_ema_filter | true | true/false | Enables the optional EMA trend-bias filter from the card. |
| strategy_ema_period | 55 | 1+ | EMA period for the optional bias filter. |
| strategy_sl_pips | 6 | 1+ | Fixed stop-loss distance in pips. |
| strategy_tp_rr | 2.5 | 0+ | Take-profit as an R multiple of the stop; 2.5R on 6 pips equals 15 pips. |
| strategy_max_spread_sl_pct | 25.0 | 0+ | Blocks only genuinely wide positive spreads above this percent of stop distance. |

Framework-level risk, news, Friday close, RNG, stress, and portfolio inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card target and liquid M5 FX major.
- GBPUSD.DWX - card target and liquid M5 FX major.
- AUDUSD.DWX - card target and liquid M5 FX major.
- USDCAD.DWX - card target and liquid M5 FX major.

**Explicitly NOT for:**
- Index, metals, energy, and non-card FX symbols - not named in the approved card's R3 portable target set for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework entry gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 250 |
| Expected trade frequency | frequent M5 trend-scalp entries when ADX/DI and momentum align |
| Typical hold time | intraday; generally minutes to a few hours due to 6-pip SL and 15-pip TP |
| Expected drawdown profile | many small fixed-risk losses in ranging markets, offset by larger 2.5R winners in trends |
| Regime preference | trend-following / momentum |
| Win rate target (qualitative) | medium-low, consistent with 2.5R payoff |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** b5a932a2-40b6-5628-840b-d5069ac35c4a
**Source type:** online compilation PDF
**Pointer:** Anonymous, "ADX and Momentum", Robo-forex Strategy Compilation, robofx.com, approximately 2015; source PDF `362359657-Robo-forex-strategy.pdf`, pages 19-20.
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11737_rfs-adx-momentum-m5.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-23 | Initial build from card | 3b900b00-702c-4778-9f95-debc9bd6c9aa |
