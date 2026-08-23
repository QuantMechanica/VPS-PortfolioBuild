# QM5_41131 WTI monthly daily tail-trim momentum — source build and CPU-ceiling handoff

Date: 2026-08-23

Branch: `agents/board-advisor`

EA: `QM5_41131_wti-mdaily-tailtrim-mom`

Outcome: **SOURCE BUILD COMMITTED; GOVERNED COMPILE ENQUEUED AND ACTIVATION-HELD; CPU CEILING HIT; Q01 PENDING; Q02 NOT ENQUEUED**

## New structural commodity edge

QM5_41131 is one low-frequency, symmetric WTI sleeve outside the certified
XAU/SP500/NDX/XNG carriers. On the first executable D1 bar of a normalized
broker month, it reconstructs the immediately completed 17-to-23-session WTI
month plus one adjacent older boundary close. It forms every chronological
daily log return ending in that month, verifies the raw sum against the direct
endpoint within `1e-10`, sorts a copy ascending, removes exactly the single
minimum and maximum array elements, and follows the sign of the remaining
inner sum. The raw endpoint sign is diagnostic and may disagree with the
trade.

One normalized month attempt is persisted before every fallible gate. A valid
direction opens at most one `XTIUSD.DWX` position under aggregate
`RISK_FIXED=1000`, a frozen `3.5*ATR(20,D1)` stop, no target, and a first-tick
next-month exit with forty-day stale repair. This is distinct physical-energy
exposure, not evidence of profitability or decorrelation; unchanged Q09 alone
owns realized portfolio overlap.

## Reputable source and non-duplicate boundary

The approved bounded packet is
`strategy-seeds/sources/MOP-WTI-MDAILY-TAILTRIM-MOM-2026/source.md`, derived
from Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`. The paper supplies WTI
membership, own-return continuation, and monthly formation/renewal lineage.
The within-month daily horizon and exact one-observation-per-tail trim are
explicit QM translations; no source performance, density, CFD-equivalence, or
portfolio result transfers.

The fail-closed pre-allocation scan covered 4,630 registry identities, 1,298
cards, and 45 canonical Strategy-Wiki nodes and returned `CLEAN`. The
post-allocation receipt found only the expected 41131 slug and strategy-ID
self-hits. Manual family review separates this mechanic from the raw one-month
endpoint (`QM5_20187`), twelve monthly returns with two deletions per tail
(`QM5_20270`), sign breadth plus endpoint agreement (`QM5_41111`), L2/L1 path
normalization (`QM5_41124`/`QM5_41126`), and adjacent-return persistence
(`QM5_41127`).

## Deterministic identity and commits

| Stage | Commit |
|---|---|
| durable source approval and pre-allocation dedup | `77dca19cb` |
| bounded reputable-source extraction | `6e8df9e35` |
| atomic EA-ID reservation | `b241a2557` |
| approved G0 card and post-allocation dedup | `d2cd62754` |
| governed magic allocation and resolver evidence | `f3ce9988b` |
| EA source, SPEC, reference suite, and fixed-risk set | `7aaa9c45f` |

Execution identity is exact `XTIUSD.DWX`, D1, slot 0, magic `411310000`.
The MQ5 SHA-256 at compile enqueue is
`E15173AC581EA222AC3F89E13B9966C6E4649947BBD307AEA5C46423FD86EF08`.

The normal magic allocator aborted atomically on the unchanged three
legacy-active IDs whose EA directories are absent. The reviewed same-day
bounded fallback added only 41131 and regenerated with `--keep-obsolete`,
retaining 17,832 rows, dropping zero, embedding canonical registry SHA-256
`2516A77673DF806F182B85E8905DB3005197A13A2D04F41D4975AF5CA74D25FE`,
and producing a byte-identical second regeneration. No `--allow-dropped` or
legacy identity mutation was used.

## Source-level validation

- Approved-card and EA-local card schema/prohibited-ML lint: PASS.
- Approved and local card content after newline normalization: identical.
- Deterministic reference suite: 17/17 PASS. Coverage includes raw and `+1`
  label equivalence, mixed-label/collision rejection, raw grace without
  twenty-four-hour wrap, year rollover, 17/20/23 acceptance and 16/24
  rejection, boundary/current-month checks, chronological return inclusion,
  endpoint identity, distinct and tied extremes, exact one-element-per-tail
  deletion, positive/negative/zero inner sums, endpoint agreement and
  disagreement, durable attempt timing, lifecycle repair, and fixed-risk
  containment.
- Build prerequisite guard: PASS for EA registry, magic registry, and EA
  directory.
- SPEC validator: PASS.
- Build guardrails: PASS with zero findings across source and setfile.
- Symbol-scope validator: `SINGLE_SYMBOL_OK`, zero violations.

The sole setfile is backtest-only and locks `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, both news axes OFF, Friday close OFF,
and every card parameter. It deliberately retains `build_hash=pending` because
no compiler output exists.

## Compile handoff

A direct strict compile stopped before compilation at the live-factory
include-mirror guard with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no bypass or
retry was used. The prescribed governed path then accepted only this EA:

- compile work item: `19504c2f-750c-4c40-af3e-a337651a9a3e`;
- status at stop: `pending`;
- activation hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`;
- activation hold released: no;
- EX5: absent;
- build-check result: absent;
- Q01: pending.

The activation hold was deliberately left intact after the capacity ceiling
bound. No worker, terminal, tester, dispatcher, or reservation was manually
started, stopped, restarted, claimed, or released.

## CPU-ceiling stop and Q02 state

Five consecutive whole-host `Processor(_Total)\% Processor Time` samples at
`2026-08-23T12:30:45.8191569Z` were:

`100.00, 100.00, 99.51, 100.00, 100.00`

Average CPU was **99.90%** and maximum CPU was **100.00%**, breaching the
explicit paced-fleet ceiling of 97%. The read-only process count saw five
`terminal64.exe` and three `metatester64.exe` processes. CPU, not an inferred
process count, owns the stop verdict.

This is the mission's binding stop condition. No Q02 preview, work item,
dispatcher tick, terminal reservation, smoke, manual tester, or backtest was
created. Q02 is also gated by the absent strict compile, EX5, final setfile
hash binding, and Q01 PASS.

## Safe continuation and safety boundary

After the resident CPU remains below 97% and the compile-worker rollout hold
is reviewed and cleared, consume the existing exact-source compile item.
Require zero compiler errors and warnings, a non-empty EX5, strict build-check
PASS, final setfile hash binding, and Q01 PASS. Then take a fresh capacity
sample and enqueue exactly one target-only Q02 row. Retire below five completed
positions in any full post-warm-up scored year rather than tune the card.

No portfolio gate, `T_Live` manifest, `T_Live` process/file, AutoTrading
state, live/deploy artifact, portfolio admission, correlation waiver, or
decorrelation claim was touched.

Machine-readable companion:
`artifacts/qm5_41131_wti_mdaily_tailtrim_mom_source_build_cpu_ceiling_handoff_20260823T123045Z_board_advisor.json`.

