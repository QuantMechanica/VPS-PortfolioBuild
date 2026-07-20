# QM5_20002 short-NY reverse-time candidate: outcome-blind static audit

Date: 2026-07-20  
Analysis: `QM5_20002_SHORT_NY_REVERSE_TIME_SCREEN_001`  
Status: **STATIC REVIEW COMPLETE; EMPIRICAL SCREEN NOT STARTED**

## Scope and outcome fence

This review covered the frozen MQ5 source, its framework dependencies, the
Strategy Card and build brief, Contract v2, the four generated set files, and
the PRE/LAUNCH/POST evidence tool. It did not parse OHLC or tick values, open a
QM5_20002 native tester report, inspect a 2017-2021 result, or start MT5.

Consequently, this document makes no profitability claim. The 19 passing Python
tests exercise the generator and evidence auditor; they are not strategy
backtests.

## Candidate actually frozen for the screen

The screen contains two arms of one short-only New-York ICT model:

- `A_SHORT_NY_NO_HTF`: short-only, New York 07:00-10:00, H1 bias disabled.
- `B_SHORT_NY_H1_BIAS`: the same model with H1 bias enabled.

Each arm must survive both `EURUSD.DWX` and `GBPUSD.DWX`, M1, 2017-10-01
through 2021-12-31. Two native Model-4 duplicates per cell make four cells and
eight tester runs. No arm or symbol may be silently dropped.

These are hypothesis variants, not two diversified trading sleeves. EURUSD and
GBPUSD share USD macro exposure, the same New-York session, the same execution
logic, and most framework failure modes. Transport across the second symbol is
a generalisation check, not proof of portfolio diversification.

## Static findings

