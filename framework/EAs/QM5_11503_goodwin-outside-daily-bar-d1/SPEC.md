# QM5_11503_goodwin-outside-daily-bar-d1 — Strategy Spec

**EA ID:** QM5_11503
**Slug:** `goodwin-outside-daily-bar-d1`
**Source:** `2a126283-6905-5bb7-903a-cccd5f2b533f`
**Author of this spec:** Codex
**Last revised:** 2026-08-03

---

## 1. Strategy Logic

On each new D1 bar, the EA checks whether the last closed daily bar made a higher high and a lower low than the preceding bar. It buys when that outside bar closed below the preceding low, and sells when it closed above the preceding high, entering at the next bar's market open. Each trade uses a 200-pip stop and a 400-pip target by default; the card-authorized alternative removes the target and exits at the next D1 bar, while every trade has a five-D1-bar maximum hold. New Friday entries and spreads above 30 pips are blocked.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_sl_pips` | 200 | 1–200 pips | Fixed stop distance; 200 pips is the source-specified EURUSD D1 value and P2 cap. |
| `strategy_tp_pips` | 400 | 200–600 pips | Fixed target distance represented as an R multiple of the stop; supports the card's P3 target sweep. |
| `strategy_next_bar_exit` | false | true / false | When true, omit the fixed target and close after one completed D1 holding bar. |
| `strategy_max_hold_bars` | 5 | 1–20 D1 bars | Fallback maximum holding period when SL/TP has not closed the position. |
| `strategy_require_body_engulf` | false | true / false | Optional P3 variant requiring the outside bar's candle body to engulf the prior body. |
| `strategy_use_sma200_filter` | false | true / false | Optional P3 variant requiring longs above and shorts below the closed-bar D1 SMA(200). |
| `strategy_spread_cap_pips` | 30 | 1–30 pips | Blocks only a genuinely positive modeled spread above the card's cap; zero-spread DWX ticks remain eligible. |

Framework-level risk, news, Friday-close, seed, stress, and portfolio inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — source-specified liquid FX pair for which the 200-pip D1 stop was stated.
- `GBPUSD.DWX` — card-authorized liquid major-FX expansion using the same daily price-action rule.
- `AUDUSD.DWX` — card-authorized liquid major-FX expansion using the same daily price-action rule.

**Explicitly NOT for:**

- Non-FX `.DWX` symbols — the source's fixed 200-pip stop and 30-pip spread cap are calibrated to FX rather than index, metal, or energy price scales.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` on a D1 chart; the entry hook rejects any other chart period |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 30 |
| Trade frequency | approximately 2–3 entries per month per symbol |
| Typical hold time | 1–5 D1 trading bars |
| Expected drawdown profile | Counter-trend entries can cluster losses during persistent directional moves; each loss remains bounded by the fixed-risk 200-pip stop. |
| Regime preference | Mean-reverting or exhaustion-reversal conditions after unusually wide daily ranges. |
| Win rate target (qualitative) | medium; the default 2:1 reward/risk does not require a high hit rate |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `2a126283-6905-5bb7-903a-cccd5f2b533f`
**Source type:** self-published strategy guidebook
**Pointer:** local source record `sources/goodwin-beat-the-markets-strategy-guidebook`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11503_goodwin-outside-daily-bar-d1.md`.

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
| v1 | 2026-08-03 | Initial build from card | `774e82a8-5a7d-4d93-a62f-c55b60da117f` |
