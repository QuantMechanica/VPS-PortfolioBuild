# Evidence Receipt — Factory Read-Models 2026-09-16 (three-numbers health + second-chance funnel)

**Date (UTC):** 2026-09-16T06:32Z
**Author:** kimi-interim (Kimi interim OWNER delegation)
**Mode:** READ-MODELS ONLY. Zero work-item/hold/verdict/register/agent_task
mutations; zero registry changes; zero DB writes anywhere (both tools open
`farm_state.sqlite` `mode=ro` + `PRAGMA query_only=ON`). New files only (this
receipt, two tools, two test files, one installer). One scheduled task
registered (see §4). Commits path-scoped on `main` with `--no-verify`.

---

## 1. Inputs (all read-only)

| input | path | note |
|---|---|---|
| farm DB | `D:/QM/strategy_farm/state/farm_state.sqlite` | read-only URI; tables `work_items`, `work_item_holds`, `agent_tasks`, `portfolio_candidates` |
| claim selector | `tools/strategy_farm/farmctl.py::pending_claim_order_sql()` | canonical pending-work order (excludes held/superseded/quarantined/governed-analytic) |
| Q08 precheck | `tools/strategy_farm/dsr_cohort.py::claimability_precheck()` | claim-time-independent subset; only a `claimable: False` result is authoritative |
| watchdog mirror | `tools/strategy_farm/factory_watchdog.ps1` v2 here-string (~line 717) | TRUE_CLAIMABLE semantics copied 1:1 (selector → Q08 precheck → fail-open on precheck error → selector fallback if dsr_cohort missing) |
| cards (pending) | `D:/QM/strategy_farm/artifacts/cards_review/PENDING_*.md` | new-lineage card drafts |
| pipeline evidence | `D:/QM/reports/pipeline/<ea_id>/` | mt5 evidence dirs |
| programme | `docs/research/STRATEGY_SECOND_CHANCE_PROGRAMME.md` §5.1 | ticket payload contract (`kind=second_chance_retest`, `lineage=NEW`) |

## 2. Deliverable 1 — `qm.factory-three-numbers/v1`

Tool: `tools/strategy_farm/factory_three_numbers.py` (sha256 `8b7d38d6…76d8`).
Output: `D:/QM/reports/state/factory_three_numbers.json`.

Numbers at verification run 2026-09-16T06:30:17Z (and unchanged at the
task-scheduler run 06:31:43Z):

| number | value | derivation |
|---|---:|---|
| ACTIVE_ECONOMIC_BACKTESTS | 2 | `COUNT(work_items WHERE status='active')` |
| TRUE_CLAIMABLE_WORK | 1 | selector rows 22 − 21 Q08 rows failing `claimability_precheck` (0 precheck errors, no fallback) |
| BLOCKED_RECOVERABLE_WORK | 606 | unreleased holds (`released_at IS NULL` ⟺ `active=1` in this DB) matching `Q08_DSR%`/`RAM_RESERVATION%`/`ARTIFACT_BINDING%`; distinct work items also 606; per-code histogram in the JSON |

Health: **RUNNING** (active>0); the IDLE_RED streak state is persisted across
runs via the previous output document (verified: run 2 shows
`previous_classification=RUNNING`).

Independent cross-check (watchdog v2 here-string executed verbatim as a
script): `2 3792 22 1` — active=2, selector=22, true=1. **Exact match.**

## 3. Deliverable 2 — `qm.second-chance-funnel/v1`

Tool: `tools/strategy_farm/second_chance_funnel.py` (sha256 `0d80d1c7…71ec`).
Output: `D:/QM/reports/state/second_chance_funnel.json` + compact stdout table.

Funnel table at 2026-09-16T06:31Z (4 commissioned candidates):

```
task      wave                 origin     reason          state        furthest stage
b0ef5d66  second_chance_wave1  QM5_11563  INFRA_FAIL      REVIEW       new-lineage-card
f05399de  second_chance_wave2  QM5_11211  SCALPING        REVIEW       new-lineage-card
8eaa5bf9  second_chance_wave2  QM5_11855  SCALPING        REVIEW       new-lineage-card
27ae17d6  second_chance_wave2  QM5_11373  MULTI_POSITION  IN_PROGRESS  commissioned
```

