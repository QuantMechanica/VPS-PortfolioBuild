# Slice f1_ftmo_validation_readiness — report

**Slice key:** `f1_ftmo_validation_readiness`
**Authority:** OWNER-DEC-CBE-20260915 (master directive 2026-09-15 sections 11-19, 57,
62, 63, 68F, 70; follow-up sections 13-14).
**Date:** 2026-09-15. **Branch:** agents/board-advisor (worktree).

## What this slice delivers

A deterministic FTMO Demo → readiness data model that can answer follow-up §13
end-to-end, plus the §14 material-change contract, a refreshed Standard-profile
rule snapshot, FTMO fitness kept separate from DXZ, and a policy guard proving no
paid-purchase code path exists.

The honest current answer, produced from real runtime data: **NOT READY.** The
running demo book is 8 DXZ-derived swing sleeves (explorative M13 capture, not a
frozen intended-challenge book); cycle-1 realized **-9.95 %** with a **-10.26 %
max drawdown that breached the 10 % total-loss limit**; best FUND_SCORE **0.41 vs
floor 1.0**; would-Fable-buy-today = **NO**.

## Files changed

### New package `tools/strategy_farm/ftmo/`
- `policy_config.py` — OWNER-only paid-Challenge policy constants (100k / 2-Step /
  Standard default; one paid Challenge at a time; success-probability-over-speed;
  14-day min validation; snapshot 7-day warn / 30-day blocker) and the §14
  material-change thresholds X (0.20 of book risk) and Y (0.10 of book risk).
- `rules_snapshot.py` — read-only freshness tracking, connectivity probe (GET only,
  injectable fetcher), safe fallback to disk when blocked, and format-preserving
  rulepack rebind (pointer + `as_of` + `rule_snapshot_binding` only; never a
  go-criterion value).
- `demo_cycle.py` — deterministic demo-cycle ledger + material-change state machine
  (NEW → RUNNING → REPRESENTATIVE → DECISION_PACKAGE); roster observed read-only
  from the terminal chart profile (`chart*.chr`), fallback attach-map.
- `ftmo_fitness.py` — `compute_ftmo_fitness(snapshot) -> dict`; FTMO axes only
  (venue=`ftmo`), degrades to NOT_EVALUATED/EVIDENCE_MISSING, reuses FUND_SCORE
  cache + first-passage evidence; asserts no DXZ axis leaks.
- `demo_metrics.py` — §16 account/sleeve metrics from the demo deal journal
  (read-only); names the exporter for every gap it cannot fill.
- `challenge_readiness.py` — assembles the readiness read-model + living doc;
  deterministic recommendation enum + "would Fable buy today" + strongest failure
  mode + blockers.

### New tests `tools/strategy_farm/tests/`
- `test_ftmo_demo_cycle.py`, `test_ftmo_fitness.py`, `test_ftmo_rules_snapshot.py`,
  `test_ftmo_challenge_readiness.py`, `test_ftmo_no_purchase_guard.py`.

### New docs / evidence
- `docs/ops/FTMO_DEMO_VALIDATION_CONTRACT.md` — §14 semantics + state machine.
- `docs/ops/FTMO_CHALLENGE_READINESS.md` — living doc (generated).
- `docs/ops/evidence/2026-09-15_ftmo_official_rules_snapshot.json` — refreshed
  Standard-profile snapshot (repairs the 2026-09-04 Swing/404/leverage gaps).

### Modified
- `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json` —
  rebound to the 2026-09-15 snapshot (pointer + sha + `as_of` + freshness binding
  block). Go-criteria thresholds unchanged (verified).

## Contracts written (shared read-models)

- `D:/QM/reports/state/ftmo_challenge_readiness.json` — `qm.ftmo-challenge-readiness/v1`.
- `D:/QM/reports/state/ftmo_demo_cycle.json` — `qm.ftmo-demo-cycle/v1`.
- `docs/ops/evidence/2026-09-15_ftmo_official_rules_snapshot.json` —
  `qm.ftmo-official-rules-snapshot/v2`.
- Python function `tools/strategy_farm/ftmo/ftmo_fitness.py:compute_ftmo_fitness(snapshot) -> dict`
  (E1 imports lazily; degrades to NOT_EVALUATED if absent — present here).

## Tests + pytest summary

