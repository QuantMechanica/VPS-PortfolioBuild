# Q08 requalification cohort baseline repair — task 9248139c

Date: 2026-07-16  
Router task: `9248139c-2f5d-4913-a768-f6b85da7fa04` (`triage_failure`, Codex)  
Scope: the five cited Q08 work items only; no live terminal, `T_Live`, AutoTrading, gate threshold, or EA binary change.

## Outcome

The Q08.5 baseline-lineage repair is implemented, integrated into local `main`, and independently
verified by Codex. The bounded five-row rerun is not yet complete: at the 2026-07-16T22:39Z
single-pass inspection, two rows were `done`, one was `active` on T1, and two were `pending`.
No active terminal was interrupted and no additional work item was created or requeued.

The two completed aggregates prove that the repaired Q08.5 path now rejects stale evidence,
regenerates from the exact symbol-matched parameter baseline, and grades the resulting
non-degenerate neighborhoods `PASS`. They also expose a separate fail-closed Q08.7 condition:
QM5_11708 and QM5_12969 each have only one distinct Q03 configuration, so the PBO runner correctly
returns `insufficient_distinct_q03_configs` and the aggregate remains `INVALID`. Synthetic or
duplicate configurations were not created to manufacture a PBO result. Consequently, this artifact
does **not** claim a Q08 PASS or final book qualification; those remain pipeline-evidence decisions.

## Root cause confirmed

Q08.5 support evidence is shared at `D:/QM/reports/pipeline/QM5_<ea>/Q08/neighborhood/<symbol>/perturbations.json`. The aggregator previously treated file existence as sufficient freshness. The cited 10476, 10513, and 12567 artifacts therefore reused old empty-parameter/zero-trade baselines; 11708 had a traded baseline but no strategy parameters. The 12567 Q08.7 attempt also predated its later Q03 PASS evidence.

The original handoff was stale in two material respects:

- QM5_12969 already had a real Q08.5 PASS before this task; it was rerun because the router explicitly named all five sleeves.
- QM5_12567 now has a Q03 PASS source, but the current Q08.7 fallback exposes only one configuration. Any resulting PBO PASS is pipeline evidence, but scientifically weak and is not represented here as multi-configuration robustness.

## Durable repair

The Q08.5 runner and aggregator now:

- reject a baseline whose `; symbol:` metadata does not match the tested symbol;
- reject a baseline with an empty strategy-parameter block;
- bind cached evidence to the absolute baseline path, SHA-256, declared symbol, and strategy-parameter count;
- bind the Q03 plateau-pick or fallback setfile through a parameter-source SHA-256;
- require a nondegenerate baseline and complete, nondegenerate perturbation rows;
- quarantine stale shared evidence and fail closed if quarantine or regeneration fails;
- revalidate lineage after support-run completion before allowing sub-gate 8.5 to grade it;
- record an explicit invalid status when a strategy genuinely has no perturbable numeric parameter.

Board-advisor commits:

- `6c1bc1e2b` — baseline identity and cache invalidation.
- `528593aa8` — post-run validation and fail-closed quarantine handling.
- `3fa59d113` — approved-card/default parameters restored to QM5_11708 EURUSD/AUDUSD sets.
- `34f2084a0` — tracked QM5_10513 XAUUSD requalification baseline.

The same task changes were integrated through `C:/QM/worktrees/cto_main` as local-main commits `01c0578f9`, `99cb776bb`, `0ab7ca121`, `6a5d2c10f`, `ea8b4a3ea`, `731c05338`, and `be670c3de` before this evidence file was finalized.

## Baseline identities used

