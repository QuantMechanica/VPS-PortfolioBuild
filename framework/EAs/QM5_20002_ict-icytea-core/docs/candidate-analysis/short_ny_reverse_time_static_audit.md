# QM5_20002 short-NY reverse-time candidate: outcome-blind static audit

Date: 2026-07-20  
Analysis: `QM5_20002_SHORT_NY_REVERSE_TIME_SCREEN_001`  
Status: **SOURCE-CORRECTED V3 STATIC REVIEW COMPLETE; EMPIRICAL SCREEN NOT STARTED**

## Scope and outcome fence

This review first identified defects in the Contract-v2 implementation and then
corrected them outcome-blind against the primary DOCX. Contract v3 now binds the
corrected MQ5 source, its framework dependencies, the still-`intake` Strategy
Card and build brief, the primary source and correction plan, the four generated
set files, and the PRE/LAUNCH/POST evidence tool. It did not parse OHLC or tick
values, open a QM5_20002 native tester report, inspect a 2017-2021 result, or
start MT5.

Consequently, this document makes no profitability claim. The 25 passing Python
tests exercise the generator and evidence auditor; they are not strategy
backtests.

## Source-corrected candidate frozen for the screen

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

The primary source resolves the sweep convention as an immediate closed-bar
wick-through plus close-reclaim, or the first later reclaim within the fixed
3-5-bar source range. Contract v3 uses the preregistered value 3, never infers
intrabar sweep-before-MSS order from OHLC, and permits a reclaim-bar MSS only
when the recorded sweep bar is already earlier. The source does not define a
numeric sweep-to-MSS expiry, FVG tie-break, or rejected-send retry policy; v3
retains the existing 30-bar expiry, FVG direction and one-shot send assumptions.

## Static findings