`python -X utf8 -m pytest tools/strategy_farm/tests/test_ftmo_demo_cycle.py
test_ftmo_fitness.py test_ftmo_rules_snapshot.py test_ftmo_challenge_readiness.py
test_ftmo_no_purchase_guard.py -q`
→ **35 passed in 2.17s** (1 pre-existing unrelated DeprecationWarning in farmctl.py).

Coverage vs §70: FTMO two-week Demo state tracked correctly (cycle state machine +
material-change reset); paid purchase cannot occur through automation (no-purchase
guard greps package, asserts none; no HTTP POST); only one paid-Challenge policy
represented (policy constants + no competing default size); venue fitness remains
separate (fitness venue=ftmo, no DXZ axis leak); rules freshness blocker; safe
fallback on blocked fetch; deterministic/reproducible from frozen inputs.

## Runtime artifacts written (real data)

- `D:/QM/reports/state/ftmo_demo_cycle.json` — 8 sleeves, roster_hash
  `6c5383d8…`, state NEW, source chart_profile.
- `D:/QM/reports/state/ftmo_challenge_readiness.json` — recommendation NOT_READY,
  strongest failure = -10.26 % total-loss breach, 105 sleeves scored, best
  FUND_SCORE 0.4076 vs floor 1.0, demo cycle-1 net -9.95 % / maxDD -10.26 %.
- `docs/ops/FTMO_CHALLENGE_READINESS.md` — regenerated living doc.
- Rulepack `FTMO_2S_100K_STANDARD_V2.json` rebound to the 2026-09-15 snapshot.

## Rollback

- Delete the new package files under `tools/strategy_farm/ftmo/` (policy_config,
  rules_snapshot, demo_cycle, ftmo_fitness, demo_metrics, challenge_readiness) and
  the five new tests.
- `git checkout -- tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_STANDARD_V2.json`
  restores the 2026-09-04 binding.
- Remove the new docs/evidence files. Runtime read-models under `D:/QM/reports/state/`
  are regenerated artifacts and can be deleted; no farm-DB or evidence was mutated.

## Items NOT done (with reasons)

- **First-passage / p_pass per FTMO-locked pair:** left as EVIDENCE_MISSING. No pair
  is CONFIG_LOCKED to FTMO (Q10 admits 0/42), so the existing first-passage engine
  has no FTMO-scoped inputs to run on. `compute_ftmo_fitness` accepts a
  `first_passage` block when a future FTMO-locked run produces one.
- **Q10 admission wired into the readiness build:** the readiness CLI defaults
  `q10_admission=None` (→ EVIDENCE_MISSING) to stay DB-free and fast; the audit's
  0/42 figure is reproducible via `q09_ftmo_recommendation.collect()` and can be
  passed in. Deliberate to avoid a heavy read-only DB dependency in the default
  build path; the honest verdict is already NOT_READY via the realized breach and
  FUND_SCORE floor.
- **Per-symbol cost/swap and payout suitability axes:** NOT_EVALUATED — need the
  per-symbol FTMO cost snapshot (only 5/10 symbols covered per the audit) and a
  funded-account payout model. Exporters named in `demo_metrics._EXPORTER_GAPS`.
- **§16 intratrade equity / spread / slippage / session / news / gap metrics:**
  reported as NOT_EVALUATED with the required exporter named; the raw deal journal
  does not carry them.
- **FTMO census/lane tickets 42a437a4 and 3e0c8b83:** not touched (orchestrator
  owns `agent_tasks`). See note below.

## Note for the orchestrator (tickets)

- **42a437a4** (v2 demo-book census, IN_PROGRESS, RECYCLE→merge): this slice does
  not deploy or modify the v2 book. The readiness model treats the running M13
  book as the observed roster and reports NOT_READY; when the merged v2 roster is
  frozen, run `demo_cycle build` then `challenge_readiness build` to re-evaluate.
  Drift D1 (US500.cash/NATGAS.cash resolvable from the v1 attach map) is unchanged
  and still a census decision, not a readiness one.
- **3e0c8b83** (session-pin fix): unaffected by this slice.
- Recommend adding two scheduled builds (like the other read-model tasks):
  `python -m tools.strategy_farm.ftmo.demo_cycle build` then
  `python -m tools.strategy_farm.ftmo.challenge_readiness build`, demo_cycle first
  so readiness reads the persisted ledger.
