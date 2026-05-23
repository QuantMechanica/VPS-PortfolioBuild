# DL-062 · Zero-Trade Rework Policy

date: 2026-05-23
authority: OWNER directive 2026-05-23
related: DL-054 (Gate 4 per-symbol zero-trade ADR), `_TEMPLATE_zero_trade.md`
status: ACTIVE

## Context

As of 2026-05-23, the strategy_farm state DB shows **78 EAs at P2 with
0 PASS verdicts and ≥1 FAIL verdicts** — i.e., backtests ran, but no
symbol passed the gate. A large fraction of these are zero-trade
failures: the strategy logic ran but never triggered a signal. Examples:
QM5_1371 (0/73), QM5_1143 (0/58), QM5_1089 (0/41), QM5_1058 (0/40),
QM5_1059 (0/40), QM5_1044 (0/39), QM5_10260 (0/37) — top scorers by
FAIL count.

DL-054 / `_TEMPLATE_zero_trade.md` exists for **per-symbol per-instance**
acceptance of `trade_count=0` as a non-PASS verdict. That's a different
layer — accepting an individual zero-trade run as terminal evidence.

This DL covers the **strategic** question: what do we do with an EA
whose zero-trade pattern is *universal across the symbol universe*? Not
just one symbol blocked by market conditions — the whole strategy is
mechanically silent. Such EAs are not dead-by-pipeline-rule (they
backtested, evidence exists), but they're equally not viable. They
need rework, not just archival.

## Decision

When an EA satisfies the **rework trigger** below, it is automatically
queued for a **`_v2` rework** rather than being dead-shelved.

### Rework trigger

All four must hold:

1. **Phase scope**: EA has reached at least P2 (Q02 Backtest gate).
2. **Coverage**: EA has ≥10 completed backtest runs (verdict ∈
   {`PASS`, `FAIL`}; `INVALID`/infra-failed runs do NOT count).
3. **Zero PASS**: count of `PASS` verdicts across all symbols = 0.
4. **Zero-trade dominance**: ≥80% of FAIL verdicts have `trade_count=0`.

The 80% threshold prevents triggering on EAs that have a few zero-trade
runs alongside real losing runs (those are economic failures, not
mechanical silence — different problem class).

### What rework means

A new EA card and source tree at `QM5_XXXX_<slug>_v2`. Same `ea_id`
family prefix is preserved, suffix `_v2` (then `_v3`, etc.) indicates
generation. The new card has its own ea_id (next free integer in the
QM5 range), with a `parent_ea_id` field pointing back to the original.

The `_v2` is a **fresh derivation**, not a fork:
- Strategy card body must be re-derived from the Strategy Card source
  with at least one of: parameter widening (e.g., RSI thresholds 70/30
  → 75/25 → 65/35), signal-logic substitution (e.g., crossover →
  divergence), or entry-condition relaxation (e.g., require 1 confirm
  instead of 2).
- Set files regenerated via `framework/scripts/gen_setfile.ps1`.
- Re-enters pipeline at Q00 (intake / G0 review) — does **not** inherit
  any pipeline progress from the original.
- All Hard Rules apply (no ML, RISK_FIXED for backtest, etc.).

### Ownership

- **Trigger detection**: a periodic job (TBD: hourly, in same cadence
  as the prior Repair_Hourly slot now retired) scans `work_items` for
  EAs matching the trigger, writes candidates to `agent_tasks` table
  with `task_type=research_strategy` and a `rework_target` field in
  the payload.
- **Rework design**: Claude (review skill) reads the original card +
  P2 evidence, drafts the parameter / logic change in a research
  artifact, hands to Codex.
- **Rework build**: Codex creates the `_v2` directory, copies and
  modifies source, generates set files, enqueues for P0/P1.
- **Original disposition**: the original EA is set to
  `state=RECYCLE` in `agent_tasks` with reason
  `"superseded by ea_id=<v2_ea_id> per DL-062"`. Strategy archive
  shows it as `s-recycled` (new status, distinct from `s-dead`).

### When NOT to rework (out-of-scope)

- EAs where the zero-trade pattern is **caused by infra failure**
  (INVALID dominates rather than FAIL) — those need `re-enqueue`, not
  rework. See the INVALID diagnostic workflow (Codex task `9632cb9e`
  re-route, 2026-05-23).
- EAs where the zero-trade pattern is **explained by a known
  market-condition window** (e.g., pure crisis-only logic that didn't
  fire in the backtest period) — those need a Strategy Card body update
  noting the expected sparseness, not a logic rework.
- EAs that have already been reworked twice (`_v2` and `_v3` exist
  with same trigger pattern) — escalate to OWNER for manual review;
  don't auto-spawn `_v4`. Risk: thrashing on a fundamentally broken
  edge.
- EAs that are flagged in `_TEMPLATE_zero_trade.md`-style per-symbol
  ADRs across the board (i.e., zero-trade was accepted on each symbol
  as a known final verdict) — those are by-design silent, not rework
  candidates.

## Acceptance criteria for a `_v2`

Identical to any new EA: must clear the full Q00→Q14 pipeline. No
special privileges, no fast-tracking, no inheritance from the original.
The `_v2` lineage is informational only — it does not lower any gate.

## Initial 78-EA candidate triage

This policy applies prospectively. The existing 78 candidates (top
ranked by FAIL count above) require OWNER-prioritized triage to
identify which are:
(a) genuine rework candidates → spawn `_v2` per this policy,
(b) infra-victims awaiting clean re-enqueue → wait for the INVALID
diagnostic Codex output before deciding,
(c) by-design-silent → ADR-cover with `_TEMPLATE_zero_trade.md` and
move to dead,
(d) escalate-to-OWNER.

A separate Codex `research_strategy` task should produce a triaged
list with one of the four labels per candidate. Sequencing: that task
SHOULD NOT auto-create `_v2` EAs — it labels only. The actual `_v2`
spawning happens through the OWNER-signed-off labels.

## Implementation backlog

This DL defines the policy. Not yet implemented:
- Trigger-detection job (scans work_items, writes rework candidates
  to agent_tasks)
- `_v2` build pipeline (Codex side: directory layout, set-file
  generation, ea_id allocation, parent_ea_id field in cards)
- `s-recycled` status in render_dashboards.py (new lane chip beside
  s-dead / s-live / s-flow)
- Initial 78-candidate triage Codex task
