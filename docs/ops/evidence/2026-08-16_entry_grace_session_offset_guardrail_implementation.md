# Entry-grace versus session-offset build guardrail implementation

- Router task: `cdb974cf-ec7d-4027-8546-cf874d5f8b82`
- Branch: `agents/board-advisor`
- Date: 2026-08-16
- Disposition: `REVIEW`

## Outcome

The build path now rejects a backtest set when an operational D1-label/bar-open
entry grace cannot reach the first tradable tick recorded in
`framework/registry/session_offset_minutes.csv`.

The binding rule is:

`declared_grace_minutes >= measured_offset_minutes + 5 minutes`

The narrowest numeric declaration found in the EA input, scoped set file, or
local strategy-card/SPEC is binding. This prevents a set-file override from
silently widening a tighter source/card contract.

Only `offset_source=measured` is authoritative. A D1 grace idiom on an inferred
or unmeasured row fails closed with `session_offset_non_authoritative`; a symbol
that cannot be resolved or is absent from the registry fails with the explicit
`session_offset_symbol_missing` finding. No override mechanism was introduced.

EAs without an operational bar-open grace are unaffected. EAs whose grace is
clearly anchored to the current intraday bar (H1/M30/etc.) are also outside this
D1 label-to-first-tick relationship gate.

## Build-path binding

`tools/strategy_farm/compile_ea.py` now evaluates build guardrails before its
EX5 timestamp cache. This closes the case where a timestamp-current binary
could be reported `COMPILED_CACHED` even though newly landed source/set policy
would reject it. A policy failure returns `BUILD_GUARDRAILS_FAILED` and
`symbol_scope_verdict=NOT_RUN_GUARDRAIL_FAILURE` before compilation or cache
acceptance.

## Payload premise correction: QM5_20095 is D1, not H1

The task payload states that QM5_20019 and QM5_20095 both anchor on the current
H1 bar and must keep building. The checked-in sources do not support the second
half of that statement:

- QM5_20019 sets `g_current_host_bar = iTime(g_leg_xau, PERIOD_H1, 0)` and checks
  its XAG synchronization with `PERIOD_H1`; it remains `PASS`.
- QM5_20095 sets `g_current_host_bar = iTime(g_leg_xau, PERIOD_D1, 0)` and checks
  XAG with `PERIOD_D1`. `git blame` binds this D1 implementation to its original
  source commit `d76a07d7fa`; it is not a local drift introduced by this task.

QM5_20095 declares 15 minutes for measured XAU/XAG offsets of 60 minutes. The
guardrail therefore correctly emits two `entry_grace_below_session_offset`
findings with a 65-minute minimum. No EA-specific exemption was added because
that would defeat the fail-closed contract this task implements.

## Verification

Focused deterministic tests:

```text
python -m pytest tools/strategy_farm/tests/test_build_guardrails.py tools/strategy_farm/tests/test_mnt012_build_guards.py -q
..............................                                           [100%]
30 passed in 1.79s
```

Syntax verification:

```text
python -m py_compile tools/strategy_farm/validate_build_guardrails.py tools/strategy_farm/compile_ea.py
PASS
```

The regression coverage includes:

- XTIUSD grace 5: refused (minimum 66.6 minutes from measured 61.6 + 5).
- XAUUSD grace 5: refused (minimum 65 minutes).
- XTIUSD grace 180: pass, including the QM5_41019/41020 pattern.
- EURUSD grace 5: pass (measured offset 0 plus the 5-minute margin).
- H1-anchored grace on a D1-named set: pass.
- Missing registry symbol: explicit named failure.
- Inferred/unmeasured offset: fail closed.
- Declared but operationally unused grace: unaffected.
- A wider set value cannot weaken a tighter card declaration.
- A cached EX5 cannot bypass the guardrail.

Real-source/build checks on 2026-08-16:

```text
QM5_41019 / XTIUSD.DWX -> COMPILED_CACHED (guardrails PASS before cache)
QM5_41020              -> guardrails PASS
QM5_20019              -> guardrails PASS (current H1 anchor)
QM5_20095              -> guardrails FAIL (current D1 anchor; XAU and XAG minimum 65 > 15)
QM5_20117 / XTIUSD.DWX -> BUILD_GUARDRAILS_FAILED, cached=false
```

A corpus audit of every EA source declaring
`strategy_entry_grace_minutes` confirmed that operational D1 tight-grace cases
are rejected, inferred/unmeasured D1 symbols fail closed, current H1/M30 cases
remain unaffected, and 180-minute measured-offset patterns pass. The audit did
not compile, enqueue, or run any backtest.

## Safety and scope

- No terminal was launched and no T1-T10 work was interrupted.
- No AutoTrading or T_Live state was changed.
- No pipeline verdict is asserted by this evidence.
- The news-staleness ceiling and fixed-risk guardrails were not weakened.
- Unrelated working-tree files were neither staged nor modified.
