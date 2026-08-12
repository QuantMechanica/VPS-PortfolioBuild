# Priority-track, Level-Up cohort-0, registry re-key, and holdout evidence

Date: 2026-07-20  
Worktree: `C:\QM\worktrees\codex` (`agents/codex`)  
Handoff: `docs/ops/CODEX_HANDOFF_2026-07-20b_priority_track_and_holdouts.md`

## H-A — fresh/force-build Q02 priority track: COMPLETE

Commit: `f19eb2e76a3bb1c80cfcd9f8274c53d31e17098e`

- A newly recorded build, a literal approved-card `force_build`, or an EA with no
  prior Q02/P2 row now receives `payload_json.priority_track=true` before the
  strategy-priority scorer has observed it.
- The change is additive: scored priority remains active on Q02 and later phases;
  existing survivors are not reordered out of their old priority lane.
- All rows in a fresh build's immediate and deferred Q02 cohort carry the flag.
- The focused dispatch test inserts an older same-phase FIFO row and proves that
  the fresh flagged row sorts first.

Urgent live backfill, performed as one bounded SQLite transaction while leaving
`status`, `created_at`, and `updated_at` unchanged:

| EA | symbol | work item | result |
|---|---|---|---|
| QM5_20004 | NDX.DWX | `90c4751d-7547-450d-8974-6d24461eaa7e` | pending payload flagged |
| QM5_20004 | GDAXI.DWX | `ec31f192-30e8-47eb-8e87-004a6d55ec11` | pending payload flagged |
| QM5_20010 | XAUUSD.DWX | `7905692c-e582-4d98-ae58-2c311cdccd4e` | pending payload flagged |
| QM5_4006 | EURUSD.DWX | `89e2b33b-b22f-41e8-aafa-6d7f700f0e93` | pending payload flagged |
| QM5_20006 | SP500.DWX | `1fe24586-9c9b-44ef-ab42-96697753fa98` | already done; not mutated |

The post-transaction dispatch snapshot contained 3,519 pending rows. The four
flagged rows ranked 2, 3, 4, and 6. Each payload records
`priority_track_reason=handoff_2026-07-20b_urgent_backfill`.

## H-B — QM5_10026 NDX Q04 holdout: COMPLETE, DOCUMENTED NO ACTION

Read-only snapshot from
`D:\QM\strategy_farm\state\farm_state.sqlite` (`mode=ro`,
`PRAGMA query_only=ON`):

- Holdout `0f5c259e-6a09-471a-9313-c90438b1a1da` is Q04 / NDX.DWX,
  `status=done`, `verdict=PENDING_RUNNER`, no evidence path, last updated
  `2026-07-19T22:13:43+00:00`.
- Its setfile points into
  `C:\QM\worktrees\claude-orchestration-2\framework\EAs\QM5_10026_rw-fx-squeeze-mr\...`.
- QM5_10026 has zero pending or active work items.
- Latest real-symbol Q02 evidence is EURUSD FAIL
  (`064e9257-ce73-4f4b-9d3e-151bf07eb1df`), GBPUSD FAIL
  (`81fe235f-b7a8-40eb-86d3-a279f3e0f387`), and AUDUSD INFRA_FAIL
  (`ce16ee9a-06a8-4b1f-957c-5f2cdf5cc88d`).
- The referenced worktree is dirty and remains at
  `8c134094a2ef5cc39bb62c0c158f20573785a3cb`; it was not touched.

Decision executed: do not resurrect or requeue this negative-value, already-done
NDX holdout for a failed FX mean-reversion EA.

## H-C — Level-Up cohort-0 systemic fixes: COMPLETE

Commit: `f19eb2e76a3bb1c80cfcd9f8274c53d31e17098e`

1. `record_build_result` now scans built `.mq5` sources after SPEC validation and
   blocks the build with `strategy_entry_stub` before Q02 if it finds the
   auto-generated-skeleton marker or a comment-only constant-false
   `Strategy_EntrySignal`.
2. Exact zero-trade Q02 rows remain distinct from low-positive, missing-metric,
   and infrastructure results. Only a fully finished cohort in which every
   enqueued row has exact-zero evidence is promoted to `DRAFT_DEFECT`; staged
   cohorts wait for deferred rows. Aggregate classification carries
   `route=RE_DRAFT` and `retire_strategy=false` through both farmctl and the
   terminal worker. The legacy P2 CSV path requires concrete zero-trade summary
   evidence for every row.
3. Card approval and build-ready validation now require non-empty
   `target_symbols` frontmatter and a literal timeframe token in the card body
   (`M1/M5/M15/M30/H1/H4/D1/W1/MN1`); a timeframe appearing only in
   frontmatter cannot satisfy the body contract.

## H-D — registry-only duplicate re-key: COMPLETE

Commit: `4c4f95cfae0548cd4b8bca5ab6931bda1f7671a3`

| displaced active identity | replacement active identity |
|---|---|
| `1158,qp-january-barometer` → retired | `12075,qp-january-barometer` |
| `1258,hopwood-dmi-cross-h1` → retired | `12076,hopwood-dmi-cross-h1` |

The built identities `QM5_1158,french-weekend-effect-idx` and
`QM5_1258,hopwood-bermaui-rsi-h1` remain active and their EX5 artifacts remain in
place. Tests prove that 12075/12076 are registry-only: no source directory was
invented, and no EA directory, MQ5, EX5, magic row, or resolver content was part
of the re-key commit.

`health.chk_ea_id_slug_uniqueness` no longer reports 1158 or 1258. It remains
WARN=6 for unrelated pre-existing registry-only duplicate IDs 1492, 9197, 9198,
11277, 11427, and 11857; this work does not claim a global health PASS.

## Validation

```text
python -m py_compile tools/strategy_farm/farmctl.py
  tools/strategy_farm/terminal_worker.py
  tools/strategy_farm/sweep_enqueue_built_eas.py
  tools/strategy_farm/tests/test_levelup_cohort0.py
  tools/strategy_farm/tests/test_priority_track_new_q02.py
PASS

QM_AGENT_ID=codex python -m pytest -q
  test_levelup_cohort0.py test_priority_track_new_q02.py
  test_zero_trade_prevention.py
  test_basket_work_items.py::...test_embedded_build_result_materializes_and_records
  test_verdict_taxonomy_ws2.py test_phase_verdict_profit_check.py
  test_terminal_worker_atomic_claim.py test_registry_rekey_p19.py
  test_health_registry_uniqueness.py test_basket_order_helper_static.py
  test_news_filter_fresh_boundary_static.py
90 passed, 5 subtests passed
```

Factory workers and the pump were active. No MetaEditor build, tester session, or
manual execution session was started. The unrelated pre-existing/concurrent
working-tree change in `framework/include/QM/QM_MagicResolver.mqh` was excluded
from every explicit commit pathspec and left untouched.
