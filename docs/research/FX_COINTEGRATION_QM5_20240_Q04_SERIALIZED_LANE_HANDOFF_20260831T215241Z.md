# QM5_20240 FX cointegration Q04 serialized-lane handoff

Date: 2026-08-31 UTC (`2026-08-31T21:52:41.8067599Z`); 23:52
Europe/Berlin

Branch: `agents/board-advisor`

Observation base: `c77b4f60cb485a247c9ef14214b62e8a150de62f`

Status: the frozen 66-pair frontier remains fully mechanized, the exact
existing USDCHF/GBPJPY continuation remains ready exactly once at Q04, the
explicit CPU ceiling is clear, and a healthy governed basket still owns the
single multisymbol lane. No Card, EA, work-item row, payload, claim, tester,
terminal, or portfolio object was created or changed.

## Non-duplicate frontier decision

The controlling reputable-source record remains
`docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its v3 scan tested all
66 FX relationships and selected only `QM5_12532` AUDUSD/NZDUSD and
`QM5_12533` EURJPY/GBPJPY under the published survivor criterion. Both have
canonical Q02 PASS; their later chains end at Q05 FAIL and Q04 FAIL,
respectively. Neither has a current Q02 `ONINIT` or `NO_HISTORY` blocker.

The committed sign-aware audit accounts for all 66 relationships. A fresh
repo-approved-card census found 119 distinct cointegration/coint EA IDs and a
matching EA directory for every ID. No relevant path changed after the prior
committed receipt at `299e75955e`; creating another Card, basket manifest,
magic allocation, EA, or Q02 row would therefore be duplicate work. The
Strategy Card extraction and EA-build gates remained closed.

## Existing forex fallback preserved

The dependency-correct continuation is frozen-scan rank 59,
`QM5_20240_USDCHF_GBPJPY_COINTEGRATION_D1`. Its approved Tier-A Chan-backed
Card, structural fixed-beta D1 implementation, compiled basket, manifest, and
logical setfile already exist. It trades `USDCHF.DWX` and `GBPJPY.DWX`, with
`USDJPY.DWX` used only for conversion history. The setfile remains
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`; there is no
learned model, adaptive beta refit, banned indicator, rescue filter, grid, or
martingale.

Its canonical lineage is unchanged and dependency-correct:

| Phase | Work item | State |
|---|---|---|
| Q02 | `24154a28-be35-469e-a5be-58881e29733c` | done / PASS |
| Q03 | `65a8b9cb-2c57-4068-81fb-2158f7b1beb7` | done / PASS |
| Q04 | `85e98029-14f6-4f73-a991-b814d4f3c151` | pending, priority-bound, unclaimed, attempt 0 |

The existing Q04 row still has `priority_track=true` with reason
`board_advisor_fx_fallback_rank59_q04_after_q03_pass`. There is already one
successor, so no duplicate enqueue, restamp, claim, or dispatch was attempted.

## Material serialized-lane progress

The prior 20:51 UTC receipt observed `QM5_20294_XAU_XAG_LOWMAX_D1` Q03 run 2
only as newly active. The same governed work item
`9437109a-799b-4f29-a501-89e6b4a3809c` remains active on T8, and its tester is
healthy and making authenticated forward progress:

- terminal PID `10536` and tester PID `10588` remain live;
- the tester is responding and has accumulated `6072.953125` CPU seconds;
- the append-only EA log reached simulated date `2020-05-14`, or 41.509% of
  the calendar span from `2018-07-02` through `2022-12-31`;
- the log was 208,708 bytes at `2026-08-31T21:52:24.7241559Z`, with snapshot
  SHA-256 `9486f84a7bdc82314171951550816c7a5d17e8c3d8dfa9d70fbe04a6959eae5f`;
  and
- no run-2 report exists yet, so Q03 correctly remains active without a
  verdict.

This is new run progress beyond the preceding stop receipt. Claiming or
launching `QM5_20240` concurrently would violate the one-basket pacing
contract.

## Capacity and stop condition

The final five one-second whole-host CPU samples were `77.455197%`,
`67.889500%`, `77.555391%`, `81.066181%`, and `77.064566%`. Average CPU was
`76.206167%` and maximum CPU was `81.066181%`, both strictly below the 97%
hard ceiling. CPU is not the binding stop for this wake; the healthy occupied
multisymbol lane is.

No dispatch tick ran and no worker, reservation, terminal, tester, queue row,
or verdict was controlled. After `QM5_20294` Q03 becomes terminal, take a new
five-sample CPU window. Only if both average and maximum remain strictly below
97% may the resident paced worker claim exact Q04 row
`85e98029-14f6-4f73-a991-b814d4f3c151`. Do not enqueue a duplicate or force a
second basket.

## Safety

- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  path changed.
- No `T_Live` manifest or terminal, AutoTrading state, live setfile, or deploy
  artifact changed.
- Existing unrelated staged, unstaged, and untracked worktree changes were
  preserved and excluded from this receipt.

Machine-readable evidence is
`artifacts/qm5_20240_q04_serialized_lane_handoff_20260831T215241Z_board_advisor.json`.
