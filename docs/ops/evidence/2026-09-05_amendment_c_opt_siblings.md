# Amendment C: six measurement siblings

Router task: `db42cb90-ce73-4126-aa97-862bdb0438af`.
Disposition: **BUILD COMPLETE; REVIEW with Q02 dependency residuals**.

All six requested siblings already had approved, task-bound cards, governed ID
and magic allocations, sources, and successful compile-worker receipts when
this single-pass cycle resumed their handoff. The last three binaries and
worker-bound setfiles are now committed in `e75101ec12`. No new identity,
calendar modification, program, or pipeline verdict was created by this cycle.

| Parent / symbol | Sibling | Active magic | Successful compile row | Matrix dry run |
|---|---|---:|---|---|
| 11708 / EURUSD.DWX | QM5_41342 | 413420000 | `f0dc12bc-7da4-47b0-a3f5-7ee69cc0f8bf` | Existing program maintained |
| 20086 / EURUSD.DWX | QM5_41343 | 413430000 | `07db9119-79a3-4d5a-bafe-4cd7577d187a` | Would materialize |
| 41221 / EURUSD.DWX | QM5_41344 | 413440000 | `31b31c43-740d-44d8-bf0a-bc4fec6b0b43` | Would materialize |
| 21502 / XAUUSD.DWX | QM5_41345 | 413450000 | `2ce7a9da-42ef-432e-939e-ec7af7a31646` | Held: measurement Q02 ZERO_TRADES |
| 41219 / XAUUSD.DWX | QM5_41346 | 413460000 | `2a5ffbfc-95d6-4004-ad24-5f1b1eb43cd7` | Would materialize |
| 11294 / XAUUSD.DWX | QM5_41347 | 413470000 | `245ee112-e9b1-4346-a5b0-82ae91cd039c` | Would materialize; Q02 completed during this cycle |

The six dry-run receipts are adjacent files named
`2026-09-05_amendment_c_opt_siblings_dry_run_<parent>.json`. Each was produced
by capturing stdout from the canonical `farmctl.py service-dl089-matrix
--work-item-id <exact-owner>` without `--apply`; each says `applied=false`.
All six approved siblings are recognized. A claim that all six programs can
materialize today would be false because one Q02 prerequisite remains unmet.
The scheduled service owns subsequent materialization.

## Verification and source review

- Six compiler results: 0 errors, 0 warnings, build-check PASS. Every current
  MQ5 and EX5 exactly matches its compile receipt.
- All six active registry identities and magic rows reconcile; each magic has
  one active owner. The local cards exactly match the approved runtime cards
  and bind the requested parent, symbol, and this router task.
- Source-to-parent review confirms unchanged entry, exit, sizing, news, and
  Friday-close mechanics. Intentional deltas are identity, the common closed-D1
  permission module, six neutral inputs, fail-closed profile initialization,
  permission before each sole order consumer, and summary telemetry.
  41342 and 41347 also explicitly zero-initialize the request; 41345 has an
  identity-specific attempt-state key. All six common permission blocks are
  byte-identical after normalizing line endings.
- `test_pattern_permission_framework_wiring.py`: **5 passed**.
- `validate_build_guardrails.py`: **6 PASS**, no findings, stale-news ceiling
  336 hours. `validate_spec_doc.py`: **6 PASS**.
- Six sets have `RISK_FIXED=1000`, `RISK_PERCENT=0`, and six zero permission
  inputs. The generation-receipt hash is intentionally earlier than the
  build-check rewrite: `compile_work_items.py:4833` captures generation bytes,
  then `build_check.ps1:389` normalizes CRLF and replaces the pending header.
  Reconstructing the pending header reproduces all six generation hashes and
  all six subsequent build-header values. No setfile was rewritten here.

Full paths, hashes, cards, registry rows, and current and generation set hashes
are in `2026-09-05_amendment_c_opt_siblings_verification.json`.

## Q02 residual: 41345

| EA | Bound run | First unresolved layer | Repair | Compile | Candidate permission evaluations | Trades | Remaining gap |
|---|---|---|---|---|---:|---:|---|
| QM5_41345 | `fb0b6989-719b-5697-998c-82fb0045cd27` | Entry hook; cause unproven, symbol-specific | None | PASS | 0 | 0 | Attribute the earlier strategy rejection before any repair or rerun |

The actual bound run is XAUUSD.DWX / D1 / Model 4 / T2,
2018.07.02 through 2022.12.31. Its 34,188-byte report is valid, the real-tick
marker is present, and deployed EX5/set identities were stable. INIT_OK and
NEWS_CALENDAR_LOADED are present; the calendar was four hours old and the
harness reports no initialization failure. The permission summary shows no
candidate reached the new permission gate. There is no demonstrated setup or
implementation defect to repair from this evidence alone, and this result
does not establish strategy failure. The evidence and hashes are preserved in
`2026-09-05_amendment_c_opt_siblings_zero_trades.json`.

The separate 41347 Q02 was initially active and was left to its worker. It
completed with PASS before the final captured dry run. Neither result was
relabeled and no active test was interrupted.

## Commit and approval receipts

Existing reservation: `e8d4550541`; source build: `222f4bdc5f`;
unbound set generation: `da19a2a70c`; compile-release receipts: `875ada61e6`;
first two compiled artifacts: `1852f31091`; third: `3e14644e4b`;
remaining three: `e75101ec12`.
The six existing `2026-09-05_amendment_c_magic_<id>.json` and
`2026-09-05_amendment_c_compile_release_<id>.json` files retain governed
allocation and release evidence. Card `g0_authority` names this task and the
OWNER-authorized Amendment C measurement scope.

Evidence is committed only on `agents/board-advisor`, as required by the
explicit scheduler instruction, using task paths. Main integration and the
independent close-out remain with Claude and OWNER. This is a build handoff;
the unresolved Q02 results prevent an all-six-program readiness claim.
