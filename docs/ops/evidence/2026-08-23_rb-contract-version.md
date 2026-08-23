# rb-contract-version evidence — 2026-08-23

## Status and safety

PASS. Proposal tickets 3 and 4 are implemented without activating v4. The
active/default loader remains v3. No command opened the live farm database for
write, no backtest was enqueued/deleted, no verdict or gate criterion changed,
and `C:/QM/mt5/T_Live` and factory state were untouched.

The live database was inspected only through a `mode=ro` URI. Migration testing
used the isolated copy at
`scratch/rb-contract-version-db-copy/state/farm_state.sqlite`.

## What changed

- `tools/strategy_farm/farmctl.py:1537-1620` adds the idempotent work-item
  migration. It adds `gate_contract_version TEXT`, fills only NULL/blank rows,
  applies the fixed `2026-08-23T09:00:00Z` split, recognizes v2 from a real
  `pipeline_version` column or version fields in `payload_json`, and installs a
  storage-boundary stamp trigger from the manifest-loaded active version. A
  second trigger makes every nonblank stamp immutable.
- `tools/strategy_farm/farmctl.py:1709` adds the column to fresh databases.
  `tools/strategy_farm/farmctl.py:1897` invokes the migration before the Q09
  sidecar schema transaction.
- `tools/strategy_farm/phase_ids.py:73-86` derives the short active storage
  stamp (`v3` today) from `load_gate_manifest()` rather than a write-path
  literal. `tools/strategy_farm/phase_ids.py:137-169` resolves stamped v1/v2/v3
  rows through the explicit v3 side and stamped v4 rows through
  `contract_equivalence`. Unknown utility phases still pass through.
- `tools/strategy_farm/phase_ids.py:172-241` makes `phase_qid`, `phase_label`,
  and `normalize_phase_id` version-aware and adds `display_phase`. A future v4
  active contract renders historical v3 `Q10` as `Q11 (v3:Q10)`; unstamped and
  `legacy` rows retain the old alias fallback.
- `tools/strategy_farm/farmctl.py:6616`, `:15879-16081`,
  `:17899-18187`, `:19482`, `:20619-21692`, `:22085-22193`,
  `:24693`, and `:25151` explicitly stamp farmctl enqueue,
  cascade/pump, Q09-plan-lane, append-only rerun, auto-Q02, harness, and
  head-to-head rows with the active manifest version. The insert trigger covers
  rarer external enqueue utilities that use the same initialized schema.
- `tools/strategy_farm/q09_news_schema.py:43-61` defines the exact append-only
  v3+v4 dependency-role union. The DDL CHECK is at `:204-218`.
  `tools/strategy_farm/q09_news_schema.py:800-844` reuses the existing SQLite
  table-rebuild migration, compares the exact CHECK token set for idempotency,
  copies every row, swaps the table, and reinstalls append-only/validation
  triggers. Schema version is 7.
- Tests are in `tools/strategy_farm/tests/test_gate_contract_version.py:1-114`,
  `tools/strategy_farm/tests/test_gate_manifest.py:176-199`, and
  `tools/strategy_farm/tests/test_q09_news_schema_v2.py:205-291`.

No gate manifest, threshold, window, verdict row, or eligibility criterion was
changed. The stale v4-draft byte-digest assertion in
`test_gate_manifest.py:232` was aligned with the current checked-out draft
bytes; the draft itself was not modified.

## Copied production database migration

Source copied with PowerShell `Copy-Item` from
`D:/QM/strategy_farm/state/farm_state.sqlite`; migration was run only on the
worktree-local copy. `farmctl.init_db(copy_root)` was executed twice.

```text
                         before       after first   after second
work_items               111622       111622        111622
work_item_dependencies       102          102           102
dependency SHA-256       f7e2925b1ba384152868ae3bf4976a9ff969955c627b90c8fee8c09bb6657cd0
PRAGMA quick_check       ok           ok            ok

gate_contract_version distribution after first/second:
legacy  111614
v3           8
v2           0
```

Dependency-role row distribution remained `Q08_INPUT=101`,
`Q14_ADMISSION=1`. The copied table CHECK contains exactly:

