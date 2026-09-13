# Stale COMPILE_EA rollout re-issue (2026-09-13)

Governed, append-only re-issue of stale `COMPILE_EA` rows so the compile queue
moves again. The whole held rollout wave was stale:
`release_compile_wave.py --apply` released 0 of 12 (every held
`COMPILE_EA_WORKER_ROLLOUT_PENDING` row deferred `SOURCE_SHA_STALE_OR_MISSING`),
because sources were patched after the rows were pinned.

- Tool: `tools/strategy_farm/session_tools/reissue_stale_compile_rows_0913.py`
- Tests: `tools/strategy_farm/tests/test_reissue_stale_compile_rows_0913.py` (9 passed)
- Plan: `plan.json` in this directory
- **plan_sha256: `d7518a03ba4d1ed29162d501b11d4f547d8c043fefd461c921028bb70458017c`** (deterministic)
- Mechanism: `compile_work_items.enqueue_compile_eas(..., apply=True, source_repair_authority=ROLLOUT_RECONCILIATION_SOURCE_REPAIR_AUTHORITY)`.
  The library creates one activation-held successor per label pinned to the
  CURRENT source SHA, with a `work_item_supersedes` edge back to each stale
  predecessor (never mutates the stale row). Dry-run is default; `--apply`
  requires the matching `--plan-sha256`, takes the factory mutation lock, writes a
  verified state backup, then writes a receipt.

## Disposition of the 30 pending COMPILE_EA rows (29 stale, 1 fresh)

| count | action | reason |
|---|---|---|
| 4 rows / 3 labels | **REISSUE** | held, stale, predecessor not superseded, source committed |
| 6 | skip | `USABLE_CURRENT_COMPILE_VERDICT_EXISTS` — EA already compiled at current source |
| 2 | skip | `PREDECESSOR_ALREADY_SUPERSEDED` — double source-change; library refuses at apply |
| 13 | skip | non-held vestigial — EA already has `COMPILE_OK` at current source |
| 4 | skip | non-held **ORPHAN** — not compiled at current, needs a separate path |
| 1 | untouched | fresh (`QM5_41285`, pinned == on-disk) |

### The 3 re-issued labels (create 3 successors, supersede 4 stale rows)

| label | new SHA | supersedes | commit |
|---|---|---|---|
| QM5_1538_aa-tsmom-1-3-12 | `f4d84bdfac61…` | `550b62ec`, `674da780` | `1de542e477` |
| QM5_41179_xtixng-mcoxstuart-rv | `6110e1969bf0…` | `9ced0252` | `d0433c1c1d` (symbol-input patch) |
| QM5_41189_xtixng-mlad-rv | `8989d43bb7c1…` | `e5505264` | `d0433c1c1d` (symbol-input patch) |

Rerun reason recorded per label: `source refreshed after enqueue: <commit> <subject>`.

### Uncommitted-source gate

None of the 3 actionable labels are dirty. The only dirty `.mq5` in the tree,
`framework/EAs/QM5_41233_wti-samecal-gast5/QM5_41233…mq5` (` M`), is **not** in
the pending-stale set, so nothing is excluded today. The gate is enforced anyway
(fail-closed) at plan time and re-checked at apply time.

## Reported blockers (NOT fixed here — out of the rollout-reconciliation scope)

- **2 held, double-superseded:** `QM5_41142`, `QM5_41356`. Their held predecessor
  was already superseded by a prior re-issue that compiled at an intermediate
  hash; the source then changed again. The rollout authority refuses a
  second supersede (`SOURCE_REPAIR_PREDECESSOR_ALREADY_SUPERSEDED_AT_APPLY`).
- **4 non-held orphans:** `QM5_41113`, `QM5_41123` (both today's symbol patches),
  `QM5_13128`, `QM5_9730`. Stale, not compiled at current source, non-held and
  already superseded — unreachable by the rollout authority. They need a separate
  governed path (`enqueue_repair_successor` from their terminal `COMPILE_FAIL`
  row, or a fresh `build_ea` → compile).

## Exact commands

Apply the re-issue (gated on the reviewed plan hash):

```
python -X utf8 tools/strategy_farm/session_tools/reissue_stale_compile_rows_0913.py \
  --apply --plan-sha256 d7518a03ba4d1ed29162d501b11d4f547d8c043fefd461c921028bb70458017c
```

Then release the newly source-fresh rows in staggered waves, one at a time
(re-run per wave; each `--max-items 1` release lets one compile land before the
next — thundering-herd discipline):

```
python -X utf8 tools/strategy_farm/release_compile_wave.py --max-items 1 --apply
```

## MFE include verification

The framework include `QM_Common.mqh` gained an MFE hook today (commit
`7c3e0ea6d0`). It does not change EA source hashes, but every new compile
validates the include. **The first compiles from these re-issued rows therefore
double as the live MQL5 verification of the MFE include** — watch the first
wave's build_check/compile evidence before releasing the rest. (Confirmed: the
first wave compiled QM5_41179 with MetaEditor errors=0 — MFE include OK — though
build_check then refused it, `EA_FRAMEWORK_INPUT_PINNED`, row `3f0de0a8`.)

