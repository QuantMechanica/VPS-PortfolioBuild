# Q10 long-cell breaker — 7-day dry-run retrospective + activation checklist

- Router task: `5527df0c-26dc-49d3-a3e6-6efc366d3179` (ops_issue, claude, priority 70)
- Executed: 2026-08-27, from canonical checkout `C:/QM/repo` on `agents/board-advisor`
- Subject: `tools/strategy_farm/q10_long_cell_breaker.py`, delivered+APPROVED dry-run
  per `docs/ops/evidence/2026-08-24_q10_long_cell_circuit_breaker.md` (task
  `cae3df77`). **This ticket implements/activates nothing** — read-only
  retrospective + recommendation only, per its own constraint.

## Method

`read_active_q10_parents()` only sees the *current* `active`/`pending` Q10
snapshot, so it cannot answer "what would it have flagged over the last 7
days" by itself — a parent that already finished has left that state. I wrote
an ad hoc read-only script (not committed; reused the breaker's own pure
`scan_parent_cells` / `evaluate_parent` functions unmodified) that instead
queried `work_items` for every `Q10_NEWS`/`Q10` row with `updated_at` in the
last 7 days **regardless of current status**, then ran the identical
threshold/classification logic against each row's on-disk cell artifacts
(`D:\QM\reports\work_items\<id>\q09_contract_v3\cells`). Raw result JSON:
`D:\QM\reports\state\q10_long_cell_breaker_7day_retro.json`. No DB write, no
hold, no `--apply` executed anywhere in this ticket.

## 1) What the breaker would have flagged

| Metric | Count |
|---|---|
| Q10 parents touched (`updated_at`) in last 7 days | 128 |
| ...of which cell artifacts already purged from disk / never had Q09 cells | 32 |
| Parents evaluated against the threshold rule | 96 |
| **Parents that would breach** (`max(3×median, 7200s)`) | **62** |

62/96 (65%) of evaluated parents breach. That headline number is misleading
on its own — see the false-positive breakdown below, which is the actual
finding.

## 2) False-positive review — the number that matters

I cross-joined each of the 62 breaching parents against its own `work_items`
row (`status`, `attempt_count`, `claimed_by`):

| Class | Count | Verdict |
|---|---|---|
| `attempt_count=0` **and** `claimed_by IS NULL` — never dispatched | **54 / 62 (87%)** | **FALSE POSITIVE** |
| `attempt_count≥1`, currently `claimed_by` set (terminal actively holds it) | 3 / 62 | Genuine — matches the `13f41983` pathology this breaker targets |
| `attempt_count≥1`, `claimed_by=NULL` now (`failed`/`done`/`pending` after a prior released attempt, stale abandoned cell dirs left over) | 5 / 62 | Ambiguous — real garbage, but not a *current* occupancy breach |

### Root cause of the 54-parent false-positive class

Example: work item `06b9c0f8` (`QM5_11147`/`SP500.DWX`), `status='pending'`,
`attempt_count=0`, `claimed_by=NULL`, `created_at=2026-08-23T16:24:56Z`. Its
cell directory `control_off__m0__c0__s17` contains only `inputs.set` (plan
materialization) — no `runs/*/*/*` tester-run directory exists because the
cell has **never been dispatched to a terminal**. `_earliest_run_marker_epoch`
falls back to the `inputs.set` mtime as the wall-time start when no run
directory exists, `scan_cell_timing` classifies it `inflight` (no receipt, no
`cell_failure_3.json`), and `end=now`. Wall time is therefore reported as
"time since the plan was materialized", not "time occupying a terminal" —
**322,713s (3.7 days) of pure queue-depth, not a stuck cell**. This shape
recurred identically across 54 of the 62 breaches (several EA/symbol pairs,
`created_at` clustered 2026-08-23 through 2026-08-27, i.e. the entire current
backlog depth).

This is not a cosmetic wrinkle: `read_active_q10_parents()` in the shipped
module selects `status IN ('active','pending')` — **`pending` is in scope for
the real breaker today**, so every one of these 54 would be flagged by a live
`--apply` run right now, and each flag writes a `work_item_holds` row that the
claim selector (`farmctl.py:1499-1502`) then excludes from the pending queue.
**Activating `--apply` as shipped would self-inflict holds on the entire
population of not-yet-started backlog work and stop the factory from ever
claiming it — a throughput regression the breaker exists to prevent, not
cause.**

