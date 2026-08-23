# rb-q09-autoseal — Q09 autoseal recovery and contract-v3 execution evidence

Date: 2026-08-23

Branch: `rb-q09-autoseal`

Starting HEAD: `4828d9664abcaa27df50725b1b05ce848b9b30f1`

Runtime inspected: `D:/QM/strategy_farm`

State database: `D:/QM/strategy_farm/state/farm_state.sqlite`, opened only as
`file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro`.

## Outcome

The code frontier defect is fixed, but none of the nine live holds was released: every
row has a genuine Q07/Q08/source-vintage blocker. The repaired autosealer now checks the
Q08 setfile/EX5/MQ5 identity before writing a plan, creates the approved Q09 evidence
contract-v3 plan (8 configurations, seed 17, selection + holdout), and reconstructs the
full-window metrics from authenticated daily-equity streams. The governed binder now has
a true read-only dry-run path. Q09 thresholds, material-effect rules, 7x4 expansion rule,
and verdict criteria are unchanged.

This scope follows the active gate-manifest v3 and ROT instruction
(`docs/ops/rebaseline/GATE_NAME_CENSUS_2026-08-23.md:5`,
`docs/ops/rebaseline/FACTORY_AUTOMATION_INVENTORY_2026-08-23.md:5`). The proposed gate
manifest v4 remains inert (`docs/ops/rebaseline/GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md:100`),
and that proposal explicitly preserves criteria
(`docs/ops/rebaseline/GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md:142`).

## Durable hold census and query

There are no nine independent marker files. The authoritative markers are the nine active
`work_item_holds` rows in the SQLite database; each row has
`hold_code='Q09_AWAITING_SEALED_PLAN'`. The actual latest exception is stored in the same
work item's `payload_json.q09_autoseal_failure`.

Read-only query used:

```sql
SELECT w.id,w.ea_id,w.symbol,w.created_at,w.updated_at,h.hold_code,h.reason,
       d.parent_work_item_id AS q08_id,p.evidence_path AS q08_evidence,w.payload_json
FROM work_items w
JOIN work_item_holds h ON h.work_item_id=w.id AND h.active=1
LEFT JOIN work_item_dependencies d
  ON d.child_work_item_id=w.id AND d.dependency_role='Q08_INPUT'
LEFT JOIN work_items p ON p.id=d.parent_work_item_id
WHERE w.phase='Q09_NEWS' AND w.status='pending'
  AND h.hold_code='Q09_AWAITING_SEALED_PLAN'
ORDER BY w.created_at,w.id;
-- 9 rows
```

The inventory snapshot reported 8 bind failures + 1 closure failure
(`docs/ops/rebaseline/FACTORY_AUTOMATION_INVENTORY_2026-08-23.md:139-140`). By the
read-only query at 10:50Z, the same nine durable holds had been automatically retried and
their latest payloads were 5 bind failures + 4 closure failures. This explains the count
change without implying that any hold was released.

## Per-hold root cause and deterministic disposition

`Q08 identity` below compares each Q08 aggregate's `baseline_run` hashes with the current
work-item setfile and canonical EA files. Closure files are under
`D:/QM/reports/pipeline/_q09_include_closures/<EA>_include_closure.json`.

