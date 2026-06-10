# QM5_10169_rsi-div-trend - Strategy Spec

**EA ID:** QM5_10169
**Slug:** rsi-div-trend
**Source:** d3c009d7-a8d6-5251-b572-4777b207c2b9
**Author of this spec:** Codex
**Last revised:** 2026-06-10

---

## 1. Strategy Logic

The EA evaluates once per completed D1 bar. It scans confirmed D1 swing pivots with order 5, then opens long when price confirms a lower low while RSI(14) confirms a higher low and the confirming RSI is below 50. It opens short when price confirms a higher high while RSI(14) confirms a lower high and the confirming RSI is above 50. Long exits require RSI to remain below 50 and fall below entry RSI while EMA(50) is not above EMA(200); short exits mirror this with RSI above 50, above entry RSI, and EMA(50) not below EMA(200). Initial stops sit one ATR(14) beyond the confirming pivot, and optional trailing uses 4 ATR only after the EMA trend conversion is active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rsi_period` | 14 | 10, 14, 21 | RSI period used for divergence and exit checks. |
| `strategy_pivot_order` | 5 | 3, 5, 8 | Bars on each side required to confirm a swing pivot without lookahead. |
| `strategy_pivot_count_k` | 2 | 2 | Number of confirmed pivots compared for divergence. |
| `strategy_ema_fast_period` | 50 | 20, 50, 64 | Fast EMA in the trend-conversion hold rule. |
| `strategy_ema_slow_period` | 200 | 100, 200, 256 | Slow EMA in the trend-conversion hold rule. |
| `strategy_centerline` | 50.0 | 50.0 | RSI centerline used by entries and exits. |
| `strategy_atr_period` | 14 | 14 | ATR period for initial stop and trailing stop. |
| `strategy_atr_stop_mult` | 1.0 | 0.5, 1.0, 1.5 | ATR buffer beyond the confirming pivot for initial SL. |
| `strategy_trail_atr_mult` | 4.0 | 0.0, 3.0, 4.0 | ATR trailing multiple after trend conversion; 0 disables trailing. |
| `strategy_warmup_bars` | 220 | >= 200 | Minimum D1 history before evaluating entries. |
| `strategy_pivot_scan_bars` | 80 | >= 20 | Bounded D1 pivot scan window. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` - S&P 500 index custom symbol named explicitly in the card R3 section.
- `NDX.DWX` - Nasdaq 100 index CFD/custom symbol named explicitly in the card R3 section.
- `WS30.DWX` - Dow 30 index CFD/custom symbol named explicitly in the card R3 section.

**Explicitly NOT for:**
- Any symbol not registered for `QM5_10169` in `framework/registry/magic_numbers.csv` - the framework magic resolver rejects unregistered symbol slots.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Expected trade frequency | Fewer entries than oscillator-only systems |
| Typical hold time | Multi-day, extending during EMA trend conversion |
| Expected drawdown profile | Hybrid reversal-to-trend giveback risk bounded by initial ATR stop and framework risk |
| Regime preference | Reversal into trend-following continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** d3c009d7-a8d6-5251-b572-4777b207c2b9
**Source type:** blog
**Pointer:** https://raposa.trade/blog/test-and-trade-rsi-divergence-in-python/ section "RSI Divergence and Trend"
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_10169_rsi-div-trend.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-10 | Initial build from card | be1e6416-9621-4f62-907b-71004d85c24b |
