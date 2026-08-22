# Q09_NEWS autopilot repair — 2026-08-22

Task: `20dfec9f-561a-44d5-8f2b-d33d1952cde0`

Verdict: **PARTIAL RECOVERY / REVIEW**. The four orchestration paths are
implemented and regression-tested. Seven current legacy rescue rows are sealed
and runnable; rows whose historical evidence or Q07 lineage is missing remain
explicitly held. No gate threshold or contract criterion was changed.

## Implementation

Commits on `agents/board-advisor`:

- `cae2520fe` — immutable include-closure build/validation, deterministic
  standard-v2 auto-seal/bind, paired portfolio-rescue backfill, same-cycle Q09
  sealing, exact post-Q09 Q10 cascade, and terminal-finish cascade invocation.
- `06d064312` — allow a Q08 `FAIL_SOFT` rescue to reach the binder, which then
  requires and authenticates the exact `PASS_PORTFOLIO` sibling.
- `318e1cfc9` — remove stale failure diagnostics after a later successful seal.
- `fa49b2c84` (already present) — bounded two-retry cell execution,
  failure-sidecar persistence, continue-on-cell-error, and final aggregate over
  the complete cell cohort.

The auto-sealer derives every identity from the exact Q09 row and `Q08_INPUT`
dependency. It uses:

- lineage key `sha256(ea_id + 0x1f + symbol + 0x1f + q08_work_item_id)`;
- calendar bundle `q09cal-20150101-20260809-0bb19b5bb9790b76` and common path
  `QM/q09_news/q09cal-20150101-20260809-0bb19b5bb9790b76/events.csv`;
- full 2019-01-01 through 2025-12-31, selection through 2023-12-31, holdout
  from 2024-01-01, with 60/24 complete months;
- `REAL_TICKS`, `DXZ_CANONICAL_REAL_TICKS_V1`, DXZ, 40 cells, and a 10,800
  second per-cell timeout.

Existing include closures are rehashed against the EX5 and exact recursive
source/include inventory before reuse. Autopilot never supplies `--force`.
Every derivation, closure, build, or bind error leaves the row under the active
`Q09_AWAITING_SEALED_PLAN` hold with a structured stage, reason code, and error.

The original cascade starvation was a `LIMIT 10` scan applied before per-row
eligibility checks: ten permanently ineligible old rows could hide every later
candidate. The bounded scan is now 500, and a separate exact-pair repair path
creates the missing news arm only when the current Q08 and portfolio evidence
files and hashes authenticate. Q08 `FAIL_SOFT` is admissible only with a
matching done `PASS_PORTFOLIO` row for the same EA, symbol, setfile, Q08 ID, and
Q08 evidence hash. Q10 remains guarded by authenticated news and portfolio arms
and the existing five-seed confirmation contract.

## Verification

Committed-state focused suite:

```text
118 passed in 105.44s
```

The suite covers opt-census dispatch/selection, Q09 contract/calendar/schema,
the 40-cell runner, farm integration, Q10 confirmation, immutable include
closures, exact `FAIL_SOFT` portfolio authentication, unpaired-rescue refusal,
oracle standard-v2 plan semantics, per-row failure continuation, automatic
collect/persist, and exact-predecessor Q10 cascade invocation. Python compile
checks also passed for all changed modules.

## Governed production backfill

The current database did not match the stale task snapshot. The current exact
pair cohort is Q08 `FAIL_SOFT` plus `PASS_PORTFOLIO`, not Q08 `PASS`. Ten rows
had readable, hashable Q08 and portfolio evidence and were created under the
standard activation hold. Seven reached `RUNNABLE_BOUND` with an inactive hold,
a sealed plan path/hash, and `q09_cell_timeout_sec=10800`:

- `e454278b-3984-49f7-bbad-12e01254a89c` — QM5_12966/GDAXI.DWX
- `dd7b14a0-103c-4765-b2b5-8d0efb79e23b` — QM5_11910/NZDUSD.DWX
- `678b8cac-f572-44cb-a20a-6ac8dbfd2703` — QM5_12710/XTIUSD.DWX
- `77bd97c2-b2bb-4de6-8644-c0011e837f75` — QM5_10700/XAUUSD.DWX
- `aece4bcc-62aa-4f8e-937e-5f81c071a4d0` — QM5_12580/AUDUSD.DWX
- `a0533901-56f8-48bd-a5a1-c7c83ff8b4ab` — QM5_20086/EURUSD.DWX
- `317b916e-f93f-43ce-9b40-1c43d1639a49` — QM5_1354/XAUUSD.DWX

The resident factory subsequently claimed QM5_1354 normally. It was not
started, stopped, or interrupted manually.

Three created rows remain fail-closed under the active hold:

- `57d8bacd-2805-45a6-ac51-156e22bb3a65` — QM5_10815/GDAXI.DWX: the bound Q07
  evidence file is missing.
- `2604a1f0-4f58-4597-89ef-432af9093131` — QM5_1567/EURUSD.DWX: the Q08 payload
  has no Q07 predecessor binding.
- `856a8faf-97c2-4c62-9d63-aaafbbba397a` — QM5_12969/USDJPY.DWX: the Q08 payload
  has no Q07 predecessor binding.

Nine other exact historical pairs were not inserted because their Q08 or
portfolio evidence files are no longer readable: QM5_11421, QM5_10940,
QM5_10706, QM5_11132, QM5_10919, QM5_10403, QM5_1556, QM5_10939, and QM5_11708.
The task's examples QM5_10476/USDCAD and QM5_10715/USDJPY are also no longer
eligible: their latest exact Q08 rows are `FAIL_HARD`, not `PASS` or
`FAIL_SOFT`. Reconstructing missing evidence or overriding current verdicts
would fabricate pipeline lineage, so no such action was taken.

At audit time 17 Q09 rows remained held: the three backfill rows above plus 14
older rows with missing Q07 lineage/evidence or an include-closure inventory
mismatch. Their machine-readable holds are the durable recovery queue.

No terminal was launched manually, no active test was interrupted, no routing
command was run, and no live or AutoTrading setting was changed.