| Q09 work item | Pair | Latest durable failure | Authenticated underlying cause | Disposition |
|---|---|---|---|---|
| `49a059da-82ab-4835-9c46-f18ba9b94dcf` | QM5_10847 / GDAXI.DWX | bind: no identity-bound Q07 | Q08 set/EX5/MQ5 match; DB has no completed Q07 candidate before Q08. Q08 evidence: `D:/QM/reports/work_items/a201f967-887d-4d77-ac31-c3c00640e6ca/QM5_10847/Q08/GDAXI_DWX/aggregate.json`. | `BLOCKED_Q07_PREDECESSOR_MISSING` |
| `1cff016c-d25c-4723-a892-6bc53bfafa0b` | QM5_12989 / XAUUSD.DWX | closure inventory/hash mismatch | Q08 set expected `8ff8cc9b…`, current `df759ee4…`; MQ5 expected `72b3fd6e…`, current `0beecb76…`. Q07 candidate evidence is also missing. | `NEEDS_Q08_REBIND` |
| `aa80274f-fb46-4432-b47e-6fb2bf28c9a2` | QM5_13128 / NDX.DWX | closure inventory/hash mismatch | Q08 set expected `edca7afa…`, current `49da27d9…`; closure binds old EA MQ5 `4e6e18c1…`, current/Q08 MQ5 is `e2bd93a2…`. | `NEEDS_Q08_REBIND` |
| `cc670aa2-c9b4-4605-aea3-a925afb238bf` | QM5_12847 / NDX.DWX | bind: Q07 evidence missing | Q08 set/EX5/MQ5 match. Q07 `8878bd6b-2ec8-4d39-a1b2-e77dd2360ab3` points to missing `D:/QM/reports/work_items/8878bd6b-2ec8-4d39-a1b2-e77dd2360ab3/QM5_12847/Q07/NDX_DWX/aggregate.json`. | `BLOCKED_Q07_EVIDENCE_MISSING` |
| `cdfc4ddc-2f82-4321-ac36-876202eadcad` | QM5_10706 / GBPUSD.DWX | bind: no authenticated Q07 | Q08 EX5 expected `7b287687…`, current `eaffda6f…`; the Q07 aggregate exists but cannot authenticate this changed binary. | `NEEDS_Q08_REBIND` |
| `5302ac48-3123-4327-8d8a-506fffeee365` | QM5_12623 / XAUUSD.DWX | bind: Q07 evidence missing | Q08 set/EX5/MQ5 match. Q07 `7f927320-f7f5-4938-a6f4-80e98e23bfb0` aggregate is missing. | `BLOCKED_Q07_EVIDENCE_MISSING` |
| `8214410d-7708-4077-8626-c3c449ee862c` | QM5_11294 / GDAXI.DWX | closure inventory/hash mismatch | Direct Q08 identities match, but closure gained `QM_AccountRiskReservation.mqh` and has non-allowlisted drift in `QM_Common`, `QM_Entry`, `QM_Errors`, `QM_Indicators`, `QM_NewsFilter`, `QM_RuntimeExecutionContract`, `QM_TradeContext`, and `QM_TradeManagement`. The EX5/source closure is a different vintage. | `NEEDS_Q08_REBIND` |
| `57d8bacd-2805-45a6-ac51-156e22bb3a65` | QM5_10815 / GDAXI.DWX | bind: Q07 evidence missing | Q08 aggregate has no `baseline_run` set/EX5/MQ5 identity at all; declared Q07 `1a7d6630-f840-4987-8dda-d38a67d39526` aggregate is also missing. | `NEEDS_Q08_REBIND` |
| `2604a1f0-4f58-4597-89ef-432af9093131` | QM5_1567 / EURUSD.DWX | closure inventory/hash mismatch | Q08 set expected `1282e2ad…`, current `20128a80…`; MQ5 expected/closure `685af902…`, current `a9531d33…`; no completed Q07 candidate. | `NEEDS_Q08_REBIND` |

The only harmless closure drift on the otherwise matching rows is the allowlisted generated
`framework/include/QM/QM_MagicResolver.mqh` registry hash. The closure validator already
permits that class; it is not used to hide any EA/shared-source drift.

Primary cause grouping (mutually exclusive disposition driver): 5 Q08 identity defects,
1 shared include-closure/binary vintage defect, 2 missing durable Q07 aggregates, and 1
missing Q07 predecessor. Some rows have additional overlapping Q07 defects, recorded in
the table. There are therefore zero `RELEASE_AFTER_FIX` rows.

## Code defects fixed

1. **Autoseal planned mutable bytes before authenticating Q08 vintage.**
   `validate_q08_source_vintage` now fails closed on setfile, EX5, and (where recorded)
   MQ5 drift (`tools/strategy_farm/q09_news_runner.py:773`). The autosealer invokes it
   before closure creation or plan writes (`tools/strategy_farm/farmctl.py:15365`). The
   binder repeats the check, and revalidates the bound closure against current sources,
   before resolving Q07 lineage (`tools/strategy_farm/q09_news_runner.py:1059`). This
   prevents a misleading sealed plan from being left behind for a known stale Q08 input.

2. **Approved Q09 contract v3 had only a design document, not executable code.** Commit
   `11f833bfe` changed only
   `docs/ops/evidence/2026-08-21_q09_acceleration_contract_v3.md`; that document records
   the held collision and implementation recipe at lines 218-228. The implementation now:
   accepts physical seed 17 and fans it into the unchanged logical selector
   (`tools/strategy_farm/q09_news_contract.py:599-655`), creates 8-config/two-window v3
   plans (`tools/strategy_farm/q09_news_runner.py:417`), and makes v3 the autoseal plan
   contract (`tools/strategy_farm/farmctl.py:15394-15412`).

3. **No executable seam reconstruction.** The pure seam module authenticates ordered
   account equity snapshots and reconstructs cross-window drawdown, daily Sharpe,
   additive counts/net-R, and profit factor (`tools/strategy_farm/q09_news_seam.py:26-127`).
   Receipts bind `seam_reconstructed`, the two source streams, and the documented 0.584%
   pilot residual bound. The design source is `docs/ops/Q09_ACCELERATION.md:185-231` and
   `docs/ops/evidence/2026-08-21_q09_acceleration_contract_v3.md:106-143`.

