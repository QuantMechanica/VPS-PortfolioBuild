# QM5_11277_blade-m5-ema-zone-scalp - Strategy Spec

**EA ID:** QM5_11277
**Slug:** `blade-m5-ema-zone-scalp`
**Source:** `e78a9f1f-4e6a-563c-a080-915133d6ed28` (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-23

---

## 1. Strategy Logic

This EA trades the Blade M5 EMA zone scalp. It reads EMA(10), EMA(21), and EMA(50) on the closed M5 bar, then trades only in the direction of a visibly sloping EMA(50). A long entry opens when EMA(10) is above EMA(21), EMA(50) is rising, and the closed bar has retraced into the EMA(10)-EMA(21) zone at or below its midpoint while remaining above EMA(21); shorts mirror the same rule. The EA places the stop 5 pips beyond EMA(21), uses a fixed 10-pip take profit or 5 pips in weak slope conditions, moves to break-even after 5 pips, and exits remaining positions at the relevant session end.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_ema_fast` | 10 | >=2 | Fast EMA defining one side of the Blade zone. |
| `strategy_ema_slow` | 21 | >=2 | Slow EMA defining the opposite side of the Blade zone and SL anchor. |
| `strategy_ema_trend` | 50 | >=2 | Trend EMA used for direction and slope. |
| `strategy_slope_lookback` | 5 | >=1 | Bars back for EMA(50) slope comparison. |
| `strategy_min_slope_pips` | 1.0 | >0 | Minimum EMA(50) movement over the lookback to accept a trend. |
| `strategy_weak_slope_pips` | 2.0 | >0 | EMA(50) slope below this threshold uses the 5-pip weak-trend TP. |
| `strategy_sl_pips` | 5 | >0 | Pip distance beyond EMA(21) for the initial stop. |
| `strategy_tp_pips` | 10 | >0 | Normal fixed take-profit distance in pips. |
| `strategy_weak_tp_pips` | 5 | >0 | Take-profit distance in weak trend conditions. |
| `strategy_be_trigger_pips` | 5 | >0 | Profit in pips required before moving SL to break-even. |
| `strategy_session_buffer_min` | 30 | >=0 | No-entry buffer at London and New York session boundaries. |
| `strategy_spread_cap_pips` | 3 | >0 | Maximum modeled spread before new entries are blocked. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - primary card symbol and the most liquid major FX pair.
- `GBPUSD.DWX` - card-listed P2 portable major with M5 DWX history.
- `USDJPY.DWX` - card-listed P2 portable major with M5 DWX history.

**Explicitly NOT for:**
- Index `.DWX` symbols - the source strategy is a forex M5 scalp with pip-sized SL/TP conventions.
- Metals and energy `.DWX` symbols - pip semantics and session behaviour differ from the card's FX-major design.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework OnTick gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 200 |
| Typical hold time | minutes to a single session |
| Expected drawdown profile | scalp-sized fixed stops, many small losses possible during ranging sessions |
| Regime preference | trend-following pullback |
| Win rate target (qualitative) | medium to high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `e78a9f1f-4e6a-563c-a080-915133d6ed28`
**Source type:** archived PDF strategy guide
**Pointer:** `C:\Users\Administrator\Dropbox\Finanzen\Forex\###  Forex to read\219755537-Blade-Forex-Strategies.pdf`, "M5 Scalping System" pages 11-25
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11277_blade-m5-ema-zone-scalp.md`

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
| v1 | 2026-06-23 | Initial build from card | 0c2c2c4c-5765-48b8-a5dd-2f060e807648 |
