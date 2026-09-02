# Q09 REQUAL-8 pair 7 smoke authenticated; boundary halted on absent governed successor/release tooling

- Recorded: `2026-09-02T09:20Z`
- Router task: `1b57e398-3709-44b3-a53a-21e20fdb5d7b`
- OWNER authority: `OWNER-DEC-Q09HOLD-REQUAL-8-20260829`
- CEO authority: Claude Fable acting as CEO
- Approved manifest SHA-256:
  `0b6845c941314f9c2f754b0897bd66fd1f4daa0220921726f2d51ef0e72a76f2`
- Canonical branch: `agents/board-advisor`
- Checkpoint: `PAIR7_Q01_SMOKE_AUTHENTICATED_PASS__BOUNDARY_NOT_EXECUTED`

## Verdict

`PAIR7_SMOKE_AUTHENTICATED_GENERATION_SUCCESSOR_TOOL_ABSENT`. The pair-7
worker-bound Q01 smoke is a **genuine, formally authenticated PASS** against
every sealed binding (all three artifact hashes, window, expert, symbol,
timeframe, deterministic real-tick trades). The remainder of the pair-7
boundary (generation successor -> generation-matched reviews -> single Q02
enqueue -> exact hold release) and the pair-8 build handoff were **not
executed**, because the two privileged writes the boundary requires have **no
available authorized write-path**: no committed canonical tool performs them
for QM5_41221, and the "exact governed pattern pair 6 used" survives only as
prose (its scripts were ephemeral and never committed). Reconstructing bespoke
mutations of the live factory state DB from prose would be a guess, which the
fail-closed rule forbids. Nothing was mutated. All holds remain active. The
protected `QM5_41162 OPT_CENSUS` program is byte-stable.

## 1. Q01 smoke authentication (COMPLETE)

Work item `7afddab0-dfc1-5324-bb7d-b585d9ddfa69`
(`q01_smoke / Q01`, `QM5_41221 / EURUSD.DWX / D1`) is `done / PASS`, finished
`2026-09-02T07:01:46Z`. Evidence:
`D:/QM/reports/work_items/7afddab0-dfc1-5324-bb7d-b585d9ddfa69/QM5_41221/20260902_065835/summary.json`
(`evidence_schema: run_smoke/v2`).

Immutable execution bindings — current repo bytes recomputed and matched to the
sealed manifest and to the smoke summary's `execution_identity`:

| Artifact | Sealed / current / summary SHA-256 | Result |
|---|---|---|
| MQ5 | `ede8570a029563fadecdfb99b829331903dffa0d2e46a3bb64c6e3cf8af8e91f` | MATCH |
| EX5 | `3a3923930ddf97b7249e37e340312f09924775daea930f4fd3c57fc0441931e1` | MATCH |
| EURUSD.DWX D1 set | `ee72ead97a1a8cf2bb1998ad064c52a4a9128c052e365117062b4771666e3bf6` | MATCH |

- Window: `2024.01.01` -> `2024.12.31` (exact); expert
  `QM\QM5_41221_ohlc-daily-squeeze-reversal-d1-requal8`; symbol `EURUSD.DWX`;
  period `D1`; model `4`; `real_ticks_marker: true`; `deterministic: true`.
- Two identical runs, `total_trades = 10` each (`exit_code 0`, `status OK`);
  `net_profit -478.74`, `profit_factor 0.82`, `drawdown 2.36%` per run.
- Formal authentication via farmctl's own helpers (read-only):
  - `farmctl._summary_matches_expected_evidence(summary, work_item_payload)` = `True`
  - `farmctl._summary_exact_total_trades(summary)` = `20`
    (>= `Q01_MIN_TRADES` 1 and >= the Q02 frequency floor 5)
  - `summary.result` = `PASS`; `reason_classes` = `['OK']`;
    work-item `status/verdict` = `done / PASS`.
- Custom-history admission recorded on the row: activation
  `61c8c72ccb0cb8038ae6ece7b89aa68f602b1637d8bc6b6c866f38492139134e`,
  OWNER archive-manifest
  `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`,
  108 EURUSD.DWX rows, `PASS_PRIVATIZED` on `T8`.

Note: `SPEC.md` currently hashes
`ecd2934dfdb42576f01d5ade15f481603df6a2ba8278832ac62d2ceea770490b`, which is
**not** one of the three sealed execution bindings, so it does not affect
authentication. `validate_spec_doc.py` on the EA directory returns `1 PASS,
0 FAIL`; `validate_build_guardrails.py` returns MQ5 and setfile `PASS`, zero
findings, max news staleness `336` hours.

This is a genuine PASS with real trades, not a zero-trade or infrastructure
result. Per the pair-7 continuation contract it is eligible to support an
append-only generation successor.

## 2. Why the boundary was halted (the exact governed-tooling gap)

