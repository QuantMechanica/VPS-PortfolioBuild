# QM5_20269 WTI Median-Return Momentum — Q01 PASS / Q02 Enqueued

Date: 2026-08-09 (Europe/Berlin)

Branch: `agents/board-advisor`

Agent: Codex headless paced fleet

## Status

`QM5_20269_wti-medret-mom` is a new low-frequency direct-WTI structural
candidate. It passed Q01 and has exactly one Q02 work item:
`6e8edd6b-72da-4b37-8a27-15ccdea515b8`.

Immediate readback found the row pending, attempt 0, unclaimed, and without a
verdict. Enqueue is a screening handoff, not a profitability, certification,
decorrelation, or portfolio-admission result.

## Edge And Non-Duplicate Boundary

On the first `XTIUSD.DWX` D1 bar of a genuine broker-month transition, the EA
reconstructs thirteen consecutive completed month-end closes, forms twelve
disjoint chronological log returns, sorts them ascending, and calculates the
even-sample median as `(sorted[5] + sorted[6]) / 2`. It buys a positive
median and sells a negative median. Exact-zero or invalid state consumes the
month flat.

The position renews monthly, has a forty-calendar-day stale guard, and carries
one frozen `3.5 * ATR(20,D1)` hard stop. A persistent month-attempt marker,
owned-position state, and deal history prevent same-month re-entry.

The deterministic pre-allocation check found no exact identity across 4,326
EA-registry rows and 442 cards. Manual review separated this return-order
statistic from cumulative WTI momentum, binary sign breadth, multi-horizon
votes, pairwise month-end rank trend, log-price OLS trend, and the existing
rolling D1 price-median EA. The load-bearing distinction is the sign of the
average of center indexes 5 and 6 after sorting twelve non-overlapping monthly
returns.

Direct crude oil is a different carrier from the certified XAU, SP500, NDX,
and XNG book, but realized independence is not claimed. Q09 alone may
establish portfolio correlation if the candidate reaches it.

## Source And G0 Record

The bounded source packet is
`strategy-seeds/sources/MOP-WTI-MEDRET-2026/source.md`. Its complete-read
parent is Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*,
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The peer-reviewed paper includes WTI and
documents monthly own-return continuation.

The monthly-return median, exact center indexes, CFD mapping, fixed-risk
sizing, stop, spread cap, and lifecycle are transparent QM mechanizations, not
source performance claims. G0 authorization is
`decisions/2026-08-09_qm5_20269_wti_medret_mom_g0.md`.

## Deterministic Allocation And Q01 Evidence

- EA/slug/strategy: `QM5_20269` / `wti-medret-mom` /
  `MOP-TSMOM-2012_XTI_MEDRET12_S18`.
- Symbol/slot/magic: `XTIUSD.DWX` / 0 / `202690000`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Strict compile: `D:/QM/reports/compile/20260809_130444/summary.csv`,
  PASS with zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260809_130444/QM5_20269_wti-medret-mom.compile.log`.
- Target build check:
  `D:/QM/reports/framework/21/build_check_20260809_130553.json`, PASS with
  zero failures and zero warnings.
- P1 artifact validation:
  `D:/QM/reports/pipeline/QM5_20269/P1/P1_QM5_20269_result.json`, PASS.
- Card-schema/ML lint, G0 lint, build-prerequisite guard, and SPEC validation:
  PASS.
- Generated setfile header build hash:
  `2c8b82e29caae4c25b759f3e4fe1765a2536879d528da95aed0207c71afe6024`.
- Manual smoke/backtest: none.

Artifact SHA-256 values at handoff:

| Artifact | SHA-256 |
|---|---|
| EA registry | `356FE0C16DBF5DD19BD74F9028F39204FA27B2B129D046783312E56BF50E8E18` |
| Magic registry | `9C6A34207A0575B8E550E5D0C511A38681D041D54BA2EACF444BE8036E0BFE3A` |
| Generated magic resolver | `4E18B8EF63754E168C820363681A45546ECD37B7CA8FA70E47E712549D084745` |
| Source packet | `82EAE6531C71AA6318D2A8959AD869BF02AC01B6F8A7F51D27E62475DD19050E` |
| Canonical/build card | `C39465C83CFD0F91174DE8EEC6EA0C1F71D575F01676E5D90B09AB48F8D78A04` |
| MQ5 | `0C0ED591991060A16BCF366F5F994E9FE7005F55193B166151FD64E6FE216438` |
| EX5 | `2BED6E5635D3715254C75300298A0C11FCA213F76AD1F2E4194458E0ECDD41C0` |
| SPEC | `8971507165ABB56727D8D1167856C4314D4BE92C25FEF864830FF086EDB6883A` |
| Backtest set | `69B407556F14691D5C481176DF4F9928C3097AED85C5B060447EB24F24C92BD7` |

## Paced Q02 Handoff

The binding `farmctl mt5-slots` sample at
`2026-08-09T13:08:58+00:00` found zero executing factory terminals against
the ceiling of seven. It separately observed T_Live and FTMO terminal
processes outside the T1-T10 factory roots; those were excluded from the count
and were not changed.

The target-only dry run selected one never-tested row. The single apply run
then enqueued one and no stranded retry or deferred promotion:

- Work item: `6e8edd6b-72da-4b37-8a27-15ccdea515b8`.
- Created: `2026-08-09T13:09:10+00:00`.
- Phase/kind: Q02 / backtest.
- Symbol/timeframe: `XTIUSD.DWX` / D1.
- Setfile:
  `QM5_20269_wti-medret-mom_XTIUSD.DWX_D1_backtest.set`.
- Priority: `priority_track=true`.
- Immediate state: pending, attempt 0, unclaimed, no verdict.

## Commits Before This Closing Evidence

- `8bdebf98d` — OWNER mission authorization and exact G0 decision.
- `116c06bd8` — bounded source packet plus approved/intake cards.
- `b901f0d69` — deterministic EA-ID reservation.
- `49f1d51a7` — WTI magic allocation, resolver generation, and SPEC.
- `0dc7789c4` — paced pump setfile artifact commit.
- `5a7f59c79` — final EA source, compiled EX5, build card, Q01 status, and
  fixed-risk set binding.

## Safety Boundary

- No manual backtest, smoke test, dispatch tick, or downstream phase was run.
- No terminal was started, stopped, reserved, reaped, or altered.
- No live, demo, shadow, optimization, or stress setfile was created.
- AutoTrading was not toggled; T_Live was not changed.
- The portfolio gate and T_Live manifest were not touched.
- Unrelated pre-existing and concurrent working-tree edits were preserved and
  excluded from this mission's commits.
