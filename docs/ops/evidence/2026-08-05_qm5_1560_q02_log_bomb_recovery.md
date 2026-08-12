# QM5_1560 Q02 LOG_BOMB recovery — 2026-08-05

## Scope and coordination

- Mission lane: priority 2, diverse-instrument Q02 infrastructure recovery. The approved build backlog had no eligible non-duplicate higher-diversity card: the rates cards remained data-blocked and the other diverse candidates were already built/pipelined or did not meet the low-frequency priority.
- EA: `QM5_1560_aa-zak-macd-3-12-6`, approved Alpha Architect/Zakamulin monthly MACD(3,12,6) long/cash sleeve on D1 host data (approximately 12 decisions/year).
- Agent claim: `9835ef9d-5482-4c8f-9e5e-7e3ec06a1686`.
- Explicit farm rebuild task: `0c918194-45c1-4042-b509-07b42766d5fd`, claimed by `codex:agents/board-advisor` before recording.
- Targeted diversity scope: `EURUSD.DWX`, `GBPUSD.DWX`, and `USDJPY.DWX`. No open Q02/Q03 work existed for these EA-symbol pairs when claimed.

## Failure evidence and diagnosis

- Primary failure: work item `582407a4-2ec8-4a3f-b2f3-e38c7d565bdf`, evidence `D:\QM\reports\work_items\582407a4-2ec8-4a3f-b2f3-e38c7d565bdf\QM5_1560\20260805_071202\summary.json`.
- Result: `LOG_BOMB;INCOMPLETE_RUNS` on `EURUSD.DWX` D1 model 4. The tester killed the run after the EA event log reached 4.02 GB. `oninit_failure_detected=false`.
- The evidence bound the same old binary in source and T5 deployment (`9c04a7120611a4d8af8e0672423672af14b4022872f6436ca9846ad8cf5bf7d1`) and reported it stable during the run. The failure was therefore not a stale deployment.
- The old source hash was `335b7b77ad894b4abef3af441fde595293d22ff6f59e797c8e09772db4e2907f`.
- `RefreshMonthlyStateIfNeeded()` only short-circuited when `g_state_valid` was true. During the initial 21-month warmup, `ComputeMonthlyState()` legitimately returned invalid, so every tick recomputed the same month and emitted `MONTHLY_MACD_STATE_INVALID`. That converted a bounded warmup event into a per-tick journal flood.
- The same signature was present in the terminal FX failures `e3529366-f4c6-4426-8763-5add155ddf1e` (`GBPUSD.DWX`) and `5d28d955-129d-413c-a1a9-294c65628627` (`USDJPY.DWX`).

## Repair

- The monthly refresh now returns when the current calendar-month key has already been attempted, regardless of whether the state was valid. It retries once on the next month boundary.
- This bounds warmup-invalid logging to one event per month while preserving the approved signal, exit, and risk mechanics.
- `SPEC.md` revision v1.1 records the infrastructure-only change.
- All targeted backtest setfiles remain `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Validation and enqueue

- Strict build check: PASS, 0 failures, 0 warnings. Report: `D:\QM\reports\framework\21\build_check_20260805_220639.json`.
- Strict compile: PASS, 0 errors, 0 warnings. Log: `C:\QM\repo\framework\build\compile\20260805_220639\QM5_1560_aa-zak-macd-3-12-6.compile.log`.
- Repaired source SHA-256: `95e77c9527d1c05c49520ed9673875b8bc33d9dea2cb700b8b187bf94f0526e4`.
- Repaired binary SHA-256: `7570d3226923f5efb09aba9269e5f749c7113b584ca7400b52ef68a47dc0e130`.
- A canonical append-only rerun of the old EURUSD work item was attempted first and correctly failed closed with `historical_artifact_binding_mismatch`; no row was created because the old evidence was bound to the pre-repair source hash.
- The explicit rebuild record then appended three current-build Q02 work items through `record_build_result.auto_q02`:
  - `c88c3f28-8b62-4814-9e78-f2895c52a82e` — `EURUSD.DWX`, pending.
  - `9d06acf7-d729-44c4-879d-8aadf96daaec` — `GBPUSD.DWX`, pending.
  - `37a5f4dd-7608-4371-be3e-10090fde732a` — `USDJPY.DWX`, pending.
- All three rows carry build-task lineage to `0c918194-45c1-4042-b509-07b42766d5fd` and `priority_track=true`.

## Safety

- At enqueue time 9 of 10 factory terminals were running. No manual smoke or backtest was started; the work was left to normal paced dispatch.
- T_Live, AutoTrading, the portfolio gate, and the T_Live deploy manifest were not touched.
