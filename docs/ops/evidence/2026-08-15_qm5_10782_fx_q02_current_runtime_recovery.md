# QM5_10782 FX Q02 current-runtime recovery

Date: 2026-08-15

Branch: `agents/board-advisor`

EA: `QM5_10782_tv-smc-btc-r3`

Disposition: `REBUILT_REBOUND_PENDING_CPU_CEILING`

## Outcome

The approved structural SMC EA was rebuilt from its byte-identical MQ5 against
the current V5 include and magic-resolver state. The one existing append-only
`EURUSD.DWX` M15 Q02 successor was then hash-rebound in place with a guarded
compare-and-swap. No second work item was created, and no strategy mechanic or
executable parameter was changed.

- Farm coordination task: `bbde419d-3da0-4aff-83c2-3dde4db89543`, assigned to
  `codex:agents/board-advisor` under the exclusive claim
  `manual:codex:agents/board-advisor:QM5_10782:q02-current-runtime-recovery:20260815T184347Z`.
- Preserved predecessor: `158ce101-f31d-4c6e-88e2-95ca670f1ab6`.
- Existing successor: `db466eec-5b39-4837-9bcb-da31323fa461`.
- Post-state: `pending`, unclaimed, attempt 0, no verdict.
- Host: `EURUSD.DWX`, M15, `2022.07.01` through `2022.12.31`.
- Risk binding: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Selection and authorization

The canonical farm database had no unclaimed eligible `build_ea` backlog row.
Its two nominal `APPROVED` build rows were already review-closed artifacts
assigned to the `gemini` lane. This made the mission's priority 2 the first
available unit. The live database already held the branch-exclusive claim for
`QM5_10782`, so no competing claim was created.

The approved card is
`D:\QM\strategy_farm\artifacts\cards_approved\QM5_10782_tv-smc-btc-r3.md`.
Its frontmatter records `g0_status: APPROVED`, R1/R2/R3/R4 PASS, a fixed-rule
implementation without ML/grid/martingale, and the exact public source pointer
to rico2956's TradingView strategy `Strategie SMC V18.2 (BTC/EUR FINAL R3 -
Tendance)`. This recovery changes neither the card nor the source-derived
entry, exit, stop, or sizing rules.

## Bound failure and diagnosis

The retained predecessor is terminal `done / INFRA_FAIL`, with
`ONINIT_FAILED` and `INCOMPLETE_RUNS`; it is not an economic verdict. Its
authenticated farm evidence binding is:

`D:\QM\reports\work_items\158ce101-f31d-4c6e-88e2-95ca670f1ab6\QM5_10782\20260728_173939\summary.json`

Summary SHA-256 recorded in the source work item:
`e5b3cd7e70cb188c79048e36afc3bd0eb0edd1f4c7a6a8413f1a2165967d356e`.

The failed execution identity was stable and used:

- MQ5 SHA-256
  `93ae99d5980f75e4873b9a44db12256919e8d5e8d0a867d77a4e2fa77c935d35`;
- old EX5 SHA-256
  `fa0da11e7e7ed92c0d57b35c82332c44f45e26467c42f2bdf7439b0b1dc55df2`;
- old EX5 size 238,644 bytes;
- valid backtest risk inputs and `EURUSD.DWX` slot 4.

The failed run produced no structured logger sample. V5 magic resolution occurs
before logger initialization, while the canonical registries contain the
active tuple `10782 / slot 4 / EURUSD.DWX / 107820004`. All six card symbols
exist in `dwx_symbol_matrix.csv` and all six magic rows are active. The narrow
infrastructure diagnosis is therefore an old compiled framework/resolver
binding, not a signal rule failure. No rule was relaxed to force a trade.

## Interrupted handoff reconciliation

The first portion of this same farm claim had already produced clean receipts:

- strict compile PASS at `D:\QM\reports\compile\20260815_184453\summary.csv`;
- build-check PASS at
  `D:\QM\reports\framework\21\build_check_20260815_184532.json`;
- one append-only successor enqueued at `2026-08-15T18:47:29Z`.

That successor expected EX5
`1f5b51f338bcca0b4e104f6380fb0dc3da60fd446a57d52e2b573a499fb630aa`.
Before the artifact was committed, the shared checkout's tracked EX5 was
replaced by the old `fa0da1...` bytes at `2026-08-15T19:00:10Z`. The row stayed
pending and unclaimed, so it was safe to complete the interrupted handoff. A
fresh open-identity check found exactly that one pending successor and no
duplicate.

## Current repair evidence

The MQ5 remained byte-identical at SHA-256
`93ae99d5980f75e4873b9a44db12256919e8d5e8d0a867d77a4e2fa77c935d35`.

- Strict compile: PASS, 0 errors, 0 warnings.
- Strict compile summary:
  `D:\QM\reports\compile\20260815_204008\summary.csv`.
- Strict compile log:
  `C:\QM\repo\framework\build\compile\20260815_204008\QM5_10782_tv-smc-btc-r3.compile.log`.
- EA-scoped build check: PASS, 0 failures, 0 warnings.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260815_204138.json`.
- Build-check SHA-256:
  `d4614053337740d7a3682c8af89c724920c608dd14ac2b9c27588ada16aa603d`.
- Final rebuilt EX5 SHA-256:
  `3606ca4c33945b9fbd94f2d710d7018aa6461c5e29f6740e2af80d592e683a2c`.
- Final rebuilt EX5 size: 380,570 bytes.
- SPEC validation: PASS.

The checker changed only each preset's `build_hash` comment. Every one of the
six backtest presets retains `RISK_FIXED=1000`, `RISK_PERCENT=0`, and its
registered magic slot. The rebound EURUSD preset SHA-256 is
`3d37fa89807b05c5a2b68f06824e791b2b1a1691914708ff156e702c5cb7d250`.

## Guarded database reconciliation

An online SQLite backup was completed and passed `PRAGMA quick_check=ok` before
the mutation:

`D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10782_pending_binding_reconcile_20260815T204502Z.sqlite`

Backup SHA-256:
`78d25e27fd985d228c881082ac6f7d7f6da706b2924919f5b1c1b56bb9bdd428`.

A single `BEGIN IMMEDIATE` transaction compare-and-swapped the existing row
only if it was still `pending`, unclaimed, attempt 0, verdict-null, bound to the
known interrupted payload, and protected by the branch's live agent-task claim.
It updated only the MQ5/EX5/setfile evidence bindings and reconciliation
metadata, then appended:

- work-item transition ledger sequence `1847`, action
  `current_runtime_binding_reconcile`;
- event `q02_pending_artifact_binding_reconciled`.

Post-reconciliation payload SHA-256:
`d8c35dbaae1953aaedabf0cfe5100655b0abf5720ec566c6e32ab34c872bb5a3`.
The transaction created zero rows and preserved the predecessor and all prior
evidence.

## CPU-ceiling stop

After the binding was sealed, five host CPU samples were
`94.6%, 88.7%, 83.9%, 90.5%, 75.6%` (average `86.7%`). The factory already had
an active T3 Q02 tester, with 43,542 MB physical memory and 202.8 GB free on D:.
Per the paced-fleet instruction, no smoke, dispatch tick, manual terminal
start, or backtest was attempted. The authenticated successor remains pending
for the factory's own capacity gate.

## Safety boundary

No `T_Live` file or process, AutoTrading setting, live setfile, deploy manifest,
portfolio gate, or portfolio KPI artifact was modified. This is an
infrastructure rebuild and exact Q02 handoff, not a Q02 result or live-use
authorization.
