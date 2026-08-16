# Stalled build recovery review — task `fa922736-c65e-424e-a576-ecfa67120a5a`

Date: 2026-08-16  
Operator: Codex  
Checkout: `C:\QM\repo` (`agents/board-advisor`)  
Disposition: **PARTIAL RECOVERY / DETERMINISTIC HOLDS**

## Scope and safety boundary

This pass reviewed only the cohorts named in the routed task. It did not enqueue
Q02, run a pipeline phase, launch `terminal64.exe`, toggle AutoTrading, or touch
T_Live. Gemini-authored tasks remain in `REVIEW`; no Gemini build was
self-approved.

The V5 build preflight was applied before any rebuild: an OWNER-approved G0 card,
an active EA registry row, and active magic rows for every target symbol are all
required. Missing magic rows are a fail-closed precheck, not permission to invent
an allocation.

## Five Claude builds: independent close-review

Each EA was freshly compiled in strict mode (zero errors, zero warnings), checked
against its approved card, checked for every strategy input, checked for
`req.symbol_slot = qm_magic_slot_offset`, and checked against all generated
setfiles.

| EA | Review | Evidence | Router close |
|---|---|---|---|
| QM5_11533 | APPROVED | `docs/ops/evidence/abfb4871_qm5_11533_codex_review_2026-08-16.md` | APPROVED |
| QM5_11563 | APPROVED | `docs/ops/evidence/e26b6273_qm5_11563_codex_review_2026-08-16.md` | APPROVED |
| QM5_11539 | APPROVED | `docs/ops/evidence/5ea0928f_qm5_11539_codex_review_2026-08-16.md` | APPROVED |
| QM5_11537 | APPROVED | `docs/ops/evidence/985081a7_qm5_11537_codex_review_2026-08-16.md` | APPROVED |
| QM5_12401 | RECYCLE | `docs/ops/evidence/581a9957_qm5_12401_codex_review_2026-08-16.md` | RECYCLE |

QM5_12401 hardcodes `req.symbol_slot = 0` although its seven governed setfiles
select slots 0 through 6. The five review records were committed as `5a44c9659`.

## Six Gemini builds with no setfiles

All six had an approved card, an active EA registry row, and a complete active
magic-row set. `framework/scripts/gen_setfile.ps1` generated 24 `backtest`
setfiles with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1.0`.

| EA | TF | Setfiles | Strict compile | Codex review |
|---|---:|---:|---|---|
| QM5_11363 | M15 | 3 | PASS 0/0 (`20260816_091716`) | REVIEW — build-ready |
| QM5_11362 | M15 | 6 | PASS 0/0 (`20260816_091827`) | REVIEW — build-ready |
| QM5_1630 | H4 | 4 | PASS 0/0 (`20260816_091950`) | **RECYCLE** |
| QM5_1628 | H4 | 4 | PASS 0/0 (`20260816_092224`) | REVIEW — build-ready |
| QM5_20070 | M5 | 3 | PASS 0/0 (`20260816_092436`) | REVIEW — build-ready |
| QM5_20071 | H1 | 4 | PASS 0/0 (`20260816_092619`) | REVIEW — build-ready |

Mechanical verification matched every filename symbol to its active registry
row and found all 24 `qm_magic_slot_offset` values exact. The audit result was
`total=24 failures=0`. `validate_build_guardrails.py` returned PASS for all six
EA directories with the fail-closed news ceiling held at 336 hours.

Codex input-use review found no declaration-only strategy input in QM5_11363,
QM5_11362, QM5_1628, QM5_20070, or QM5_20071, and each explicitly assigns
`req.symbol_slot = qm_magic_slot_offset`.

QM5_1630 cannot be accepted despite its clean compile:

- neither entry branch assigns `req.symbol_slot`, so nonzero host slots silently
  resolve as slot 0; and
- `strategy_cooldown_bars` occurs only in its input declaration and is not wired
  into strategy behavior.

All six originating Gemini tasks therefore remain in `REVIEW`. QM5_1630 is
marked for recycle; the other five are build-ready but are not moved to PIPELINE
by this task.

## Nine Claude sources with missing EX5 artifacts

The approved cards and active EA registry rows favor **rebuild**, not retirement,
for QM5_20074, QM5_20075, QM5_20076, QM5_20082, QM5_20085, QM5_20086,
QM5_20176, QM5_20177, and QM5_20178. However, canonical preflight found zero
active magic rows for every one of the nine. Their declared symbol counts are 6,
5, 7, 6, 9, 7, 6, 6, and 6 respectively.

No setfile or EX5 was generated. The correct disposition is
`PRECHECK_BLOCK_MAGIC_ROWS`: allocate governed rows in a separately authorized
registry operation, regenerate and verify the resolver, then rebuild serially.
The prior build verdicts from other worktrees are not canonical binary evidence.

## Ten earlier PRECHECK_BLOCK builds

The ten recoverable tasks are QM5_11291, QM5_11292, QM5_11294, QM5_11299,
QM5_11300, QM5_11465, QM5_11496, QM5_11516, QM5_11517, and QM5_11518. Each
has an approved card, an active EA row, a source directory, and zero active magic
rows.

The routed task authorizes the governed `dirs -> CSV -> resolver regeneration ->
verification -> compile` sequence. It was not safe to perform in this pass:
during the review, the canonical checkout acquired unrelated, uncommitted edits
to both `framework/registry/magic_numbers.csv` and the generated
`framework/include/QM/QM_MagicResolver.mqh` (including an in-flight QM5_41021
allocation), while `agents/board-advisor` advanced through unrelated commits.
Appending and regenerating over those files would mix another operation's
uncommitted registry transaction into this task's commit. The ten existing task
states remain `REVIEW/PRECHECK_BLOCK`; no partial registry write was made.

## Net disposition

- Four Claude builds approved; one Claude build recycled.
- Five Gemini builds now have complete governed setfiles and clean strict
  compiles, but remain REVIEW as required.
- One Gemini build (QM5_1630) remains REVIEW/RECYCLE on two concrete wiring
  defects.
- Nine missing-binary Claude builds are rebuild candidates held by missing magic
  allocations.
- Ten PRECHECK builds remain held until the shared canonical registry is clean
  enough for an atomic governed allocation transaction.

No pipeline verdict is asserted by this evidence.
