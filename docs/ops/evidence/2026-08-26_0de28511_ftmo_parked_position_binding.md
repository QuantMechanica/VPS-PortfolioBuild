# FTMO parked-position OWNER binding

- Router task: `0de28511-60c4-4e4b-a218-d013c66246bf`
- Authority: `decisions/2026-08-26_owner_q12_disposition_ftmo_position.md` §2
- Branch: `agents/board-advisor`
- Scope: read-only monitoring configuration; no account, position, terminal,
  T_Live, AutoTrading, or deployment action

## Result

`ftmo_trial_pulse.py` now binds the intentionally open FTMO trial position to
the exact observed contract: one position, position ID `527674048`, and logical
magic `107060001`. The state is published as `OK / PARKED_WITH_POSITION` with
the OWNER decision reference. Zero, two, replacement, unattributed, or
otherwise mismatched positions remain fail-closed.

The PARKED path continues to reconcile the broker deal lifecycle with a fresh
AccountMonitor snapshot. It also retains journal-event inspection and the
existing 5% daily / 10% total equity-limit assessment. The pulse remains an
observer only and cannot write a halt signal or take account action.

Actual read-only pulse at `2026-08-26T13:52:40Z`:

```text
verdict=OK
condition=PARKED_WITH_POSITION
decision_reference=decisions/2026-08-26_owner_q12_disposition_ftmo_position.md#2
open_positions=1
active_qm_position_ids=[527674048]
active_qm_magics=[107060001]
equity=99774.97
total_dd_pct=0.22503
alarms=[]
warns=[]
health_contract.overall=OK
```

## Verification

```text
python -m pytest tools/strategy_farm/tests/test_ftmo_trial_pulse.py -q
22 passed in 1.09s

python -m py_compile tools/strategy_farm/ftmo_trial_pulse.py
PASS

git diff --check -- tools/strategy_farm/ftmo_trial_pulse.py \
  tools/strategy_farm/tests/test_ftmo_trial_pulse.py
PASS
```

The focused suite includes the required negative case: two open positions emit
`ftmo_parked_position_count_changed:2!=1`.

## Rollback

Revert only this task's implementation commit on `agents/board-advisor`, then
rerun the focused test and one read-only pulse. Rollback is monitoring-code
only; it must not be coupled to closing a position, starting/stopping a
terminal, or toggling AutoTrading.
