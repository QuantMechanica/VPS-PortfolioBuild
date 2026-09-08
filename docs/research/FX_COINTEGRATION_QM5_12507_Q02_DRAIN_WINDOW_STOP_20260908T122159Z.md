# FX cointegration QM5_12507 Q02 drain-window stop

Recorded: 2026-09-08T12:21:59.8857884Z (14:21 Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `6dd33bb530caf6d9e75d06608ff127bd6d529b11`

## Outcome

No new scan-derived pair was built. The cross-ledger reconciliation of the
frozen 66-pair scan remains exhaustive: every approved cointegration/coint Card
in the runtime reservoir has a matching EA directory, and the durable frontier
guard accounts for all 66 unordered relationships. The preferred anchors do
not need Q02 infrastructure repair: `QM5_12532` has logical-basket Q02 PASS and
Q04 PASS followed by Q05 FAIL, while `QM5_12533` has logical-basket Q02 PASS
followed by Q04 FAIL.

The mission-authorized existing-card fallback remains the concrete
`EURUSD.DWX` / `GBPUSD.DWX` H1 relationship in `QM5_12507_pair-coint-z`. Its
canonical logical Q02 work item
`547c4fd3-f3fd-4c59-b9dc-654e96521251` was reread as pending, unclaimed,
unheld, attempt zero, without a verdict, and already `priority_track=true`.
It is the only open row for this exact EA, phase, and logical-symbol identity.
The canonical selector placed it 148th among 5,479 eligible pending rows.

The guarded `mark-priority-track --dry-run` returned
`reason=already_priority_track`. No duplicate row or redundant priority mark
was written.

## Capacity and drain-window stop

Five one-second whole-host CPU samples were `81.963143%`, `92.857698%`,
`90.685132%`, `79.404863%`, and `69.090929%`. Average utilization was
`82.800353%` and maximum utilization was `92.857698%`; neither measure reached
the 97% CPU ceiling.

Free physical memory was 42.195 GiB of 63.120 GiB. The canonical reservation
classifier resolved the target's four-symbol basket payload to
`heavy_or_unknown_multisymbol`, with a 44 GiB reservation and a 14 GiB
post-reservation floor. Normal admission therefore requires 58 GiB free.

The governed drain window already belongs to the older pending logical basket
`QM5_12512` work item `acbad967-bf94-4565-9e51-db193de01bf9`, with a 32 GiB
reservation and 14 GiB floor. The farm had zero active work items and no
factory `terminal64.exe` processes at the snapshot, but the existing drain
owner and insufficient free memory prohibit bypassing queue order or manually
claiming `QM5_12507`. Nine resident terminal workers were present with no
duplicates or orphaned tester processes. `T_Live` was observed only by the
read-only slot census and was not controlled.

## PACER guard and fixed-risk contract

No `.mq5` source was generated or edited, so no compile enqueue was necessary.
The binding source audit was nevertheless run read-only:

`python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source "C:/QM/repo/framework/EAs/QM5_12507_pair-coint-z/QM5_12507_pair-coint-z.mq5"`

It returned `ok=true`, predicate `EA_FRAMEWORK_INPUT_PINNED`, and zero
findings. `validate_symbol_scope.py --ea QM5_12507_pair-coint-z --json`
returned `BASKET_OK` and confirmed all four source-warmed symbols are declared
by `basket_manifest.json`.

The authenticated logical setfile remains `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. The Card explicitly approves both
the EURUSD/GBPUSD and NDX/WS30 pairs. Narrowing the source or manifest to two
symbols would therefore misstate the approved implementation and invalidate
the existing Q01/Q02 artifact lineage; it was not attempted.

## Safety and continuation

No Strategy Card, EA source or binary, registry, magic row, setfile, basket
manifest, farm row, priority, hold, claim, terminal, tester, verdict,
portfolio-admission/KPI/Q08-contribution surface, portfolio gate, `T_Live`
manifest or terminal, live/deploy artifact, or AutoTrading state was changed.
Concurrent unrelated shared-worktree changes were left unstaged and untouched.

Let the older governed drain owner resolve, then let the existing authenticated
priority Q02 row advance through normal worker claim order when its 58 GiB RAM
admission condition is satisfied. Never append a duplicate Q02 row.

Machine-readable companion:
`artifacts/fx_cointegration_qm5_12507_q02_drain_window_stop_20260908T122159Z_board_advisor.json`.
