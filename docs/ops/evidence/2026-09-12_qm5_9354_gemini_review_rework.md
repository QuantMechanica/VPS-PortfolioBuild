# QM5_9354 Gemini build review rework

Date: 2026-09-12

Router review task: `982fe1f3-c9e2-430b-a080-093f59a5b012`

Source build task: `78fa29a2-a41f-4eaf-bc55-b892025fadb1`

EA: `QM5_9354_demark-td-dwave-wave4-h4`

Disposition: REVIEW — source wiring repaired; governed compile queued and activation-held

## Review and repair

Build preflight passes the card/registry identity checks: the approved runtime card has `g0_status: APPROVED` (SHA-256 `a86db017d5adcf344b7d1d97b9fc699806697b5bfc134a627777708fe06848aa`), the active EA-ID row matches the slug/source, and nine active magic rows match all card symbols and setfiles.

The prior review's transactional finding reproduced. `Strategy_EntrySignal` wrote `last_traded_w3_time` and `last_w4_extreme` before `QM_TM_OpenPosition`; a rejected order therefore consumed the valid Wave-3 skeleton and suppressed retry. It also omitted MAE-first instrumentation and evaluated news/spread entry gates before management and exits.

Commits `3fc7fd8364` and `285eb3279b` apply a card-preserving repair:

- signal evaluation writes only pending candidate metadata;
- permanent skeleton/Wave-4 state commits only inside the successful `QM_TM_OpenPosition` branch;
- failed submission clears pending metadata without consuming the skeleton;
- `QM_FrameworkTrackOpenPositionMae()` is the first OnTick action;
- management and card exits execute before the entry-only news/spread gates;
- the caller zeroes `QM_EntryRequest`; and
- the missing canonical SPEC and Codex-owned tests are added.

The repaired MQ5 SHA-256 is `833fe31bac63affbe9d234cdfe5031cebdba1fb11eeedf1b553cc43ad48e5f28`. No entry/exit ratios, stop, target, timeout, symbol, or risk economics were changed. The stale-news ceiling remains 336.

## Verification

- Focused EA contract: 4 passed.
- Canonical SPEC validator: 1 PASS, 0 FAIL.
- Nine backtest setfiles: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and slots 0-8 match registry.
- Exact source/evidence compile-authority binding: PASS.
- Direct `build_check.ps1 -SkipCompile` was correctly refused with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` because terminal processes were active. It was not retried or bypassed; final build evidence must come from the governed worker.
- Source/SPEC/test commits: `3fc7fd8364`, `285eb3279b`.
- Compile-only authority commit: `c75e8af361`.

## Governed compile

`farmctl enqueue-compile` accepted work item `030c32c3-c47d-4b7e-922e-f9af38c3cb1d` under the exact review authority. It is pending under `COMPILE_EA_WORKER_ROLLOUT_PENDING`. No hold was released or bypassed, no compile PASS is claimed, and the existing `.ex5` is not treated as repaired build evidence.

This grants compile only. No smoke, Q02, pipeline, or live authority was granted. No terminal was started, no backtest was run or interrupted, and neither `T_Live` nor AutoTrading was touched.

RESULT: REVIEW_READY_TRANSACTIONAL_STATE_AND_EXIT_WIRING_REPAIRED_COMPILE_ACTIVATION_HELD — Gemini build remains REVIEW pending governed compile evidence.
