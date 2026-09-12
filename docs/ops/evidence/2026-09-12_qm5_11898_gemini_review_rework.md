# QM5_11898 Gemini build review rework

Date: 2026-09-12

Router review task: `7ac78733-f755-445e-a36c-1e21f7d6b600`

Source build task: `ccde1b2a-b70f-466a-bdf6-e626b2af48b4`

EA: `QM5_11898_trix-signal-line-cross-h1`

Disposition: REVIEW — card timeout repaired; governed compile queued and activation-held

## Review finding and repair

Preflight passes: the runtime approved card has `g0_status: APPROVED` (SHA-256 `2dc61029618b83f4f0ebcc9496817828ed275159b08294372b5df67c178d0fc8`), `ea_id_registry.csv` has the active 11898/slug/source row, and all ten approved symbols have matching active magic rows and backtest setfiles.

The prior defect reproduced at the former source lines 261-262. The implementation described the card's “H1 bar 96 after entry” contract but evaluated `(TimeCurrent() - open_time) >= 96 * 3600`. That was elapsed wall time, so weekend and holiday closures incorrectly aged a position despite no H1 bars forming.

Commit `3d59a268f8` replaces that expression with `iBarShift(_Symbol, PERIOD_H1, open_time, false)` through `Strategy_PositionAgeH1Bars()`, then exits at an observed age of at least 96. It also records the bar-count semantics in SPEC and adds Codex-owned tests. The repaired MQ5 is 11,637 bytes with SHA-256 `078d0ef3e9b10c64f624a5a1805094d09f77dadd866b2a2a8c6b3fc406c5555b`.

All other reviewed card mechanics remain unchanged: closed-H1 TRIX(14)/signal(9) cross, same-side zero-line filter, ATR(14) stop at 2.0, target at 2R, opposite-cross exit, one position per magic, framework news controls, Friday close, and framework order calls. `qm_news_stale_max_hours` remains 336.

## Verification

- Focused EA contract: `python -m pytest -q framework/EAs/QM5_11898_trix-signal-line-cross-h1/docs/test_qm5_11898_review_rework.py` -> 4 passed.
- Canonical SPEC validator: `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_11898_trix-signal-line-cross-h1` -> 1 PASS, 0 FAIL.
- Ten backtest setfiles: `RISK_FIXED=1000`, `RISK_PERCENT=0`, slots 0-9 match the active magic rows, timeframe H1.
- Compile-authority exact-source/evidence check: PASS; two focused append-only source-repair tests passed.
- Source/SPEC/test commit: `3d59a268f8`.
- Compile-only authority commit: `1d439e9f64`.

## Governed compile status

`farmctl enqueue-compile` accepted work item `61a4a778-1f60-4f1e-bfdf-207add893592` under authority `router_review_ea:7ac78733-f755-445e-a36c-1e21f7d6b600:QM5_11898`. It is pending under hold `COMPILE_EA_WORKER_ROLLOUT_PENDING`. No hold was released or bypassed, so there is no fresh compile verdict yet and the historical `.ex5` is not claimed as repaired build evidence.

This work item grants compile only. No smoke, Q02, new pipeline phase, or live authority was granted. Existing historical Q02/Q03 passes and Q04 failures were not changed or reinterpreted.

No terminal was started, no backtest was run or interrupted, and neither `T_Live` nor AutoTrading was touched.

RESULT: REVIEW_READY_TIMEOUT_REPAIRED_COMPILE_ACTIVATION_HELD — Gemini build remains REVIEW pending the governed compile receipt.