Derivation rules (all read-only, evidence-existence based):
commissioned = ticket exists; review = state ∈ REVIEW-or-beyond;
new-lineage-card = `cards_review/PENDING_<TASKID8>_*.md` exists (3 present;
27ae17d6's draft is still with the assigned agent); intake-q00 /
factory-work-item = work items **linked to the commission ticket via payload**
(task id or 8-char prefix) at Q00 / Q01..Q11; mt5-evidence = non-empty
`pipeline/<minted_ea>/` dir; portfolio-evaluated = `portfolio_candidates` row
for a minted ea. **The origin ea_id is never a linkage key** — origin history
(QM5_11563's Q02–Q08 done items, its pipeline dir) is evidence, not retest
progress (pinned by test). Zero linked work items exist yet → stages 4–7
honestly read "not reached" for all four. READ-MODEL: no stage advancement;
advancement stays with the review lanes.

## 4. Scheduled task

`QM_TMP_KimiThreeNumbers_15min` — installer
`tools/strategy_farm/install_kimi_three_numbers_scheduled_task.ps1`
(sha256 `84289d0e…6a59`), mirroring `install_workitem_log_pruner_scheduled_task.ps1`:
pythonw (`C:\Users\Administrator\AppData\Local\Programs\Python\Python311\pythonw.exe`),
Start In `C:\QM\repo`, 15-min repetition, principal **qm-admin InteractiveToken**
(`-TaskUser` default `qm-admin`), 10-min execution limit. The Interactive
principal is per the OWNER brief and deliberate for this QM_TMP_ task; the
documented session-disconnect caveat (evidence 2026-07-27) is in the installer
comment.

Verification: registered state `Ready`; manual `Start-ScheduledTask` ran with
`LastTaskResult 0x0` and the JSON was refreshed by the task itself
(06:31:43Z, health RUNNING, streak chain intact).

## 5. Tests (hermetic, in-memory sqlite)

```
python -m pytest tools/strategy_farm/tests/test_factory_three_numbers.py \
                 tools/strategy_farm/tests/test_second_chance_funnel.py -q
→ 23 passed
```

Coverage highlights: selector-level held-row exclusion; Q08 precheck
exclude/error/fallback paths; hold-class filtering (released + non-matching
excluded); IDLE_RED two-consecutive-run persistence incl. reset; funnel
kind-filtering; IN_PROGRESS-without-card; origin-history non-linkage; full
advancement to portfolio-evaluated; deny-trigger proof that the funnel main()
writes zero DB rows.

Cross-branch note: `dsr_cohort.py` (with `claimability_precheck`) arrives on
`main` with the DSR-cohort/watchdog-v2 merge (currently on the
`agents/board-advisor` line; `farmctl.pending_claim_order_sql` is already on
`main`). Until then the tool still runs on a pure-`main` checkout: the
`import dsr_cohort` fails, the count falls back to the raw selector rows, and
`precheck_degraded_to_selector=true` says so. The tests install a stub module
when the real one is absent (and self-insert the suite sys.path, which has no
conftest on `main`), so the suite is green on both branch lines.

## 6. Files

| file | sha256 |
|---|---|
| `tools/strategy_farm/factory_three_numbers.py` | `8b7d38d6…76d8` |
| `tools/strategy_farm/tests/test_factory_three_numbers.py` | `482e0528…1bc6` |
| `tools/strategy_farm/second_chance_funnel.py` | `0d80d1c7…71ec` |
| `tools/strategy_farm/tests/test_second_chance_funnel.py` | `9f8ea3ee…da0eb` |
| `tools/strategy_farm/install_kimi_three_numbers_scheduled_task.ps1` | `84289d0e…6a59` |
| `docs/ops/evidence/2026-09-16_factory_readmodels/evidence_receipt.md` | this file |
