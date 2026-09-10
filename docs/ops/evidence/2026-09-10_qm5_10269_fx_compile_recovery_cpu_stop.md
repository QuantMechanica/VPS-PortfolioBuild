# QM5_10269 diverse-FX compile recovery — Q02 CPU stop

Date: 2026-09-10 UTC

Branch: `agents/board-advisor`

Outcome: `COMPILE_OK; Q02 DRY-RUN ELIGIBLE; Q02 NOT ENQUEUED AT CPU CEILING`

## Selection and collision control

The approved-card backlog had no collision-free, low-frequency FX/crypto/rates
candidate that also satisfied the build skill's pre-existing active magic-row
precondition. The apparent leading cards were either banned grid/high-frequency
work, index-heavy, missing active magic allocations, or already owned by another
open repair task. This unit therefore advanced the existing priority-2 recovery
for `QM5_10269_gawd-wma30-trend`, a fixed-rule D1 sleeve whose registered
universe includes AUDUSD, EURUSD, GBPUSD, NZDUSD, USDCAD, USDCHF, and USDJPY.

The existing router task is `2cd23795-b866-4ba8-b1c0-8c7d13ef5fcf`. Its prior
source repair was committed as `f3a32bf9ab` and its exact-source compile work
item `3a92321c-deb2-45a0-872e-c39d8602d5cb` remained pending under
`COMPILE_EA_WORKER_ROLLOUT_PENDING` solely because the previous paced wake hit
the host CPU ceiling. No competing open repair was created.

## Build guard and governed compile

Before release, the required pin audit was repeated against the exact source:

```text
python C:/QM/repo/tools/strategy_farm/audit_framework_input_pins.py --check-source C:/QM/repo/framework/EAs/QM5_10269_gawd-wma30-trend/QM5_10269_gawd-wma30-trend.mq5
ok=true; predicate=EA_FRAMEWORK_INPUT_PINNED; hit_count=0
```

The source SHA-256 remained
`ba1bdd99f02957c30d854a243aa870fdbda719cdee8fc0d76b8d788a1c0b1801`,
matching the sealed source-repair authority. The AUDUSD, EURUSD, and GBPUSD
backtest setfiles retained `RISK_FIXED=1000`, `RISK_PERCENT=0`, and registered
magic slots 4, 5, and 6. The release dry-run selected exactly one row.

A fresh five-sample admission window averaged 69.592% CPU and peaked at
70.315%, below the strict 97% ceiling. The governed compile-wave ceremony then
released only `3a92321c-deb2-45a0-872e-c39d8602d5cb`; resident worker T2 sealed:

- status/verdict: `done / COMPILE_OK`;
- strict build check: PASS, zero failures and zero warnings;
- MetaEditor compile: PASS, zero errors and zero warnings;
- MQ5 SHA-256:
  `ba1bdd99f02957c30d854a243aa870fdbda719cdee8fc0d76b8d788a1c0b1801`;
- EX5 SHA-256:
  `284d46702d34032f95322197fed9295d6e4296ffd387da49c5aa76b7961aecf6`;
- compile evidence:
  `D:\QM\reports\work_items\3a92321c-deb2-45a0-872e-c39d8602d5cb\QM5_10269\COMPILE_EA\compile_evidence.json`;
- compile-evidence SHA-256:
  `224f984c0cdd03c3f5d0d35075f0aa39f40eee449e24b912b60ee59f5ea2fb74`.

The release receipt is
`artifacts/qm5_10269_compile_release_20260910.json` (SHA-256
`08170e48e3bbdb68cc3871bcb35e6376b7a43ac2b0b7b174e2bb9a796dfbb8ce`).

## Q02 handoff stopped by CPU ceiling

The append-only AUDUSD requalification dry-run against predecessor
`9a0ced77-9871-4368-b153-e2a877b4a750` returned `eligible=true`,
`parameter_change_count=0`, and `would_enqueue=true`. It bound the current
source, EX5, and fixed-risk AUDUSD setfile without changing strategy parameters.

Immediately before apply, the required fresh five-sample CPU window was:
`97.764, 91.922, 94.141, 96.877, 79.591` percent. Average was 92.059%, but the
97.764% maximum violated the paced rule requiring both average and maximum to
remain strictly below 97%. The build therefore stopped before Q02 enqueue. No
Q02 successor was written and no tester or backtest was dispatched.

The next paced wake may repeat the input-pin audit, confirm EX5 SHA-256
`284d4670...aecf6`, rerun the same AUDUSD requalification dry-run, take a fresh
five-sample CPU window, and apply only if both average and maximum are below
97%.

## Safety boundary

No strategy mechanic, input value, card, registry, magic allocation, portfolio
gate, `T_Live` file, deploy manifest, or AutoTrading state was changed. The
existing stale NDX Q02 row was left untouched. This unit released one governed
compile item and did not manually control any terminal process.