| EA / sleeve | Strategy assignments | Perturbable numeric params | Baseline SHA-256 | Notes |
|---|---:|---:|---|---|
| QM5_10476 / USDCAD.DWX H1 | 11 | 11 | `2b416995ba0996c84a247142b2acb52f50998a14e5835531576721a7c4d4796a` | Existing symbol-matched set was already repaired; stale cache was the blocker. |
| QM5_10513 / XAUUSD.DWX D1 | 7 | 6 | `d70fa4088ce350a5aecbe080e0788658c58c5a8b9497ea09da9c85379c9fad82` | New tracked `...XAUUSD.DWX_requal_D1_backtest.set`; all 22 assignments equal the Q07-selected ignored ablation set. |
| QM5_11708 / EURUSD.DWX D1 | 5 | 4 | `a269d21dff388670e94b8dd0349bda2d01a93ea6c27125c1e17e61df79009815` | Exact EA/card defaults restored. |
| QM5_12567 / XAUUSD.DWX D1 | 9 | 9 | `5e826eb3aa6d585f81dd36e6706f39131d0931b9e1963164c251ef5ed424dd97` | Existing set repaired after the old Q08 run. |
| QM5_12969 / USDJPY.DWX M30 | 5 | 1 | `94802d93d0de6cbbc3f1f7a1f2589d8bd12970e77ee0418ac31adb60688d33d0` | Pre-task neighborhood already passed; rerun verifies fresh lineage. |

QM5_10513 retains the exact Q07-selected `strategy_session_end_hhmm=2633`. It is outside the documented clock range but inert because the selected sleeve leaves the session filter disabled. It was documented rather than silently normalized, preserving the tested strategy identity.

## Targeted requeue

At `2026-07-16T21:21:32Z`, only these existing work-item IDs were reset to `pending` with `priority_track=true`; prior report roots were archived with `.requeued_20260716T2121320000` suffixes:

| Work item | EA / symbol | Baseline |
|---|---|---|
| `f7f379d3-841d-455a-a64f-ea69ea3fc5ef` | QM5_10476 / USDCAD.DWX | canonical USDCAD H1 baseline |
| `7a53d77f-746c-4d83-80ca-327a6427f716` | QM5_10513 / XAUUSD.DWX | tracked requalification D1 baseline |
| `d4d139bf-7e81-48a9-a1ad-ebf392748f8d` | QM5_11708 / EURUSD.DWX | repaired EURUSD D1 baseline |
| `3f89b9ec-526b-4d15-a00c-3b34b01afc5d` | QM5_12567 / XAUUSD.DWX | canonical XAUUSD D1 baseline |
| `74a089c5-194d-466f-ba0f-0536fdf32641` | QM5_12969 / USDJPY.DWX | canonical USDJPY M30 baseline |

No EA-wide cascade command was used. A pump-created zero-evidence duplicate for QM5_10513 (`434d09d2-a1ea-4a6b-82e0-a95719bdf9cf`) was removed before claim, with an audit event. Its upstream Q07 row was rebound to the tracked set only after all 22 assignments were verified equal, preventing recurrence.

## Focused verification

Canonical board checkout:

- `python -m pytest framework/scripts/tests/test_q08_davey_subgates.py -q` → `51 passed`.
- `python -m pytest tools/strategy_farm/tests/test_cascade_real_phase_runners.py -q` → `7 passed`.
- `python -m py_compile framework/scripts/q08_5_neighborhood_runner.py framework/scripts/q08_davey/aggregate.py` → PASS.
- `validate_build_guardrails.py` on the two repaired 11708 sets and tracked 10513 set → PASS; `RISK_FIXED=1000`, `RISK_PERCENT=0`, maximum stale-news allowance unchanged at 336 hours.

Local main integration:

- Q08 suite → `46 passed` (one pre-existing deprecation warning).
- cascade real-phase-runner suite → `6 passed`.
- the same three setfile guardrail checks → PASS.

## Fresh pipeline evidence

Single-pass observation at 2026-07-16T22:39Z:

