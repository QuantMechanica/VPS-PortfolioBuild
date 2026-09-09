# QM5_41391 WTI Ten-Month Momentum / One-Month Hold — Build And Q02 CPU Stop

## Outcome

`QM5_41391_wti-tsmom10-h1` is a new approved and committed low-frequency
energy sleeve. On the first D1 bar of every broker month it follows the sign
of the exact ten-completed-month WTI log return and holds the package for one
month. The reputable-source record, approved card, deterministic ID and magic
allocation, EA, fixed-risk set, and independent reference fixture are committed.

The mandatory PACER input-pin audit passed with zero findings and the
reference vectors passed. A governed compile row was enqueued and its exact
source-hash activation hold was released. At the stop readback it remained
pending and unclaimed, without EX5, build-check result, or verdict.

## Source And Non-Duplicate Boundary

The source is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
Journal of Financial Economics 104(2), DOI
`10.1016/j.jfineco.2011.11.003`. The durable parent packet records a complete
23-page read and published-PDF hash. The paper defines the own-return `k,h`
family and includes NYMEX WTI, but no standalone WTI `k=10,h=1`, continuous
CFD, fixed-risk, or diversification result is imported.

The canonical checker scanned 4,871 registry rows, 1,484 cards, and 45 Wiki
nodes, finding no exact identity. Manual review separated the exact
`QM5_41388` ten-month/two-month odd-month package and monthly-renewal WTI
systems with different formations or added filters/statistics. This identity
uniquely combines ten-month formation with an every-month one-month lifecycle.
Q09 alone owns realized correlation.

## Build And Guard Evidence

- Source/card commit: `e89f35118f`.
- Allocation commit: `0093b63bb7`.
- EA build commit: `820d6d86a1`.
- EA ID/magic: `QM5_41391`; slot 0 `413910000`.
- Source SHA-256:
  `375e491122abf8d59ab840d63f6f48a51856762fb255429dfae6aa380204af40`.
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

- Work item: `d521089b-7d5f-496e-9be9-643169774f41`.
- State at stop: pending, unclaimed, activation hold released.
- The release receipt proves queued and current source hashes match.
- No `.ex5`, compile verdict, evidence path, or setfile binding exists yet.
- No direct compiler, tester, or terminal-control path was used.

## Binding CPU Stop

Five whole-host samples at `2026-09-09T05:01:10.0857261Z` were `98.0%`,
`96.0%`, `100.0%`, `97.0%`, and `99.0%`. Average CPU was `98.0%` and maximum
CPU was `100.0%`. Admission requires both values strictly below `97%`, so Q02
was not enqueued and no backtest was launched.

A later paced wake must first resolve the pending compile row to a
source-matched `COMPILE_OK`, then obtain a fresh passing CPU window before
using canonical first-Q02 intake exactly once.

Machine-readable evidence:
`artifacts/qm5_41391_compile_q02_cpu_stop_20260909.json`,
`artifacts/qm5_41391_compile_release_dry_run_20260909.json`, and
`artifacts/qm5_41391_compile_release_apply_20260909.json`.

## Safety Boundary

No Q02 row was created. The portfolio gate, `T_Live`, live manifest,
AutoTrading, deployment state, terminal processes, and live-use surfaces were
not touched.