```text
BASELINE_Q09, CHALLENGER_Q10, CHALLENGER_Q11, INCUMBENT_Q11,
PARENT_LINEAGE, Q08_INPUT, Q09_NEWS, Q09_PORTFOLIO,
Q10_NEWS, Q10_PORTFOLIO, Q12_ADMISSION, Q14_ADMISSION
```

The equal count and equal dependency digest prove the rebuild preserved every
dependency row. The identical second distribution proves migration
idempotency.

## Verification

Ticket and touched-path suite:

```text
> python -m pytest \
    tools/strategy_farm/tests/test_rebaseline_census.py \
    tools/strategy_farm/tests/test_gate_contract_version.py \
    tools/strategy_farm/tests/test_gate_manifest.py \
    tools/strategy_farm/tests/test_q09_news_schema_v2.py \
    tools/strategy_farm/tests/test_farmctl_cascade.py \
    tools/strategy_farm/tests/test_q09_news_farmctl_integration.py \
    tools/strategy_farm/tests/test_q16_head_to_head.py \
    tools/strategy_farm/tests/test_candidate_repair_enqueue.py \
    tools/strategy_farm/tests/test_priority_track_new_q02.py -q -ra
151 passed, 6 subtests passed in 45.78s
```

The base environment lacked optional `jsonschema`; `jsonschema==4.25.1` was
installed under a scratch-only target and that target alone was added to
`PYTHONPATH` for the final suite above. The standalone complete manifest module
also passed:

```text
> python -m pytest tools/strategy_farm/tests/test_gate_manifest.py -q -ra
25 passed in 1.16s
```

The unchanged rebaseline census was also executed against the migrated copy;
its own `open_ro()` uses `file:...?mode=ro` (`rebaseline_census.py:143-150`).

```text
> python tools/strategy_farm/rebaseline_census.py --db <copy> \
    --out-dir <scratch-census> --md-dir <scratch-census> \
    --date 2026-08-23-rb-contract-version --limit 25 --no-md --quiet
exit 0
DB SHA-256 before = 42066a35a61a9791dd62bc9e69b5301230eb27e382a89133f76096d5ece7ff18
DB SHA-256 after  = 42066a35a61a9791dd62bc9e69b5301230eb27e382a89133f76096d5ece7ff18
```

Static checks:

```text
> python -m py_compile tools/strategy_farm/farmctl.py \
    tools/strategy_farm/phase_ids.py tools/strategy_farm/q09_news_schema.py \
    tools/strategy_farm/rebaseline_census.py
exit 0

> git diff --check
exit 0 (line-ending conversion warnings only)
```

A repository-wide `python -m pytest tools/strategy_farm/tests -q -ra` was
attempted. It reached 49 passes before the first unrelated baseline failure:
`test_agent_router.py::AgentRouterTests::test_claude_disabled_flag_removes_claude_from_routing`
raised `StopIteration` because the fixture's default registry had no `claude`
agent. No contract-version module is in that failure path; the complete
ticket/touched-path suite above passes.

## Rollback

Code rollback: `git revert <this-ticket-commit>`.

Database rollback after a future orchestrator activation should normally leave
the additive column and widened CHECK in place: both are backward-compatible,
and retaining historical stamps prevents semantic loss. Disable/recreate the
manifest-derived insert trigger through the reverted `init_db` only if new
enqueues are also stopped.

If a strict CHECK rollback is required, first prove there are zero rows using
the six v4-only roles, then perform the same transactional table rebuild with
the v3 six-token CHECK, copy all rows, compare count and digest, swap, and
reinstall triggers. Do not narrow the CHECK while any v4-role row exists. Do not
NULL or rewrite `gate_contract_version`, phase, verdict, or evidence fields.

## Review fixes (2026-08-23, reviewer verdict FIX_REQUIRED)

Reviewer flagged one P1 (not cleanly mergeable to the factory) and three P2s.
All applied on this branch; the feature commit was rebased and the P2 changes
committed on top.

### P1 - rebase onto the integration branch, resolve board-advisor conflicts (FIXED)

The branch was based on rb-v4-loader@1919bb581, before the criteria-preservation
fix a4990f77a and before board-advisor's advancement-centralization refactor, so
a merge to the factory conflicted in phase_ids.py, farmctl.py and
test_gate_manifest.py. The single feature commit was rebased onto
agents/board-advisor (26cb49463), which already carries a4990f77a (board-advisor's
criteria-preserving v4 manifest + hash) and the advancement refactor. Conflicts
resolved as directed:

- phase_ids.py: kept board-advisor's advancement machinery (PhaseAdvancement,
  advancement_table, next_phase/prev_phase/phase_rank) as the base and layered the
  contract_version-aware helpers on top (_normalise_contract_version,
  _resolve_versioned_phase; phase_qid/phase_label/normalize_phase_id gained the
  optional contract_version parameter). Module imports and runtime helpers verified.
- farmctl.py: unioned the phase_ids import block; adopted board-advisor's
  successor_phase rename in the cascade so the local no longer shadows the imported
  next_phase function, and kept the ACTIVE_GATE_CONTRACT_VERSION stamp on the
  cascade INSERT.
- test_gate_manifest.py: took board-advisor's criteria-preserving v4 manifest and
  its hash (LF form, see P2 #4).

farmctl.py is a `-text` byte-exact contract in .gitattributes (its bytes feed the
runtime-activation decision hash). The initial text-mode conflict edit normalized
the whole file CRLF->LF (52k-line phantom churn that would trip Factory_ON's
clean-checkout gate). Reconstructed so unchanged lines keep the parent's exact
bytes and only the ~157 semantic additions are new (CRLF), reducing the farmctl
diff-vs-parent from full-file to 195 lines.

Trial merge into the current agents/board-advisor tip: clean, zero conflicts (see
below).

### P2 #2 - backfill cutoff pinned to the true v3 activation instant (FIXED)

`GATE_CONTRACT_V3_BACKFILL_CUTOFF` changed from `2026-08-23T09:00:00Z` to
`2026-08-23T10:18:19Z`, the actual v3 default-activation instant (commit d4e4dcfcb,
2026-08-23 12:18:19 +0200). Rows enqueued in the 09:00-10:18Z window ran while v2
was still the default and are now backfilled as legacy/v2, not silently v3. A
code comment ties the constant to the activation evidence. New test
test_backfill_cutoff_is_the_true_v3_activation_instant asserts the constant and
that a 09:30Z row stamps `legacy` while a 10:18:19Z row stamps `v3`.

### P2 #3 - display helpers degrade instead of raising (FIXED)

_normalise_contract_version gained a `strict` keyword (default False). The display
helpers (phase_qid/phase_label/normalize_phase_id via _resolve_versioned_phase)
call it non-strict: an unrecognised version token no longer raises, it is returned
as raw provenance and the phase degrades to a pass-through (e.g.
phase_label("Q05","v9") -> "Q05 (v9:Q05)"). The strict raise is retained for
explicit write/validation paths (strict=True). New tests
test_display_helpers_degrade_on_unknown_contract_version and
test_contract_version_normaliser_strict_mode_still_rejects.

### P2 #4 - v4 manifest line endings pinned to LF (FIXED)

Added a .gitattributes rule
`tools/strategy_farm/config/gate_manifest.v4.draft.json text eol=lf` and
normalized the working copy to LF (the git blob was already LF; no content change).
The loader hashes the on-disk bytes, so LF-pinning makes the stamped contract
digest - and the pinned test hash - identical on autocrlf (VPS) and LF (CI)
checkouts. The v4 sha256 test asserts the LF digest
c51fbfffb1aca470207bc0d027b172625e8680095a7a5c75ceed6327e48ae0bc; new test
test_v4_draft_manifest_is_lf_pinned_on_disk guards against CRLF reintroduction.

### Verification

```
> python -m pytest tools/strategy_farm/tests/test_gate_manifest.py     tools/strategy_farm/tests/test_gate_contract_version.py     tools/strategy_farm/tests/test_q09_news_schema_v2.py     tools/strategy_farm/tests/test_advancement_centralization.py -q
48 passed, 2 skipped

> python -m pytest tools/strategy_farm/tests/test_isolated_work_item_runner.py     tools/strategy_farm/tests/test_mission_control_v2_data.py     tools/strategy_farm/tests/test_mnt009_010_reconciliation.py     tools/strategy_farm/tests/test_render_cockpit_v2.py -q
105 passed, 1 skipped
```