| Work item | EA / symbol | State | Fresh evidence observed |
|---|---|---|---|
| `f7f379d3-841d-455a-a64f-ea69ea3fc5ef` | QM5_10476 / USDCAD.DWX | `pending` | No fresh aggregate yet. |
| `7a53d77f-746c-4d83-80ca-327a6427f716` | QM5_10513 / XAUUSD.DWX | `pending` | No fresh aggregate yet. |
| `d4d139bf-7e81-48a9-a1ad-ebf392748f8d` | QM5_11708 / EURUSD.DWX | `done / FAIL_SOFT` | Q08.5 `PASS`: 178-trade baseline, 4/4 perturbations within plateau, exact baseline lineage. Q08.7 `INVALID`: one distinct Q03 configuration. |
| `3f89b9ec-526b-4d15-a00c-3b34b01afc5d` | QM5_12567 / XAUUSD.DWX | `active` on T1 | No fresh aggregate yet; active run left untouched. |
| `74a089c5-194d-466f-ba0f-0536fdf32641` | QM5_12969 / USDJPY.DWX | `done / FAIL_SOFT` | Q08.5 `PASS`: 331-trade baseline, 2/2 perturbations within plateau, exact baseline lineage. Q08.7 `INVALID`: one distinct Q03 configuration. |

Fresh aggregate paths:

- `D:/QM/reports/work_items/d4d139bf-7e81-48a9-a1ad-ebf392748f8d/QM5_11708/Q08/EURUSD_DWX/aggregate.json`
- `D:/QM/reports/work_items/74a089c5-194d-466f-ba0f-0536fdf32641/QM5_12969/Q08/USDJPY_DWX/aggregate.json`

Additional bounded evidence inventory:

- QM5_11708 also has `8.6_chopping_block: EDGE_SOFT` (`PF=0.9786` after removing
  the top 5% of trades). The OWNER decision waives only seasonal/regime `EDGE_SOFT` and the
  specified swing/D1 `LOW_SAMPLE` cases, so this sleeve is not admissible under that waiver even if
  its PBO input is later repaired.
- QM5_10476 produced a 299-trade, PF 1.27 intermediate aggregate before its final lineage-contract
  requeue. Its neighborhood was non-degenerate but one perturbation breached the DD plateau
  (`22190.52` versus a `13967.4` baseline), yielding a genuine `EDGE_HARD` warning. Because that
  aggregate predates the final parameter-source/evidence-status contract and the row is now
  `pending`, it is recorded as provisional evidence, not as the final pipeline verdict.
- QM5_10513 has 56 distinct eligible Q03 configurations and can produce genuine PBO evidence on its
  pending rerun. QM5_10476, QM5_11708, QM5_12567, and QM5_12969 each expose only one eligible Q03
  configuration under the current deduplicating runner. Re-running the same setfile cannot resolve
  their Q08.7 `INVALID`; a real, approved Q03 configuration family must exist first.
- The QM5_12567 T1 row was confirmed to be executing sequential Q08.5 child runs, not orphaned.
  It remains untouched.

Codex focused verification from clean `C:/QM/worktrees/cto_main`:

- `python -m pytest framework/scripts/tests/test_q08_davey_subgates.py -q` -> `50 passed`.
- `python -m pytest tools/strategy_farm/tests/test_cascade_real_phase_runners.py -q` -> `6 passed`.
- `python -m py_compile framework/scripts/q08_5_neighborhood_runner.py framework/scripts/q08_davey/aggregate.py` -> PASS.
- `validate_build_guardrails.py` on the two repaired QM5_11708 baselines and the tracked QM5_10513 requalification baseline -> PASS; each uses `RISK_FIXED=1000` and `RISK_PERCENT=0`, with the maximum stale-news allowance still 336 hours.

Review disposition: the baseline-lineage repair is ready for code/evidence review. Completion of the
three remaining pipeline rows, adjudication of the provisional QM5_10476 hard neighborhood warning,
and creation of genuinely distinct Q03 configurations where PBO is required are separate
follow-through items. Duplicate reruns of one setfile do not satisfy PBO, and the OWNER soft-gate
waiver must not be extended to QM5_11708's chopping-block result.

## OWNER admissibility line

Decision `decisions/2026-07-16_q08_lowfreq_seasonal_admissibility.md` is binding. Tooling `INVALID` and genuine hard failures are not waived. Only the explicitly ratified seasonal/regime `EDGE_SOFT` and swing/D1 low-sample cases may be admitted, and each sleeve is reported against that closed set after the reruns finish.
