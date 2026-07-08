# QM5_13067_iea-omr-brk - Strategy Spec

**EA ID:** QM5_13067
**Slug:** `iea-omr-brk`
**Source:** `IEA-OMR-XTI-BRK-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-08

## 1. Strategy Logic

This EA implements a low-frequency WTI breakout sleeve on `XTIUSD.DWX` D1.
It uses the International Energy Agency Oil Market Report as official-source
lineage for a recurring mid-month information window. Runtime remains
Darwinex-native: closed D1 OHLC, spread, ATR, broker calendar, and V5
framework state only.

On each new D1 bar the EA checks whether the prior completed D1 bar falls
inside broker-calendar day 10 through day 18. It then requires an ATR-sized
range/body and a closing breakout above or below the prior Donchian context
range. A one-entry-per-month guard keeps the rule low-frequency and separate
from generic daily breakout logic.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_event_start_day` | 10 | 9-11 | First broker-calendar day in OMR proxy window |
| `strategy_event_end_day` | 18 | 16-20 | Last broker-calendar day in OMR proxy window |
| `strategy_breakout_lookback` | 20 | 10-30 | D1 Donchian context excluding OMR bar |
| `strategy_atr_period` | 20 | 14-30 | ATR period for signal and stops |
| `strategy_min_range_atr` | 1.00 | 0.75-1.50 | Minimum signal range in ATR units |
| `strategy_min_body_atr` | 0.35 | 0.20-0.60 | Minimum signal body in ATR units |
| `strategy_atr_sl_mult` | 2.50 | 1.75-3.50 | ATR hard-stop distance |
| `strategy_atr_tp_mult` | 3.00 | 2.00-4.00 | ATR target distance |
| `strategy_max_hold_days` | 5 | 3-8 | Calendar-day stale-position exit |
| `strategy_max_spread_points` | 1000 | 700-1500 | Entry spread cap |

## 3. Symbol Universe

- `XTIUSD.DWX` only, magic slot 0.

## 4. Timeframe

- Base timeframe: D1.
- Bar gating: `QM_IsNewBar()`.
- Data reads use completed D1 bars only.

## 5. Expected Behaviour

- Expected trades/year/symbol: about 4-9.
- Direction: symmetric long/short.
- Typical hold: several D1 bars, capped by ATR target, ATR stop, five-day time
  exit, or Friday close.
- Regime preference: IEA OMR proxy-window crude-oil continuation after a
  decisive closed-bar breakout.
- Risk mode for Q02 backtests: `RISK_FIXED`.

## 6. Source Citation

Official agency report source:

- https://www.iea.org/data-and-statistics/data-product/oil-market-report-omr

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Q02+ backtest | RISK_FIXED | 1000 |
| Live, if ever approved later | RISK_PERCENT | allocated by portfolio process |

No live manifest, `T_Live` file, portfolio gate, or AutoTrading setting is
touched by this build.

## Evidence

- Build result: `artifacts/qm5_13067_build_result.json`.
- Q02 enqueue: `artifacts/qm5_13067_q02_enqueue_20260708.json`.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-08 | Mission-directed IEA OMR WTI breakout build | Enqueue to Q02 |
