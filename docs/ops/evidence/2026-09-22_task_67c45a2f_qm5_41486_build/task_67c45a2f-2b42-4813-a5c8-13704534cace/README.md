# Build QM5_41486 connors-rsi2-sma200-mean-reversion-d1-v2 — evidence

Task: `67c45a2f-2b42-4813-a5c8-13704534cace` (agent: claude, worktree
`agents/claude-orchestration-1`). Second-Chance v2 of `QM5_11563`
(INFRA_FAIL, never reopened), revision `b0ef5d66` (Antigravity, APPROVED).
Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41486_connors-rsi2-sma200-mean-reversion-d1-v2.md`
(repo mirror `artifacts/cards_approved/QM5_41486_connors-rsi2-sma200-mean-reversion-d1-v2.md`,
identical content, verified byte-for-byte modulo CRLF/LF).

## What changed

1. `framework/EAs/QM5_41486_connors-rsi2-sma200-mean-reversion-d1-v2/QM5_41486_connors-rsi2-sma200-mean-reversion-d1-v2.mq5`
   — byte-exact clone of the parent `QM5_11563_connors-rsi2-sma200-mean-reversion-d1.mq5`
   with only identity strings changed (`qm_ea_id` 11563 -> 41486; description,
   header comment, `req.reason` LONG/SHORT tags, `INIT_OK` log event name).
   All mechanical parameters (RSI(2)/SMA(200) thresholds, ATR safety stop,
   Friday/spread filters, news/risk/friday-close framework inputs) are
   unchanged — matches the card's DSR single-configuration contract, which
   locks the same values as the parent. Diff vs. parent confirmed
   identity-only (see below).
2. `framework/EAs/QM5_41486_connors-rsi2-sma200-mean-reversion-d1-v2/SPEC.md`
   — new spec, records the Second-Chance lineage, the identity-only delta,
   and the registry identity.
3. Setfiles generated via `framework/scripts/gen_setfile.ps1` (governed
   generator, not hand-written) for the three card-target symbols:
   - `sets/QM5_41486_connors-rsi2-sma200-mean-reversion-d1-v2_EURUSD.DWX_D1_backtest.set` (slot 0)
   - `sets/QM5_41486_connors-rsi2-sma200-mean-reversion-d1-v2_GBPUSD.DWX_D1_backtest.set` (slot 1)
   - `sets/QM5_41486_connors-rsi2-sma200-mean-reversion-d1-v2_USDJPY.DWX_D1_backtest.set` (slot 2)
   `RISK_FIXED=1000` / `RISK_PERCENT=0` (Build Guardrail compliant, ENV=backtest).
   `build_hash` field is `pending` — no `.ex5` exists yet (governed compile not
   yet run; see Blocker below).

## Identity / registry (already governed, not touched by this task)

| Field | Value |
|---|---|
| `qm_ea_id` | 41486 |
| Magic EURUSD.DWX (slot 0) | 414860000 |
| Magic GBPUSD.DWX (slot 1) | 414860001 |
| Magic USDJPY.DWX (slot 2) | 414860002 |
| Registry commit | `ae8ea16228` (governed magic allocator; `framework/registry/magic_numbers.csv` + `QM_MagicResolver.mqh` regen) |
| `ea_id_registry.csv` row | `41486,connors-rsi2-sma200-mean-reversion-d1-v2,278c6e13-0726-5779-83fe-a38f5a2e480f,active,Fable,2026-09-21,,,` (line 4969) |

No edits were made to `magic_numbers.csv` or `ea_id_registry.csv` (constraint
honored; rows already existed on the canonical side, see Blocker below for how
they became visible in this worktree).

## Hashes

```
source (.mq5) sha256: b91bad98c2a9299fc577ef594dd6d0787894cbccee617186c8eccc37b363cae2
set EURUSD.DWX sha256: dd1451dab94f7a8080e57c65dfcbef5c01af27e0ba061ef9e1fdd6cbfced74dc
set GBPUSD.DWX sha256: deac39155854d1eb278f711cb9793c17909cdb56bc3a6814dc645b05227e0785
set USDJPY.DWX sha256: ee5e715b284f6e8a42812b55f55490e8d0ac74c88dac80b3a9b865c3aeaeb586
```

## Pre-existing infra defect found and repaired: worktree 6271 commits stale

At session start this worktree (`agents/claude-orchestration-1`) was **6271
commits behind, diverged by 8 local commits** from canonical `origin/main`
(merge-base `2026-08-21`, tip `f1a7b2aaf0` dated `2026-09-22T09:05:45+02:00`
vs. canonical `0275fc67dc` dated `2026-09-22T09:30:15+02:00` — i.e. this
branch had not been synced with main in roughly a month of factory activity).
Consequences observed before repair:
- `framework/registry/magic_numbers.csv` / `ea_id_registry.csv` had no rows
  for QM5_41486 (registry commit `ae8ea16228` was not an ancestor of this
  worktree's HEAD), even though the task payload asserted the rows
  "ALREADY EXIST".
- `framework/scripts/build_check.py` (named in the generic SOP) did not
  exist in this worktree at all (only `.ps1`), confirming the toolchain was
  stale relative to current convention.

Repair (per launcher instruction "if it is behind, fast-forward it first";
literal fast-forward was impossible given genuine divergence, so a merge was
used instead — local-only, reversible, does not touch `main` or any other
worktree):
1. `26` pre-existing uncommitted files were found dirty at session start
   (unrelated to this task — stale `.ex5` rebuild artifacts + `tools/strategy_farm/*`
   edits, apparently left over from an interrupted prior session on this
   worktree). The 3 staged `.ex5` binaries were rejected by the
   `validate_ex5_commit_guard` pre-commit hook
   (`NO_GOVERNED_COMPILE_EA_RECEIPT`) and were reverted to HEAD. The
   remaining 23 files were committed as a WIP set-aside commit
   (`add950194e`) to get a clean tree for the merge, per worktree-discipline
   guidance to never discard unreviewed uncommitted work.
2. `git merge --no-edit -X ours 0275fc67dc` (canonical `origin/main` tip,
   commit `4331c0db98`). Verified clean: `git diff 0275fc67dc HEAD --
   framework/registry/magic_numbers.csv framework/registry/ea_id_registry.csv
   framework/include/QM/QM_MagicResolver.mqh` is empty, i.e. the shared
   registry/resolver files landed byte-identical to canonical — the `-X ours`
   strategy did not silently discard any canonical registry state.
3. Post-merge, the QM5_41486 registry rows, resolver entries, and the current
   `build_check.ps1` / `gen_setfile.ps1` toolchain became visible.

**Blast radius:** this worktree branch only (`agents/claude-orchestration-1`).
Not main, not `cto_main`, not pushed to `origin`. Fully reversible
(`git reset` to `f1a7b2aaf0` recovers the pre-merge state; the WIP commit
preserves the pre-existing dirty files either way).

This is reported as GRÜN-autonomy infra repair (does not touch verdict
logic; test = the registry/resolver diff-empty check above; rollback =
documented; blast radius = this worktree only) per the Stehende Vollmacht.

## Blocker: governed COMPILE_EA row not yet enqueued

`python tools/strategy_farm/farmctl.py enqueue-compile QM5_41486_connors-rsi2-sma200-mean-reversion-d1-v2 --build-task-id 67c45a2f-2b42-4813-a5c8-13704534cace`
was attempted and refused:

```
[ABORT] farmctl 'enqueue-compile' is a state-mutating command and must run
from the canonical checkout (C:\QM\repo\tools\strategy_farm\farmctl.py).
Current script: C:\QM\worktrees\claude-orchestration-1\tools\strategy_farm\farmctl.py.
```

This is correct, intended behavior (CLAUDE.md: state-mutating farmctl
commands run only from the canonical checkout; this session must never write
to `C:/QM/repo`). Re-running from the canonical path is not sufficient
either: `compile_work_items.enqueue_compile_eas` resolves EA source, SPEC,
setfiles and the approved card relative to `REPO_ROOT` (i.e.
`C:/QM/repo/framework/EAs/QM5_41486_...`), which do not exist there yet — this
task's new EA files exist only in this worktree branch
(`agents/claude-orchestration-1`) and are not yet integrated into `main`/the
canonical checkout. Per Worktree Discipline and the Main Integration hard
rule, only Claude+OWNER close-outs advance `main`.

Also attempted, and correctly refused independent of the above:
`framework/scripts/build_check.ps1 -EALabel QM5_41486_connors-rsi2-sma200-mean-reversion-d1-v2 -SkipCompile`
raised `BUILD_CHECK_LIVE_FACTORY_COMPILE_REFUSED` /
`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED` — `terminal64` processes are alive
(factory in active use), so the script's `Assert-CompilePipelineGuard` fires
unconditionally (its `-SkipCompile`-bypass path also requires
`-PresetRepairTemplatePath`/`-PresetRepairBuildHash`, which do not apply
here). This confirms `build_check`/compile is not meant to be run ad hoc from
this worktree while the factory is live; per this task's own SOP wording it
is the governed `enqueue-compile` queue path that performs the check +
compile, not a local invocation.

**Net effect:** source, SPEC, and setfiles are complete, committed, and
ready to build; the compile row and the resulting `.ex5` are pending main
integration of this branch (close-out step), after which
`enqueue-compile QM5_41486_connors-rsi2-sma200-mean-reversion-d1-v2` can run
from `C:/QM/repo` and the governed worker attaches Q02 canaries per the
velocity pump.

## Verdict

BUILD_COMPLETE_COMPILE_PENDING_MAIN_INTEGRATION — source/SPEC/setfiles for
QM5_41486 (Second-Chance v2 of QM5_11563) committed on
`agents/claude-orchestration-1`; identity-only delta vs. parent confirmed;
governed COMPILE_EA enqueue correctly deferred (farmctl canonical-checkout
guard + EA files not yet in `C:/QM/repo`) to post-merge close-out. Worktree
was also resynced from 6271 commits stale (see above), which is separately
useful infra hygiene for this branch going forward.
