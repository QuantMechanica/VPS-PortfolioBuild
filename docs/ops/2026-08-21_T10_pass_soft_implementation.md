# T10 — Q06 PASS_SOFT band verdict: implementation protocol (2026-08-21)

**Auftrag:** Implement `PASS_SOFT` for gate Q06, OWNER Option A of
`docs/ops/Q05_Q06_FAIL_SOFT_VORLAGE_2026-08-21.md` (approved 2026-08-21; activation
condition met — band measured at 40.3% in
`docs/ops/evidence/2026-08-21_q06_fail_soft_band_sizing.md`, threshold ≥ 2%).
**Classification:** ROT (gate criteria) — executed under the OWNER Option-A approval only.
**Scope:** config + runner emission + one anti-stacking guard + dashboard chip + tests.
No factory / DB-write / terminal interaction was performed during implementation.

## Changed files + lines

| File | Lines | Change |
|---|---|---|
| `framework/scripts/q06_stress_harsh.py` | 45–51 | New constant `SOFT_PF_FLOOR = 0.95` + rationale. |
| " | 208–223 | `pf_below_floor` branch restructured: emit `PASS_SOFT` when `SOFT_PF_FLOOR ≤ pf < PF_FLOOR` **and** `dd_pct ≤ DD_PCT_MAX` **and** trades ≥ MIN_TRADES (already guaranteed). DD guard placed HERE because this branch fires before `dd_above_ceiling` in the elif chain. |
| " | 309–314 | `main()` exit code: `PASS_SOFT` returns 0 (advancing), mirroring `q04.exit_code_for_verdict`. |
| `tools/strategy_farm/farmctl.py` | 16434 | `cascade_pass_verdicts["Q06"]` → `{"PASS", "PASS_SOFT"}` (Q06→Q07 cascade). |
| " | 20033 | `phase_prev_verdicts["Q07"]` → `{"PASS", "PASS_SOFT"}` (Q07 predecessor = Q06). |
| " | 14382–14428 | New helpers `_q08_cost_cushion_edge_soft` + `_q06_soft_probation_present`. |
| " | 14463–14520 | Anti-stacking guard inside `_promote_q08_soft_fails_to_q09_portfolio`. |
| `tools/strategy_farm/dashboards/render_dashboards.py` | 2378–2392 | `_verdict_family`: `PASS_SOFT` → own `"passsoft"` family; `_VCLS["passsoft"]="v-passsoft"`. |
| " | 2495–2505 | `passsoft` still counts as gate advancement (`n_pass`/highest-pass-phase). |
| " | 4054, 4154 | Inline verdict→class maps: `"PASS_SOFT": "v-passsoft"`. |
| " | 1685, 1759, 1897 | `.v-passsoft{color:var(--signal)}` in archive/wi/att table style blocks. |
| `framework/scripts/tests/test_q05_q07_verdicts.py` | +helper +5 tests | Q06 verdict truth table. |
| `tools/strategy_farm/tests/test_farmctl_cascade.py` | +`Q06SoftStackingTests` (3 tests) | Anti-stacking helpers + promote integration. |

`CANONICAL_PARENT_CHILD_VERDICTS` (farmctl:9046) **already** contained `PASS_SOFT` — no
change, as the sizing audit predicted. Q05 was NOT touched.

## Verdict truth table (Q06 runner, after all hard/INVALID checks upstream)

Preconditions reaching the PF branch: summary valid, stress input authenticated (=0.10),
`trades ≥ MIN_TRADES (20)`, `pf` and `dd_money` present. `dd_pct = dd_money/100000*100`.

| pf | dd_pct | Verdict | reason |
|---|---|---|---|
| pf > 1.00 | ≤ 25 | **PASS** | `pf=…:dd_pct=…:stress=HARSH` |
| pf > 1.00 | > 25 | **FAIL** | `dd_above_ceiling:…` |
| 0.95 ≤ pf < 1.00 | ≤ 25 | **PASS_SOFT** | `pass_soft_band:pf=…:dd_pct=…:probation:q06_soft` |
| 0.95 ≤ pf < 1.00 | > 25 | **FAIL** | `pf_below_floor:…` (DD guard blocks the band) |
| pf == 1.00 | any | **FAIL** | `pf_below_floor:…` (1.00 is outside the `< 1.00` band) |
| pf < 0.95 | any | **FAIL** | `pf_below_floor:…` |
| trades < 20 | — | **FAIL** | `trades_below_floor:…` (never reaches PF branch) |
| INVALID/INFRA classes | — | **INVALID** | unchanged |

Boundary choices: band is `[0.95, 1.00)` (PF=1.00 excluded, matching the sizing evidence
§4(c)); DD predicate reuses the exact hard-gate test `dd_pct ≤ DD_PCT_MAX` so PASS_SOFT ⇔
"would be PASS except PF is in the soft band". `probation:q06_soft` rides in the `reason`
string, which propagates to `payload_json → verdict_reason` exactly as today's reasons do
(verified against the sizing-audit reproduction query — no new aggregate key added).

