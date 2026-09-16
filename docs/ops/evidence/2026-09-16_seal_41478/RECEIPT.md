# RECEIPT — OWNER-APPROVED DECISION 3 / QM5_41478 seal → allocation → promotion → compile → service — 2026-09-16

**Operator:** Kimi subagent under Kimi interim OWNER delegation, executing
OWNER-APPROVED DECISION 3 (scope: **QM5_41478 only**).
**Seal authority:** `OWNER-DEC-Q12-SIBLING-41478-20260916`.
**Parent:** `QM5_10911_grimes-complex-pb` — **untouched** (verdicts, evidence, rows unchanged).

## 0. Binding governance classification (recorded first, everywhere)

**QM5_41478 `grimes-complex-pb-opt` is an optimization/measurement sibling of
QM5_10911 — NOT a new edge, NOT independent diversification, NOT a new strategy
family.** It exists solely to run the DL-089 pattern-permission measurement census
against the approved parent's GDAXI book. No live or pipeline verdict is authorized
from the sibling itself.

---

## 1. SEAL — DONE

| | path | sha256 |
|---|---|---|
| BEFORE (DRAFT) | `docs/ops/evidence/2026-09-16_opt_sibling_10911/staged/strategy_card_QM5_41478_grimes-complex-pb-opt.DRAFT.md` | `798d2eeb…4e98` |
| AFTER (APPROVED) | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41478_grimes-complex-pb-opt.md` | `7d6b37e6…d9b6` |

Frontmatter set: `g0_status: APPROVED`,
`g0_authority: "OWNER-DEC-Q12-SIBLING-41478-20260916 (scope: QM5_41478 only; measurement sibling of QM5_10911; not a new edge/ diversification/family)"`.
`parent_ea_id: QM5_10911`, `period: H1`, `target_symbols: [GDAXI.DWX]`, R1–R4 all PASS.
Card body carries the explicit not-a-new-edge banner. Verified parseable by
`farmctl.parse_card_frontmatter` (all required keys read back correct).
No generic g0 seal tool exists (checked); the OWNER frontmatter act + this
hash-bound receipt IS the governed seal per processes/01-ea-lifecycle.md:32.

## 2. MAGIC ALLOCATION — DONE

Governed allocator from canonical worktree `C:/QM/repo` (default `--repo`),
exact-card mode `--card` → sealed card. Dry-run (`allocate`/`eligible`) then apply.

- **Identity row** (`framework/registry/ea_id_registry.csv:4961`): `41478,grimes-complex-pb-opt,fbfd7f6e-…,active,Research,2026-09-16`
- **Magic row** (`framework/registry/magic_numbers.csv:18507`): `41478,grimes-complex-pb-opt,0,GDAXI.DWX,**414780000**,2026-09-16,…,active`
- Resolver regenerated: `QM_MagicResolver.mqh` now contains `414780000`; allocator verification block **PASS** (identity_exact_active / magic_rows_exact_card_order / resolver_contains_every_registry_tuple all true).
- **21/21 verification tests pass** (`test_governed_magic_allocator` + `test_magic_allocation_precheck` + `test_magic_resolver_strict_default`).
- Commit **`9784505ad8`** (path-scoped: ea_id_registry + magic_numbers + QM_MagicResolver only).
- EA dir + card-of-record created by the allocator at
  `framework/EAs/QM5_41478_grimes-complex-pb-opt/docs/strategy_card.md`
  (gitignored by design — generated local artifact, not committed).

## 3. ARTIFACT PROMOTION — DONE

Promoted staged artifacts into the allocator-created EA dir (hashes match staged):

| artifact | sha256 |
|---|---|
| `QM5_41478_grimes-complex-pb-opt.mq5` | `ac7476b4…d7f2` (staged) |
| `sets/…_GDAXI.DWX_H1_backtest.set` | `0ad60a94…573f` |
| `SPEC.md` | (new sibling spec) |

- Identity strings verified: `#property description "…DL-089 opt sibling"`,
  `qm_ea_id = 41478`, `#include <QM/QM_PatternPermission.mqh>`, six `opt_pp_*`
  inputs, `Pattern_AllowsRequest` entry gate, `INIT_OK` log identity.
