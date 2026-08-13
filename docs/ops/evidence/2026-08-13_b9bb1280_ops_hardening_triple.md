# 2026-08-13 ops-hardening triple

Router task: `b9bb1280-53df-4d2a-8baa-22c5fce53525`

Assigned agent: Codex

Branch: `agents/board-advisor`

Disposition: REVIEW REQUIRED

## A. Windows Update reboot policy — proposal only

The decision memo is
`docs/ops/WINDOWS_UPDATE_REBOOT_POLICY_PROPOSAL_2026-08-13.md`.

Read-only host evidence established Windows Server 2022 build 20348,
`AUOptions = 3`, and `NoAutoRebootWithLoggedOnUsers = 1`. Microsoft documents
that the latter only applies with option 4, so the existing pair is not an
effective no-reboot contract. The memo recommends Server-only option 7
(`Auto Download, Notify to install, Notify to Restart`) and a manual weekend
OWNER window. It records exact Group Policy and registry paths, rollback, and
residual risks.

No registry, Group Policy, update, service, scheduled task, reboot, terminal,
T_Live, FTMO, or AutoTrading state was changed.

The event audit also corrects the incident boundary: the 23:44/23:47 restarts
were planned Windows servicing, while the 05:27 `wininit` event reports an
unexpected LSASS termination and the 05:28 Event 6008 reports an unclean
shutdown. Update policy cannot prevent the second class.

## B. FTMO PARKED contract

Changed:

- `tools/strategy_farm/ftmo_trial_pulse.py`
- `tools/strategy_farm/tests/test_ftmo_trial_pulse.py`

`PARKED` now means:

- the FTMO terminal may be stopped or warm/running;
- the broker-derived active QM magic count must be zero;
- missing, malformed, stale, or account-count-inconsistent activity evidence
  fails closed;
- any active QM magic remains an ALARM.

The activity source is AccountMonitor's append-only
`journal/live_deals_normalized.csv`, grouped by broker `position_id` and closed
only by `OUT`, `OUT_BY`, or `INOUT`. This avoids treating attached EAs or stale
EA logs as live trading. A fresh `account_snapshot.json` open-position count
must equal the reconstructed broker position count.

Read-only production evaluation found that the ticket payload's “0 magics
active” statement is no longer true:

```text
active position_id: 517753858
active QM magic:    107060001
snapshot positions: 1
contract result:    ftmo_qm_magics_active_while_parked:1
```

This is a real fail-closed alarm, not the removed
`ftmo_terminal_running_while_parked` process-only false alarm. No position,
order, terminal, profile, Expert setting, or trading control was touched.

## C. Codex main-integration stop

The instructing source was the scheduled Codex mission template in
`tools/strategy_farm/run_agent_orchestration_task.py` (the action for
`QM_StrategyFarm_CodexOrchestration_15min` invokes this file). Its prior text
required evidence to be “merged to the main branch.” Codex sessions interpreted
that as authority to cherry-pick through `C:/QM/worktrees/cto_main`.

The template now states:

- commit in canonical `C:/QM/repo` on `agents/board-advisor` only, with explicit
  pathspecs;
- do not cherry-pick, merge, commit, reset, or otherwise advance main or
  `C:/QM/worktrees/cto_main`;
- main integration is exclusively a Claude+OWNER close-out action;
- leave the artifact in REVIEW.

No existing main history was rewritten, reset, reverted, or otherwise changed.

## Focused verification

```text
python -m pytest \
  tools/strategy_farm/tests/test_ftmo_trial_pulse.py \
  tools/strategy_farm/tests/test_agent_orchestration_lock.py -q

27 passed
```

The suite proves warm-terminal/zero-magic PARKED is OK, positive active-magic
PARKED is ALARM, unknown activity is ALARM, broker lifecycle parsing ignores a
closed position, malformed evidence fails closed, and the generated headless
prompt contains the Claude+OWNER-only main boundary.

Additional checks before commit: Python compilation, `git diff --check`, exact
pathspec inspection, and a read-only production activity evaluation. Pipeline
verdicts and live/deployment authority are outside this artifact.