4. **Persistence/Q10 still required five physical seeds.** Schema v7 records v3 and
   accepts exactly physical seed 17 for v3 while retaining exactly five physical seeds
   for v2 (`tools/strategy_farm/q09_news_schema.py:48-50`, `:1345-1445`). The
   qualification trigger was updated with the same versioned rule; no selector or gate
   criterion changed (`tools/strategy_farm/q09_news_schema.py:652-674`).

5. **Binder dry-run was not truly read-only at the CLI boundary.** `--dry-run` now skips
   `init_db`, is not classified as a mutating command, and the binder opens SQLite through
   `mode=ro` (`tools/strategy_farm/farmctl.py:22187-22209`, `:26168-26171`;
   `tools/strategy_farm/q09_news_runner.py:1059-1103`). It never registers the calendar,
   updates payload JSON, commits, or releases the hold.

## Governed binder dry-run and proposed plan

Commands used for each existing plan (never `apply`):

```powershell
python tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm bind-q09-plan `
  --work-item-id <id> --plan D:/QM/reports/work_items/<id>/run_plan.json `
  --plan-file-sha256 <Get-FileHash SHA256> --cell-timeout-sec 10800 --dry-run
```

All eight existing plans were v2, 40 cells, `7x1_target_compliance`; QM5_11294 had no
plan file. The read-only binder results were:

| Work item | Dry-run result |
|---|---|
| `49a059da…` | blocked: no authenticated Q07 predecessor |
| `1cff016c…` | blocked: Q08 setfile expected `8ff8cc9b…`, got `df759ee4…` |
| `aa80274f…` | blocked: Q08 setfile expected `edca7afa…`, got `49da27d9…` |
| `cc670aa2…` | blocked: bound Q07 evidence missing |
| `cdfc4ddc…` | blocked: Q08 EX5 expected `7b287687…`, got `eaffda6f…` |
| `5302ac48…` | blocked: bound Q07 evidence missing |
| `57d8bacd…` | blocked: Q08 baseline identity incomplete |
| `2604a1f0…` | blocked: Q08 setfile expected `1282e2ad…`, got `20128a80…` |
| `8214410d…` | no sealed plan exists; closure validation blocks planning |

The repaired planner was also run in a temporary directory for the matching QM5_10847
source tuple, followed by the same binder with `dry_run=True`. It proposed:

```text
schema=q09-news-run-plan/v3
contract=q09-news-evidence/v3
scope=7x1_target_compliance
cell_count=8; window_count=2; seed_set=[17]
CONTROL_OFF/OFF/NONE/s17
POLICY_ON/{OFF,PRE30,PRE60,PRE30_POST30,PRE60_POST60,SKIP_DAY,CLOSE_ALL_PRE}/DXZ/s17
binder result=BLOCKED_Q07_PREDECESSOR_MISSING
```

The temporary plan path was intentionally discarded. No runtime plan was overwritten and
no database row or hold was changed.

## Why Q09 completions were REVIEW_REQUIRED/INFRA

The census conclusion is recorded at
`docs/ops/rebaseline/GATE_MANIFEST_V4_LINEAR_PROPOSAL_2026-08-23.md:81-83`.
The read-only database grouping at inspection time was:

```text
active/NULL 4
done/CONFIG_LOCKED 1       # historical 2026-08-08 row, not a current rebaseline PASS
done/INVALID_EVIDENCE 1
done/PENDING_RUNNER 18
done/REVIEW_REQUIRED 47
failed/INFRA_FAIL 27
pending/NULL 23
```

The recent evidence verifies three distinct classes:

- Historical first-cell abort is real in pilot `46409fc4…`: only 4 authenticated cells,
  1 failed, 35 missing; aggregate at
  `D:/QM/reports/work_items/46409fc4-5bf5-4ec4-a6bf-4cf770ed6b0a/QM5_11294/Q09_NEWS/XAUUSD_DWX/aggregate.json:1`.
  The repair wave did land: `fa49b2c84` implements continue-on-cell-failure plus K=2;
  `983a8c837` routes transient failures and preserves failure evidence. Current tests cover
  complete accounting and receipt-invalid classification.
- `receipt_invalid` is now fail-closed `INVALID_EVIDENCE`, not an early abort. This is
  exercised in `tools/strategy_farm/tests/test_q09_news_runner_v2.py` by mixed authenticated,
  failed, invalid, and missing buckets; all planned cells are reconciled.
- The recent complete 7x1 rows that reached adjudication were legitimately
  `expanded_7x4_matrix_required`, not runner defects. Example:
  `D:/QM/reports/work_items/ba24e7a3-4edf-4dc1-b74d-5854a6b5ecf2/QM5_11294/Q09_NEWS/XAUUSD_DWX/aggregate.json:1`
  reports `material_effect` and 105 missing expanded cells. Contract v3 preserves that
  rule (`tools/strategy_farm/tests/test_q09_news_contract_v2.py:258`). A non-material,
  complete 8-config v3 run reaches and persists `CONFIG_LOCKED`
  (`tools/strategy_farm/tests/test_q09_news_runner_v2.py:1373`).

