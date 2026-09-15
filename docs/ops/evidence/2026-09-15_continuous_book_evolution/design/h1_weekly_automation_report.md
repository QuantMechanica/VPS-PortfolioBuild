# Slice h1_weekly_automation — Weekly book-evolution ceremony automation (Phase H)

Date: 2026-09-15. Authority: OWNER-DEC-CBE-20260915 (directive §6, §61, §64, §68H, §70;
follow-up §12). Author: implementation subagent (board-advisor worktree). Branch
`agents/board-advisor` (base `22597ce2a2`).

## What this slice does

Turns the reserved Phase-H task names in `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md` §7 into a
working, deterministic, idempotent weekly ceremony driven end to end by one runner. It
composes the already-landed pieces (recompose engine E1, ftmo package F1, read-models D1/D2,
agent_chain cross-vendor critic, owner_decisions mechanism, tlive verify tooling) — it does
**not** re-implement portfolio math, fitness, or the critic chain.

The follow-up §12 requirement is met: the weekly recomposition dry run concludes KEEP or
CHANGE with **no candidate-count condition anywhere** (a regression test greps the runner
source for a bare `25` and fails if one appears).

## Files changed / added

New:
- `tools/strategy_farm/book_evolution_runner.py` — the ceremony runner. Subcommands
  `friday-cut`, `saturday-analysis`, `sunday-recommendation`, `runtime-verify`, `status`,
  `readmodels`. Deterministic; every subcommand idempotent; logs to
  `D:/QM/strategy_farm/logs/book_evolution.log`.
- `tools/strategy_farm/install_book_evolution_scheduled_tasks.ps1` — SYSTEM-principal
  installer for the five scheduled tasks (`-Uninstall`).
- `tools/strategy_farm/tests/test_book_evolution_runner.py` — regression tests.

Edited:
- `tools/strategy_farm/owner_decision_store.py` — new `upsert_open_item()`: idempotently
  surfaces an OPEN OWNER decision card into the existing feed (created → unchanged on re-run;
  a terminal DECIDED/SUPERSEDED card is never re-opened). Reuses the store's own validation,
  locking and Vault sync. Additive; no existing behaviour changed.
- `docs/ops/CONTINUOUS_BOOK_EVOLUTION.md` — §7 rewritten from "reserved / Phase H work / does
  not exist yet" to the **implemented** contract (commands, task names, artifact paths,
  idempotency, what OWNER receives).

Also created (outside the repo, runtime/company docs):
- Vault `04 Processes/Weekly Book Recomposition.md` — the process page (written by hand;
  Obsidian links to Mission Control and the Book Evolution index; marked IMPLEMENTED
  2026-09-15).
- Runtime dry-run artifacts under `D:/QM/reports/book_evolution_dryrun/2026-W38/...` (below).

## Contracts written

