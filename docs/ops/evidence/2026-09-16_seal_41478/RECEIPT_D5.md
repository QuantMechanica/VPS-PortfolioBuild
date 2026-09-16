# RECEIPT — OWNER-APPROVED DECISION 5 / QM5_41478 re-compile authority → COMPILE_OK → DL-089 service — 2026-09-16

**Operator:** Kimi subagent under Kimi interim OWNER delegation, executing
OWNER-APPROVED DECISION 5 (scope: **QM5_41478 only**).
**Authority citation:** `OWNER-DEC-Q12-SIBLING-41478-20260916-D5` (source-repair:
ZeroMemory(req) behavior-preserving, hardening-gate-verified).
**Parent:** `QM5_10911_grimes-complex-pb` — **untouched** (verdicts, evidence,
rows unchanged). No extension to any other sibling.

## 1. AUTHORITY REGISTRATION — DONE

Mechanism class: per-EA source-repair authority in
`tools/strategy_farm/compile_work_items.py` (same class as the
`QM5_41201_COMPILE_FAIL_REPAIR_*` compile-fail repair bindings; **not** a
force-rebuild allowlist entry — D4 registered 11731 on that class in parallel).

Registered (code-hardcoded, minimal entry, exact-bind):

- `QM5_41478_COMPILE_FAIL_REPAIR_PREDECESSOR_ID = 672431ad-c9eb-45d3-8ebf-057366d07b47`
- `QM5_41478_COMPILE_FAIL_REPAIR_AUTHORITY = owner_dec_q12_sibling_41478:OWNER-DEC-Q12-SIBLING-41478-20260916-D5`
- `QM5_41478_COMPILE_FAIL_REPAIR_EA_LABEL = QM5_41478_grimes-complex-pb-opt`
- `QM5_41478_COMPILE_FAIL_REJECTED_SOURCE_SHA256 = ac7476b4…f9d7f2`
- `QM5_41478_COMPILE_FAIL_REPAIRED_SOURCE_SHA256 = b0771317…7c03d8`
- `_qm5_41478_compile_fail_repair_authorized()`: binds the authority to the one
  immutable failed COMPILE_EA row (phase COMPILE_EA, status failed, verdict
  COMPILE_FAIL, payload ea_label/mq5_sha256 exact, verdict_reason
  EA_TRADE_REQUEST_UNINITIALIZED, compile_result PASS + build_check FAIL +
  failure_classes [EA_TRADE_REQUEST_UNINITIALIZED]) and to the exact repaired
  source hash. Dispatch entry added in `_source_repair_authorized`.
- Grants no backtest, gate-verdict, or general EX5-overwrite authority; cannot
  be used for any other EA.

