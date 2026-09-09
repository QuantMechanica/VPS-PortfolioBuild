# QM5_41390 WTI Eleven-Month Momentum / Two-Month Hold — Build And Q02 CPU Stop

## Outcome

`QM5_41390_wti-tsmom11-h2` is a new approved and committed low-frequency
energy sleeve. On the first D1 bar of each odd broker month it follows the
sign of the exact eleven-completed-month WTI log return and holds the package
for two months. The reputable-source record, approved card, deterministic ID
and magic allocation, EA, fixed-risk set, and independent reference fixture
are committed.

The mandatory PACER input-pin audit passed with zero findings and the
reference vectors passed. A governed compile row was enqueued and its exact
source-hash activation hold was released. At the stop readback it remained
pending and unclaimed, without EX5, build-check result, or verdict.

## Source And Non-Duplicate Boundary

The source is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
Journal of Financial Economics 104(2), DOI
`10.1016/j.jfineco.2011.11.003`. The durable parent packet records a complete
23-page read and published-PDF hash. The paper defines the own-return `k,h`
family and includes NYMEX WTI, but no standalone WTI `k=11,h=2`, continuous
CFD, fixed-risk, or diversification result is imported.

The canonical checker scanned 4,870 registry rows, 1,483 cards, and 45 Wiki
nodes, finding no exact identity. Manual review separated monthly-renewal WTI
systems, the existing twelve-month/two-month build, and the exact one- through
ten-month/two-month siblings. This card uniquely combines eleven-month
formation, the fixed odd-month epoch, and a non-overlapping two-month hold.
Q09 alone owns realized correlation.

## Build And Guard Evidence

- Source/card commit: `eb2b9d274c`.
- Allocation commit: `8332d7897e`.
- EA build commit: `7a0b80f3f3`.
- EA ID/magic: `QM5_41390`; slot 0 `413900000`.
- Source SHA-256:
  `910c9d6b571a74a4723aa20cdd342ea4b694ffeb7627a7edc590a1b6c37ba7ae`.
- PACER audit: exit 0, `ok=true`, `hit_count=0`, empty findings.
- Card schema lint: PASS; prohibited-ML hits 0.
- Independent reference vectors: PASS.
- Backtest preset: D1, `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The locked guard compares only strategy inputs, `qm_ea_id`,
`qm_magic_slot_offset`, and fixed-risk mode. It does not equality-check RNG,
news, or Friday inputs. Stress probability is checked only for finiteness and
the inclusive `0..1` range.

## Governed Compile State

- Work item: `81b3a907-99aa-4414-b68c-0f918b7357e2`.
- State at stop: pending, unclaimed, activation hold released.
- The release receipt proves queued and current source hashes match.
- No `.ex5`, compile verdict, evidence path, or setfile binding exists yet.
- No direct compiler, tester, or terminal-control path was used.

## Binding CPU Stop

Five one-second whole-host samples at
`2026-09-09T04:01:15.302201+00:00` were `97.1%`, `95.2%`, `96.4%`, `98.9%`,
and `99.2%`. Average CPU was `97.4%` and maximum CPU was `99.2%`. Admission
requires both values strictly below `97%`, so Q02 was not enqueued and no
backtest was launched.

A later paced wake must first resolve the pending compile row to a
source-matched `COMPILE_OK`, then obtain a fresh passing CPU window before
using canonical first-Q02 intake exactly once.

Machine-readable evidence:
`artifacts/qm5_41390_compile_q02_cpu_stop_20260909.json`,
`artifacts/qm5_41390_compile_release_dry_run_20260909.json`, and
`artifacts/qm5_41390_compile_release_apply_20260909.json`.

## Safety Boundary

No Q02 row was created. The portfolio gate, `T_Live`, live manifest,
AutoTrading, deployment state, terminal processes, and live-use surfaces were
not touched.
