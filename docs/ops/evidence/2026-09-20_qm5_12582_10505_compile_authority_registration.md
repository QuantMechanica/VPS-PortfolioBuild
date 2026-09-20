# QM5_12582 / QM5_10505: compile-authority registration + canary dispatch (Claude, 2026-09-20)

Task `f1ff8fce-78bc-47dd-9ec6-a27bb96bc242`, successor of `0ceeea69-43dd-4b3a-a189-fa893a58a5e7`
(itself successor of `4216dd75-6430-4ccb-b545-6c6cf6f3fd4b`). Structured evidence:
`2026-09-20_qm5_12582_10505_compile_authority_registration.json` (this directory). Predecessor's
finding this cycle depended on: `docs/ops/evidence/2026-09-20_q02_stranded_pairs_instrumented_rebuild/README.md`.

## What this cycle did

1. **Confirmed the predecessor's blocker is real**, not resolved by mere passage of time: a plain
   `enqueue-compile QM5_12582_chan-ng-spring QM5_10505_mql5-macd-sar` (no authority) was attempted
   first and refused for both — `farmctl.py compile-status` alone reports `NOT_ENQUEUED` for both
   (it only reflects existing `COMPILE_EA` rows, not the full `classify_candidate` guard set), but
   the actual classifier refuses on `EX5_ALREADY_PRESENT` / `WORK_ITEMS_EXIST` / `BUILD_TASK_EXISTS`
   for both, plus `BOUND_SETFILE_HASH_EXISTS` and `EA_ID_REGISTRY_IDENTITY_INVALID` for QM5_10505.
2. **Wired the registration the predecessor deliberately deferred**: two new entries in
   `tools/strategy_farm/compile_work_items.py`'s `BACKLOG_SOURCE_REPAIR_REGISTRATIONS`, keyed
   `router_ops_issue:0ceeea69-43dd-4b3a-a189-fa893a58a5e7:QM5_12582` and `:QM5_10505`, each with an
   empty `predecessors` dict (verified against `D:/QM/strategy_farm/state/farm_state.sqlite`:
   neither EA has ever had a `COMPILE_EA`-phase work_items row, so there is nothing to supersede).
   `python -m py_compile` confirmed the edit parses; `classify_candidate()` was called directly
   (read-only, before any state mutation) to dry-check both EAs under the new authority — see the
   JSON evidence for the exact `reasons` before/after.