---

# Repair-successor path for the skipped rows (2026-09-13, re-runnable)

The rollout re-issue above skipped non-held orphans, double-superseded rows, and
41179's fresh `COMPILE_FAIL`. This second lever handles them via the OTHER governed
function, `compile_work_items.enqueue_repair_successor` (append-only successor for a
terminal `COMPILE_FAIL`/`BUILD_CHECK_FAIL`, bound to an OPEN `build_ea` task, once
source is repaired). Sibling tool + test:

- Tool: `tools/strategy_farm/session_tools/repair_successor_stale_compile_rows_0913.py`
- Tests: `tools/strategy_farm/tests/test_repair_successor_stale_compile_rows_0913.py` (9 passed)
- Plan: `plan_repair_successors.json` (this dir)
- **plan_sha256: `aac8c1d4ccf8aef8c48a0fa06d498309063b7d5213d1e564da8b620f2744390f`**
- **RE-RUNNABLE.** Every disposition is recomputed from the live DB + live source on
  each run; no SHA is baked into the tool or its tests. Sources are being re-patched
  now (framework-input-pin repair, `docs/ops/evidence/2026-09-13_framework_input_pin_repair.md`),
  so re-run after each source change and re-review the new `plan_sha256`.

## Current disposition (7 targets) — 0 eligible for repair-successor right now

| EA | disposition | why | card? |
|---|---|---|---|
| QM5_41113 | `FLAG_NEEDS_FRESH_BUILD_EA` | no terminal COMPILE_FAIL row to repair from | **no** |
| QM5_41123 | `FLAG_NEEDS_FRESH_BUILD_EA` | no terminal COMPILE_FAIL row | **no** |
| QM5_13128 | `SKIP_SOURCE_NOT_REPAIRED` | newest COMPILE_FAIL is AT current source (still fails) | yes |
| QM5_9730 | `SKIP_SOURCE_NOT_REPAIRED` | newest COMPILE_FAIL is AT current source (still fails) | yes |
| QM5_41142 | `FLAG_NEEDS_OPEN_BUILD_TASK` | source repaired vs failed row, but bound build task closed | yes |
| QM5_41356 | `SKIP_ALREADY_COMPILED_AT_CURRENT` | done `COMPILE_OK` at current source (row 414447dc) | yes |
| QM5_41179 | `SKIP_SOURCE_NOT_REPAIRED` | 3f0de0a8 is AT current source; awaiting the pin repair | no |

Key facts driving the zero-eligible result: `enqueue_repair_successor` **requires an
open, identity-matching `build_ea` task**; none of the targets has one (41142's bound
task is done, the rest have none). 41113/41123 have **no approved card**, so even the
fresh-build path needs a card commissioned first — this tool never fabricates a build
task or a card.

## What unblocks each (re-run this tool after)

- **41179** (and 41113/41123/41374/41389/41397/41399): after the framework-input-pin
  repair changes the source, the newest COMPILE_FAIL is no longer at the current
  source → `SOURCE_NOT_REPAIRED` clears. 41179 then needs an open `build_ea` task
  (→ `NEEDS_OPEN_BUILD_TASK`).
- **41142**: open a `build_ea` task for it (card exists) → becomes `repair_successor`
  eligible; the tool will then plan a governed repair-successor from `b04fb953`.
- **13128 / 9730**: current source genuinely fails to compile (COMPILE_FAIL at the
  current SHA) — they need a source FIX (code), not a re-issue. Not in the pin-repair set.
- **41113 / 41123**: commission a `build_ea` (needs a card) → normal build→compile.
- **41356**: already compiled at current source; nothing to do.

## Exact command

```
python -X utf8 tools/strategy_farm/session_tools/repair_successor_stale_compile_rows_0913.py \
  --apply --plan-sha256 aac8c1d4ccf8aef8c48a0fa06d498309063b7d5213d1e564da8b620f2744390f
```

With today's plan this is a no-op (0 eligible) and will report the blockers above.
The value is on **re-run after upstream fixes**: the moment a target has a
source-repaired terminal failure plus an open build task, the same command appends the
governed append-only repair-successor (mutation lock, verified backup, receipt).