- `qm_magic_slot_offset=0` / `magic_slot: 0` reconciled against the registry row
  (slot 0 / magic 414780000 for the sole GDAXI target). **Reconciled.**
- Canonical readiness (re-run post-promotion): `_neutral_matrix_setfile` OK (1732 B),
  `census.validate_base_setfile` OK, `_pattern_measurement_readiness` **ready=True, 0 blockers**.
- Commit **`577907f208`** (EA .mq5 + setfile + SPEC; card-of-record stays gitignored).

## 4. COMPILE/BUILD — ATTEMPTED, gate failure fixed, re-compile AUTHORITY-BLOCKED (STOP)

### 4a. Provider-mandate determination (the step-4 contract read)

**Determination: deterministic local MetaEditor compile is the COMPILE_EA provider;
NO binding contract mandates codex (or any LLM) for this compile class.** Evidence:
- `run_compile_work_item` (`compile_work_items.py:6037`, the sole COMPILE_EA executor)
  runs `gen_setfile.ps1` then `build_check.ps1 -Strict -CompileWorkItemId … -ClaimedTerminal T#`
  → `compile_one.ps1` → `metaeditor64.exe`. No codex/LLM call.
- COMPILE_EA contract constants (`COMPILE_EA_PHASE`, `COMPILE_CONTRACT_VERSION`) carry no provider.
- `build_check.ps1` gates are deterministic (compile + magic collision + guardrails +
  `build_gate_hardening`); no provider mandate.
- `validate_ex5_commit_guard.py` requires a governed COMPILE_OK receipt (hash-bound), no provider.
- `include_mirror.py` references codex ONLY in the FTMO monitor-probe path, not the general compile.
- The OWNER decision package's "COMPILE_EA (codex lane, 09-19)" is the *operational routing
  plan* (codex quota was held to 09-19), not a contract constant. The parallel
  `QM5_11731` determination (`94680de31c`) reached the identical conclusion.

So the build was attempted via the deterministic canonical lane, NOT deferred to codex.

### 4b. What happened

1. `farmctl enqueue-compile QM5_41478_grimes-complex-pb-opt` → COMPILE_EA work item
   **`672431ad-c9eb-45d3-8ebf-057366d07b47`** (candidate ELIGIBLE; mq5 `ac7476b4`).
2. Activation hold released via governed `release_compile_wave.py --work-item-id 672431ad --apply`
   (bounded to this one item; other 13 held rows untouched). Factory mutation lock was
   contended (live factory); released cleanly once free.
3. Pump dispatched the compile worker (claimed quiescent slot). **MetaEditor compile:
   0 errors, 0 warnings, ex5 produced** (`7d367cee…b34d`). But the deterministic
   `build_gate_hardening` check **fail-closed**: `EA_TRADE_REQUEST_UNINITIALIZED` at
   OnTick — bare `QM_EntryRequest req;` reaching `Strategy_EntrySignal`/`QM_TM_OpenPosition`.
   Verdict **COMPILE_FAIL** (evidence `D:/QM/reports/work_items/672431ad…/compile_evidence.json`).

### 4c. The fix (applied + committed)

Root cause: the 7-hunk sibling transform inherited the parent's (grandfathered)
`Strategy_EntrySignal`, which assigns 5/7 required fields (omits `symbol_slot`,
`expiration_seconds`). The struct's default constructor (`QM_Entry.mqh`, 2026-07-06
audit) already zero-inits all fields, so the fix is **behavior-preserving**; it
satisfies the gate's static check and matches the house standard (`ZeroMemory(req);`,
same as passing sibling QM5_41342).

- Added `ZeroMemory(req);` after the `QM_EntryRequest req;` declaration.
- Verified: `build_gate_hardening.py` on the fixed source → **0 failures, 0 warnings**;
  build guardrails PASS; identity intact; diff vs parent = the 7 sibling hunks + this 1 line.
