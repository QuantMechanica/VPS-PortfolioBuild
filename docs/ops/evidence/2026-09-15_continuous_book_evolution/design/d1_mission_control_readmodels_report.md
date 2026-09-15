# Slice d1_mission_control_readmodels — implementation report

OWNER-DEC-CBE-20260915 · Directive §3, §60, §62, §72 · authored 2026-09-15.
Branch `agents/board-advisor`, worktree `wf_4fa62b18-d2d-1`.

## What this slice did

Replaced the abolished "Way to 25" primary objective block in Mission Control
(cockpit v2) with the **Book Evolution primary view** (DXZ · FTMO · Research ·
Factory) plus the **FTMO Challenge Readiness** block, all bound verbatim from the
shared read-models and degrading to `EVIDENCE_MISSING` when a read-model is
absent (E1/F1/G1 produce them in parallel — this slice does not wait on them).
Added the deterministic `factory_bottleneck.json` producer (§72), the
`book_evolution_health` keys, and the tests. Diagnosed the
`QM_StrategyFarm_Cockpit_2min` `0x800710E0` abort.

## Files changed

- **NEW** `tools/strategy_farm/factory_bottleneck_readmodel.py` — writes
  `D:/QM/reports/state/factory_bottleneck.json` (`qm.factory-bottleneck/v1`)
  deterministically from `farm_state.sqlite` (RO), `pipeline_state.json`
  (`by_gate_v4` frontier + `book_guard`), `drain_window.json`, and the
  `terminal_worker_T*.log` tails (latest `claim_result` per terminal → idle-in-
  drain count vs claimable-pending). Resources: D: free via `shutil`; CPU/RAM via
  `psutil` when importable, else `UNKNOWN` (never invented). Top-3 bottlenecks are
  ranked deterministically. Also owns the shared `load_readmodel` loader and
  `compute_book_evolution_health` + writes `book_evolution_health.json`
  (`qm.book-evolution-health/v1`) for the vault Heartbeat.
- `tools/strategy_farm/mission_control_v2_data.py` — added read-model path
  constants (monkeypatchable), `load_book_evolution_sections()`, wired
  `book_evolution` / `ftmo_challenge_readiness` / `research_state` /
  `factory_bottleneck` / `book_evolution_health` into `build_contract` (verbatim,
  fail-soft), kept `path_to_25` unchanged (now a diagnostic, §3), and added
  permissive optional schema entries for the new keys (not `required`, so
  validation stays green before E1/F1/G1 land).
- `tools/strategy_farm/render_cockpit_v2.py` — added `_render_book_evolution`
  (DXZ/FTMO venue sub-blocks + Research + Factory), `_render_ftmo_challenge_
  readiness` (§62 multi-component + recommendation enum + would-Fable-buy-today),
  EVIDENCE_MISSING helpers, freshness chips, book-evolution CSS (only `var(--*)`
  tokens, radius 0, no new colours). Body order now: control strip → **Book
  Evolution** → **FTMO Challenge Readiness** → OWNER To-Dos → Risk Freeze → …
  `_render_path_to_25` is retained in the module (history, §3) but removed from
  the primary flow; candidate counts survive only as a labelled Factory
  diagnostic ("Qualified Pool: N (Diagnostik, KEIN Ziel)").
- `tools/strategy_farm/tests/test_mission_control_v2_data.py` — added 4 tests for
  the read-model wiring + health grading (GREEN/AMBER/RED, EVIDENCE_MISSING) and
  a contract-validates-with-new-keys test.
- `tools/strategy_farm/tests/test_render_cockpit_v2.py` — added 6 tests: all four
  sections render from fixtures; absent read-models render EVIDENCE_MISSING w/o
  crash; partial-missing isolation; §70 "25 is no longer an objective string";
  freshness badge STALE-only-when-STALE; candidate pool shown as diagnostic.
- **NEW** `tools/strategy_farm/tests/test_factory_bottleneck_readmodel.py` — 15
  tests: queue/claimable counting excl. active holds, idle-in-drain detection
  (incl. stale-log exclusion), frontier band, bottleneck ranking, full assembly
  (incl. DB-missing → NOT_EVALUATED), `load_readmodel`, health composer, health
  file persistence.

## Contracts

- Wrote (as documented shared contracts): `factory_bottleneck.json`
  (`qm.factory-bottleneck/v1`), `book_evolution_health.json`
  (`qm.book-evolution-health/v1`). Both carry `schema` + ISO `generated_at_utc`.
- `qm.mission_control.v2` gained optional keys `book_evolution{dxz,ftmo}`,
  `ftmo_challenge_readiness`, `research_state`, `factory_bottleneck`,
  `book_evolution_health` (all fail-soft; not `required`).
- Consumed (bound verbatim, EVIDENCE_MISSING tolerant — produced by E1/F1/G1):
  `book_evolution_dxz.json`, `book_evolution_ftmo.json`
  (`qm.book-evolution-venue/v1`), `ftmo_challenge_readiness.json`
  (`qm.ftmo-challenge-readiness/v1`), `research_state.json`
  (`qm.research-state/v1`).
- No gate threshold, verdict semantics, DB write, or qualification changed.

## Health keys (requirement 3)

`book_evolution_health` (in the MC contract for the cockpit; also persisted to
`book_evolution_health.json` for the vault Heartbeat) exposes:
`book_evolution_readmodels` (GREEN/AMBER/RED by freshness),
`ftmo_readiness_recommendation`, `research_state_freshness`,
`factory_bottleneck_top`. The cockpit renders these as chips atop the Book
Evolution section.

