# Zero-Trade `_v2` Build Pipeline

Authority: [DL-062](../decisions/DL-062_zero_trade_rework_policy.md)
Status: spec — implementation in Codex backlog
Date: 2026-05-23

This document specifies HOW a `_v2` rework EA is produced when DL-062's
trigger fires. Read DL-062 first for WHY and WHEN.

## Triggering event

Either:
- `tools/strategy_farm/zero_trade_rework_detector.py` auto-detection
  (Codex task `df9c07f1`) writes an entry to `agent_tasks` with
  `task_type=research_strategy` and a `rework_target` payload field
  pointing at the parent EA, OR
- OWNER manually decides on the 78-EA triage output (Codex task
  `306dbeca`) and signals a specific EA for rework.

Either path lands in the same workflow below.

## Identifier conventions

| Field | Convention | Example |
|---|---|---|
| `ea_id` | next free integer in QM5 namespace | `QM5_11842` |
| Suffix in dir/file names | `_v2`, then `_v3`, etc. for further reworks | `QM5_11842_moskowitz-tsmom-multiasset_v2` |
| Card slug | `<original-slug>_v2` (preserves family for archive grouping) | `moskowitz-tsmom-multiasset_v2` |
| `parent_ea_id` in frontmatter | original ea_id (string) | `QM5_1056` |
| `parent_chain` in frontmatter | comma-separated lineage (newest-first absent) | `QM5_1056` (single-rework), `QM5_1056,QM5_11842` (when v3 is built) |
| `rework_vector` in frontmatter | one of: `parameter_widening`, `signal_substitution`, `entry_relaxation` | `parameter_widening` |
| `rework_reason` in frontmatter | one-line explanation tying to the trigger | `"0 PASS on 40/40 P2 symbols, 95% zero-trade FAILs → widen RSI thresholds 70/30 → 75/25"` |

The `_vN` integer reflects rework generation, not version of same EA.
DL-062 caps at `_v3` automatically; further reworks need OWNER signoff.

## Source-tree duplication

Starting point: `framework/EAs/QM5_1056_moskowitz-tsmom-multiasset/`
Target: `framework/EAs/QM5_11842_moskowitz-tsmom-multiasset_v2/`

1. Copy entire directory tree.
2. Rename `.mq5` and `.ex5` files to match new ea_id + slug.
3. Update `#property` lines in the `.mq5` source: `link`, `description`,
   any version string.
4. Update the `MAGIC_BASE = ea_id * 10000` constant in the source —
   it shifts because ea_id changed (per `ea_id * 10000 + slot` registry
   formula).
5. Delete `sets/` subdirectory (regenerated in step "Set-file regen").
6. Delete any per-symbol `evidence/` directories (start clean).

## Required change vector (exactly one)

Per DL-062 rework trigger, a `_v2` is a fresh derivation. Pick exactly
one of the three vectors. The choice is recorded in `rework_vector`
frontmatter.

### A. Parameter widening

Loosen numerical thresholds that gate signal generation. Examples:
- RSI 70/30 → 75/25 (widen overbought/oversold window for entries)
- ATR multiplier for stop 2.0 → 2.5 (allow wider noise tolerance)
- MA period 50 → 30 (faster response)
- Volume threshold 1.5× → 1.2× (let lower-volume candles qualify)

**When to choose**: zero-trade pattern looks like "filter too strict".
The strategy logic is intact, signals just never met the threshold.

### B. Signal-logic substitution

Replace one signal-generating block with a near-equivalent. Examples:
- Crossover trigger → divergence trigger
- Bollinger Band break → ATR-channel break
- Single MA filter → dual-MA filter (cleaner trend confirmation)

**When to choose**: zero-trade pattern looks like "signal mechanism
doesn't fire in this market regime". Same edge, different detector.

### C. Entry-condition relaxation

Remove one of multiple AND-conditions (require 1 confirm instead of 2,
drop an optional filter). Examples:
- Require both RSI<30 AND price-below-MA → require only RSI<30
- Drop session filter (was "London only", now "any session")
- Drop weekday filter

**When to choose**: zero-trade pattern looks like "every condition
must hold, joint probability too low". Reduce gate count.

### NOT allowed in any vector

- Changing core mechanic of the strategy (a momentum strategy stays
  momentum, mean-rev stays mean-rev).
- Adding ML / curve-fit parameters (Hard Rule 14).
- Adding/removing RISK_FIXED vs RISK_PERCENT distinction.
- Anything that needs new framework headers or news-filter changes.

## Set-file regeneration

After source modifications, regenerate the per-symbol set files via the
canonical script:

```powershell
framework/scripts/gen_setfile.ps1 -EaId QM5_11842 -Slug moskowitz-tsmom-multiasset_v2
```

The script reads `framework/registry/tester_defaults.json` for the
canonical broker/commission/timezone assumptions and the EA's parameter
defaults from the new `.mq5` source. Output: `sets/QM5_11842_<symbol>_<tf>_backtest.set`
per supported symbol.

## Card frontmatter additions

Original card path: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1056_moskowitz-tsmom-multiasset.md`
New card path: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_11842_moskowitz-tsmom-multiasset_v2.md`