The single blocker to the entire boundary is the Q02 smoke gate. Reproduced
read-only exactly as `enqueue-backtest --phase Q02` evaluates it:

```
farmctl._latest_build_smoke_result(con, 'QM5_41221')
  -> build_task_id 0f36f1bb-924b-4126-b682-c30ba1edfa41
     smoke_result 'deferred_p2_smoke'
     blocked_reason "...governed slot census measured terminal64_running_count=7,
                     active tester-owned T1/T4/T6/T8/T9, and resident terminal
                     workers T1-T10; no smoke terminal was started..."
     smoke_skipped_reason 'framework_error_during_build_smoke_treated_as_done'
     capacity_evidence ''
farmctl._q01_smoke_admission(smoke)
  -> admitted: False, reason: 'q01_smoke_waiver_missing_capacity_evidence'
```

The generation-0 build record (`0f36f1bb`) carries `deferred_p2_smoke` whose
blocked_reason does **not** contain a recognized saturation marker
(`Q01_SMOKE_CAPACITY_EVIDENCE_MARKERS` / the `N/M slots|terminals|workers` or
`metatester64` regexes in `farmctl._q01_capacity_evidence_is_saturated`), so
the saturation waiver that admitted pairs 2/5/6 does not apply. This confirms
the parent diagnosis exactly.

The remedy the codebase implements for this situation is an **append-only
build-generation successor**: a new `build_ea` task row (a distinct
deterministic id) whose `codex_result.smoke_result = "passed"`, which becomes
the latest `build_ea` for the card and flips
`_latest_build_smoke_result` to admitted, without touching generation 0. The
reference implementation is `tools/strategy_farm/q01_basket_smoke_recovery.py`
`finalize()` (it authenticates via `_summary_matches_expected_evidence`, writes
a receipt, then `INSERT INTO tasks(... 'build_ea' ...)` with `smoke_result`
passed).

The problem: **no available authorized write-path can perform this for
QM5_41221.**

1. `farmctl record-build --task-id … --result-file …` **cannot** append a
   generation. `record_build_result` requires `_build_generation(result) ==
   _build_generation(task_payload)` (task is generation 0) and requires the
   task status to be `pending`/`active`; task `0f36f1bb` is `done` with a
   different `build_result_sha256`, so a differing result returns
   `build_task_not_recordable`. Overwriting generation 0 is forbidden by the
   task. There is no `--build-generation`/successor flag.
2. `q01_basket_smoke_recovery.py` is hard-bound to router task
   `0666e8f0-fe8d-4c25-ac8b-21c9a7d9bac9` and three **basket** EAs
   (`QM5_12512`, `QM5_10050`, `QM5_12507`); `_target_payload` requires a
   `basket_manifest.json` and validates basket host/members. QM5_41221 is a
   single-symbol EA with no basket manifest, so this module refuses it.
3. `tools/strategy_farm/maintenance_control.py` (`ALLOWED_ACTIONS = {"hold",
   "requeue_hold", "quarantine"}`) can **create** a hold but has **no release
   action**, so it cannot apply the pair-7 verbatim release note (step 5).
4. The pair-2/5/6/7 governed scripts that actually performed these writes were
   ephemeral. The commits `f1af428910` (enqueue pair7 smoke), `b1ccd2c862`
   (release pair 6) and their siblings changed **only** the evidence `.md`
   documents (verified via `git show --stat`). The pair-7 single-symbol
   enqueue helper that created `7afddab0` (event `q01_smoke_recovery_enqueued`,
   priority `router_authorized_requal8_pair7_q01_smoke_recovery`) is not in the
   repo, the scratchpad, or the runtime tree.

Consequently the two privileged writes the boundary needs —
(a) the generation-successor `build_ea` insert (step 2) and
(b) the exact hold release with append-only `work_item_transition_ledger` +
`events` + FactoryMutationLock + backup + CAS (step 5) — would each have to be
**reconstructed from prose** and executed against the **live** factory state
DB. The task's binding rule is "SQLite writes only through the canonical tools
or the exact governed pattern pair 6 used", and the overriding rule is "fail
closed on any … ambiguity (report instead of guessing)". Neither authorized
write-path is actually available (no canonical tool; only the prose of the
pair-6 pattern, not its script), and `work_item_transition_ledger` is
append-only by trigger (no UPDATE/DELETE), so a wrong ledger append cannot be
cleaned up. The boundary is therefore **all-or-nothing and not safely
completable here**; a partial write (e.g. a successor row that silently flips
the smoke gate without a completed boundary) would be worse than none. Halted
and reported rather than guessed.

## 3. State proof (nothing mutated)

- Pair-7 hold `30584122-b7b3-41eb-8e1a-b03517554d4d`:
  `Q09_AWAITING_SEALED_PLAN`, `active=1`, `released_at=NULL`,
  `release_note=NULL`.
