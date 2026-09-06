# QM5_41366 XTI/XNG Decoupling Continuation — Build and Q02 CPU Stop

## Outcome

`QM5_41366_xtixng-decouple-cont` is a committed, non-live V5 basket build.
The governed worker compiled the exact committed MQ5 source with zero compiler
errors and zero compiler warnings, and the strict build check passed. Q02 was
not enqueued because the required fresh CPU admission window exceeded the
binding 97% ceiling.

## Structural Edge

On the first tradable D1 bar of a new Monday-anchored broker week, reconstruct
the immediately completed synchronized XTI/XNG week and its consecutive
parent. If the individual completed-week returns have strict opposite signs,
buy the winner and sell the loser as one equal-notional, aggregate-fixed-risk
package. Exit in the next broker week. This is the continuation-side sibling
of `QM5_41365_xtixng-decouple-rv`, which trades the same state in the opposite
direction; it is also distinct from the monthly 126-D1 rank in `QM5_12733` and
the single-symbol XNG oscillator in `QM5_12567`.

## Q01 Evidence

- Governed compile work item: `469c6d49-4bd3-4c4f-af33-a68739e7877c`.
- Source SHA-256: `41620da346c972ddfb1b90016e5308aaf8bbe7e7bd0af1054eac9cde67b44e45`.
- EX5 SHA-256: `1b10812d1df947a00365aba98fd5988756e255d1c77b90ac61cbe0944e5c0563`.
- Verdict: `COMPILE_OK`; strict build check `PASS`; three setfiles sealed.
- Reference model: 9/9 tests pass.
- Card schema lint: PASS; no ML hits or missing sections.
- Backtest presets keep aggregate `RISK_FIXED=1000` and `RISK_PERCENT=0`.

The strict build check emitted three advisory card-inference warnings for
loss-limit, broker-time-window, and pending-order inference. They were not
compiler warnings and did not change the PASS verdict; the card itself fixes
the broker-week clock and forbids pending orders.

## Q02 Admission Stop

At `2026-09-06T10:01:36.4754558Z`, five one-second whole-host CPU samples were
`99.024541`, `99.034667`, `97.562535`, `95.947612`, and `96.909027` percent.
Average utilization was `97.695676%` and maximum utilization was `99.034667%`.
Both exceed the `97%` ceiling, so no Q02 work item was created and no terminal
or fleet control was changed.

Resume only by taking a fresh CPU admission sample. If it is below the binding
ceiling, use the canonical first-Q02 intake tied to compile work item
`469c6d49-4bd3-4c4f-af33-a68739e7877c`.

## Safety Boundary

No `T_Live`, AutoTrading, portfolio gate, deploy manifest, live preset, manual
backtest, terminal restart, or priority boost was touched.
