# Adversarial review — slice `h1_weekly_automation` (Phase H weekly ceremony automation)

Reviewer: Claude (adversarial). Date: 2026-09-15.
Patch: `scratchpad/patches_h/h1_weekly_automation.patch`.
Repo HEAD at review: `22597ce2a2` (matches the implementer base).
Verdict: **ACCEPT_WITH_FIXES**.

## Scope verified against the task

Directive §6/§61/§64/§68H/§70 + follow-up §12. All five subcommands present
(`friday-cut`, `saturday-analysis`, `sunday-recommendation`, `runtime-verify`,
`status`, plus `readmodels`), the SYSTEM installer, the tests, and the real
2026-W38 dry run.

## Checks run

- **`git apply --check` against HEAD `22597ce2a2`: exit 0** (no conflicts).
- **Tests (run from the implementer worktree, where the code lives):**
  `python -X utf8 -m pytest tools/strategy_farm/tests/test_book_evolution_runner.py -q`
  → **9 passed in 1.28s**. `upsert_open_item` present in the worktree store.
- **Determinism / §70 reproducibility — CONFIRMED real:** re-ran
  `sunday-recommendation --week 2026-W38 --cut-id dryrun-20260915 --root
  D:/QM/reports/book_evolution_dryrun --no-owner-card --no-vault` from the worktree;
  `OWNER_DECISION_PACKAGE.md` sha256 byte-identical before/after
  (`d42998e0…99ab23`). (An earlier re-run from the canonical repo path produced a
  *false* match because the runner is not yet applied to the working tree and the
  command silently no-op'd; the real match above was produced from the worktree
  after confirming the command actually executed.)
- **Runtime artifacts are real and honest.** `cut_manifest.json` is `CLOSED`,
  carries sha256 of all six frozen inputs (all `PRESENT`), git commit
  `22597ce2a2`, seed derived from the frozen instant, and real venue snapshot
  hashes (dxz pool=26 / 44 streams; ftmo pool=26 / 26 streams). `verify.json` is
  read-only, DXZ profile `EVIDENCE_MISSING` (no book-v2 profile yet), FTMO demo
  `roster_hash` matches the frozen cut, overall `INCOMPLETE`. The package answers
  the §9 questions with genuine engine numbers and the §72 executive block is
  populated from the real read-models (real FTMO demo breach `-10.26%`, real
  factory bottleneck text, real Kimi `auth_error`).
- **No production disturbance.** Real `D:/QM/reports/book_evolution/2026-W38/`
  holds only `dxz/`+`ftmo/` (no `cuts/`). Production
  `D:/QM/reports/state/owner_decisions.json` has **0** `BOOK-EVOLUTION` cards
  (dry run used `--no-owner-card --no-vault` + separate root). Cross-review
  honestly `gated` with `cross_vendor: null` and the real reason recorded
  (`claude_disabled_flag`), never blocking the analysis.
- **RED-touch sweep: clean.** Files touched: the runner, the installer, the tests
  (new); `owner_decision_store.py` (purely additive `upsert_open_item`, inserted
  after `record_decision`, no existing function changed); `CONTINUOUS_BOOK_EVOLUTION.md`
  §7 (authorized by the task). No gate-manifest/threshold edits, no verdict writes,
  no farm-DB (`farm_state.sqlite`) writes, no `.ex5`/setfile writes, no T_Live /
  AutoTrading toggle (CHANGE artifacts are emitted as DRY-RUN command strings
  only), no in-place edits of dated `decisions/*` or sealed artifacts, no secrets/
  tokens. Owner-card id regex + required fields validated by the store’s own
  `_validate_item`.
- **Installer:** faithfully mirrors `install_kimi_governor_scheduled_task.ps1`
  (SYSTEM principal, `-X utf8`, IgnoreNew, same default pythonw path — which exists
  on this VPS: both `C:\Python311\pythonw.exe` and the AppData path are present).
  `-Uninstall` present.

## Findings

### MAJOR — `runtime-verify` scheduled on Monday targets the WRONG ISO week (fails weekly)

`QM_BookEvolution_RuntimeVerify` is registered for **Monday 06:30** with args
`runtime-verify` and **no `--week`**. The runner defaults the week to
`iso_week_of(_now().date())`. ISO weeks run Mon–Sun, so:

- Fri cut → `2026-W38`; Sat analysis → `2026-W38`; Sun recommendation → `2026-W38`
  (all correct, same ISO week), but
- **Mon runtime-verify → `2026-W39`** (the *next* ISO week), where no cut exists.

Confirmed both ways:
`iso_week_of(2026-09-21)` → `2026-W39`; and
`runtime_verify(iso_week='2026-W39', root=…dryrun)` **raises**
`BookEvolutionError: no CLOSED cut at …\2026-W39\cuts\c1`.

Consequence: the Monday task raises before writing `verify.json`, so §61’s
“after OWNER action: verify runtime identity and state” never runs for the week
OWNER just acted on. Fails safe (read-only, no corruption) but the phase is
non-functional as scheduled. Fix is trivial — one of: default `runtime-verify`
to the *previous* ISO week (or the most-recent CLOSED cut across weeks), or have
the installer pass an explicit prior-week reference to the Monday task. The
subcommand itself is correct when given the right `--week`.

### MINOR — card evidence path ignores `--root`

`sunday_recommendation` hardcodes `package_rel =
"D:/QM/reports/book_evolution/<week>/OWNER_DECISION_PACKAGE.md"` for the card’s
`evidence`, regardless of `--root`. Harmless in production (root is the default)
and moot under `--no-owner-card`, but a custom-root run that *did* enqueue a card
would point OWNER at the wrong (production) path. Low impact.

### MINOR — `readmodels` 15-min task can exceed its 5-min limit

`readmodels` runs four sub-builds each with a 300s timeout; the task’s
`ExecutionTimeLimit` is 5 min. A slow `ftmo.demo_cycle build` (terminal
observation) could be killed mid-build by the OS limit. Per-spec (the task
requires those four builds) and self-healing on the next tick, but worth a note.

## Notes (not defects)

- Deliberate deviations are honestly disclosed: test file under
  `tools/strategy_farm/tests/` (no top-level `tests/` package exists — correct),
  scheduled tasks not registered (subagent never registers tasks), dry run used
  `--no-state-builds` to avoid re-observing the FTMO terminal during rehearsal.
- Pre-existing unrelated failure `test_recompose_engine.py::…
  test_ftmo_degrades_to_not_evaluated_when_module_absent` is an E1/F1 cross-slice
  staleness, not introduced by this slice.

## Conclusion

Core ceremony (Friday cut → Saturday analysis → Sunday recommendation) is
deterministic, reproducible from frozen inputs (§70 verified byte-identical),
idempotent, honest, and stays entirely inside GREEN boundaries — no RED touch.
One MAJOR functional defect: the Monday `runtime-verify` task defaults to the
rolled-over ISO week and fails every week; two MINOR items. All are isolated and
trivially fixable, none block the slice’s substance. **ACCEPT_WITH_FIXES.**