The 5 "ambiguous" cases are real but softer: leftover cell directories from
one earlier claim attempt that was released (parent went back to
`pending`/`failed`/`done`) without cleanup, so old `inflight` classification
persists and grows forever even though nothing currently holds the row. Worth
a separate cleanup pass; not an activation blocker in the same way.

The 3 genuine matches (`a0694aa0`/`QM5_10848` held by `T8`, `205e5aef`/`QM5_10938`
held by `T6`, `ac59fa26`/`QM5_10692` held by `T3`) are exactly the target
pathology: `status='active'`, terminal currently assigned, cells inflight
1854–2069 minutes past the 120-minute floor with no receipt.

## Recommendation before any scheduling

**Do not schedule `--apply` on the module as shipped.** Add one precondition
to `read_active_q10_parents` (or filter in `run()`): only evaluate parents
where `claimed_by IS NOT NULL` (i.e. a terminal genuinely holds the row right
now), not merely `status='pending'`. That single change eliminates the
54-parent false-positive class by construction, since a never-claimed row has
no terminal to free and nothing to hold-block. The 5 ambiguous stale-debris
cases should route to a separate cleanup check, not the breaker's hold path.
This is a code change, not a config flip — flagging it for whoever owns the
next revision; this ticket does not implement it.

## 3) Recommended `--apply` cadence + alert path (once the precondition fix lands)

- **Cadence**: new Scheduled Task `QM_StrategyFarm_Q10LongCellBreaker`, SYSTEM
  account, **15-minute** interval (same cadence family as
  `QM_StrategyFarm_QuotaGovernor`) — a 120-minute floor threshold tolerates a
  15-minute detection lag trivially, and matches the "recovery script family"
  precedent in this repo rather than inventing a new cadence class.
  `python C:/QM/repo/tools/strategy_farm/q10_long_cell_breaker.py --apply --json --no-state`
  from the canonical checkout only (per the worktree-hazard precedent already
  documented for other recovery scripts).
- **Alert path**: no new channel — the module already surfaces via
  `health.chk_q10_long_cell_breaker_holds` (`WARN` on any active hold, `FAIL`
  past 6h unactioned), which already feeds `farmctl.py health` /
  `state/health.json`. That is consistent with "Mail-Kanäle: NUR 06:00-HTML +
  FAIL-Digest" — a `FAIL` row after 6h rides the existing FAIL-Digest without
  a bespoke notification path.
- **Kill switch**: `QM_DISABLE_Q10_LONG_CELL_BREAKER=1`, already implemented,
  read fresh every run, no restart needed.

## 4) Activation checklist for orchestrator review

1. [ ] Land the `claimed_by IS NOT NULL` precondition (or equivalent) on the
   evaluated population; re-run this same 7-day retrospective method and
   confirm the false-positive class (never-claimed `pending` rows) drops to 0.
2. [ ] Re-run retrospective once more against a fresh 7-day window immediately
   before scheduling, to confirm no new false-positive shape has appeared
   (e.g. from the 5 ambiguous stale-debris rows — decide whether those need
   their own filter too).
3. [ ] Install the Scheduled Task per §3 in dry-run (`--apply` **omitted**)
   for one full day; confirm `health.json` stays `OK`/`WARN` only and no
   holds are written to already-queued, not-yet-claimed work.
4. [ ] Flip the task to `--apply`; watch `chk_q10_long_cell_breaker_holds` and
   `farmctl.py health` for one shift (per the existing 6h `FAIL` window) before
   declaring it unattended.
5. [ ] Confirm `QM_DISABLE_Q10_LONG_CELL_BREAKER=1` is documented in the
   runbook that owns Q10 incident response, so an operator can kill it without
   a code change if it misfires again after the fix.
6. [ ] OWNER/orchestrator sign-off recorded before the Scheduled Task is
   installed — this is a GRÜN-adjacent infra change (new automated `--apply`
   cadence) but touches claim eligibility, so treat as GELB per the standing
   authorization's "new Q14-adjacent levers" caution rather than assuming GRÜN.

## Evidence

- `D:\QM\reports\state\q10_long_cell_breaker_7day_retro.json` (raw retrospective,
  96 evaluated parents, 62 breaching, per-parent breakdown)
- `docs/ops/evidence/2026-08-24_q10_long_cell_circuit_breaker.md` (module this
  builds on)
- No database, registry, gate criterion, verdict, or hold was written by this
  ticket. Read-only throughout.