## Anti-stacking status: IMPLEMENTED

**Rule:** an (ea, symbol) with `probation:q06_soft` lineage whose Q08 outcome is the
DL-072 thin cost-cushion `EDGE_SOFT` (1× ≤ cushion < 2×) becomes **terminal FAIL**
(reason `soft_stacking_forbidden:q06_soft+q08_edge_soft`), never routed onto the Q09
portfolio-rescue track.

**Location decision (why NOT "where EDGE_SOFT is decided"):** the literal EDGE_SOFT
decision is `q08_davey/aggregate.py::_aggregate_verdict`, but that runner is a pure
per-(ea,symbol) evidence producer — it has **no** access to pipeline lineage and must do
**no** DB read (both a task constraint and an architectural purity break; wiring the Q06
lineage in would require threading a new parameter through `run_all` + `main` + the
farmctl spawn cmd + a farmctl DB lookup — a 4-point change to a hot-path aggregator).
The Q06 lineage lives only in the DB, owned by farmctl. The **clean single point where
both signals are already in scope** is farmctl's
`_promote_q08_soft_fails_to_q09_portfolio` — the exact routing step where a Q08 thin-
cushion `FAIL_SOFT` would otherwise advance onto the Q09 rescue track. The guard is
append-only (the Q08 verdict is never overwritten — ROT-safe) and mirrors the existing
below-min `NEED_MORE_DATA` terminal-row idiom in the same function. Detection:
`q08_verdict_classification.cost_cushion == "EDGE_SOFT"` (top-level `cost_cushion_tier`
fallback) — a clean Q08 PASS can never carry that tier, so the guard only ever fires on
the thin-cushion `FAIL_SOFT`, exactly the DL-072 1–2× band the Vorlage names.

## Dashboards

- `render_dashboards.py`: `PASS_SOFT` renders as its own steel-blue `v-passsoft` chip at
  every verdict-chip site; never collapsed into the green `v-pass`. It still counts as
  gate advancement for progress/highest-pass-phase (a probation IS advancement). The
  coarse EA-lifecycle label in `_idx_status` (has-passed-a-gate) is left unchanged — it
  already treats every soft-pass family (Q04 PASS_SOFT/PASS_LOWFREQ) identically; that is
  pre-existing behavior, out of scope for "don't collapse the per-verdict chip".
- `render_cockpit.py`: **no change needed** — the funnel already buckets `PASS_SOFT` into
  `is_soft` (render_cockpit.py:375), never `is_pass`. (Note: the cockpit `upstream` CTE
  counts only `verdict='PASS'` as an upstream advance; this already under-counts Q04
  PASS_SOFT advancers and is an established pre-existing convention, left untouched.)

## Test results

- `framework/scripts/tests/test_q05_q07_verdicts.py`: **57 passed** (5 new Q06 band tests:
  ok-DD→PASS_SOFT, high-DD→FAIL, PF==1.00→FAIL, PF>1.00→PASS, PF<0.95→FAIL).
- `tools/strategy_farm/tests/test_farmctl_cascade.py::Q06SoftStackingTests`: **3 passed**
  (`_q08_cost_cushion_edge_soft`, `_q06_soft_probation_present`, promote integration:
  ea1 stacks→terminal FAIL, ea2 control→normal promotion).
- Regression suites all green: `test_farmctl_cascade` (full), `test_render_cockpit_cohorts`,
  `test_verdict_taxonomy_ws2`, `test_phase_verdict_semantics`, `test_pipeline_view_work_items`,
  `test_work_item_lifecycle_v2`.
- `py_compile` clean on all four changed Python modules.

## Rollback

1. Config-only revert of advancement: remove `PASS_SOFT` from the two farmctl policy dicts
   (`cascade_pass_verdicts["Q06"]`, `phase_prev_verdicts["Q07"]`). Q06 stops advancing soft
   rows immediately on the next runner/farmctl load.
2. Runner revert: restore the single `pf_below_floor` line in `q06_stress_harsh.py` (drop
   the `SOFT_PF_FLOOR` branch + constant + the `main()` exit-code arm). Q06 emits only
   PASS/FAIL/INVALID again.
3. Anti-stacking is inert once (1) holds (no new PASS_SOFT lineage is produced); to remove
   it fully, delete the guard block + the two helpers in farmctl.
4. Dashboard: drop the `v-passsoft` CSS + the `"passsoft"` family; harmless if left.

Already-written `PASS_SOFT` / `soft_stacking_forbidden` rows remain as append-only
evidence — no verdict is overwritten. Blast radius: Q06→Q07 forwarding and the one Q08→Q09
routing guard; no live/deploy/T_Live contact.
