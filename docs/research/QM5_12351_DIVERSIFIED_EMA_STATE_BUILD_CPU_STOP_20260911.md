# QM5_12351 diversified EMA-state build — compile held at CPU ceiling

Date: 2026-09-11

Branch: `agents/board-advisor`

Build commit: `c1ea1c0d03`

EA: `QM5_12351_alp-ema12-26`

## Outcome

The highest-diversity actionable approved build-backlog card was mechanized and
committed. The M15 EA implements the card's literal long-only EMA(12)-minus-
EMA(26) state, closes when the spread becomes negative, and places a fixed
2×ATR(14) protective stop. It is registered across EURUSD, GBPUSD, USDJPY,
XAUUSD, GDAXI, NDX, and WS30. The stale phantom `GER40.DWX` allocation was
corrected to the canonical `GDAXI.DWX` matrix symbol without changing its slot
or magic number.

Seven backtest setfiles were generated. Each sets `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and the exact symbol slot. The Q01 spec validator returned
PASS.

## Guard evidence

The required framework-input-pin command was run after the final MQ5 write and
before every enqueue-compile attempt. Its final result was exit 0 with
`EA_FRAMEWORK_INPUT_PINNED hit_count=0`; the exact receipt is
`artifacts/qm5_12351_input_pin_audit_20260911.json`.

The EA's configuration validation does not compare RNG, news, or Friday-close
inputs. Stress rejection is checked only for finiteness and the inclusive
0..1 range. Backtest risk is locked to positive fixed risk and zero percent
risk.

## Governed handoff and stop

Build task `b63e991a-cf37-4a8d-a884-a3ef1bb5a90e` is bound to compile work item
`92797bae-0f0d-45cb-872d-6f0bcccb258d`. The row is pending under
`COMPILE_EA_WORKER_ROLLOUT_PENDING`; its hold was not released, so no terminal
compile or smoke was started.

A fresh five-sample CPU admission check measured 98.73%, 96.78%, 90.09%,
92.63%, and 97.48% total processor use (95.14% average, 98.73% maximum). Since
the 97% ceiling was crossed, work stopped before compile activation. Q02 was
not enqueued. Resume by rechecking CPU, releasing only work item
`92797bae-0f0d-45cb-872d-6f0bcccb258d` through the bounded compile-wave tool,
then record the compile result and use the governed Q02 intake path.

No T_Live, AutoTrading, portfolio gate, or deployment manifest state was
touched.
