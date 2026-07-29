# FTMO Book 3 execution preregistration — evidence vintage V2

Date: 2026-07-29
Decision authority: OWNER
Execution scope: isolated BACKTEST-ONLY measurement while the autonomous Factory remains OFF

## Why a new evidence vintage is required

The first Stage-0 measurement under source commit
`0ba3768a7c79b2f77ade7269977ccf90ce464043` produced valid R0 and J0 MT5 runs,
but its V1 fidelity receipt correctly returned `FAIL`:

| Artifact | SHA-256 |
|---|---|
| R0 isolated-runner receipt `D:\QM\strategy_farm\artifacts\ftmo_book3\runtime\r0_0ba3768a7c79_runner_receipt.json` | `2f6f5b3bd096606fda41a381ebc1b2fc977d9c82b06744f8db88e0fb5c66977b` |
| J0 isolated-runner receipt `D:\QM\strategy_farm\artifacts\ftmo_book3\runtime\j0_0ba3768a7c79_runner_receipt.json` | `6f3b188dde77e26afc7b443f9a332cd1214d42269a19fb8d776476e33bf3364d` |
| V1 Stage-0 FAIL receipt `D:\QM\strategy_farm\artifacts\ftmo_book3\runtime\fidelity_stage0_0ba3768a7c79_receipt.json` | `920a8c99f73c6443c8e65d98da9effb9c4b10f565014b787a88d6d28cf84d048` |
| R0 harvested stream | `ce22025d76ae70e132e272f06dced6d8a4842248be95102b0224901fd0fd8a27` |
| J0 harvested stream | `c0bb59b92ccdbb8162ba20321ab7bfe9d6bd6395b0fce06cc687f8dac3756791` |

Independent reconciliation established that all 1,143 trades have the same
order, entry time, close time, volume, side, entry price, exit price, profit,
swap, and full MT5 commission. The native MT5 reports also reconcile exactly.
The V1 standalone Q08 producer emitted only the exit-side commission, whereas
the joint producer emitted entry plus exit commission. Consequently:

- standalone V1 Q08 net sum: USD 132,351.13;
- joint Q08 and both native MT5 report net sums: USD 118,491.58;
- difference: USD 13,859.55, exactly the omitted entry-side commission; and
- for every one of the 1,143 rows, `standalone_v1.net +
  standalone_v1.commission == joint.net` within floating-point representation.

This is a measurement-producer defect, not a strategy, order, timing, sizing,
or joint-adapter fidelity finding. It must not be repaired by changing the
comparison tolerance, synthesizing a second commission side downstream, or
overwriting V1 evidence. V1 rows and their non-releasing holds remain a failed
evidence vintage and are never eligible for release.

## Frozen V2 measurement contract

The new exact contract is
`FTMO_BOOK3_FIDELITY_LADDER_V2_FULL_LIFECYCLE_NET`, evidence vintage
`FTMO_BOOK3_20260729_V2`, and money basis
`FULL_POSITION_LIFECYCLE_ACTUAL_V1`.

Every standalone `TRADE_CLOSED` row must be produced from actual MT5 deal
history and carry all of these finite, reconciled fields:

- `profit`, `swap`, `fee`, `entry_commission`, `exit_commission`,
  `commission`, and `net`;
- `commission == entry_commission + exit_commission` within USD 0.005;
- `net == profit + swap + fee + commission` within USD 0.005; and
- exact `money_basis: FULL_POSITION_LIFECYCLE_ACTUAL_V1`.

The producer must allocate actual deal components across scale-ins and partial
exits without inventing money. It must preserve the final residual so allocated
components sum back to the authoritative MT5 position lifecycle. Orphan exits,
unsupported reversals/`DEAL_ENTRY_INOUT`, non-finite values, inconsistent
volumes, ambiguous ownership, or unreconciled arithmetic fail closed.

The joint operand remains bound to schema 2, producer
`QM5_20181_FTMO_TRACE_V2`, the exact V2 rung run ID, a fully closed position,
its entry/exit deal lineage, and the same component arithmetic. A missing,
legacy, mixed, null, unknown, or arithmetically invalid money basis is
`SETUP_BLOCKED`; it can never become a fidelity FAIL or PASS.

## Immutable book and execution boundary

The OWNER-locked book remains exactly:

| Stage | Standalone | Symbol | Joint sleeve/magic | Joint run ID |
|---:|---|---|---:|---|
| 0 | QM5_9936 | USDJPY.DWX | 0 / 201810000 | `FTMO_BOOK3_20260729_V2_J0` |
| 1 | QM5_10145 | XAUUSD.DWX | 1 / 201810001 | `FTMO_BOOK3_20260729_V2_J1` |
| 2 | QM5_13108 | XTIUSD.DWX | 2 / 201810002 | `FTMO_BOOK3_20260729_V2_J2` |

QM5_13301 is not a member. No strategy inputs, signals, risk parameters, cost
inputs, calendars, symbols, terminal, model, or dates may change within V2.
All six measurements use T10, Model 4 real ticks, USD 100,000, the exact window
2018-07-02 through 2025-12-31, `RISK_PERCENT=0`, and `RISK_FIXED=1000` per
enabled sleeve.

All four affected EAs must be strict-compiled serially from the same clean
source vintage after the shared framework producer change. Their new EX5 files
and compile logs must be written to a V2-specific artifact directory; V1 EX5
files, receipts, reports, and streams remain byte-identical.

`FACTORY_OFF.flag` must stay present and byte-identical. The Factory mutation
lock covers every isolated claim, MT5 run, evidence harvest, and receipt
publication. Factory tasks remain disabled. T5 and T_Live are forbidden;
T_Live and AutoTrading are never touched. No paid Challenge, deployment,
release, or Factory-ON action is authorized by this preregistration.

## Fixed ladder and unchanged gates

The only permitted order is R0, J0, Stage 0 gate, R1, J1, Stage 1 gate, R2,
J2, Stage 2 gate. A non-PASS gate stops every later rung.

For each stage the comparator still requires:

- both operands valid and non-empty;
- `match_rate == 1.0`;
- zero unmatched trades on either side;
- exact side and lifecycle ordering;
- exact entry and exit prices (`price_tolerance == 0`);
- entry and close times equal;
- volume tolerance USD-independent at 0.005; and
- every actual money component and full-lifecycle net equal within USD 0.005.

There is no V1-to-V2 waiver, tolerance relaxation, count-only comparison,
downstream commission imputation, or reuse of the V1 MT5 runs. All six V2
measurements and all three adjudication receipts must be fresh, create-only,
source-bound, artifact-bound, and mutually consistent.

## Outcomes and next boundary

- **Fidelity PASS:** permits the next preregistered rung only.
- **Fidelity FAIL:** preserves the evidence, stops the ladder, and requires a
  new strategy/framework decision before another vintage.
- **SETUP_BLOCKED:** preserves the evidence, repairs only the proven setup or
  producer defect, and repeats under a newly hash-bound source state.

Even three fidelity PASS receipts do not prove FTMO suitability. The joint
money gate still requires event-complete account equity, Prague-midnight daily
anchors, official-rule evaluation, governor parity/fault injection, and the
predeclared probability thresholds. The current in-EA joint equity trace
honestly declares `coverage_complete: false`; unless a separately validated
event-complete producer supplies admissible evidence, the money gate must stop
as `SETUP_DATA_MISSING` and no hold or restart gate may be released.

Factory restart readiness remains a separate, hash-bound OWNER decision. This
work may prepare a restart dossier after all applicable gates pass; it may not
remove `FACTORY_OFF.flag` or invoke `Factory_ON.ps1`.