- Cut manifest: `qm.book-evolution-cut/v1` (`cut_manifest.json`; CLOSED; sha256 of every
  frozen input; frozen instant = the ISO week's Friday 21:15 UTC close; git commit).
- Cross review: `qm.book-evolution-cross-review/v1` (`<venue>_cross_review.json`;
  `cross_vendor` true/false/null, critic seat, verdict pointer, `blocked_on_quota`).
- Runtime verify: `qm.book-evolution-runtime-verify/v1` (`verify.json`; read-only).
- Status: `qm.book-evolution-status/v1`.
- Analysis / recommendation indices: `qm.book-evolution-analysis/v1`,
  `qm.book-evolution-recommendation/v1`.
- OWNER decision card id contract: `BOOK-EVOLUTION-<ISO-WEEK>-<VENUE>` (deterministic,
  idempotent) in the existing `qm.owner-decisions/v2` feed.
- Directory layout: `D:/QM/reports/book_evolution/<ISO-week>/cuts/<cut-id>/{snapshot,inputs,
  analysis,OWNER_DECISION_PACKAGE.md,verify.json}` + `active_cut.json` pointer.

## Tests + pytest summary

`python -X utf8 -m pytest tools/strategy_farm/tests/test_book_evolution_runner.py -q`
→ **9 passed in 1.2s**.

Coverage maps to the slice list: end-to-end dry run concludes KEEP for an unchanged fixture
and CHANGE for a clearly superior challenger; byte-identical package + evaluation on re-run;
no count condition in the runner source (regex for a bare `25`); decision-card idempotency
(created → unchanged; revision stable) + terminal card kept; `friday-cut` refuses to
overwrite a CLOSED cut and `--force-new-cut` mints a new id; `runtime-verify` writes only
`verify.json`; cross-review gating never blocks the analysis.

`owner_decision_store` suite (touched file):
`python -X utf8 -m pytest tools/strategy_farm/tests/test_owner_decision_store*.py -q`
→ **14 passed**.

Neighbour note: `test_recompose_engine.py::VenueFitnessSeparationTests::
test_ftmo_degrades_to_not_evaluated_when_module_absent` FAILS at the base commit — a
PRE-EXISTING E1/F1 cross-slice staleness (F1's `ftmo/ftmo_fitness.py` now exists, so
`venue_fitness` no longer degrades to NOT_EVALUATED). This slice touches neither
`venue_fitness` nor `ftmo_fitness`; it is not a regression from h1. Left for the E1/F1
owners to reconcile (the E1 test's "F1 module is not present in this worktree" assumption is
stale).

## Real dry run (ISO week 2026-W38, the ceremony week)

Ran into a SEPARATE root so the existing E1 W38 evaluation was not disturbed (verified:
`D:/QM/reports/book_evolution/2026-W38/` still holds only `dxz/`, `ftmo/` — no `cuts/`):

```
book_evolution_runner.py friday-cut          --week 2026-W38 --cut-id dryrun-20260915 --root D:/QM/reports/book_evolution_dryrun --no-state-builds
book_evolution_runner.py saturday-analysis   --week 2026-W38 --cut-id dryrun-20260915 --root D:/QM/reports/book_evolution_dryrun --no-cross-review-apply
book_evolution_runner.py sunday-recommendation --week 2026-W38 --cut-id dryrun-20260915 --root D:/QM/reports/book_evolution_dryrun --no-owner-card --no-vault
book_evolution_runner.py runtime-verify      --week 2026-W38 --cut-id dryrun-20260915 --root D:/QM/reports/book_evolution_dryrun
```

- Produced package: `D:/QM/reports/book_evolution_dryrun/2026-W38/cuts/dryrun-20260915/OWNER_DECISION_PACKAGE.md`.
- **DXZ outcome: ADD_SLEEVE** (add `10700 XAUUSD.DWX`; material=True; block-bootstrap CI
  excludes 0) — `owner_action = REVIEW_PROPOSED_CHANGE`; the card that WOULD be enqueued is
  `BOOK-EVOLUTION-2026-W38-DXZ` (not enqueued — `--no-owner-card`). Independently reproduces
  the human-planned v2 cutover and the E1 real run.
- **FTMO outcome: CONTINUE_OBSERVATION** — `owner_action = NONE` (FTMO_FITNESS first-passage
  not yet computed; representative demo not complete). No card.
- Cross-review: `gated` for both venues (no critic seat available under the current quota
  flags) — honest fallback `cross_vendor = null`, recorded, never blocked.
- `runtime-verify`: DXZ profile `EVIDENCE_MISSING` (no book-v2 live profile yet), FTMO demo
  `roster_hash` matches the frozen cut (OK); overall `INCOMPLETE`; only `verify.json` written.
- Determinism verified: a second `sunday-recommendation` produced a byte-identical package
  (sha256 unchanged); a second `friday-cut` for the week is REFUSED (CLOSED cut).
- Production `owner_decisions.json` untouched (no `BOOK-EVOLUTION` card present).

## Determinism / boundaries

Deterministic code for all numbers; the cut's frozen instant is the ISO week's Friday-close
(fixed), so evaluation + package are a pure function of the frozen inputs (§70). No farm-DB
write (DB read-only in the engine), no `terminal64` start, no deployment, no AutoTrading
toggle, no FTMO purchase, no gate/verdict change, no evidence rewrite. The CHANGE technical
artifacts are emitted as DRY-RUN command strings only — never executed. The OWNER card carries
no execution authority beyond the printed yes/no effect.

## Rollback

- Delete `tools/strategy_farm/book_evolution_runner.py`,
  `tools/strategy_farm/install_book_evolution_scheduled_tasks.ps1`,
  `tools/strategy_farm/tests/test_book_evolution_runner.py`; revert the `owner_decision_store.py`
  `upsert_open_item` hunk and the `CONTINUOUS_BOOK_EVOLUTION.md` §7 hunk. No DB/state migration.
- If the tasks were installed: `install_book_evolution_scheduled_tasks.ps1 -Uninstall`.
- Generated reports under `D:/QM/reports/book_evolution*` are additive diagnostics (no
  verdicts); remove `D:/QM/reports/book_evolution_dryrun/` to drop the dry-run rehearsal.

## Items NOT done (with reasons)

- **Test file location** — placed at `tools/strategy_farm/tests/test_book_evolution_runner.py`
  (not the literal `tests/` in the brief). There is no top-level `tests/` package; the farm
  suite + its `conftest.py` (sys.path, isolated ledgers) live under `tools/strategy_farm/tests/`,
  so a test there is actually collected and importable. Deliberate deviation.
- **Scheduled tasks not registered** — per the slice, only the installer script is written;
  the orchestrator runs it (a subagent never registers tasks).
- **`friday-cut --no-state-builds` used for the dry run** — the scheduled friday-cut refreshes
  the four read-models first; the dry run froze the already-current read-models to avoid
  re-observing the FTMO demo terminal during a rehearsal. The 15-min `readmodels` task keeps
  them fresh in production.
- **Cross-vendor critic ran gated in the dry run** — no critic seat was open under the current
  quota flags; the design records this honestly and does not block. When a seat is open the
  scheduled `saturday-analysis` (apply) runs the real cross-vendor critique.

## Exact commands the orchestrator must run

1. Install the tasks (elevated):
   `powershell -File tools/strategy_farm/install_book_evolution_scheduled_tasks.ps1`
   (add `-RunNow` to fire once immediately; `-Uninstall` to remove).
2. Nothing else is required for the weekly cadence; the tasks self-drive. The Sunday task
   enqueues at most one OWNER decision card per CHANGE venue into Mission Control.
