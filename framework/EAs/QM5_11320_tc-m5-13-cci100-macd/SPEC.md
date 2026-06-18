# QM5_11320_tc-m5-13-cci100-macd — Strategy Spec

**EA ID:** QM5_11320
**Slug:** `tc-m5-13-cci100-macd`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Short-horizon M5 momentum scalp from Thomas Carter's "5 Min Trading System #13".
The single trigger is a CCI(14) cross of a +/-100 level on the last closed bar:
LONG when CCI crosses up through +100 (`cci[2] <= +100 AND cci[1] > +100`),
SHORT when CCI crosses down through -100 (`cci[2] >= -100 AND cci[1] < -100`).
MACD(12,26,9) acts as a confirming STATE (not a second cross event, to avoid the
two-cross-same-bar zero-trade trap): LONG requires `macd_main[1] > macd_signal[1]`
with a rising histogram (`(main-signal)[1] > (main-signal)[2]`); SHORT requires the
mirror. MACD main may be negative — its sign is never gated. Exit is a fixed stop
(14 pips) and fixed target (8 pips baseline); no discretionary or trailing exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_cci_period` | 14 | 7-28 | CCI lookback period |
| `strategy_cci_level` | 100.0 | 75-125 | +/- level the CCI must cross (trigger event) |
| `strategy_macd_fast` | 12 | 8-16 | MACD fast EMA period |
| `strategy_macd_slow` | 26 | 20-34 | MACD slow EMA period |
| `strategy_macd_signal` | 9 | 5-12 | MACD signal SMA period |
| `strategy_sl_pips` | 14 | 12-15 | Stop-loss distance in pips |
| `strategy_tp_pips` | 8 | 7-12 | Take-profit distance in pips (baseline) |
| `strategy_spread_cap_points` | 15 | 5-30 | Block entry only if modeled spread exceeds this many points |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — source-named pair, 8-pip target; tightest spread major fits a small-target scalp.
- `GBPUSD.DWX` — source-named pair, 10-pip target in source; liquid major with CCI/MACD momentum bursts.
- `AUDUSD.DWX` — source-named target pair, 7-pip target; commodity-major with frequent M5 momentum swings.

**Explicitly NOT for:**
- Index / commodity `.DWX` symbols — the pip-scaled small targets are calibrated to FX-major tick sizes, not index points.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | `none` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~180` |
| Typical hold time | `minutes to a few hours` |
| Expected drawdown profile | `frequent small wins/losses; scalp-style shallow equity grind` |
| Regime preference | `momentum / volatility-expansion` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** `Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", 5 Min Trading System #13, page 32 (local PDF cited in card frontmatter)`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11320_tc-m5-13-cci100-macd.md`

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
| v1 | 2026-06-18 | Initial build from card | (central build step to record commit) |
