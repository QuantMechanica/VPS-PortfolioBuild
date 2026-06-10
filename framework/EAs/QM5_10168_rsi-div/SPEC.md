# QM5_10168_rsi-div — Strategy Spec

**EA ID:** QM5_10168
**Slug:** `rsi-div`
**Source:** `d3c009d7-a8d6-5251-b572-4777b207c2b9` (see `strategy-seeds/sources/d3c009d7-a8d6-5251-b572-4777b207c2b9/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA evaluates once per completed D1 bar. It computes RSI(14) and detects swing pivots requiring five confirmed bars on each side. A bullish divergence long signal fires when the most recent two confirmed swing lows show lower price lows combined with higher RSI lows, and the most recent pivot RSI is below the 50 centerline. A bearish divergence short signal fires when higher price highs coincide with lower RSI highs, with the most recent pivot RSI above the centerline.

Entries are market orders placed after pivot confirmation. The entry reason string stores the pivot RSI value for exit reference. Long exits occur when RSI crosses up through the centerline, or while still below the centerline falls below the entry RSI. Short exits occur when RSI crosses down through the centerline, or while above the centerline rises above the entry RSI. Initial stops are placed below the confirming swing low minus 1.0 ATR(14) for longs, and above the confirming swing high plus 1.0 ATR(14) for shorts. One position per magic number at a time.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_rsi_period` | 14 | 10–21 | RSI lookback period |
| `strategy_pivot_order` | 5 | 3–8 | Bars required on each side of a confirmed pivot |
| `strategy_pivot_count_k` | 2 | 2–3 | Consecutive pivots required for divergence |
| `strategy_centerline` | 50.0 | 45–55 | RSI centerline threshold |
| `strategy_atr_period` | 14 | fixed | ATR period for stop buffer |
| `strategy_atr_stop_mult` | 1.0 | 0.5–1.5 | ATR multiple beyond the confirming pivot |
| `strategy_warmup_bars` | 60 | ≥1 | Minimum D1 bars before signals are enabled |
| `strategy_pivot_scan_bars` | 60 | ≥1 | Maximum D1 bars scanned for recent confirmed pivots |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — US large-cap index, OHLC-based pivot logic portable to this custom symbol (backtest-only; not broker-routable for live T6)
- `NDX.DWX` — Nasdaq 100, same pivot/RSI logic applies to trending tech index
- `WS30.DWX` — Dow Jones 30, similar index regime characteristics

**Explicitly NOT for:**
- Forex pairs — RSI divergence on 24h D1 bars loses the structural swing clarity present in equity index sessions

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~15 |
| Typical hold time | days to weeks |
| Expected drawdown profile | sparse reversals; long flat periods and losing stretches plausible |
| Regime preference | mean-revert |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `d3c009d7-a8d6-5251-b572-4777b207c2b9`
**Source type:** blog / forum
**Pointer:** Raposa, "Test and Trade RSI Divergence in Python", 2021-07-26
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10168_rsi-div.md`

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
| v1 | 2026-06-10 | Initial build from card | 9066c94a-42ae-4b80-8624-daa95ef596a6 |
