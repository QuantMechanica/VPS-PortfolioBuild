# Task 7267e593 — general farmctl Q01 smoke dispatch route (2026-09-22)

Router task `7267e593-64af-4f3d-8599-8a9d0babe291` (`ops_issue`), filed as the
follow-up from task `ea8b4312`'s reconciliation
(`docs/ops/evidence/2026-09-22_ftmo_recovery/task_ea8b4312-e092-481b-ad10-b08a8c18fced/reconciliation.md`
§2/§4). Built in worktree `agents/claude-orchestration-1`; **not applied to
any live EA or the running `farm_state.sqlite`** — this cycle implements and
unit-tests the route only, per the task's explicit "needs its own
cross-vendor review before touching any EA source/binary."

## 1. The gap this closes

`tools/strategy_farm/q01_basket_smoke_recovery.py` is the only existing code
that *appends* a pending `q01_smoke` work item (the only kind the fail-closed
Q02-admission check recognizes as a real smoke attempt, contract
`qm.q01.worker_bound_basket_smoke.v1`). It is hard-scoped by a literal
`TARGETS` tuple to three specific basket EAs, each bound to its own fixed
`review_task_id` in the legacy `tasks`/`ea_review` pipeline.
`farmctl.record_q01_smoke_successor` only *authenticates* an already-terminal
`q01_smoke` row against a legacy `tasks` build record; it cannot create one.

Neither route works for EAs built through the newer `agent_tasks`
capability-router pipeline (task_type=`build_ea`), which has no `tasks`-table
row at all — e.g. the six recovered FTMO candidates from task `ea8b4312`
(QM5_9241/20078/36001/36003/36004/36008), all `COMPILE_OK`, none with a
`Q01`/`q01_smoke` work item.

## 2. What was built

`tools/strategy_farm/farmctl.py`:

- `append_q01_smoke_work_item(root, *, ea_id, symbol, build_task_id, compile_evidence_path, from_date=None, to_date=None, dry_run=False)`
  plus its read-only authenticator `_authenticate_q01_smoke_dispatch`.
- New CLI subcommand `append-q01-smoke-work-item` (`--ea-id --symbol
  --build-task-id --compile-evidence-path [--from-date --to-date] [--dry-run]`),
  wired into `_command_mutates_state` (dry-run exempt, like
  `record-q01-smoke-successor`) so a real append is gated by the existing
  canonical-checkout guard (`_assert_canonical_checkout`) the same way every
  other state-mutating farmctl command is.

No EA id, symbol, or task id is hard-coded anywhere in the new code — every
identity is re-derived from the named compile evidence file and the
`agent_tasks` row passed on the command line, closing the exact `TARGETS`
objection the task raised.

### Authentication chain (fail-closed at every step)

1. `ea_id` matches `^QM5_\d+$`; `symbol` and `build_task_id` non-empty;
   `from_date <= to_date`, both well-formed `YYYY.MM.DD` (defaults
   `2024.01.01`..`2024.12.31`, matching the existing basket-recovery
   convention and its `Q01_MIN_TRADES` semantics).
2. `--compile-evidence-path` must be a real file; it is hashed and parsed.
3. Exactly one `work_items` row with `kind='compile' AND phase='COMPILE_EA'
   AND ea_id=<ea_id>` must have that exact (path-normalized) `evidence_path`,
   `status='done'`, `verdict='COMPILE_OK'` — refuses on zero or >1 matches.
4. The evidence JSON's own `ea_id`, `success`, `compile_result` are checked;
   its `setfile_generation` list must contain an entry for `symbol` with
   `setfile_exists=true`.
5. **Three-way hash check**: the evidence's `ex5_sha256`/`mq5_sha256` must
   match the `work_items` row's own `ex5_sha256`/`mq5_sha256` columns, and the
   **current bytes on disk** of the ex5/mq5/setfile paths named in the
   evidence must still hash to the sealed values — refuses
   `artifact_drift_since_compile` if the source was touched after the compile
   that produced this evidence.
6. **Build-task binding**: `agent_tasks` row `<build_task_id>` must exist,
   `task_type='build_ea'`, `state` not in `{FAILED, RECYCLE, BLOCKED,
   OPS_FIX_REQUIRED}`, and its `artifact_path` (path-normalized) must equal
   the exact `--compile-evidence-path` — this is the binding proof that the
   requesting build task is the one that produced this exact compile
   evidence, not a different EA's.
7. Deterministic idempotency key
   `uuid5(ea_id:symbol:build_task_id:compile_work_item_id)`: an exact repeat
   is a no-op (`already_applied`); a mismatched repeat on the same id raises
   (data-integrity collision, mirrors `q01_basket_smoke_recovery.apply()`);
   any other **pending/active** `q01_smoke` row already open for the same
   `(ea_id, symbol)` under a different identity blocks the append
   (`q01_smoke_already_pending_for_target`) so two dispatch calls can never
   race two concurrent worker-bound smokes for the same target.