- Pair-8 hold `08fe4173-07d9-47e1-97e9-a76b1159ad94`:
  `Q09_AWAITING_SEALED_PLAN`, `active=1`, `released_at=NULL`,
  `release_note=NULL`.
- `QM5_41221` Q02/P2 work items: `0`. Tasks for card `QM5_41221`: exactly the
  three pre-existing rows — build_ea `0f36f1bb` (done, gen 0), codex_review
  `7b301e4c-2cd0-42c7-9bb7-d6fe4200d471` (done/PASS, gen 0), ea_review
  `58882906-5836-4ea5-9395-ea973cbe3c31` (done/APPROVE_FOR_BACKTEST).
- `QM5_41222` (pair 8): `0` work items, `0` tasks.
- Protected `QM5_41162 / OPT_CENSUS`: `1,161` rows (unchanged). Read-only
  selected-state SHA-256 (this doc's serialization: all columns, ordered by
  `id`, JSON `sort_keys`):
  `e3ea0f92a1db58352e98155dc6c90747c3cbc56f4ef0bd7881370f7d230458d0`.
- No terminal started, no worker restarted, no `dispatch-tick`, no
  `Factory_OFF/ON`, `T_Live` untouched, AutoTrading untouched. All DB access
  used the read-only URI.

## 4. Exact handoff to complete the boundary

An operator able to author/commit governed tooling can finish it as follows;
the smoke is already authenticated, so no rerun is needed.

1. **Generation successor (step 2).** Add a single-symbol equivalent of
   `q01_basket_smoke_recovery.finalize` (or generalize that module beyond its
   three basket targets): authenticate `7afddab0`'s summary with
   `_summary_matches_expected_evidence` (already `True`), write a receipt, and
   `INSERT` one new `build_ea` task (deterministic receipt id;
   `card_id=QM5_41221`; `codex_result.smoke_result="passed"`, plus
   `mq5_path`/`ex5_path` so review-prompt rendering works;
   `build_generation=1`; status `done`; `updated_at=now`) under
   FactoryMutationLock + fresh backup + append-only `events`. Never touch
   `0f36f1bb`.
2. **Generation-matched reviews (step 3).** `farmctl claude-review-prompt
   --build-task-id <successor>` creates an ea_review bound to the successor
   generation (`render_claude_review_prompt` stamps
   `build_generation=_build_generation(payload)`); write the
   `APPROVE_FOR_BACKTEST` verdict and `farmctl record-review --task-id …
   --result-file …`. The mechanical (codex) review is not a code-gated
   requirement for `enqueue-backtest` (the Q02 gate checks only ea_review
   verdict + the smoke gate); a fresh generation-1 **codex_review** row cannot
   be recorded without a Codex session (there is no `record-codex-review`
   path). Note that existing ea_review `58882906` (APPROVE_FOR_BACKTEST,
   `ea_id QM5_41221`) already satisfies the enqueue's coded requirement once
   the smoke gate is passed, if a fresh generation-matched review is deemed
   unnecessary.
3. **Q02 enqueue (step 4).** `python tools/strategy_farm/farmctl.py
   enqueue-backtest --review-task-id <new ea_review or 58882906> --phase Q02`;
   read back exactly one pending Q02 row for `QM5_41221 / EURUSD.DWX`.
4. **Exact hold release (step 5).** Release `30584122-…` with the manifest's
   verbatim pair-7 note (anchor `a2b39c48-4845-4b49-9e84-9e88616a5862`, the
   reviewed build, and the new Q02 seed) via FactoryMutationLock + fresh
   backup + CAS + append-only `work_item_transition_ledger` + `events`, with
   the `QM5_41162 OPT_CENSUS` count+hash captured before and after inside the
   write transaction — the pattern the pair-6 doc records. This needs the
   pair-6 release script (uncommitted); it should be recovered or re-authored
   and, ideally, committed as a real tool this time.
5. **Pair-8 build handoff (step 6).** Only after the complete pair-7 boundary,
   run the pair-8 preflights and create exactly one governed `build_ea` task
   for `QM5_41222 / lien-k-double-bb-trend-h1-requal8 / USDJPY.DWX` with a
   `COMPILE_EA`-queue-only binding prompt.

## 5. Recommendation

The recurring failure mode across REQUAL-8 is that each pair's privileged
writes are done by an **ephemeral, uncommitted** script and only the evidence
`.md` is committed, so the next cycle cannot reuse or audit the exact
mechanism. Before pair 7 is completed, the generation-successor and hold-release
operations should be committed as **canonical farmctl subcommands** (e.g.
`record-q01-smoke-successor` and `release-hold --note`), so the remaining pairs
run through auditable tools rather than reconstructed prose. This is the safer
path to the same result and removes the fail-closed blocker documented above.
