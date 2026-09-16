# Q09 sealed-plan derivation (Q09_AWAITING_SEALED_PLAN) — diagnosis and OWNER package

Date: 2026-09-16
Agent: Kimi interim OWNER delegation, task `det-repairs`
Backlog row: `q09_sealed_plan_derivation` (RECOVERABLE_WITHOUT_OWNER, 2 rows,
expected ~4.08 runnable hours)
Verdict: **STOP — both rows are evidence-semantic, not deterministic derivation
gaps. The fail-closed holds are CORRECT. No code change made; no hold released.**

## Method

- Read both held rows (`work_item_holds` active `Q09_AWAITING_SEALED_PLAN`):
  - `8b233bbf-4ed6-4c27-a3d2-5e940c9248ab` (QM5_10148, EURNZD.DWX)
  - `08fe4173-07d9-47e1-97e9-a76b1159ad94` (QM5_11476, USDJPY.DWX)
- Re-ran both governed derivation lanes read-only:
  - autoseal/bind lane (`q09_news_runner.bind_plan_to_work_item`,
    failure stage `bind_plan`, re-observed 2026-09-16T14:25Z), and
  - anchor lane (`q09_pass_anchor_binder.py` census, receipt
    `2026-09-16_q09_binder_census.json`).
- Traced each failure to first principles (DB lineage, evidence files on disk).

Both lanes agree: the rows cannot be bound, and the refusals are correct
fail-closed behavior, not derivation defects.

## Row 1: 8b233bbf (QM5_10148)

Autoseal lane: `RunnerError: bound Q07 seed-stability evidence is missing`
(`q09_news_runner.py:1425`).
Anchor lane: `Q09 PASS aggregate/summary contradiction`.

Facts:

1. The identity-bound Q07 fallback resolves correctly: Q07 `bad1b2f7-5f19-40e7-
   90a5-880551e84d27` (PASS, EURNZD.DWX, exact setfile identity, created
   2026-08-20, before the Q08 PASS `1da1645c`). The derivation logic works.
2. The Q07 evidence file
   `D:\QM\reports\work_items\bad1b2f7...\QM5_10148\Q07\EURNZD_DWX\aggregate.json`
   **does not exist** — the whole work-item tree retains only empty directory
   skeletons (all `raw/run_01` dirs empty). This is 2026-08-31 evidence-loss
   incident damage. Fail-closed refusal is correct; no deterministic repair
   can recreate measurements.
3. The Q09 PASS source (`6ee9adbe`, the row's `promoted_from_work_item`)
   contradicts itself: `aggregate.json` says `verdict=PASS` (pf=1.57), but
   its own immutable run summary `.../20260905_092300/summary.json` says
   `result=FAIL, reason_classes=[MIN_TRADES_NOT_MET]` (29 trades < 30 floor,
   `recency_shadow_v1.q08_half_vs_half=INVALID`, `recency_gate=STALE_WINDOW,
   deployment_blocker=true`). Binding a sealed plan on this basis would
   manufacture news-gate lineage from a run that missed the measurement floor
   — evidence-semantic, OWNER/readjudication-lane territory.

## Row 2: 08fe4173 (QM5_11476)

Autoseal lane: `RunnerError: Q08 dependency has no Q07 lineage and no
identity-bound Q07 predecessor could be authenticated`.
Anchor lane: `no exact completed Q09 PASS source`.

Facts:

1. No Q07 work item exists for QM5_11476 at all (verified by phase census) —
   `_resolve_identity_bound_q07` has nothing to authenticate. Correct refusal.
2. The EA's only Q09 rows are `done FAIL` (fae2b8eb, 2a7e17b7); the Q08_INPUT
   dependency (`43c9d9d7`) is `FAIL_SOFT` with an empty lineage payload.
   There is no Q09 PASS anywhere to derive a sealed plan from. Deriving one
   would require a new economic Q09 measurement — verdict work, not infra.

## Options for OWNER

- `8b233bbf`: (a) order Q07 re-measurement (fresh Q07 run; consumes a terminal
  slot = economic spend) and route the Q09 aggregate/summary contradiction to
  the readjudication lane; or (b) retire/disposition the row.
- `08fe4173`: (a) re-run Q09 after addressing the Q09 FAIL verdicts; or
  (b) retire/disposition the row.
- `d712832c` (QM5_11422, NEWS_RUNNER_SPAWN_SILENT_ABORT, excluded from wave-3)
  belongs to this same lane: its bound plan fails source-vintage
  authentication at load (`load_authenticated_plan` -> `_validate_source_vintage`
  hash mismatch) — plan re-derivation needed once a fresh derivation basis
  exists.

## Artifacts

- Binder census receipt: `2026-09-16_q09_binder_census.json` (this directory).
- Machine-readable package: `2026-09-16_q09_sealed_plan_owner_package.json`.
- Runnable-hours unlocked by this item: **0 of ~4.08** (parked pending OWNER).