- Source sha256 `ac7476b4…` → **`b0771317…c03d8`**. Commit **`89980c99cb`**.
- Recompile readiness is proven (first compile was 0/0; the only failure was the gate,
  now passing) — the re-compile WILL produce COMPILE_OK once authorized.

### 4d. STOP — re-compile is authority-blocked (not a provider mandate)

The first governed compile consumed the one "free" compile for a new EA. Re-compiling
the repaired source has **no legitimate governed path without an OWNER-ratified
authority**, and minting one is outside this delegation (same boundary agent-16 held
at the seal; same conclusion as the parallel `QM5_11731` STOP):

- **Fresh enqueue** → refused `WORK_ITEMS_EXIST_AT_APPLY` (a work item now exists for 41478).
- **`--repair-successor-of 672431ad`** → refused `BUILD_TASK_BINDING_NOT_REQUESTED`:
  the successor must bind an open `build_ea` task, and **41478 has none** (staged/derived
  source, never codex-built). The reference sibling 41321 could use this path only because
  it had a `build_ea` task (`1208ad50`) to bind.
- **force-rebuild** → 41478 is not in `DL089_FORCE_REBUILD_EA_IDS` / MAE-hook / pre-0803
  allowlists, and `owner_priority_tracks.json` cannot add it (hardcoded name must also match).
- **Per-EA source-repair constant** → none exists for 41478 (all are individually governed).

**Unblock (OWNER/router act, then mechanical):** ratify a force-rebuild allowlist entry
for 41478, OR register `OWNER-DEC-Q12-SIBLING-41478-20260916` as a source-repair authority
for this EA, OR provide a scoped enqueue. Then:
`enqueue-compile --repair-successor-of 672431ad …(bound)` [or force-rebuild] →
`release_compile_wave.py --work-item-id <new> --apply` → worker compiles the fixed source
→ COMPILE_OK → step 5.

The stale ex5 from the failed compile is left **uncommitted** on disk per EX5_COMMIT_GUARD
(no COMPILE_OK; also stale vs the fixed source).

## 5. SERVICE — dry-run proves the flip; NOT applied (no compile evidence)

`farmctl service-dl089-matrix --work-item-id 96239586-47c0-5fe2-8ef5-3d29910cc47c` (dry):

- **Before:** `expected one approved _opt sibling for QM5_10911/GDAXI.DWX, found 0`
- **After:** `no COMPILE_OK receipt for QM5_41478`  (`applied=false`)

The refusal **flipped** — the sibling is now fully discovered (seal + allocation +
promotion + readiness all recognized); the single remaining blocker is the COMPILE_OK
receipt. **`--apply` was deliberately NOT run**: step 5's own precondition ("once
compile evidence exists") is unmet, and applying without a COMPILE_OK would be
advancing past what the service can legitimately do. Evidence:
`service_dryrun_after_96239586.json`.

## 6. State left behind

- **Card** sealed in `cards_approved` (outside repo). **Registry + resolver** committed
  (`9784505ad8`). **EA source + setfile + SPEC** committed (`577907f208`, `89980c99cb`).
- **DB:** one failed COMPILE_EA row (672431ad) + its released hold; the source fix is
  bound to no work item yet (awaits the authorized re-compile). No verdicts fabricated.
- **Parent 10911:** untouched. **11294 / 20086 / all others:** untouched (out of scope).

## 7. Claimable delta

The `QM5_10911`/`GDAXI.DWX` Q12 frontier pair went from **"no approved sibling"** to
**"sibling sealed, allocated (magic 414780000), promoted, readiness-green; pending
COMPILE_OK"**. The moment the re-compile is authorized and passes, the service flips to
Q02-seeded on `--apply` and the DL-089 census materializes over subsequent cycles.

## 8. Commits (path-scoped, on the mainline integration branch `agents/board-advisor`)

| commit | content |
|---|---|
| `9784505ad8` | registry: governed allocation QM5_41478 (magic 414780000) |
| `577907f208` | EA: promote staged artifacts (.mq5 + setfile + SPEC) |
| `89980c99cb` | EA: gate-mandated zero-init of QM_EntryRequest |
