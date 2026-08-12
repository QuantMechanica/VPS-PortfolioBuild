# OPT-1 — Q14/Q15/Q16 manifest v2 and inert factory wiring

- Router task: `801e108e-5aee-4b57-acd9-305600d01a93`
- Binding decisions: DL-084 and `FACTORY_ADAPTATION_OPTIMIZATION_TRACK_2026-08-12.md`
- Implementation commit: board-advisor `a3866a44e`; main `d4156e281`
- Verdict: `PASS — REVIEW REQUIRED`

## Delivered contract

- The new default `qm.gate-manifest/v2` declares Q14 Optimization Admission,
  Q15 Challenger Build & Freeze, and Q16 Head-to-Head Requalification, with
  Q14 -> Q15 -> Q16 -> Q11 edges (`tools/strategy_farm/config/gate_manifest.v2.json:2,29-31`).
- The manifest separately freezes the ordinary Q00-Q13 chain, documents the
  explicit Q10 optimization fork, and records Q11_DXZ/Q11_FTMO as non-top-level
  storage lanes (`gate_manifest.v2.json:38-65`). Legacy aliases are byte-equal
  to v1 and are enforced as a frozen loader contract
  (`tools/strategy_farm/gate_manifest.py:37-53,259-260`).
- The strict loader accepts both closed v1 fixtures and v2, defaults runtime
  consumers to v2, validates the fork/lane topology, and exposes manifest edges
  (`gate_manifest.py:29,138-178,180-275`). `phase_ids.py` derives all phase
  names/order/edges from that loader and exposes ordinary versus optimization
  order explicitly (`tools/strategy_farm/phase_ids.py:53-63,121-124`).

## Controller and evidence binding

- The canonical verdict vocabulary and lifecycle projection now cover
  `OPT_ELIGIBLE`, `OPT_REJECTED`, `CHALLENGER_SPAWNED`,
  `PROMOTE_CHALLENGER`, `KEEP_INCUMBENT`, and `ADMIT_BOTH`
  (`tools/strategy_farm/farmctl.py:8046-8051`;
  `tools/strategy_farm/work_item_lifecycle_v2.py:42-46,81`).
- `enqueue-opt-admission` is the canonical CLI name; the prior
  `admit-optimization` spelling remains a compatibility alias. Both are
  read-only unless `--apply` is explicit (`farmctl.py:21746-21752,21786-21787,21953-21959`).
- Q16 writes two append-only sidecar dependencies: `PARENT_LINEAGE` and
  `CHALLENGER_Q10`. Each must reference a matching completed Q10 PASS and the
  exact lineage-bound evidence path/SHA-256 (`farmctl.py:21082-21139,21231-21280`).
  Schema v4 widens only the dependency-role CHECK, preserves v3 rows during the
  SQLite table rebuild, and adds trigger-enforced phase/status/identity checks
  (`tools/strategy_farm/q09_news_schema.py:42,194,506-516,761-801`).
- Q16 work is explicitly marked `ANALYTIC_DISPATCH_NOT_TERMINAL_WORKER`
  (`farmctl.py:21216`). No phase-runner allowlist entry or terminal-worker
  source change was made.

## Read-only operator visibility

- The cockpit projection opens SQLite with `mode=ro` plus
  `PRAGMA query_only=ON`, counts only recorded Q14-Q16 outcomes, and validates
  parked dry-run dual-book manifests fail-closed. It accepts only
  `deployment_action=NONE`, `autotrading_action=NONE`, OWNER-only authority,
  expected lane/status, hashes, and sleeve structure
  (`tools/strategy_farm/optimization_dashboard_status.py:45-169,176-225`).
- The cockpit renders Q14-Q16 cards and Q11_DXZ/Q11_FTMO status chips while
  stating that it grants no worker, deployment, terminal, money, or AutoTrading
  authority (`tools/strategy_farm/render_cockpit.py:629-708,2070-2071,3930`).
- Project/archive dashboards now follow the declared phase edge rather than
  ordinal adjacency; this prevents Q13 from appearing to advance to Q14 and
  makes Q16 return to Q11 (`tools/strategy_farm/dashboards/render_dashboards.py:561-563,1148,3825`).

## Verification

All commands ran from the canonical checkout and did not launch or interrupt a
terminal.

1. Python compilation for the modified controller, schema, manifest, phase,
   cockpit, and dashboard modules: `PASS`.
2. Focused manifest/controller/schema/lifecycle/dashboard regression suite:
   `86 passed in 5.97s` before commit and `86 passed in 6.42s` after exact
   cherry-pick to main.
3. Unchanged terminal-worker regression suite:
   `110 passed, 4 subtests passed in 40.56s`.
4. Q16 idempotency test verifies both dependency rows and then substitutes the
   parent DB evidence path; the apply path fails closed with
   `DB evidence does not match`
   (`tools/strategy_farm/tests/test_q16_head_to_head.py:287-313`).
5. Migration regression copies an existing v3 dependency row byte-for-byte,
   advances schema metadata to v4, and accepts both constrained Q16 roles
   (`tools/strategy_farm/tests/test_q09_news_schema_v2.py:159-220`).
6. Inert-shipping regression initializes a fresh farm database and proves zero
   total and zero Q14/Q15/Q16 work items, dry-run CLI classification, no new
   phase-runner entry, and no Q14/Q15/Q16 terminal-worker token
   (`tools/strategy_farm/tests/test_optimization_track_manifest_v2.py:145-175`).
7. Production read-only audit after implementation:
   `production_extension_total=0`; no Q14/Q15/Q16 rows existed. The committed
   and working-tree `terminal_worker.py` blob hashes were identical:
   `5d51ecb8932827c7ea0c6e30b7434cc1d590c10d`.
8. `git diff --check`: `PASS`.

One unrelated environment-sensitive assertion in
`test_render_cockpit_pipeline_books.py` expects the factory to display
`INTENTIONALLY_OFF`; the current established behavior reads the live factory
flag and correctly displays `ON` while the factory is running (introduced by
commit `755320bcdb`). It failed before and after this work and was not weakened
or edited.

## Safety disposition

- Shipping the manifest/controller/display change created **zero** optimization
  work items. The first mutation remains an explicit Q14 `--apply` action.
- No `.set`, EA, news-staleness, terminal-worker, T_Live, FTMO terminal,
  deployment, scheduler, or AutoTrading surface changed.
- This artifact records implementation evidence only. It does not confer a Q14,
  Q15, Q16, portfolio, pipeline, deployment, or live-trading verdict.