3. **Diagnosed, did not waive, `EA_ID_REGISTRY_IDENTITY_INVALID` for QM5_10505** (the acceptance
   criterion's explicit requirement): `framework/registry/ea_id_registry.csv` carries two `active`
   rows for `ea_id=10505` (same slug/strategy_id, `owner` Research vs Development, `created_at`
   2026-05-22 vs 2026-06-13) — an apparent ownership-handoff duplicate. This reason is not a member
   of `FORCE_REBUILD_WAIVABLE_REASONS`, so the new registration structurally cannot and does not
   waive it. QM5_10505 remains refused on this reason alone. **No registry edit was made this
   cycle** — deduping an `active` registry row for a live-referenced ea_id needs its own deliberate
   review, not a side effect of an unrelated compile-guard registration. See the JSON's
   `recommended_follow_up`.
4. **Enqueued QM5_12582's compile** under the new authority:
   `enqueue-compile QM5_12582_chan-ng-spring --source-repair-authority
   router_ops_issue:0ceeea69-43dd-4b3a-a189-fa893a58a5e7:QM5_12582` → `COMPILE_EA` work item
   `82d760a8-5c7a-40c7-bdcd-1658b3ee4c3c`, created under the standard `COMPILE_EA_WORKER_ROLLOUT_PENDING`
   activation hold.
5. **Released the wave**: `release_compile_wave.py --work-item-id 82d760a8-... --apply` deactivated
   the hold (first attempt hit the expected `FACTORY_MUTATION.lock` busy transient from concurrent
   factory activity; succeeded on retry ~10s later — a pre-mutation backup was taken automatically,
   receipt `D:\QM\strategy_farm\state\backups\receipts\tool_backup_cap_compile_wave_20260920T083636_428833Z.json`).
6. A resident terminal worker claimed the row (`status: active`) within seconds of release.

## QM5_10505 disposition this cycle

Refused, reason `EA_ID_REGISTRY_IDENTITY_INVALID` only (every other reason correctly waived by the
new authority). No `COMPILE_EA` work item was created for QM5_10505 this cycle — creating one while
the registry identity is ambiguous would bind a compile to an EA whose canonical ownership row is
not settled. **Terminal disposition: BLOCKED, pending a separate registry-hygiene decision** (see
JSON `recommended_follow_up`). Not a compile-authority defect; not requeued blind.

## QM5_12582 canary (append-only Q02, XNGUSD.DWX) — NOT dispatched this cycle, blocked+diagnosed

`COMPILE_EA` reached `COMPILE_OK` (work item `82d760a8-5c7a-40c7-bdcd-1658b3ee4c3c`, ex5 sha256
`33f05561...`, `build_check_result: PASS`) within seconds of releasing the wave. The next step,
one governed append-only Q02 canary, hit two dead ends in sequence, both correct fail-closed
behavior, not bugs to route around blind:

1. `enqueue-backtest --append-only-rerun-of ae468d0f-2d3c-4595-9d49-6b5b00a25f75` refused
   (`q02_append_only_rerun_requires_same_exact_source_and_rerun_row`) because the new compile
   minted a genuinely new `.ex5` identity — append-only-rerun is for an *identical*-binary retry,
   not a new identity.
2. The correct tool for a new-identity Q02 successor, `farmctl.py requalify-q02
   --old-work-item-id ae468d0f-... --expected-current-ex5-sha256 33f05561... --dry-run`, itself
   refused (`eligible: false`, `parameter_change_provenance_not_authenticated`): the current
   on-disk XNGUSD.DWX setfile differs from the one bound to the old row (9 orphaned `qm_filter_*`
   keys removed, `qm_ea_id` added) and that change has no provenance binding the tool recognizes.

Root cause: the setfile change is real and legitimate but **predates this cycle** — commit
`65e1641235` (2026-09-11, `fix(QM5_12582): repair stale Q02 framework wiring`) made it, alongside
a `.mq5` source fix (the source this cycle's compile actually used). That commit's own evidence
file (`docs/ops/evidence/2026-09-11_qm5_12582_stale_framework_rebuild_authority.json`) predates a
`"registrations"` array convention that `farmctl.py`'s parameter-change-provenance check requires
(precedent: `docs/ops/evidence/2026-09-08_qm5_10269_stale_resolver_rebuild_authority.json`), so it
cannot be authenticated after the fact. This cycle's own evidence JSON was missing that array too
at the moment work item `82d760a8` compiled, and `compile_evidence.json` freezes the exact
evidence-file sha256 it saw at compile time — so **a `"registrations"` array added now cannot
retroactively authenticate `82d760a8`'s already-frozen binding**, only a *future* compile made
after this edit. A `"registrations"` array was added to the JSON evidence anyway (forward-fix,
harmless, matches the QM5_10269 precedent shape), and both `compile_work_items.py` registration
entries' `evidence_sha256` were updated to the new file hash. Re-verified with
`python -m py_compile` and a direct `classify_candidate()` dry call: QM5_12582 now correctly shows
`USABLE_CURRENT_COMPILE_VERDICT_EXISTS` (a real `COMPILE_OK` exists, a second compile is correctly
refused); QM5_10505 is unchanged.

**Terminal disposition, QM5_12582: `COMPILE_OK` achieved; Q02 canary BLOCKED, diagnosed, not
forced.** See the JSON's `q02_canary_finding.recommended_next_step` for the two concrete follow-up
options (narrow-scope `requalify-q02` extension vs. a `STALE_INCLUDE_CLOSURE`-style current-lookup
mechanism) — deliberately not decided or implemented this cycle; both touch a live gate's
provenance-authentication logic and warrant their own review rather than a same-pass patch.

## Evidence

- `2026-09-20_qm5_12582_10505_compile_authority_registration.json` (this directory) — structured
  authority registration, waived/not-waived reasons, registry-duplicate diagnosis, target EA detail.
- `docs/ops/evidence/2026-09-20_q02_stranded_pairs_instrumented_rebuild/` — predecessor cycle's
  root-cause detail and instrumentation diff, unchanged, still authoritative.
- Diff: `tools/strategy_farm/compile_work_items.py` (two new `BACKLOG_SOURCE_REPAIR_REGISTRATIONS`
  entries, additive only — no existing entry, guard, or waivable-reasons set changed).