## Tests

Tests were written before implementation. Recorded red phases:

```text
python -m pytest ...test_q09_news_contract_v2.py ...test_q09_news_runner_v2.py ...test_q09_news_seam.py -q
ERROR test_q09_news_seam.py - ModuleNotFoundError: No module named 'q09_news_seam'

test_q10_gate_accepts_contract_v3_single_physical_seed
FAILED - AttributeError: module 'q09_news_schema' has no attribute 'CONTRACT_VERSION_V3'

test_bind_q09_dry_run_does_not_initialize_or_write_database
FAILED - Expected 'init_db' to not have been called. Called 1 times.
```

Final ticket/touched-module suite:

```text
python -m pytest \
  tools/strategy_farm/tests/test_q09_news_contract_v2.py \
  tools/strategy_farm/tests/test_q09_news_runner_v2.py \
  tools/strategy_farm/tests/test_q09_news_schema_v2.py \
  tools/strategy_farm/tests/test_q09_news_seam.py \
  tools/strategy_farm/tests/test_q09_news_farmctl_integration.py \
  tools/strategy_farm/tests/test_q09_news_migration_v2.py \
  tools/strategy_farm/tests/test_q09_live_news_diagnostic.py \
  tools/strategy_farm/tests/test_q09_autoseal_hold_census.py \
  tools/strategy_farm/tests/test_health_q09_sealed_plan_hold_age.py \
  tools/strategy_farm/tests/test_ftmo_q09_admission.py -q
115 passed in 95.70s
```

Compilation check:

```text
python -m py_compile tools/strategy_farm/farmctl.py \
  tools/strategy_farm/q09_news_contract.py tools/strategy_farm/q09_news_runner.py \
  tools/strategy_farm/q09_news_schema.py tools/strategy_farm/q09_news_seam.py
PASS
```

Mandated full directory run:

```text
python -m pytest tools/strategy_farm/tests -q
226 failed, 4136 passed, 3 skipped, 2 warnings, 42 subtests passed in 1527.04s
```

The full repository suite is not green. Failures span unrelated router-generation,
FTMO book fixtures, static registry/card hashes, dashboard snapshots, and target-rulepack
fixtures. Two Q09-adjacent failures in that output were repaired and rerun: the migration
test had hard-coded schema version 6, and one Windows temp-path assertion compared short
and resolved paths. Their combined rerun was `18 passed in 11.88s`, and both are included
in the final 115-test green run above. The entire 25-minute directory run was not repeated
after those test-only corrections.

## Changed files

- `tools/strategy_farm/farmctl.py` — pre-plan Q08 validation, v3 autoseal, read-only bind CLI.
- `tools/strategy_farm/q09_news_contract.py` — v3 evidence/adjudication and inert seed fanout.
- `tools/strategy_farm/q09_news_runner.py` — v3 plan/receipts, two-window execution, seam,
  vintage/closure checks, dry-run binder.
- `tools/strategy_farm/q09_news_schema.py` — schema v7, v3 persistence and downstream seed rule.
- `tools/strategy_farm/q09_news_seam.py` — pure full-window reconstruction.
- `tools/strategy_farm/tests/test_q09_news_{contract_v2,runner_v2,schema_v2,seam}.py`
  and `test_q09_news_farmctl_integration.py` — v3, seam, vintage, and dry-run coverage.
- `tools/strategy_farm/tests/test_q09_news_migration_v2.py` and
  `test_q09_live_news_diagnostic.py` — schema-v7 migration and path-stable diagnostics.

## Risks and rollback

- Existing runtime v2 plan files remain untouched and stale holds remain active. Upstream
  operators must regenerate the indicated Q07/Q08 evidence; this ticket does not authorize
  that work.
- A material-effect v3 8-config result still returns `REVIEW_REQUIRED` and requires the
  unchanged 7x4 matrix. This is intentional fail-closed semantics.
- V3 seam production requires fresh account-scope `EQUITY_SNAPSHOT` rows plus report Gross
  Profit/Loss. Missing, overlapping, non-monotone, or invalid streams fail the cell; they do
  not manufacture metrics.
- Schema v7 is installed only when the canonical operational path next runs `init_db`; this
  investigation did not migrate the runtime database.
- Rollback code and tests with `git revert <this ticket commit>`. If an operator has already
  installed schema v7, leave the additive tables/data in place and redeploy the prior code;
  do not downgrade or overwrite append-only verdict rows. No runtime data rollback is
  needed for this ticket because binder execution was dry-run only.
