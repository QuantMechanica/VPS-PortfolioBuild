# QM5_11731_tc-m5-s20-ema3-bb-macd — Strategy Spec

**EA ID:** QM5_11731
**Slug:** tc-m5-s20-ema3-bb-macd
**Source:** 40a4454c-64ff-5015-8538-9f7b32abc0e9
**Author of this spec:** Codex
**Last revised:** 2026-08-04

---

## 1. Strategy Logic

On the first tick after an M5 bar closes, the EA buys when EMA(3) has crossed above the Bollinger(20, 3) middle line and the MACD(12, 26, 9) main line crossed upward through zero during one of the last three closed bars. It sells on the mirrored downward conditions. Each trade uses a 12-pip stop and 12-pip take profit; an opposite EMA/Bollinger-middle cross closes the position early if it occurs first.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_period` | 3 | 3 (card-fixed) | EMA period used for the primary crossing signal. |
| `strategy_bb_period` | 20 | 20 (card-fixed) | Bollinger period whose middle line is the signal baseline. |
| `strategy_bb_deviation` | 3.0 | 3.0 (card-fixed) | Bollinger standard-deviation setting; required even though the middle line is traded. |
| `strategy_macd_fast` | 12 | 12 (card-fixed) | Fast EMA period in MACD. |
| `strategy_macd_slow` | 26 | 26 (card-fixed) | Slow EMA period in MACD. |
| `strategy_macd_signal` | 9 | 9 (card-fixed) | MACD signal period required by the indicator definition. |
| `strategy_macd_zero_window` | 3 | 3 (card-fixed) | Number of closed bars scanned for the confirming MACD zero-line cross. |
| `strategy_sl_pips` | 12 | 10–15 | Fixed stop-loss distance in scale-correct pips. |
| `strategy_tp_pips` | 12 | 10–15 | Fixed take-profit distance in scale-correct pips. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — liquid major FX pair named by the approved card.
- `GBPUSD.DWX` — liquid major FX pair named by the approved card.
- `USDJPY.DWX` — liquid major FX pair named by the approved card.
- `USDCHF.DWX` — liquid major FX pair named by the approved card.

**Explicitly NOT for:**

- Other FX, index, metal, energy, or crypto symbols — the approved card does not authorize expansion beyond the four listed major pairs.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M5 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the canonical skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | Approximately 250 |
| Expected trade frequency | Approximately one trade per trading day per symbol |
| Typical hold time | Not stated in the card; bounded by the 12-pip SL/TP or the next opposite closed-bar cross and expected to be intraday for an M5 scalp |
| Expected drawdown profile | Not quantified in the card; frequent symmetric 1R outcomes make losing streaks and commission drag visible quickly |
| Regime preference | Short-horizon EMA/SMA crossover momentum around the Bollinger middle line; no separate regime gate is authorized |
| Win rate target (qualitative) | Not stated in the card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 40a4454c-64ff-5015-8538-9f7b32abc0e9
**Source type:** book / local PDF
**Pointer:** Thomas Carter, *20 Forex Trading Strategies (5 Minute Time Frame)*, Strategy #20, 2013; `367145560-20-forex-trading-strategies-5-minute-time-frame-pdf.pdf`
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11731_tc-m5-s20-ema3-bb-macd.md`

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
| v1 | 2026-08-04 | Initial build from card | 1a17f439-b48e-46db-986b-2a3c62f8816c |

