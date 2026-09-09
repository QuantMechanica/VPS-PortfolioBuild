# FX cointegration QM5_12507 logical Q02 hard CPU stop

Recorded: 2026-09-09T09:47:43.3921052Z (11:47 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `c448762d7cb4225102d48ee0f26dc6201becbd6d`

## Outcome

No new scan-derived pair was built. The bounded OWNER-requested source
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md` was read completely and
still admits only `AUDUSD.DWX` / `NZDUSD.DWX` and `EURJPY.DWX` /
`GBPJPY.DWX` from its 66-pair scan. Those relationships are already built as
`QM5_12532` and `QM5_12533`. Current canonical history confirms that 12532 has
logical-basket Q02 and Q04 PASS followed by Q05 FAIL, while 12533 has
logical-basket Q02 PASS followed by Q04 FAIL. Neither anchor has a current
Q02 ONINIT or NO_HISTORY blocker.

The durable sign-aware coverage audit remains 66/66 relationships covered, so
another scan identity would duplicate governed work or promote a row that did
not satisfy the reputable-source admission threshold.

## Existing-card fallback

The legitimate existing fallback remains the concrete `EURUSD.DWX` /
`GBPUSD.DWX` H1 relationship in approved `QM5_12507_pair-coint-z`. Its public
source citation and deterministic R1-R4 assessment remain recorded in
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_12507_pair-coint-z.md`.
The EA has a basket manifest and its logical setfile retains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

Canonical item `547c4fd3-f3fd-4c59-b9dc-654e96521251` is still the single
logical Q02 continuation. It is pending, unclaimed, attempt zero, unheld, and
already carries `priority_track=true`. Appending, requeueing, or priority
mutating another row would be duplicate work rather than advancement.

## Binding capacity stop

A path-aware slot scan immediately before the admission window observed five
factory terminals: `T1`, `T3`, `T5`, `T9`, and `T10`. `T_Live` and the FTMO
terminal were observed only to exclude them and were not controlled. The farm
contained eight active and 7,013 pending work items.

Five one-second whole-host CPU samples were `93.85%`, `97.73%`, `99.03%`,
`96.10%`, and `92.40%`. Their average was `95.82%` and their maximum was
`99.03%`. The maximum exceeds the binding 97% admission ceiling, so all
build, compile, enqueue, dispatch, claim, tester, reservation, and terminal
activity stopped.

This is a fresh non-duplicate state receipt: since the 2026-09-07 receipt the
pending backlog contracted from 10,026 to 7,013 and the governed terminal
cohort rotated, while the exact fallback row remained the sole valid
continuation.

## PACER guard and safety

No `.mq5` file was generated or edited, so the mandatory post-write
`audit_framework_input_pins.py --check-source` boundary was not entered and no
compile was enqueued. Any later source write must pass that audit with no
`EA_FRAMEWORK_INPUT_PINNED` finding before compile admission.

No Strategy Card, EA source or binary, setfile, basket manifest, registry,
magic row, queue row, priority, hold, claim, verdict, portfolio-admission,
portfolio-KPI, Q08-contribution, T_Live manifest, live/deploy artifact, or
AutoTrading state was changed. Concurrent unrelated worktree changes were
preserved and excluded from this receipt.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_q02_hard_cpu_stop_20260909T094743Z_board_advisor.json`.
