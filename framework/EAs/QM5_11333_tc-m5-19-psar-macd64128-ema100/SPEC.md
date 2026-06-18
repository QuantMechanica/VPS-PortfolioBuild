# QM5_11333_tc-m5-19-psar-macd64128-ema100 — Strategy Spec

**EA ID:** QM5_11333
**Slug:** `tc-m5-19-psar-macd64128-ema100`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see `strategy-seeds/sources/e78a9f1f-4e6a-563c-a080-915133d6ed28/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Thomas Carter "5 Minute Trading System #19" on M5. The macro trend is a STATE
read from price versus EMA(100); the MACD(64,128,9) sign is a second STATE (the
MACD line is a very-slow trend filter on M5 and may be negative — only its sign
matters); the Parabolic SAR(0.01,0.01) side relative to price is a third STATE.
A single fresh EVENT triggers entry: EITHER the PSAR flips to the trade side on
the just-closed bar, OR the MACD main line crosses zero on the just-closed bar.
Requiring both a fresh PSAR flip and a fresh MACD cross on the same bar almost
never coincides (the .DWX two-cross-same-bar zero-trade trap), so only one is
the trigger and the rest are confirming states. Long when close(1) > EMA(100)
AND MACD(1) > 0 AND PSAR below price AND (fresh bullish PSAR flip OR MACD
up-cross of zero). Short is the mirror. Stop is 3 pips beyond the PSAR dot;
take-profit is a fixed 10-pip target. One position per magic.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_ema_period` | 100 | 50-200 | Macro-trend EMA period (price-vs-EMA trend state) |
| `strategy_sar_step` | 0.01 | 0.01-0.02 | Parabolic SAR acceleration step |
| `strategy_sar_max` | 0.01 | 0.01-0.20 | Parabolic SAR acceleration max (card uses tight 0.01) |
| `strategy_macd_fast` | 64 | 12-64 | Very-slow MACD fast EMA period |
| `strategy_macd_slow` | 128 | 26-128 | Very-slow MACD slow EMA period |
| `strategy_macd_signal` | 9 | 9-9 | MACD signal period (entry uses zero-cross, not signal) |
| `strategy_sl_buffer_pips` | 3 | 1-10 | SL buffer beyond the PSAR dot, in pips |
| `strategy_tp_pips` | 10 | 7-12 | Fixed take-profit in pips (card range 7-12, P2 = 10) |
| `strategy_spread_cap_pips` | 8.0 | 5-15 | Skip a genuinely wide spread above this many pips |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid major; tight scalp TP (10 pips) needs low spread.
- `GBPUSD.DWX` — liquid major with enough M5 trend movement for a 10-pip target.
- `AUDUSD.DWX` — liquid major; card's third named portable FX pair.

**Explicitly NOT for:**
- Index / metal `.DWX` symbols — pip scaling and the tight 10-pip scalp target
  are calibrated for 5-digit FX majors, not indices or XAUUSD.

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
| Trades / year / symbol | `100` |
| Typical hold time | `minutes to a few hours` |
| Expected drawdown profile | `frequent small scalps; shallow per-trade risk (~3 pip + PSAR distance stop)` |
| Regime preference | `trend` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** `book`
**Pointer:** `Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)", 5 Min Trading System #19`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11333_tc-m5-19-psar-macd64128-ema100.md`

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
| v1 | 2026-06-18 | Initial build from card | board-advisor build |