Copy + edit frontmatter:

```yaml
---
ea_id: QM5_11842
slug: moskowitz-tsmom-multiasset_v2
parent_ea_id: QM5_1056
parent_chain: QM5_1056
rework_vector: parameter_widening
rework_reason: "0 PASS on 40/40 P2 symbols, 95% zero-trade FAILs → widen RSI thresholds 70/30 → 75/25"
generation: 2          # 1 = original, 2 = first rework, 3 = second rework, …
status: APPROVED       # _v2 inherits APPROVED from original (no re-G0; that's the policy benefit)
created_at: 2026-05-23T..
…(rest of original frontmatter, updated as needed)
---
```

Body stays mostly intact, with one prepended section explaining the
rework decision:

```markdown
## Rework note (_v2, supersedes QM5_1056)

…1-2 paragraphs explaining the vector and reasoning…
```

Original card is NOT deleted — it becomes historical archive.

## Original EA disposition

Mark the parent EA as superseded in `agent_tasks`:

```sql
UPDATE agent_tasks
   SET state = 'RECYCLE',
       artifact_path = artifact_path || ' | superseded by QM5_11842 per DL-062'
 WHERE ea_id = 'QM5_1056'
   AND state IN ('APPROVED', 'PASSED', 'PIPELINE');
```

The dashboard render code already handles `state=RECYCLE` as the new
`s-recycled` lane (Codex task `cdc58628`).

Original work_items stay as historical evidence — not deleted, not
re-enqueued.

## Pipeline re-entry

The `_v2` EA enters at **Q00** (intake). No gate skipping. It must
clear G0 review again (the parent's G0 PASS does not transfer — a
different parameter set or signal substitution is a different research
artifact).

Standard flow:
1. Q00 intake → Q01 build → Q02 P2 backtest → … → Q11 portfolio
2. If the rework was effective, P2 produces trades on at least some
   symbols → no longer zero-trade → not a re-trigger.
3. If the rework was NOT effective (`_v2` also zero-trade), the
   detector fires again → `_v3` is queued.
4. `_v3` failing → DL-062 escalate-to-OWNER threshold.

## Codex implementation breakdown

This spec needs four implementation pieces, each as its own Codex task:

1. **ea_id allocator** (`tools/strategy_farm/ea_id_allocator.py`)
   - Reads existing ea_ids from `agent_tasks` + filesystem
   - Returns next free integer in QM5 namespace
   - Concurrency-safe (advisory lock or unique-constraint retry)
   - Tests for collision detection

2. **`_v2` builder script** (`tools/strategy_farm/build_v2.py`)
   - Input: parent ea_id + rework_vector + rework_reason
   - Performs source-tree duplication, magic-base shift, .mq5 edits,
     set-file regen via gen_setfile.ps1
   - Outputs new card markdown with proper frontmatter
   - Dry-run mode (no writes) + apply mode
   - Tests for filename conflicts, magic-base correctness

3. **Original-EA disposition handler** (extend `tools/strategy_farm/agent_router.py`)
   - New command `mark-recycled --ea-id QM5_1056 --superseded-by QM5_11842`
   - Updates agent_tasks state + appends note
   - Tests for idempotency

4. **End-to-end orchestrator** (`tools/strategy_farm/v2_rework_orchestrator.py`)
   - Picks up a `research_strategy` task with `rework_target` payload
   - Routes Claude (review skill) to design the change vector
   - Routes Codex (build_ea skill) to execute build_v2.py with the
     designed vector
   - Calls disposition handler on parent
   - Tests for end-to-end happy path + failure recovery

Each piece is a separate Codex task (or pair of tasks: design then
implement). Total estimated effort: 4-6 Codex sessions + 1-2 Claude
design sessions.

## Verification before first auto-rework

Before the pipeline is allowed to auto-spawn its first `_v2`:
1. All four implementation pieces above must be code-reviewed + tested.
2. A manual test rework (OWNER-driven, single EA from the 78-list)
   must clear Q00→Q02 successfully.
3. The dashboard's `s-recycled` lane (Codex task `cdc58628`) must
   render correctly with at least one populated row.
4. OWNER signs off on automatic activation.

Until those four conditions hold, the detector (Codex task `df9c07f1`)
runs in **label-only mode** — it writes candidates to agent_tasks but
the orchestrator does NOT consume them automatically. OWNER processes
candidates manually.

## Open questions for OWNER

These need decisions before the orchestrator goes live:

- **Auto-design vs Claude-in-the-loop**: should the change vector be
  picked by an algorithm (e.g., "always start with parameter widening,
  then signal substitution, then entry relaxation")? Or should Claude
  always read the strategy card + propose a vector tailored to the
  specific EA?
  - Default proposed: Claude-in-the-loop (more deliberate, fewer
    thrashing reworks).
- **Daily cap**: how many auto-reworks per day? If unbounded, factory
  could spawn dozens of `_v2`s in a single Pump cycle.
  - Default proposed: max 3 reworks per day, prioritized by parent
    FAIL count descending.
- **Notification**: should OWNER get a daily Gmail digest of auto-
  spawned `_v2`s? Or only on escalation?
  - Default proposed: include in existing 06:05 health digest.