## Tests + pytest summary

`python -X utf8 -m pytest tools/strategy_farm/tests/test_factory_bottleneck_readmodel.py tools/strategy_farm/tests/test_mission_control_v2_data.py tools/strategy_farm/tests/test_render_cockpit_v2.py -q`
→ **58 passed, 1 failed**. The single failure is
`test_mission_control_v2_data.py::test_full_contract_is_schema_valid`, which is a
**pre-existing worktree CRLF drift** in `path_to_25.py`'s sealed-decision sha
check (`decisions/2026-08-27_owner_count_definition_option_a.md` checked out with
CRLF in the worktree → sha `2df61c55…` vs pinned `d47501ca…`; the canonical
`C:/QM/repo` copy is LF and matches the pin). Confirmed it fails identically on
the pristine tree BEFORE any edit (git stash). Not caused by, and not fixable
within, this slice (touching a dated decision is ROT). Sibling suites
`test_render_cockpit_cohorts.py`/`test_render_cockpit_pipeline_books.py`:
12 passed.

## Runtime artifacts written (scratch, NOT live D:/QM)

- `…/scratchpad/render_out/cockpit_v2_live.html` — LIVE render (70,339 bytes):
  Book Evolution + FTMO Challenge Readiness present; "Weg zu 25" / "/25" /
  "ETA zu 25" all **absent**; EVIDENCE_MISSING shown for the not-yet-produced
  E1/F1/G1 read-models (11 occurrences); no crash.
- `…/scratchpad/render_out/factory_bottleneck.json` — built from LIVE data:
  `active=3, idle_in_drain=7, claimable_pending=743`, top bottleneck
  `unwinnable_reservation_head_of_line_block` — matches the live incident in
  `audit/pipeline_factory_state.md`.
- `book_evolution_health` on live data: `AMBER` (only factory_bottleneck present;
  the other four read-models are EVIDENCE_MISSING until E1/F1/G1 land).

The production render (`D:/QM/strategy_farm/dashboards/cockpit.html`) was NOT
touched.

## 0x800710E0 cockpit abort — diagnosis (requirement 4)

**Not a renderer/launcher code bug.** `Get-ScheduledTask QM_StrategyFarm_Cockpit_2min`
shows `MultipleInstances=IgnoreNew`, `ExecutionTimeLimit=PT72H`, and a trigger
**repetition interval of `PT1M`** (every minute — despite the "_2min" name).
A full-census cockpit render (`render_cockpit.py` → `render_cockpit_v2.main([])`
→ `build_contract(operator_pair_detail_limit=None)` over ~149k `work_items`)
takes ≈1–2 minutes on the busy host (this slice's live build foreground-timed out
at 120 s). Every 60 s the scheduler fires a new instance while the previous one
is still running; with `IgnoreNew` it refuses the overlapping launch and records
that refusal as last result `0x800710E0` (HRESULT ERROR_OPERATION_ABORTED /
instance-already-running). It is intermittent because it only shows when a launch
lands inside a still-running render.

**Fix for the orchestrator (task-definition, not code):** widen the trigger
repetition to at least the worst-case render time, e.g.
`PT1M → PT5M` (also resolves the name-vs-interval drift; keep
`MultipleInstances=IgnoreNew`):

```powershell
$t = Get-ScheduledTask -TaskName 'QM_StrategyFarm_Cockpit_2min'
$t.Triggers[0].Repetition.Interval = 'PT5M'
Set-ScheduledTask -TaskName 'QM_StrategyFarm_Cockpit_2min' -Trigger $t.Triggers
```

Optional code-side mitigation (separate slice, NOT done here to keep this diff
focused): the per-minute cockpit does not need the full operator census — the
drill-down `linear_frontier.html` could refresh on a slower cadence than the main
page. Left as a note.

## Wiring the factory_bottleneck read-model (for the orchestrator)

`factory_bottleneck_readmodel.py build` must run on a 15-min cadence so
`factory_bottleneck.json` + `book_evolution_health.json` stay fresh. Recommended:
fold it into the existing read-model refresh task `QM_StrategyFarm_PipelineState`
(same 15-min cadence, same read-model directory) by appending a second action, or
add a dedicated `QM_StrategyFarm_FactoryBottleneck_15min` task:

```
pythonw.exe C:\QM\repo\tools\strategy_farm\factory_bottleneck_readmodel.py build
```

It is read-only (RO DB, no terminal64, writes only under `D:/QM/reports/state/`).

## Rollback

- Revert the three modified files + delete the new module/test. The contract's
  new keys are additive and optional; the renderer's old body order is a one-line
  revert. No state, DB, verdict, or scheduled task was modified by the slice
  itself. The scratch artifacts are outside the repo.

## Items NOT done (with reasons)

- **Scheduled-task edits** (the `PT1M→PT5M` fix and the factory-bottleneck 15-min
  wiring): documented for the orchestrator, not applied — a worktree slice must
  not mutate live Task Scheduler definitions, and it is outside the owned code
  files.
- **Morning-brief §3 replacement** (`morning_brief.py`): out of this slice's
  owned files (audit action D3); belongs to a separate slice.
- **Vault supersession pages** (audit D4): Vault writes are out of scope here.
- **`path_to_25.py` seal / CRLF drift**: pre-existing, ROT-adjacent (dated
  decision); left untouched and reported.