| ID | Severity | Finding | Code evidence | Screen disposition |
|---|---:|---|---|---|
| S01 | Positive | No direct future-bar access was found in the candidate entry logic. Swing confirmation uses a fully closed centre and wings; HTF, sweep, displacement and FVG scans use shifts of at least 1. | MQ5 lines 213-247, 257-290, 514-573, 596-856 | Suitable for a causal backtest; this does not prove economic edge. |
| S02 | High semantic mismatch | The documented "immediate same-bar" sweep/reclaim cannot fire in its normal form. A bullish immediate reclaim with the prior close above the level is rejected by `close2 > level`; the bearish mirror has the same issue. The event therefore requires a prior close on the swept side. | MQ5 lines 511-525 and 545-556 | Test the frozen behaviour as implemented; do not describe it as conventional immediate same-bar rejection. A later correction is a new candidate. |
| S03 | Medium semantic mismatch | The impulse FVG scan spans a margin wider than the registered sweep-to-MSS interval. `any_fvg` can satisfy displacement even when the selected FVG is filtered out, and a qualifying gap can predate the sweep. | MQ5 lines 606-655 and 742-789 | The frozen result, if run, measures this broader implementation. Causal tightening after outcome review is forbidden. |
| S04 | High live robustness | Swing arrays, structural pending state, and partial/breakeven flags are volatile. `OnInit` clears pending and position-management state and does not backfill swings or reconstruct completed partial/BE state. A restart can therefore change signals and can attempt management a second time. | MQ5 lines 183-247, 863-997, 1068-1112, 1300-1325 | Does not invalidate a continuous tester run, but blocks a claim of restart-safe live equivalence. Must be repaired and retested as a new implementation before live use. |
| S05 | High live/risk robustness | News rejection returns before open-position management, day-end exit, and Friday close. A blackout can defer partial close, breakeven, strategy flattening, or Friday flattening. | MQ5 lines 1204-1285 and 1334-1370 | Frozen test captures this path, but the candidate is not yet a fail-closed FTMO live implementation. |
| S06 | Critical execution semantics | Entries are limit orders with time expiry. Placement is gated inside the killzone and outside news, but an accepted order is not cancelled when 10:00 NY arrives or a blackout begins; it can fill later. | MQ5 lines 725/855 and 1136-1185; `QM_Entry.mqh` lines 342-346 | Contract v2 makes every actual opening fill outside NY `[07:00,10:00)` or inside either calendar's high-impact +/-30 minute union `INVALID`, not a loss. POST enforces the gate. |
| S07 | Medium path dependence | Structural pending state is cleared once an entry request is built, before `QM_TM_OpenPosition` reports whether the broker accepted the order. A send rejection consumes the setup instead of retrying it. | MQ5 lines 872-882, 940-950 and 1377-1382 | Accepted as frozen empirical behaviour; document before any live port. |
| S08 | Medium definition mismatch | PDH/PDL and previous-week pools use broker D1/calendar boundaries, while killzones and day-end are New-York based. This is not a single New-York session calendar definition. | MQ5 lines 396-432 and 435-476 | Treat broker-calendar liquidity pools as the actual tested rule. A New-York-calendar rewrite is a new hypothesis. |
| S09 | Critical dependency closure, now gated | `QM_NewsInit` consumes two CSVs and, on current MT5 builds, falls back from the absolute `D:\` names to their basenames under the scheduled `QMDev1` account's `Common\Files`. Binding only one seed file or only the `D:\` copies would not bind the effective tester inputs. | `QM_NewsFilter.mqh` lines 285-313, 389-505 and 527-595 | Contract v2 binds both seeds. PRE now also binds both effective `QMDev1\Common\Files` mirrors and requires byte-identical SHA-256 values. POST parses the effective copies. |
| S10 | Critical build closure, pending | The committed source has no fresh standard compile evidence created after Contract v2. Existing binaries cannot establish that the EX5, current include tree, and frozen source belong together. | Contract v2 `frozen_implementation`; PRE compile validator | PRE must reject until a new PASS/0-error/0-warning compile with source/include manifests and Contract-v2 ancestry exists. No terminal launch is permitted before that. |

The Asian-range helper can return the newest incomplete 20:00-00:00 block when
called during that block, but the frozen candidate only permits entries at
07:00-10:00 NY; therefore this latent helper behaviour is not a blocker for this
specific screen.

## Evidence-chain safeguards implemented

The candidate-analysis auditor now fails closed on all of the following:

- Contract, frozen source/card/brief, set manifest and exact 52-input maps.
- Fresh compile, EX5/source/include manifests, compiler and repository ancestry.
- The exact 113 selected Model-4 files through opaque SHA-256 only; future tick
  months are not selected and market values are not parsed during PRE.
- Both news seeds and both byte-identical effective `QMDev1\Common\Files` inputs.
- Exact four-cell/two-duplicate Model-4 plan with zero native and simulated
  commission before the external cost ledger is applied.
- Explicit authorization bound to the exact PRE SHA before the detached worker
  can start.
- Immediate hashing of every native report, tester log and `tester.ini` after
  each cell, plus a COMPLETE-state chain back to job, authorization, tool, PRE,
  plan and command.
- Exact duplicate Deal sequences, report inputs/header/window, native balance
  recurrence, zero native commission, short-only openings, Model-4 markers,
  opening-fill time/news rules, and all preregistered merit gates.

The detached timeout is deliberately longer than the inner DEV1 controller's
two-run timeout. This gives the controller time to remove its Scheduled Task,
restore tester groups, and clean the exact process tree instead of allowing the
outer Python process to terminate it first.

One conservative limitation remains: the current POST gate accepts only
same-New-York-day lifecycles with zero swap. Although Contract v2 also permits an
independently exact non-zero swap-cost proof, POST will reject such a case until
that separate proof format is defined. This can create a false rejection, not a
false acceptance.

## What has and has not been tested

Tested now:

- Static causality and dependency review of the frozen implementation.
- Generator determinism and exact four-cell set closure.
- Auditor unit and adversarial gates, including effective news-copy drift,
  out-of-killzone/news opening fills, artifact closure and timeout margin.
- Result: 19 tests passed; deterministic set check passed.

Not tested yet:

- No Contract-v2 strategy backtest has run.
- No native Deal ledger has been adjudicated.
- No arm has demonstrated positive expectancy, robustness, or symbol transport.
- No combined portfolio has demonstrated FTMO profit-target, daily-loss, total
  drawdown, evaluation-duration, floating-equity, correlation, or execution-risk
  compliance.

The older claimed rescue report cannot fill this gap: Contract v2 records that
its embedded inputs conflict with the claimed short-NY configuration, so it is
invalid evidence for this candidate.

## Required top-down continuation

1. Produce a fresh standard compile evidence bundle after Contract v2.
2. Run PRE and preserve its immutable receipt SHA. Any drift blocks continuation.
3. Obtain an explicit authorization JSON for that exact PRE SHA.
4. Let the detached worker complete all eight native runs without changing code,
   sets, data, calendars, binaries, parser, runner, or tester groups.
5. Run POST once. An execution-integrity violation makes the screen `INVALID`;
   failure of merit gates rejects the candidate without tuning.
6. Only a passing arm may proceed to a genuinely unseen forward OOS/prospective
   stage and then to a joint FTMO portfolio simulation with a structurally
   different index, metal, or other sleeve.

Until those steps succeed, the accurate answer is: the strategy has been
statically evaluated, but it has not yet been empirically validated and cannot
be claimed to pass an FTMO Challenge.
