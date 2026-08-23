# QM5_41124 WTI monthly RMS-coherence momentum — CPU-ceiling handoff

Date: 2026-08-23

Branch: `agents/board-advisor`

EA: `QM5_41124_wti-mrms-coherence-mom`

Outcome: **SOURCE BUILD COMMITTED; CPU CEILING HIT BEFORE GOVERNED COMPILE;
Q01 PENDING; Q02 NOT ENQUEUED**

## New direct-energy edge

QM5_41124 is one low-frequency structural WTI sleeve on exact
`XTIUSD.DWX`, D1. At the first executable D1 bar of a new broker month it
reconstructs the immediately completed month from 17 through 23 closes plus
the adjacent older-month boundary close. For every chronological log return
ending in the completed month it computes:

```text
N = sum(r)
Q = sum(r^2)
C = abs(N) / sqrt(n * Q)
```

It requires finite `Q>0`, nonzero `N`, the endpoint identity, bounded `C`, and
inclusive `C>=0.16`. Positive `N` buys WTI and negative `N` sells WTI for one
broker month. The monthly attempt is persisted before every fallible gate, so
a flat or failed state cannot retry.

The approved baseline locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, one position,
a frozen `3.5*ATR(20,D1)` hard stop, no profit target, a 1,500-point spread
cap, news filtering OFF, no Friday close, next-month exit, and 40-calendar-day
stale repair. Q02 must retire the baseline below five completed positions in
any full post-warm-up year. This is a direct crude-oil economic carrier, not a
claim of profitability or realized decorrelation; Q09 alone owns portfolio
overlap.

## Reputable source and non-duplicate boundary

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-MRMS-COHERENCE-MOM-2026/source.md`. Its
governed parent is Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial
Economics* 104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, represented by
a complete 23-page author-hosted paper receipt in
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. The paper explicitly
includes NYMEX WTI and a one-month formation/hold commodity specification.
The daily mean-to-RMS coherence gate, CFD mapping, execution, and risk contract
are disclosed QM falsification translations rather than source results.

The fail-closed pre-allocation checker scanned 4,623 registry identities,
1,292 cards, and 45 Strategy-Wiki nodes and returned `CLEAN`. The
post-allocation receipt found only the two expected self-hits for EA 41124.
The mechanic differs from unconditional one-month WTI endpoint momentum,
twelve-month normalized momentum/path efficiency, daily sign breadth, fixed
block agreement, and sequence/extreme-state designs: it qualifies one
completed month with the magnitude-sensitive L2 statistic
`abs(sum(r))/sqrt(n*sum(r^2))` and has no block, rank, vote, sequence, rolling
center, or oscillator state.

## Deterministic identity and commits

| Stage | Commit |
|---|---|
| durable OWNER source approval and pre-allocation dedup | `04f9f9b019b6ddc62b96848adb60b6cb574db9c5` |
| bounded reputable-source extraction | `dc41f9f345b3bc42dc6e17b3bead36faa4d99527` |
| atomic EA-ID reservation | `d69e09b6fc86825e475fd175dbf04f78405c349b` |
| approved G0 card and post-allocation dedup | `4e15000231263be963d405842969028005c6b6c8` |
| magic allocation, resolver binding, and local card | `67df3656161c0ef65e7d5fa4772e62d1e1ab9632` |
| EA source, SPEC, reference suite, and fixed-risk set | `eb2487fd31156a85c863f1ddf21b88a20021ee3f` |

Execution identity is slot 0 `XTIUSD.DWX`, D1, magic `411240000`. The governed
allocator added exactly one active registry row and one resolver row, deleted
zero retired rows, and copied the approved card byte-for-byte. Its initial
strict run failed closed on three pre-existing active legacy IDs whose EA
directories are absent. A strict rerun temporarily materialized only those
three empty directory identities, used no `--allow-dropped` option, preserved
all existing rows, added only 41124, and removed the empty placeholders.

## Source-level validation

- Approved-card schema, G0 status, and prohibited-ML lint: PASS.
- Registry ID, magic row, resolver identity, exact directory, symbol, and
  strategy binding: PASS.
- Deterministic reference suite: 8 tests PASS.
- SPEC validator: PASS.
- Build guardrails: PASS across two checked files with zero findings.
- Symbol-scope validator: `SINGLE_SYMBOL_OK`, zero violations.
- Approved and EA-local cards are byte-identical at SHA-256
  `690896573D2274153C691BF439DF02A6D4D3AC00B889476D1086FA60E18615BA`.
- Scoped whitespace validation: PASS.

The backtest-only set locks `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Its SHA-256 is
`888C1814E6130A19731692E97B6995988F6D818457FD2A3A763BC70598E54C1A`.
It retains `build_hash=pending` because no compiler output exists.

## Compile and Q01 state

An ad-hoc build-check invocation was refused before compilation by the live
factory guard with `LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`; no retry or bypass
was used. The prescribed governed compile was not enqueued because the fresh
capacity sample below immediately triggered the mission's stop condition.

At handoff, read-only `farmctl work-items --ea QM5_41124` returned zero items.
No `.ex5` exists, no build-check result exists, and Q01 remains pending. No
compile PASS is claimed.

## CPU-ceiling stop and Q02 state

Five consecutive whole-host `Processor(_Total)\\% Processor Time` samples at
two-second intervals completed at `2026-08-23T04:17:31.5126246Z`:

`100.00, 100.00, 100.00, 99.62, 100.00`

Average CPU was 99.92 percent and maximum CPU was 100 percent, above the
paced-fleet ceiling of 97 percent. The sample endpoint saw ten
`terminal64.exe` and eight `metatester64.exe` processes. The adjacent
read-only slot inventory reported an already saturated governed fleet, with
no duplicate or orphaned tester condition requiring intervention.

This is the binding stop condition. No governed compile item, Q02 preview,
Q02 work item, dispatcher tick, terminal reservation, or manual backtest was
created. Q02 is additionally gated by the absent strict compile, EX5, final
set hash binding, and Q01 PASS.

## Safe continuation and safety boundary

After sustained whole-host CPU is below 97 percent, enqueue the governed
compile for exactly `QM5_41124_wti-mrms-coherence-mom`. Require zero errors and
warnings, a non-empty EX5, build-check PASS, final set hash binding, and Q01
PASS. Then take a fresh capacity sample and enqueue exactly one Q02 row. Do
not change the approved mechanic to manufacture the five-per-year floor.

No AutoTrading action, live/deploy artifact, `T_Live` mutation,
`T_Live`-manifest change, portfolio-gate change, portfolio admission,
correlation waiver, or decorrelation claim occurred. `T_Live` and FTMO were
visible only in read-only process inventory and were not touched.

Machine-readable companion:
`artifacts/qm5_41124_wti_mrms_coherence_mom_source_build_q02_cpu_ceiling_handoff_20260823T041940Z_board_advisor.json`.
