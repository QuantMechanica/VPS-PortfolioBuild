# FX cointegration QM5_12507 Q02 CPU-ceiling stop

Recorded: 2026-09-06T18:17:10.7782584Z (20:17 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `d373e87c43d4e863b953476244adeb1b0a32bbf7`

## Outcome

No new scan-derived pair was built. The authoritative 66-pair report admits
only two positive-beta relationships, and both are already built and beyond
Q02: `QM5_12532` has logical-basket Q02/Q04 PASS followed by Q05 FAIL, while
`QM5_12533` has logical-basket Q02 PASS followed by Q04 FAIL. The repository's
cross-ledger duplicate guard also records the later sign-aware frontier as fully
mechanized, so another card or EA would duplicate governed work.

The legitimate existing-card fallback remains the concrete `EURUSD.DWX` /
`GBPUSD.DWX` H1 relationship in `QM5_12507_pair-coint-z`. Its canonical logical
Q02 item `547c4fd3-f3fd-4c59-b9dc-654e96521251` is still pending, unclaimed,
attempt zero, without a verdict, and the only open row for this exact identity.
It was enqueued on 2026-08-29; appending another row would not advance the
funnel and would split the authenticated logical-basket lineage.

## Binding capacity stop

Five whole-host CPU samples were 84.112239%, 75.015106%, 88.193189%,
97.363575%, and 93.751269%. Their average was 87.687076% and their maximum was
97.363575%, exceeding the mission's binding 97% backtest ceiling. Free physical
memory was 23.113 GiB of 63.120 GiB, and five farm work items were active at the
state reread.

Per the explicit ceiling rule, no backtest was launched or dispatched, no
terminal was reserved or controlled, and no queue mutation followed. The
existing pending Q02 row remains the safe continuation after capacity drains.

## PACER guard and integrity

The existing source was checked with the binding command:

`python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5`

It returned `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, and zero findings.
`validate_symbol_scope.py --ea QM5_12507_pair-coint-z` returned `BASKET_OK` with
all four warmed symbols declared in `basket_manifest.json`. The logical
backtest setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

No MQ5 source was generated or edited, so there was no compile enqueue. A
nonzero pin-audit exit or any `EA_FRAMEWORK_INPUT_PINNED` finding would have
refused the build before enqueue exactly as required.

## Safety and continuation

No EA, Strategy Card, registry, setfile, basket manifest, compile row, Q02 row,
priority, hold, claim, tester, verdict, portfolio-admission/KPI/Q08-contribution
surface, portfolio gate, `T_Live` manifest or terminal, live/deploy artifact, or
AutoTrading state was changed. Concurrent unrelated worktree changes were left
unstaged and untouched.

Let the existing logical Q02 item advance through the canonical worker after
CPU capacity is below the ceiling. Do not append, reprioritize, or manually
dispatch a duplicate.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_q02_cpu_ceiling_stop_20260906T181710Z_board_advisor.json`.
