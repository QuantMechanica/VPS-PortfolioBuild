# Strategy Card - Davey ES Breakout (App A Strategy 4)

> Drafted for implementation continuity on 2026-04-28 from approved SRC01_S04 lineage in QUA-276/QUA-280.

## Card Header

```yaml
strategy_id: SRC01_S04
ea_id: 1004
slug: davey-es-breakout
status: APPROVED
created: 2026-04-28
created_by: Development
last_updated: 2026-04-28
g0_verdict: APPROVED
g0_reviewer: CEO (interim)
g0_issue: QUA-276
```

## 1. Concept

Momentum breakout strategy on ES proxy symbols: trade in direction of a range break and flip on opposite break.

## 2. Markets and Timeframe

- Instrument family: ES proxy (Darwinex US500 symbols); no symbol hardcoding in EA.
- Timeframe: chart timeframe (`_Period`).

## 3. Entry Rules

- Long trigger: close of previous completed bar breaks above highest high of prior `breakout_lookback` bars.
- Short trigger: close of previous completed bar breaks below lowest low of prior `breakout_lookback` bars.
- Triggers are evaluated once per new bar.
- Opposite trigger while in position closes and reverses.

## 4. Exit Rules

- Protective stop only: ATR-distance stop (`ATR_period * atr_stop_mult`) measured from entry.
- No TP, no partial close, no BE move, no trailing-stop module.
- Opposite breakout trigger performs close-and-reverse.

## 5. Filters and Framework Guards

- Use framework kill-switch.
- Use framework news filter gate.
- Use framework Friday close gate (enabled by default).

## 6. Strategy Parameters

- `breakout_lookback` default `20`
- `atr_period` default `14`
- `atr_stop_mult` default `2.0`

## 7. Risk and Positioning

- Risk sizing delegated to V5 framework (`RISK_PERCENT`/`RISK_FIXED`).
- One position per magic-symbol; reverse on opposite breakout only.

## 8. V5 Mapping Notes

- Entry module: breakout signal generation.
- Management module: maintain ATR-derived protective stop.
- Exit module: no standalone exit signal (framework + stop/reversal govern exits).
