# FTMO trial pulse — OWNER park-until-25 monitoring alignment

- Router task: `97d4cafd-aa91-41ac-8505-331ab27453fc`
- Decision: `OWNER-DEC-FTMO-PARK-UNTIL-25-20260825`
- Decision source: `decisions/2026-08-25_owner_hma_requal_ftmo_park_q02_dead16.md` §2
- Implementation commit: `5e733d1bd`
- Scope: read-only monitoring configuration only; no account action, terminal action,
  deployment, T_Live change, AutoTrading change, or position change was performed.

## Implemented contract

`ftmo_trial_pulse.py` now publishes the OWNER intent as `expected_state=PARKED`.
The expired calendar review is replaced by the canonical path-to-25 trigger:

- decision ID and source path are persisted in every pulse;
- the read-only `path_to_25.path_to_25_metrics()` census supplies
  `qualified_pairs`;
- the park decision is automatically reopened as an alarm when
  `qualified_pairs >= 25`;
- an unavailable trigger census fails closed;
- PARKED retains its existing broker-deal reconciliation: a warm terminal is
  allowed only when no QM position is active.

## Verification and health delta

Focused verification:

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_trial_pulse.py -q
21 passed in 9.17s

python -m py_compile tools/strategy_farm/ftmo_trial_pulse.py
PASS
```

Before the change (`D:/QM/reports/state/ftmo_trial_pulse.json`,
2026-08-25T20:19:55Z):

```text
expected_state=RUNNING
condition=contract_expired
expected_state_review_expired=true
alarm=expected_state_review_expired
health=FAIL
```

After the change (actual read-only pulse at 2026-08-25T20:35:21Z):

```text
expected_state=PARKED
expected_state_review_expired=false
decision=OWNER-DEC-FTMO-PARK-UNTIL-25-20260825
review_trigger=0/25 (not reached; probe OK)
terminal_up=true
open_positions=1
active_qm_magics=[107060001]
active_qm_position_ids=[527674048]
condition=parked_qm_trading_active
alarm=ftmo_qm_magics_active_while_parked:1
health=FAIL
```

The obsolete expiry failure is resolved and the documented PARKED contract is
visible. The check is deliberately not green because its two independent,
fresh sources agree that one QM position is open: broker deal lifecycle and the
AccountMonitor both report one position. Suppressing that alarm would weaken
the fail-closed PARKED contract. The task forbids account/live action, so this
cycle did not stop the terminal, close the position, or toggle trading. Once the
position is closed by an independently authorized path (or the OWNER changes
the intent), the same unchanged monitor will report the PARKED condition as OK.

## Rollback

If OWNER revokes this decision, revert only implementation commit `5e733d1bd`
on `agents/board-advisor` and rerun the focused test plus one read-only pulse.
That rollback changes monitoring code only; it must not be coupled to an
account, terminal, deployment, or AutoTrading action.
