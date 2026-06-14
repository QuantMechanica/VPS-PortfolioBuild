# QM5_10784_tv-orbo-basic - Strategy Spec

**EA ID:** QM5_10784
**Slug:** `tv-orbo-basic`
**Source:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-14

---

## 1. Strategy Logic

The EA builds one opening range per trading day from 09:30 through 09:50 broker time by tracking the high and low of closed intraday bars that start inside that window. After the window is complete, it opens long when a closed bar crosses above the opening-range high and opens short when a closed bar crosses below the opening-range low, with no existing position for the current symbol magic. The stop is the opposite side of the opening range plus an optional ATR(14) buffer, the target is a fixed R multiple, and any open position is flattened at the configured session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_range_start_hour` | 9 | 0-23 | Broker-time hour when opening-range collection starts. |
| `strategy_range_start_min` | 30 | 0-59 | Broker-time minute when opening-range collection starts. |
| `strategy_range_end_hour` | 9 | 0-23 | Broker-time hour when opening-range collection ends. |
| `strategy_range_end_min` | 50 | 0-59 | Broker-time minute when opening-range collection ends. |
| `strategy_flat_hour` | 16 | 0-23 | Broker-time hour for session flatten. |
| `strategy_flat_min` | 0 | 0-59 | Broker-time minute for session flatten. |
| `strategy_atr_period` | 14 | 1+ | ATR period for the optional stop buffer and range-width filter. |
| `strategy_use_atr_buffer` | true | true/false | Add an ATR buffer to the opposite-range stop. |
| `strategy_atr_buffer_mult` | 0.10 | 0.0+ | ATR multiplier added outside the opening range for the stop. |
| `strategy_rr_target` | 1.50 | 0.1+ | Fixed reward-to-risk target multiple. |
| `strategy_use_range_filter` | false | true/false | Enable the optional ATR opening-range-width filter. |
| `strategy_min_range_atr` | 0.25 | 0.0+ | Minimum opening-range width as ATR multiple when the filter is enabled. |
| `strategy_max_range_atr` | 4.00 | 0.0+ | Maximum opening-range width as ATR multiple when the filter is enabled. |
| `strategy_max_spread_points` | 80 | 0+ | Skip new entries when current spread exceeds this many points; 0 disables. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - liquid FX major listed in the card's R3 basket.
- `GBPUSD.DWX` - liquid FX major listed in the card's R3 basket.
- `USDJPY.DWX` - liquid FX major listed in the card's R3 basket.
- `XAUUSD.DWX` - canonical DWX gold symbol for the card's `XAUUSD` entry.
- `GDAXI.DWX` - canonical matrix DAX symbol used for the card's unavailable `GER40.DWX` wording.
- `NDX.DWX` - liquid US index CFD listed in the card's R3 basket.
- `WS30.DWX` - liquid US index CFD listed in the card's R3 basket.

**Explicitly NOT for:**
- Symbols outside `framework/registry/dwx_symbol_matrix.csv` - not registered for DWX backtest routing.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` primary; setfiles also generated for `M1` and `M15` because the card lists M1/M5/M15 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework `OnTick` gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `90` |
| Typical hold time | Intraday, from post-opening-range breakout until SL, TP, or same-session flat close |
| Expected drawdown profile | Plain ORB baseline with fixed 1.5R target and opposite-range stop |
| Regime preference | Volatility-expansion breakout after the opening range |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7`
**Source type:** TradingView open-source strategy
**Pointer:** TradingView `Session Opening Range Breakout (ORBO)`, AIScripts, published 2025-12-01
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_10784_tv-orbo-basic.md`

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
| v1 | 2026-06-14 | Initial build from card | a5aa3294-0b17-4361-aee6-2fe1a84d6427 |