| ID | Severity | Finding | Code evidence | Screen disposition |
|---|---:|---|---|---|
| S01 | Positive | No direct future-bar access was found in the candidate entry logic. Swing confirmation uses a fully closed centre and wings; HTF, sweep, displacement and FVG scans use shifts of at least 1. | MQ5 lines 213-247, 257-290, 514-573, 596-856 | Suitable for a causal backtest; this does not prove economic edge. |
| S02 | High semantic mismatch, corrected in v3 | Contract v2 rejected the documented immediate same-bar reclaim when the prior close was already across the level. | v2 MQ5 lines 511-556; primary DOCX sweep rule | V3 removes the prior-close gate and encodes immediate or first causal later reclaim before any outcome access. |
| S03 | Medium semantic mismatch, corrected in v3 | Contract v2 could let a pre-sweep FVG satisfy displacement. | v2 MQ5 lines 606-655 and 742-789 | V3 records sweep time and requires all three FVG candles strictly after it and no later than MSS. |
| S04 | High live robustness, corrected in v3 | Contract v2 lost swing, structural pending and partial/BE state on restart. | v2 MQ5 lines 183-247, 863-997, 1068-1112, 1300-1325 | V3 causally rebuilds swings, transactionally persists valid pending state, and reconstructs partial/BE from broker history/SL truth. This is statically checked, not yet restart-tested in MT5. |
| S05 | High live/risk robustness, corrected in v3 | Contract v2 returned on news before management, day-end exit and Friday close. | v2 MQ5 lines 1204-1285 and 1334-1370 | V3 performs invalid-fill cleanup, Friday close, management and day-end exit before news can block new entries. |
| S06 | Critical execution semantics, corrected and still independently gated | Contract v2 left accepted limits alive after 10:00 NY or into a blackout. | v2 MQ5 lines 725/855 and 1136-1185 | V3 removes owned limits outside the enabled killzone or fresh two-calendar authorization and closes a fill racing removal. POST still makes any actual violating opening fill `INVALID`. |
| S07 | Medium path dependence | Structural pending state is cleared once an entry request is built, before `QM_TM_OpenPosition` reports whether the broker accepted the order. A send rejection consumes the setup instead of retrying it. | MQ5 lines 872-882, 940-950 and 1377-1382 | Accepted as frozen empirical behaviour; document before any live port. |
| S08 | Medium definition mismatch, corrected in v3 | Contract v2 used broker D1/week boundaries for PDH/PDL and previous week. | v2 MQ5 lines 396-476 | V3 aggregates closed M15 bars by DST-aware New-York weekday and Monday-to-Monday week. Broker D1 is forbidden by the contract and static test. |
| S09 | Critical dependency closure, now gated | `QM_NewsInit` consumes two CSVs and, on current MT5 builds, falls back from the absolute `D:\` names to their basenames under the scheduled `QMDev1` account's `Common\Files`. Binding only one seed file or only the `D:\` copies would not bind the effective tester inputs. | `QM_NewsFilter.mqh` lines 285-313, 389-505 and 527-595 | Contract v2 binds both seeds. PRE now also binds both effective `QMDev1\Common\Files` mirrors and requires byte-identical SHA-256 values. POST parses the effective copies. |
| S10 | Critical build closure, pending | The committed corrected source has no fresh standard compile evidence created after Contract v3. Existing binaries cannot establish that the EX5, current include tree, and frozen source belong together. | Contract v3 `frozen_implementation`; PRE compile validator | PRE must reject until a new PASS/0-error/0-warning compile with source/include manifests and Contract-v3 ancestry exists. No terminal launch is permitted before that. |

The Asian-range helper can return the newest incomplete 20:00-00:00 block when
called during that block, but the frozen candidate only permits entries at
07:00-10:00 NY; therefore this latent helper behaviour is not a blocker for this
specific screen.

## Evidence-chain safeguards implemented

The candidate-analysis auditor now fails closed on all of the following:

- Contract, corrected source, primary source, correction plan, card/brief, set
  manifest and exact 52-input maps.
- Fresh compile, EX5/source/include manifests, compiler and repository ancestry.
- The exact 113 selected Model-4 files through opaque SHA-256 only; future tick
  months are not selected and market values are not parsed during PRE.
- Both news seeds and both byte-identical effective `QMDev1\Common\Files` inputs.
- Exact four-cell/two-duplicate Model-4 plan with zero native and simulated
  commission before the external cost ledger is applied.
- An exact, strictly typed authorization bound to the PRE SHA, followed by one
  exclusive authorization-consumption receipt bound to the canonical run,
  state, job and Scheduled Task before the detached worker can start. A crash
  may recover only that same launch; a second run cannot reuse the receipt.
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

All mutable orchestration evidence is confined to
`D:\QM\reports\qm20002\short_ny_reverse_time`. The helper rejects reparse
points, non-local/non-NTFS volumes, an untrusted ancestor owner, and dangerous
ancestor rights held by `QMDev1` or any applicable token/group SID. Directories
and files are sealed to SYSTEM and Administrators only before publication.
The exact runtime layout is:

- `pre\pre_receipt.json`
- `authorization\authorization.json`
- `authorization\consumptions\<authorization_sha256>.json`
- `runs\<yyyyMMddTHHmmssZ_32hex>\launch_job.json`
- `runs\<yyyyMMddTHHmmssZ_32hex>\launch_state.json`
- `runs\<yyyyMMddTHHmmssZ_32hex>\post_receipt.json`

The OWNER-created runtime authorization has exactly these fields (no extras,
duplicate properties, numeric booleans, or alternate path are accepted):

```json
{
  "schema_version": 2,
  "artifact_type": "QM5_20002_SHORT_NY_LAUNCH_AUTHORIZATION",
  "analysis_id": "QM5_20002_SHORT_NY_REVERSE_TIME_SCREEN_001",
  "pre_receipt_sha256": "<exact lowercase PRE SHA-256>",
  "scope": "QM5_20002_4_CELLS_X_2_DUPLICATES_MODEL4",
  "mt5_execution_authorized": true,
  "authorized_by": "<non-empty OWNER identity>",
  "authorized_utc": "<UTC timestamp ending in Z, at or after PRE creation>"
}
```

The older repository evidence file from 2026-07-20 documents historical
authorization context but is not this schema-v2 protected runtime artifact and
must not be copied into the control root as launch authorization.

One conservative limitation remains: the current POST gate accepts only
same-New-York-day lifecycles with zero swap. Although Contract v2 also permits an
independently exact non-zero swap-cost proof, POST will reject such a case until
that separate proof format is defined. This can create a false rejection, not a
false acceptance.

## What has and has not been tested

Tested now:

- Static causality and dependency review of the source-corrected implementation.
- Generator determinism and exact four-cell set closure.
- Auditor unit and adversarial gates, including effective news-copy drift,
  out-of-killzone/news opening fills, artifact closure and timeout margin.
- Result: 90 auditor tests passed, including exclusive-publication,
  cross-run authorization, crash-recovery, duplicate-worker, stale-resume,
  locked-snapshot, strict-schema and protected-path adversarial cases;
  deterministic Contract-v3 set check passed.

Not tested yet:

- No Contract-v3 strategy backtest has run.
- No native Deal ledger has been adjudicated.
- No arm has demonstrated positive expectancy, robustness, or symbol transport.
- No combined portfolio has demonstrated FTMO profit-target, daily-loss, total
  drawdown, evaluation-duration, floating-equity, correlation, or execution-risk
  compliance.

The older claimed rescue report cannot fill this gap: Contract v2 records that
its embedded inputs conflict with the claimed short-NY configuration, so it is
invalid evidence for this candidate.

## Required top-down continuation

1. Produce a fresh standard compile evidence bundle after Contract v3.
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
