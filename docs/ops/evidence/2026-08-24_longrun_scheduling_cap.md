# Long-run claim-selection cap — Q10_NEWS expansions + Q07/Q08

- Router task: `de0f052e-8e04-419a-bfc6-c81ff4362abf` (ops_issue, claude)
- Executed: 2026-08-24, from canonical checkout `C:/QM/repo` on
  `agents/board-advisor`
- Source: `docs/ops/evidence/2026-08-24_throughput_forensics.md`
  (branch `rb-throughput-forensics`, commit `e88c8e9b0`), recommendation 1:
  "Cap expanded news parents at two fleet-wide... allow at most two 29-cell
  Q10 expansions, and at most two concurrent Q07/Q08 long regenerations...
  Validate this as a scheduling policy; do not alter any gate criterion."

## Scope

Claim-selection only. No gate criteria, verdict logic, or deletions were
touched. A skipped candidate stays `pending` and is reconsidered on the next
claim attempt once fleet occupancy drops — it is never requeued, rewritten,
or dropped.

## What changed

- `tools/strategy_farm/longrun_scheduling_policy.py` (new): pure functions —
  `classify_longrun_candidate` (identifies a `Q10_NEWS` row with
  `payload.force_expanded_news_matrix=True`, or any `Q07`/`Q08` row, as one
  of two long-run classes), `active_longrun_counts` (fleet-wide `status='active'`
  count per class, read inside the caller's existing transaction),
  `should_skip_for_longrun_cap` (skip decision + detail record), and
  `policy_enabled()` (the rollback switch).
- `tools/strategy_farm/terminal_worker.py`: added `_Q07_PHASE = "Q07"` next
  to the existing `_Q08_PHASE = "Q08"`; wired the policy into the existing
  claim-candidate loop in `claim_atomic` using the same skip-ledger
  convention as `skipped_history` / `skipped_launch_cooldown` / etc.
  (`skipped_longrun_cap`, returned as `longrun_cap_skipped`). The fleet-wide
  active count is computed once per claim attempt (lazily, on first
  long-run candidate encountered) inside the same `BEGIN IMMEDIATE`
  transaction as the eventual claim commit, so it cannot race another
  worker's concurrent claim.
- `tools/strategy_farm/tests/test_longrun_scheduling_policy.py` (new): 14
  tests — pure classify/cap-decision coverage, a real-DB
  `active_longrun_counts` test, and three end-to-end
  `terminal_worker.claim_atomic` integration tests against a temp farm root.

## Policy

| Class | Fleet-wide cap | Identified by |
|---|---:|---|
| Expanded Q10_NEWS parent | 2 | `phase == Q10_NEWS` and `payload.force_expanded_news_matrix is True` |
| Q07 / Q08 long regeneration | 2 | `phase in ('Q07', 'Q08')` |

On a 10-terminal fleet, `10 - (2 + 2) = 6` terminals are never blocked from
ordinary short gates/compiles by long-run occupancy — the forensics report's
"short-flow floor" falls out of the two caps directly rather than being a
third, separately-enforced number.

## Rollback (config flag)

Set `QM_DISABLE_LONGRUN_SCHEDULING_CAP=1` in the worker environment to fall
back to the pre-existing unconstrained claim order (same convention as
`QM_ENABLE_GEMINI_BUILDS` / `QM_ALLOW_NONCANONICAL`). No code revert or
restart-time migration is required; `policy_enabled()` is read fresh on
every claim attempt.

## Verification

```text
python -m pytest -q tools/strategy_farm/tests/test_longrun_scheduling_policy.py
14 passed in 12.37s

python -m pytest -q tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py
68 passed in 51.05s   # pre-existing claim suite, unaffected
```

### Before/after claim simulation (acceptance criteria 1 and 2)

Setup: 2 expanded `Q10_NEWS` parents already `active` fleet-wide (`T1`,
`T2`), plus one more pending 3rd expansion and one ordinary pending `Q03`
row that both outrank nothing else. A free terminal `T3` attempts a claim.

**1) Third expansion not claimed while 2 are active — with the policy
enabled (default), and only the 3rd expansion pending:**

```json
{
  "claimed": false,
  "reason": "no_pending_claimable",
  "longrun_cap_skipped": [
    {
      "item_id": "pending-expansion",
      "ea_id": "QM5_3",
      "longrun_class": "expanded_news_parent",
      "active_count": 2,
      "fleet_cap": 2
    }
  ]
}
```

**2) Floor case — short row not displaced.** Same 2 active expansions, but
now BOTH the capped-out 3rd expansion and an ordinary `Q03` row are pending
(the expansion would otherwise outrank the Q03 row in `_phase_rank`):

- Before (`QM_DISABLE_LONGRUN_SCHEDULING_CAP=1`, pre-patch behavior):
  `claimed=true`, `item_id="pending-expansion"` — the 3rd expansion wins by
  priority rank and occupies a 5th long-run terminal.
- After (policy enabled, default): `claimed=true`,
  `item_id="pending-short"` — the capped-out expansion is skipped and the
  ordinary short row is claimed instead, exactly the forensics
  recommendation's intent (reserve terminals for the short tail rather than
  letting long-run rows monopolize the fleet by priority rank alone).

Reproduction script: both scenarios above were run against a temporary
`farmctl.init_db()` root with `terminal_worker.claim_atomic()` — the real
production entry point, not a mock — via the integration tests in
`test_longrun_scheduling_policy.py::ClaimAtomicIntegrationTests`.

## Rollout note

This changes claim SELECTION only; it does not retroactively touch the
three already-active 29-cell expansions or the standard-matrix/Q07 rows
described in the forensics snapshot. It takes effect on the next claim
attempt by any terminal after this commit lands, fleet-wide (all workers
import the same `tools/strategy_farm/terminal_worker.py`).
