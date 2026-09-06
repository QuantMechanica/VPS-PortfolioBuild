# QM5_41367 XTI/XNG Common-Shock Continuation — Build and Q02 CPU Stop

## Outcome

`QM5_41367_xtixng-commonshock-cont` is a committed, non-live V5 basket build.
The governed worker compiled the exact committed MQ5 source with zero compiler
errors and zero compiler warnings, and the strict build check passed. The
read-only first-Q02 intake plan was eligible, but Q02 was not enqueued because
the required fresh CPU admission window exceeded the binding 97% ceiling.

## Structural Edge

On the first tradable D1 bar of a new Monday-anchored broker week, reconstruct
the immediately completed synchronized XTI/XNG week and its consecutive
parent. If the individual completed-week returns have the same strict sign
and differ by more than the fixed epsilon, buy the relative weekly winner and
sell the loser as one equal-notional, aggregate-fixed-risk package. Exit in
the next broker week. The same-sign state is disjoint from the opposite-sign
decoupling continuation in `QM5_41366` and its direction is the inverse of the
same-sign reversion package in `QM5_41361`; it is also distinct from the
126-D1 monthly relative-strength basket in `QM5_12733`.

## Q01 Evidence

- Governed compile work item: `a4714bf1-8238-4645-92ae-e2e763d06cca`.
- Source SHA-256: `7edc29f98193d70193e8f0559f0a9708f17e9af8b5a371f7b60d6d8091f3a167`.
- EX5 SHA-256: `5f752a75aa79dab671f481d0a446824690a86c7138cc296efd3d5cd554ca63ef`.
- Verdict: `COMPILE_OK`; strict build check `PASS`; three setfiles sealed.
- Reference model: 10/10 tests pass.
- Card schema lint: PASS; no ML hits or missing sections.
- Backtest presets keep aggregate `RISK_FIXED=1000` and `RISK_PERCENT=0`.

The strict build check emitted three advisory card-inference warnings for
loss-limit, broker-time-window, and pending-order inference. They were not
compiler warnings and did not change the PASS verdict; the card itself fixes
the broker-week clock and forbids pending orders.

## Q02 Admission Stop

The canonical first-Q02 dry run bound the logical basket setfile, both active
magic rows, and the current EX5, and returned `ELIGIBLE` without priority
boost. At `2026-09-06T11:50:14.0760009Z`, five one-second whole-host CPU
samples were `100.0`, `99.616338`, `99.610393`, `99.609801`, and `98.6331`
percent. Average utilization was `99.493927%` and maximum utilization was
`100.0%`. Both exceed the `97%` ceiling, so no Q02 work item was created and
no terminal or fleet control was changed.

Resume only by taking a fresh CPU admission sample. If it is below the binding
ceiling, use the canonical first-Q02 intake tied to compile work item
`a4714bf1-8238-4645-92ae-e2e763d06cca`.

## Safety Boundary

No `T_Live`, AutoTrading, portfolio gate, deploy manifest, live preset, manual
backtest, terminal restart, or priority boost was touched.