8. On success, the row carries `window_source` +
   `diagnostic_single_window=true` (2026-09-04 explicit-window contract,
   `_declares_diagnostic_single_window`/`_diagnostic_single_window`) so the
   worker's spawn builder honours `from_date`/`to_date` verbatim instead of
   silently substituting the `DEFAULT_RUN_SMOKE_YEAR` fallback that mislabeled
   15 OOS-2026 rows in the postmortem documented at that contract's
   definition — deliberately **not** `portfolio_scope:"basket"`, since these
   are single-symbol EAs and that flag would misdescribe them even though it
   would incidentally also unlock an explicit window.

## 3. Tests

`tools/strategy_farm/tests/test_farmctl_q01_smoke_dispatch.py` — 10 cases
against a synthetic fixture (`tmp_path`, no live DB touched): happy-path
append, dry-run writes nothing, idempotent exact repeat, second identity
blocked while the first is pending, unknown symbol refused, ex5-drift-since-
compile refused, build-task artifact_path mismatch refused, disqualified
build state refused, malformed window refused, and an explicit check that an
EA id outside the old `TARGETS` tuple is accepted (no hard-coding regression).

```
python -m pytest tools/strategy_farm/tests/test_farmctl_q01_smoke_dispatch.py -q
  -> 10 passed
python -m pytest tools/strategy_farm/tests/test_farmctl_requal8_tools.py tools/strategy_farm/tests/test_q01_basket_smoke_recovery.py -q
  -> 19 passed (no regression in the adjacent governed tooling)
python -m pytest tools/strategy_farm/tests/ -q -k "q01 or requal8 or smoke"
  -> 80 passed, 1 skipped (no regression across the wider q01/smoke suite)
```

No mutating invocation was run against `D:\QM\strategy_farm\state\farm_state.sqlite`
this cycle — `--dry-run` and real appends both require the canonical checkout
(`_assert_canonical_checkout`), which this worktree deliberately is not; the
function was only exercised through pytest against throwaway `tmp_path` DBs
and files, and no `smoke_passed` or capacity-waiver evidence was fabricated
anywhere, per the task's explicit instruction.

Changed-file hashes (this worktree, `agents/claude-orchestration-1`, after the
line-ending fixup commit below):

- `tools/strategy_farm/farmctl.py` sha256
  `5dd8416c91ea47de5858126f96044b6868954111d11ffe288e0eb3c339bc6f10`
- `tools/strategy_farm/tests/test_farmctl_q01_smoke_dispatch.py` sha256
  `85930cb8deca23327859de2d7fa0ea31831a4a79fb5a5cbea5e2d832adc751c7`

**Self-correction:** the first commit's edit tooling silently normalized ~790
pre-existing LF-only lines in `farmctl.py` to CRLF across the whole file while
making the intended addition — `farmctl.py` is a documented raw-byte-contract
file (`.gitattributes: -text`, 2026-08-02 phantom-dirty incident) whose line
endings must never be re-smudged. A follow-up commit rebuilt the file
(content-diff with EOLs stripped against the pre-change blob; unchanged lines
kept byte-identical, only genuinely new lines written CRLF) so the net diff
vs the pre-task baseline is exactly the intended 475-line addition
(`git diff --stat HEAD~2 HEAD -- tools/strategy_farm/farmctl.py`). Tests and
CLI `--help` were re-verified after the fixup.

## 4. Known follow-on gap (documented, not fixed here — out of bounded scope)

Even after a worker completes a row appended by this route with `PASS`,
**Q02 admission still cannot see it**: `farmctl._latest_build_smoke_result`
and `record_q01_smoke_successor` both hard-query the legacy `tasks` table
(`kind='build_ea' AND card_id=?`), which an `agent_tasks`-originated build
never populates. Closing that admission-side gap (teaching
`_latest_build_smoke_result` / a successor-recording path to also read an
`agent_tasks` build row) is a second, independently reviewable change and is
explicitly left for a follow-up ops_issue rather than folded into this one —
this task's payload asked only for the append side, and mixing the two would
widen the review surface on gate-adjacent logic beyond what was scoped.

## 5. Recommended next step

File a follow-up `ops_issue`: "teach Q02 admission (`_latest_build_smoke_result`)
to also resolve an `agent_tasks` build_ea row" so a real Q01 PASS produced via
this new route can actually unblock Q02 for the six recovered FTMO candidates
end-to-end. Until that lands, this route is necessary but not yet sufficient
to move QM5_9241/36001/36003/36004/36008 (and QM5_20078 once `bb697211`
closes) past Q01.

## Economic status

Unchanged: no new backtest result, no admitted economic survivor. This cycle
is infrastructure only, exactly as scoped.
