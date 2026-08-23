# SP-C6 Recurring Kill-/Recovery Dry-Run Evidence

Date: 2026-08-23

Router task: `96eb3708-4c3a-407c-aaf5-3533ecabd036` (`SP-C6`, priority 48, zone GELB).
Depends on `SP-C1` (`5c02a347-e91c-44e3-b592-6dad7c6f4d81`), which is `APPROVED`
(`PASS_DRY_RUN`, `593c9ddca`) — the dependency gate is met.

## Verdict

PASS_DRY_RUN — a recurring wrapper around the SP-C1 account/portfolio governor
now proves, from an append-only run history rather than a single sample, that
(a) every active position is detected on every run, (b) an alarm is raised
the moment the decision level rises above `CLEAR`, (c) a level-2+ decision
always carries a concrete freeze/cancel plan, (d) stage-3 flatten stays
unreachable without an independently hash-bound OWNER emergency policy across
every run in the sequence, and (e) the system recovers to `CLEAR` on its own
once the underlying condition clears, with no persisted breach latch to
reset. This is a design/test-level proof plus one live dry-run smoke test; it
does not deploy a scheduled task, compile any monitor, or authorize live
execution.

## What was built

`tools/strategy_farm/account_portfolio_governor_recurring_dry_run.py` — a
thin, dry-run-only wrapper around `account_portfolio_governor.evaluate()`:

- `build_record(...)` is a pure function (no file I/O) that turns one governor
  evaluation into one compact journal record
  (`qm.account-governor.recurring-dry-run-record/v1`): decision level/name/
  reasons, recognized position/order ticket lists, reconciliation flags, the
  cancel/flatten plan, and whether a policy/emergency-policy was bound. This
  keeps the "every run is provable on its own" property testable without
  mocking the filesystem.
- `append_journal(record, journal_path)` appends one JSON line to a JSONL
  file. It never truncates, rewrites, or reads-then-overwrites — each call is
  a single `open(..., "a")` write, so history is append-only by construction.
- `append_alarm(record, alarm_log)` appends one line to the shared
  `D:\QM\strategy_farm\state\health_alarms.log` (the same file/convention
  `live_book_dd_guard.py` already uses) whenever the decision level is above
  `CLEAR` — `WARN` for level 1/2, `CRITICAL` for level 3. Nothing is written
  for `CLEAR`.
- The CLI reuses the exact same `--policy`/`--trusted-policy-sha256`/
  `--emergency-policy`/`--trusted-emergency-sha256` hash-binding contract as
  `account_portfolio_governor.py` (same `GovernorError` fail-closed behavior),
  plus `--journal-path`/`--alarm-log`. Like its dependency, it requires an
  explicit `--dry-run` acknowledgement and has no apply mode.
- No order is sent, deleted, or closed; no AutoTrading state is touched; no
  trading signal file is written. The only side effects are the two
  append-only local files above.

## Lifecycle proof (`test_account_portfolio_governor_recurring_dry_run.py`)

`test_full_lifecycle_clear_freeze_flatten_recovery_is_append_only` drives one
continuous 20-minute timeline through `build_record` + `append_journal` +
`append_alarm` and checks the journal after every step:

| Run | Condition | Level | Name | Cancel plan | Flatten plan | Alarm |
|---|---|---|---|---|---|---|
| 1 | bound policy, gross leverage in range | 0 | `CLEAR` | `[]` | `[]` | none |
| 2 | gross leverage breach | 2 | `PENDING_CANCEL_AND_ENTRY_FREEZE` | `[401]` | `[]` | `WARN` |
| 3 | same breach + bound emergency policy | 3 | `CONTROLLED_FLATTEN_AUTHORIZED_DRY_RUN` | `[401]` | `[301, 302]` | `CRITICAL` |
| 4 | condition clears, no reset call made | 0 | `CLEAR` | `[]` | `[]` | none |

Assertions made at every step, not just at the end:

- `recognized_position_tickets == [301, 302]` on all four runs — every active
  position is detected regardless of decision level.
- After each `append_journal` call, the journal file is re-read and every
  prior record is byte-for-byte unchanged (`json.loads(prior_line) ==
  prior_record` for all earlier entries) — proves the write path is
  additive, not a read-modify-write that could silently alter history.
- `actions_executed == []` and `dry_run is True` on every run.
- Run 4 (`RECOVERY`) reaches the identical `CLEAR` decision as run 1 by
  re-evaluating that run's own snapshot — no separate "clear the breach"
  function was called and no state file exists to hold a stale level. This is
  the concrete evidence for "controlled recovery": recovery is a property of
  the evaluator being a pure function of its current input, not of any reset
  logic this wrapper would need to get right.

`test_alarm_line_omitted_for_clear_but_present_for_policy_unbound` confirms
the alarm fires even for the fail-closed `ENTRY_FREEZE_POLICY_UNBOUND` case
(an unbound policy is itself an operating condition worth flagging), and
stays silent only for genuine `CLEAR`.

`test_stage3_never_reachable_without_emergency_policy_even_across_many_runs`
repeats a level-2 breach across 5 consecutive one-minute runs with no
emergency policy bound in any of them — `would_flatten_position_tickets`
stays `[]` and `actions_executed` stays `[]` throughout, i.e. persistence of
a breach alone never accumulates into an authorization.

## Focused verification

```text
python -m py_compile tools/strategy_farm/account_portfolio_governor_recurring_dry_run.py
COMPILE_OK

python -m pytest tools/strategy_farm/tests/test_account_portfolio_governor_recurring_dry_run.py \
  tools/strategy_farm/tests/test_account_portfolio_governor.py \
  tools/strategy_farm/tests/test_live_book_dd_guard.py -q -p no:cacheprovider
16 passed in 1.49s

python tools/strategy_farm/account_portfolio_governor_recurring_dry_run.py --dry-run \
  --expected-login 4000090541 --max-age-seconds 9999999 \
  --journal-path "D:/QM/reports/state/account_portfolio_governor_recurring_dry_run.jsonl"
(run twice, 2026-08-23T07:29:57Z and 2026-08-23T07:30:19Z)
exit 0 both times; level 1 ENTRY_FREEZE_UNCERTAINTY (schema=LEGACY_UNVERSIONED);
actions_executed=[]; journal grew from 0 -> 2 lines, both preserved
```

The live smoke test against the real, currently-deployed account snapshot
correctly fails closed at level 1 — the same boundary `SP-C1`'s own evidence
documented, because the deployed monitor is still the v1 shape without the
detailed inventory arrays the v2 schema requires. This is expected and is not
a defect in this wrapper; it is proof the fail-closed behavior survives the
recurring wrapper unchanged. No MetaTrader compiler or terminal was started.
No T1-T10 or T_Live backtest was interrupted. No live order, sizing,
attachment, AutoTrading, or trading-signal-file mutation was performed.

## Explicitly out of scope for this task

- No Windows scheduled task was created or installed. The `SP-C1` contract
  already names the required gates before any live rollout (governed v1.10
  monitor compile/deploy, multi-interval reconciliation, OWNER-supplied
  policy hash) — this task proves the recurring *evaluation* property ahead
  of that rollout, not the rollout itself. Wiring an actual cadence (a
  scheduled task analogous to `QM_StrategyFarm_LiveBookDDGuard`) is separate
  ROT-adjacent operational work once the v2 monitor is live.
- Stage-2/3 execution adapters remain unimplemented, per SP-C1's own
  boundary — this wrapper only ever prints/journals a plan.

## Changed files

- `tools/strategy_farm/account_portfolio_governor_recurring_dry_run.py`
- `tools/strategy_farm/tests/test_account_portfolio_governor_recurring_dry_run.py`

This artifact remains in `REVIEW` for Codex/OWNER close-out, consistent with
`SP-C1`'s own dry-run evidence.
