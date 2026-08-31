# QM5_41239 WTI Same-Calendar Soft-L1 Q02 Enqueue

## Outcome

The OWNER commodity/energy mission produced one new branch-only structural WTI
sleeve. `QM5_41239_wti-samecal-softl1-5` passed strict Q01 compilation and was
enqueued exactly once into Q02 as pending work item
`5ca5cc87-bd67-40fe-9970-0e382ba53155`.

No manual backtest, live action, portfolio-gate change, or correlation claim
was made. Q09 remains the only authority for realized decorrelation.

## Locked edge and non-duplicate evidence

At the first normalized WTI broker-month transition, the EA requires the exact
completed return for that calendar month in each of years Y-5 through Y-1. It
starts at the odd median, freezes scale at `1.4826 * raw MAD`, performs exactly
32 soft-L1 derivative-weight updates with `1/sqrt(1+u^2)`, and trades only the
strict final sign outside `1e-12`. Entry is consumed once per month; an accepted
position holds to the next month behind a frozen `3.5 * ATR(20,D1)` hard stop,
with a 40-day repair exit and 1500-point spread ceiling.

The canonical receipt found no exact identity. On
`[-0.120,-0.075,-0.020,+0.115,+0.120]`, soft-L1 buys at
`+0.001324252685`, while Cauchy and arctangent both sell at
`-0.004100768370` and `-0.004348219120`. On a second locked fixture, soft-L1
sells at `-0.100961055448` while raw mean buys at `+0.002`. These are actual
decision disagreements, not renamed parameter differences.

## Governance and Q01

The source packet binds peer-reviewed Return Seasonalities and Time Series
Momentum records to the previously approved complete SciPy soft-L1 definition.
The source approval, G0 decision, EA ID 41239, slot-0 magic 412390000, approved
card, local card, SPEC, source, binary, and sole fixed-risk setfile are durable
and hash-bound.

Governed compile work item `e34531d1-f2c4-4444-96b9-eef792928f1a` completed
with:

- build check PASS;
- compiler PASS with zero errors and zero warnings;
- one `XTIUSD.DWX / D1 / RISK_FIXED=1000` backtest setfile;
- 12 independent reference tests passing;
- 17 allocator/precheck and 7 resolver tests passing;
- card lint, SPEC, strategy-entry, raw-source quarantine, and scoped static
  guardrail checks passing with zero findings.

The build-only skill boundary was preserved, so no smoke or other MT5 backtest
was launched manually.

## Paced Q02 enqueue

The whole-host five-sample CPU window immediately before queue mutation was
`80.6031%, 85.2849%, 87.5013%, 69.9250%, 66.7091%` (average `78.0047%`,
maximum `87.5013%`). Both were below the 97% hard ceiling.

The canonical build recorder created one Q02 row:

- work item: `5ca5cc87-bd67-40fe-9970-0e382ba53155`;
- status at readback: pending, attempt count 0, unclaimed;
- symbol/timeframe: `XTIUSD.DWX / D1`;
- custom-history archive admission: ACTIVE, 108 selected rows;
- priority track: true;
- duplicate or skipped rows: none.

This session enqueued but did not dispatch or execute that row.

## Safety boundary

AutoTrading was not toggled. `T_Live`, its manifest, deploy manifests, the
portfolio gate, portfolio admission, and certification state were untouched.
The artifact establishes a new testable direct-WTI sleeve, not performance or
decorrelation.

Machine-readable receipt:
`artifacts/qm5_41239_wti_samecal_softl1_5_q02_enqueue_20260831.json`.
