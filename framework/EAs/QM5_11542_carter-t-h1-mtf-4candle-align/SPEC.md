# QM5_11542_carter-t-h1-mtf-4candle-align — Strategy Spec

**EA ID:** QM5_11542
**Slug:** carter-t-h1-mtf-4candle-align
**Source:** 3001a121-97a0-5db0-b6ff-69b89a0fc07d (see `[[sources/carter-thomas-20-forex-strategies-1h]]`)
**Author of this spec:** Codex
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

After each H1 bar closes, the EA reads the latest closed M5, M15, M30 and H1 candles. When the required number of those candles all close in the same direction, it places a one-hour pending stop order three pips beyond the H1 close in that direction. Each order uses a fixed 20-pip stop loss and 35-pip take profit; there is no discretionary exit or active trade management beyond the framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_breakout_pips` | 3 | 1, 3, or 5 | Pending-stop distance from the last closed H1 price. |
| `strategy_required_aligned_tfs` | 4 | 3–4 | Number of M5, M15, M30 and H1 candles that must share one direction. |
| `strategy_sl_pips` | 20 | 15–20 | Fixed stop-loss distance. |
| `strategy_tp_pips` | 35 | 25, 35, or 50 | Fixed take-profit distance. |
| `strategy_spread_cap_pips` | 15 | 15 (card-fixed) | Reject a new entry only when the positive modeled spread is wider than this cap. |
| `strategy_no_friday_entry` | true | true (card-fixed) | Prevent new pending orders on Friday broker time. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

---

## 3. Symbol Universe

**Designed for:**

- `EURUSD.DWX` — approved-card R3 coverage includes all four required intraday timeframes.
- `GBPUSD.DWX` — approved-card R3 coverage includes all four required intraday timeframes.

**Explicitly NOT for:**

- All other symbols — the approved card names only EURUSD.DWX and GBPUSD.DWX.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | Closed M5, M15, M30 and H1 candles at shift 1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Typical hold time | Not specified by the card; held until 20-pip SL, 35-pip TP, expiry before fill, or framework Friday close. |
| Expected drawdown profile | Not specified by the approved card. |
| Regime preference | Intraday momentum / breakout, inferred directly from the four-timeframe direction alignment and stop entry. |
| Win rate target (qualitative) | Not specified by the approved card. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3001a121-97a0-5db0-b6ff-69b89a0fc07d
**Source type:** Self-published book
**Pointer:** `[[sources/carter-thomas-20-forex-strategies-1h]]`; Thomas Carter, *20 Forex Trading Strategies (1 Hour Time Frame)*, System #16 (2014)
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_11542_carter-t-h1-mtf-4candle-align.md`.

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
| v1 | 2026-08-10 | Initial build from card | ad642307-bb5f-4a9d-921d-8528d9edd326 |

