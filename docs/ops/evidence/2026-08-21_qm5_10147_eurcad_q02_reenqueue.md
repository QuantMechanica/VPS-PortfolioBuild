# QM5_10147 EURCAD repaired-INFRA Q02 re-enqueue

Date: 2026-08-21 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

One distinct rare-FX funnel-recovery unit was completed. The repaired
`QM5_10147_tii-momentum` EURCAD D1 candidate was handed back to paced Q02 as
append-only work item `dd3b7038-6d91-4245-88be-4c8a5147b800`.

The immediate readback was `pending`, attempt 0, unclaimed, and without a
verdict. No pump, dispatch tick, terminal, smoke test, or backtest was started
manually. This is a Q02 handoff, not an economic or certification result.

## Selection and collision control

- The approved build backlog had no unclaimed, registry-complete reputable
  forex, crypto, rates, beyond-XNG energy, or market-neutral build. The
  concurrently owned WTI build was excluded.
- `QM5_10147` is an OWNER-approved, R1-R4 PASS strategy sourced to Raposa
  Technologies' published TII article. It is a structural closed-bar D1 state
  machine with an expected cadence of 10 trades/year/symbol and no ML, grid,
  or martingale.
- The distinct target is `EURCAD.DWX`; it is not the previously completed
  `EURCHF.DWX` recovery.
- Before mutation, the farm had no open work item, downstream lineage, exact
  successor, or competing open agent task for this EA.
- Atomic farm claim:
  `fc69e317-d5c8-4f35-b2cb-132983dbdc25`, assigned to
  `codex:agents/board-advisor`.
- Claim key:
  `manual:codex:agents/board-advisor:QM5_10147:EURCAD.DWX:q02-tii-runtime-recovery-enqueue:20260821T200127Z`.
- Pre-claim online SQLite backup:
  `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_10147_eurcad_q02_enqueue_claim_20260821T200127Z.sqlite`;
  `PRAGMA quick_check` returned `ok`.

The initially considered `QM5_9194` GBPUSD continuation was not claimed or
mutated: its legacy source row no longer has a readable bound evidence file,
so the current append-only audit gate correctly refuses that lineage.

## Bound infrastructure repair

The immutable source row
`44023000-f837-4323-be2e-442c353ca2e8` remains
`failed / INFRA_FAIL`. Its authenticated evidence records
`cold_cache_retries_exhausted:BARS_ZERO` on the pre-repair artifacts:

- MQ5 SHA-256:
  `c47b1814e8d2be930424b91ee20a9c01112529e5b0e9e5a90ce39cfd875fabab`;
- EX5 SHA-256:
  `dcb983ffbe16a850bacc83117a9c1cb5ad4b97282fea6004fd425d798deabd5c`;
- source evidence:
  `D:\QM\reports\work_items\44023000-f837-4323-be2e-442c353ca2e8\QM5_10147\20260728_084159\summary.json`;
- source-evidence SHA-256:
  `1c088a517b3af7a8bc1701ac5b29a5fb127a04842985fed54a02041dff29252f`.

The mechanics-preserving repair in commit `f7d2315f8` removed the tester hot
path by replacing repeated historical indicator-handle reads with one bounded
closed-bar TII/ATR cache. The same repaired binary already converted the
separate EURCHF infrastructure lineage into a real economic Q02 result.

Current canonical bindings were reverified before the claim and enqueue:

| Artifact | SHA-256 |
|---|---|
| MQ5 | `a767f02c2ed31f90e2d8233fdf0cfb23a9a8c4314c7734e942fef65f3e650741` |
| EX5 | `12fd25c63ef5aafcd6cfea88ebf76c193c8a95e0bedc5d25935113e19fbfcb2e` |
| EURCAD D1 setfile | `84b51c358cfc14dd8eefbea90205a937acb2359f3f100b01102841c58f019d55` |

The setfile remains `RISK_FIXED=1000`, `RISK_PERCENT=0`, slot 9, and D1. No
strategy source, mechanic, parameter, registry, or risk setting changed in
this unit.

## Append-only Q02 receipt

The governed exact-row enqueue created one row and no duplicates:

| Field | Value |
|---|---|
| Successor | `dd3b7038-6d91-4245-88be-4c8a5147b800` |
| Phase / symbol / period | `Q02 / EURCAD.DWX / D1` |
| Predecessor | `44023000-f837-4323-be2e-442c353ca2e8` |
| Immediate state | `pending`, attempt 0, unclaimed |
| Exact-successor count | 1 |
| Payload classification | `append_only_rerun=true`, `repaired_infra_rerun=true` |
| Risk binding | `risk_fixed=1000.0`, `risk_percent=0.0` |

The successor binds the repaired hashes above, records the historical EX5
mismatch, and preserves the source row unchanged. Its archive admission is
`ACTIVE` for `EURCAD.DWX`, with 108 selected archive rows and OWNER-approved
manifest SHA-256
`fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`.

The paced worker and its CPU claim gate own execution. Enqueueing did not
reserve capacity or launch MT5, and no capacity guard was bypassed.

## Safety boundary

No T_Live file or process, AutoTrading setting, portfolio gate, live/deploy
manifest, terminal reservation, worker process, or historical verdict was
changed. Unrelated shared-worktree changes were left unstaged.
