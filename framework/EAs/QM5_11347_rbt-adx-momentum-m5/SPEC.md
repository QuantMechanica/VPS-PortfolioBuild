# QM5_11347_rbt-adx-momentum-m5 - Strategy Spec

**EA ID:** QM5_11347
**Slug:** rbt-adx-momentum-m5
**Source:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

This EA trades an M5 trend scalp when ADX confirms a strong directional move and Momentum confirms price is on the same side of the 100 baseline. Long entries require ADX(14) above 25, +DI above 25 and above -DI, and Momentum(14) above 100; short entries mirror the rule with -DI and Momentum below 100. The optional EMA(55) filter requires current market price to be on the trend side of the closed-bar EMA when enabled. Exits are fixed 6-pip stop loss and fixed 15-pip take profit, with the framework Friday close still active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_adx_period | 14 | 10-21 P3 sweep stated | ADX and DI period. |
| strategy_adx_threshold | 25.0 | 20-30 P3 sweep stated | Minimum ADX and directional DI threshold. |
| strategy_momentum_period | 14 | 10-21 P3 sweep stated | Momentum period. |
| strategy_momentum_level | 100.0 | fixed by card | Momentum baseline for long above and short below. |
| strategy_ema55_filter | true | true/false | Enables the optional EMA(55) macro trend gate from the card. |
| strategy_ema_period | 55 | fixed by card | EMA period for the optional macro trend gate. |
| strategy_stop_pips | 6 | 5-7 card range midpoint | Fixed stop loss in pips. |
| strategy_take_pips | 15 | 14-16 card range midpoint | Fixed take profit in pips. |
| strategy_spread_cap_pips | 3 | fixed by card | Maximum live spread; zero modeled DWX spread is allowed. |
| strategy_session_start_gmt | 13 | fixed by card | GMT session start hour. |
| strategy_session_end_gmt | 22 | fixed by card | GMT session end hour, exclusive. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - card-listed liquid M5 major FX pair.
- GBPUSD.DWX - card-listed liquid M5 major FX pair.
- AUDUSD.DWX - card-listed liquid M5 major FX pair.
- USDCAD.DWX - card-listed liquid M5 major FX pair.

**Explicitly NOT for:**
- Unregistered `.DWX` symbols - this build registers only the card-listed FX basket.
- Non-DWX symbols - research and backtest artifacts must keep the `.DWX` suffix.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) through framework wiring |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 500 |
| Typical hold time | Intraday scalp; not explicit in frontmatter, inferred from M5 fixed 6-pip SL / 15-pip TP design. |
| Expected drawdown profile | Frequent small losses during non-trending or choppy sessions; bounded per trade by fixed 6-pip SL. |
| Regime preference | Trend-following momentum burst; inferred from frontmatter concepts and card mechanics. |
| Win rate target (qualitative) | Medium; fixed TP is larger than fixed SL. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ed246754-1f4d-5bed-8dd3-3b5cbf1b420d
**Source type:** institutional strategy PDF
**Pointer:** C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\362359657-Robo-forex-strategy.pdf
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11347_rbt-adx-momentum-m5.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-20 | Initial build from card | d50575d1-77fc-4415-a0f5-459bbf6c57d4 |
