# QM5_33001_kaufman-adaptive-moving-average-breakout — Strategy Spec

**EA ID:** QM5_33001
**Slug:** `kaufman-adaptive-moving-average-breakout`
**Source:** `kaufman-adaptive-moving-average-breakout-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

On each completed H4 bar, the EA computes Kaufman's Adaptive Moving Average
(KAMA) from the close series. The smoothing speed is set mechanically by the
10-bar Efficiency Ratio: absolute ten-bar price change divided by the sum of
the ten intervening absolute bar-to-bar changes. It buys when the close is
more than 0.50 ATR above KAMA and the Efficiency Ratio is at least 0.40; it
sells under the mirrored condition below KAMA.

The initial stop is one ATR beyond KAMA on the adverse side. KAMA then acts as
a one-way dynamic stop: the EA only tightens the stop toward the current KAMA
line. A completed-bar cross back through KAMA also closes the position. The
framework independently enforces one position per host magic, the daily loss
kill switch, Friday close, and the central news blackout.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_er_period` | 10 | 5–20 | Bars used for Kaufman's Efficiency Ratio. |
| `strategy_fast_period` | 2 | 2–5 | Fast smoothing-period constant in the KAMA formula. |
| `strategy_slow_period` | 30 | 20–50 | Slow smoothing-period constant in the KAMA formula. |
| `strategy_er_threshold` | 0.40 | 0.25–0.60 | Minimum Efficiency Ratio for a new entry. |
| `strategy_atr_period` | 14 | 10–30 | Closed-bar ATR period for entry distance, spread cap, and initial stop. |
| `strategy_entry_atr_mult` | 0.50 | 0.25–1.00 | Required close distance beyond KAMA, in ATR. |
| `strategy_initial_sl_atr_mult` | 1.00 | 0.50–2.00 | Initial stop distance beyond KAMA, in ATR. |
| `strategy_max_spread_atr_mult` | 1.80 | 1.00–3.00 | Maximum positive spread as a multiple of ATR. |

Framework inputs such as `RISK_FIXED`, `RISK_PERCENT`, news controls, stress
seed, and Friday close are defined in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — the primary liquid crude-oil trend carrier in the approved card.
- `SP500.DWX` — a liquid equity-index carrier for persistent macro trends.
- `EURUSD.DWX` — a liquid FX carrier that diversifies the commodity/index tests.

**Explicitly NOT for:**

- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — no governed Model-4 history contract exists for them.
- M1/M5 scalping hosts — the approved mechanic is an H4, low-frequency trend rule.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | one latched `QM_IsNewBar(_Symbol, PERIOD_H4)` call |
| Signal data | completed H4 bars only (`shift=1`) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 40 |
| Typical hold time | one to several days; potentially multiple weeks in persistent trends |
| Expected drawdown profile | card prior of roughly 15% per standalone sleeve before portfolio weighting |
| Regime preference | efficient directional trends; intentionally quiet in choppy regimes |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `kaufman-adaptive-moving-average-breakout-official-source`
**Source type:** book
**Pointer:** Perry J. Kaufman, *Smarter Trading: Improving Performance*, McGraw-Hill, 1995.
**R1–R4 verdict (Q00):** R1, R2, R3, and R4 PASS; see
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_33001_kaufman-adaptive-moving-average-breakout.md`.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV-to-mode validation is enforced by `QM_FrameworkInit`. This build creates
backtest setfiles only and does not authorize live use.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | Initial build from approved card | Farm build task `eb98d193-1ab9-4cb6-8d37-79431e7d4aa9` |
