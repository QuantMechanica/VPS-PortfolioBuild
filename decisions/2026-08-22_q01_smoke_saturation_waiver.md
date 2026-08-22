# Decision: Q01 smoke waiver is saturation-only

- Date: 2026-08-22
- Status: accepted
- Authority: OWNER-DEC-GATECONTRACT
- Effective: immediately for Q02 admission attempts

## Decision

Q01 continues to require a deterministic trade-generation smoke with at least
one trade before Q02 fanout. The only waiver is the already stated
**saturated-tester-fleet exception**.

The executable waiver requires all of the following in the same durable build
record:

1. build check passed;
2. strict compile passed;
3. `smoke_result="deferred_p2_smoke"`; and
4. explicit capacity evidence such as resolver `status=no_capacity`, a stated
   terminal-capacity ceiling, or a tester-process/active-work count showing the
   fleet was saturated before dispatch.

A missing build/smoke row, a blank outcome, or a generic `headless` or
`framework_error` explanation is not a waiver. A real zero-trade smoke remains a
Q01 block and creates no Q02 work item. The waiver does not assert aliveness or a
pipeline verdict; it delegates the first tester execution to the paced Q02
worker path.

## Thresholds and scope

No gate threshold changes. This decision narrows the executable exception to
the OWNER wording already recorded in saturated-factory strategy evidence. It
does not authorize manual terminal launch, capacity pre-emption, or bypass of
the compile/build-review contracts.

## Executable binding

- `tools/strategy_farm/farmctl.py::_q01_smoke_admission`
- `tools/strategy_farm/tests/test_zero_trade_prevention.py`
- `tools/strategy_farm/prompts/SCHEMAS.md` (producer contract)