Concurrent-edit reconciliation: D4's 11731 force-rebuild block landed in the
same file while this registration was in flight (read-before-write observed;
appended after it). Both blocks were committed together in **`98207717da`**
("register OWNER-DEC-REQUEUE-LIFT-20260916-D4 force-rebuild authority for
QM5_11731 only"); the 41478 block is byte-identical to this receipt's
description and syntax-checked from HEAD.

Dry-run proof (batch form): `enqueue-compile --from-file …
--source-repair-authority owner_dec_q12_sibling_41478:…-D5` → **ELIGIBLE**,
waived guards `EX5_ALREADY_PRESENT` + `WORK_ITEMS_EXIST`, predecessor
`[672431ad-…]` bound. (`EX5_COMMIT_GUARD`-class guards remained fail-closed
everywhere else.)

## 2. RE-COMPILE — COMPILE_OK

Canonical executor path: `farmctl enqueue-compile QM5_41478_grimes-complex-pb-opt
--source-repair-authority owner_dec_q12_sibling_41478:…-D5` (apply; explicit
label form) → work item **`4e1069af-1e71-472b-945d-c526d01dcdff`**
(activation-held) → `release_compile_wave.py --work-item-id 4e1069af… --apply`
(source re-verified = repaired hash at release) → pump/worker T9 claimed
11:49:17Z, completed 11:49:44Z.

| check | result |
|---|---|
| MetaEditor compile | **0 errors, 0 warnings** (`compile_one.errors=0`, `compile_one.warnings=0`, reason_class OK) |
| build_check (strict) | **PASS**, `failures=[]` |
| build_gate_hardening | **PASS — 0 failures, 0 warnings** (schema `qm.build-gate-hardening/v1`; `D9_trade_request_initialization.failures=0`; post-compile re-run for this receipt) |
| verdict | **COMPILE_OK** / `COMPILE_ARTIFACT_READY` |
| ex5 sha256 | **`63f340ba859627ec818713ced2d583a872b1b89e09285f2b6bb2c874e074a3d7`** (on-disk bytes match) |
| evidence doc | `D:\QM\reports\work_items\4e1069af-1e71-472b-945d-c526d01dcdff\QM5_41478\COMPILE_EA\compile_evidence.json`, contract `qm.compile-ea-evidence/v1`, sha256 `c83bc052…f951ec4` (worker-written house path) |
| setfile build_hash | stamped by the build_check.ps1 mechanism → self-referential content hash `b96a7510…f102984` (canonical regenerated setfile) |

Observation (non-failing): build_check carried one advisory-level warning
`BUILD_CHECK_DWX_ADVISORY_DWX_SPREAD_FAILCLOSED` (`.DWX` tester quotes model
zero spread). It is a warning in `warnings[]`, not a failure — `status=PASS`.
Same advisory class as house precedent QM5_41207. Left for the Q02 measurement
to adjudicate; no action taken.

## 3. SERVICE DL-089 MATRIX

`farmctl service-dl089-matrix --work-item-id 96239586-47c0-5fe2-8ef5-3d29910cc47c`:

- **Dry:** refusal flipped past "no COMPILE_OK receipt" → Q02 prerequisite
  visible (`created:false` dry mode), `applied:false`. Evidence:
  `service_dryrun_after_compile_ok.json`.
- **Apply:** first attempt deferred on `FACTORY_MUTATION_LOCK_BUSY` (live
  factory; lock waited, never forced — house rule). Retried; applied clean on
  attempt 8 (attempts 1–7 evidence: `service_apply_attempt_*.json`; attempts
  9–10 idempotent, no duplicate seed).
- **Sibling Q12 rows for 10911** (`5cf3ea75…`, `897169ba…`, `779da760…`, all
  QM5_10911/GDAXI.DWX analytic Q12 pending): dry showed all three flipping to
  the shared Q02 prerequisite → `--apply` × 3, all clean, no deferrals.
  Evidence: `service_apply_sibling_*.json`.

## 4. Q02 SEED + CENSUS STARTUP (observe-only; NOT advanced)

- **Q02 seed:** **`ac5325b0-e774-516b-a7fb-b9cd66c342cb`** (deterministic
  uuid5), kind backtest, phase Q02, ea QM5_41478, symbol GDAXI.DWX, schema
  `qm.dl089-measurement-q02-prerequisite/v1`, `subject_ea_id=QM5_10911`,
  priority OWNER_P0_DL089_MATRIX_PREREQUISITE. Bindings: mq5 `b0771317…`,
  ex5 `63f340ba…`, setfile `183ea4d8…` = the neutral-matrix base setfile
  (`…\opt_census\DL089_QM5_10911_GDAXI_DWX_2019_2025\base_setfiles\…183ea4d8….set`,
  sha256 re-verified on disk). **Status: active, claimed by T2** at capture.
- **Census cells:** none for 41478 yet — the 1,085-cell census materializes
  over subsequent service cycles only after the Q02 prerequisite PASSes.
  Service output showed `active_opt_census_cells: 0` (expected at this point).
- **Resource awareness (OWNER §9):** fleet-wide pending/active mix at capture:
  OPT_CENSUS 2,555 / Q02 532 / Q04 288 / Q12 106 / Q08 94 … — the census will
  flow through the normal OPT_CENSUS lanes with the scheduler's existing
  admission controls (cell_slots 6, lanes_per_program 2, program_slots 8 in
  the service output). Observed only; nothing reconfigured.

## 5. PRESERVED ARTIFACTS (D5 repair-authority receipt set)

| # | artifact | path | sha256 |
|---|---|---|---|
| 1 | original source (staged, pre-repair) | git blob `577907f208:framework/EAs/QM5_41478_grimes-complex-pb-opt/QM5_41478_grimes-complex-pb-opt.mq5` | `ac7476b406a206287e7a9a94dd34fe635f6a93155059d3a96f43a8c456f9d7f2` |
| 2 | failed hardening receipt (D3 attempt) | `D:\QM\reports\work_items\672431ad-c9eb-45d3-8ebf-057366d07b47\QM5_41478\COMPILE_EA\compile_evidence.json` | `7824afc7eb41ab04358b52eb2f57207345d125aafa80edfaff4a439a6eddeced` |
| 3 | repaired source (`ZeroMemory(req);`, committed 89980c99cb) | `framework/EAs/QM5_41478_grimes-complex-pb-opt/QM5_41478_grimes-complex-pb-opt.mq5` | `b0771317d8c8fd4c7491ade67dc1ea770a110bcd603b134b3c0aa54e6b7c03d8` |
| 4 | new repair-authority receipt (D5 COMPILE_OK) | `D:\QM\reports\work_items\4e1069af-1e71-472b-945d-c526d01dcdff\QM5_41478\COMPILE_EA\compile_evidence.json` | `c83bc052cb274ba2663e8d7b7808c2c2dda75a463f55b79bb6f504334f951ec4` |

Related committed/binary identity: ex5 `63f340ba…a3d7` (uncommitted at D3 per
EX5_COMMIT_GUARD, committed now under this D5 governed receipt); setfile
(committed form) sha256 `859189ff…d9566` with build_hash stamp `b96a7510…`.

## 6. COMMITS (path-scoped, branch `agents/board-advisor`)

| commit | content |
|---|---|
| `98207717da` | tools/strategy_farm: 41478 source-repair authority (this D5 registration, together with D4's 11731 force-rebuild block) |
| this commit | ex5 (EX5_COMMIT_GUARD-passing, receipt-bound) + regenerated/stamped setfile + this evidence directory |

**STOP:** none. Execution boundary per D5: after apply, verify Q02 seed +
observe census startup — **no further advancement** (Q02 verdict, census
materialization, Q13/Q14 remain for the normal pipeline).
