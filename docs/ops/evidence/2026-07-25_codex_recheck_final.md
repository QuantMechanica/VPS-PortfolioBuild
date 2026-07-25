# Codex final re-check — WP-9/10/11 and WP-2/6

Date: 2026-07-25  
Branch: `agents/board-advisor`  
Reviewed HEAD: `3b562b004125`

This review was limited to the blockers in:

- `docs/ops/evidence/2026-07-25_codex_review_wp91011.md`; and
- `docs/ops/evidence/2026-07-25_codex_rereview_wp26.md`.

It was read-only except for this report. I did not apply to the live database, commit, run a
backtest, launch a terminal, or access `C:\QM\mt5\T_Live`. I did not inspect or modify the live
`framework/scripts/q07_multiseed.py`; WP-10 was reviewed only at the supplied scratch-copy path.

## Verdict lines

**WP-9 — STILL-BLOCKED — QM5_20123 still performs two per-member preflight rejection draws before the new memoized basket draw, so a two-member entry rejects at 27.1% rather than the intended single-draw 10%; the original blocker required this duplicate hook to be removed or suppressed.**

**WP-10 — STILL-BLOCKED — the copy still has fresh-run paths that require neither the Q07/HARSH seed label nor a present effective seed, and its report regex is a document-wide bold-tag search rather than an Inputs-cell/table-scoped parse.**

**WP-11 — STILL-BLOCKED — `--out-dir <live BASELINE_DIR>` still writes MT5 Common without `--deploy-live` or its warning, so `--deploy-live` is not the only Common-write route.**

**WP-2 — STILL-BLOCKED — an absent surviving setfile hash still creates a normal terminal row, including one ordinary Q10 PASS in the current dry-run, with only `setfile_sha256_verified:false`; no consumer enforces that flag, and the guarded revert still does not restore the pre-apply schema or guard the metric/ledger rows it deletes.**

**WP-6 — STILL-BLOCKED — a destination whose count already equals authoritative Q08 evidence bypasses SHA verification and can be graded despite foreign bytes; the requeue classifier also ignores `content_sha256`, and the v1 count-only fallback remains mutable path-plus-count rather than immutable lineage.**

## Blocker-by-blocker findings

### WP-9

The new source pattern itself is sound for the sampled caller contract:

- `QM_BasketOrder.mqh:211-230` skips the entire block at `p=0.0`.
- Static state starts at `ea_id=0`; the helper rejects non-positive EA IDs before this block, so the
  first real call cannot collide with the zero-initialized memo.
- The redraw comparison is exactly `(s_memo_ea_id != ea_id || s_memo_time != TimeCurrent())`.
- The sampled callers `10009`, `10025`, `20123`, `12821`, `12778`, `13117`, `13140`, and `10309`
  issue all legs of a logical package synchronously within one `OnTick`. I found no sampled/known
  caller that deliberately carries one basket transaction across ticks.

The static regression test is too coarse to pin that contract. It checks one
`QM_RandBoolTagged` occurrence, a static declaration, `TimeCurrent`, `ea_id`, and absence of
`symbol_slot`; it does not assert the exact two-field key comparison, non-colliding first-call
state, reuse on later legs, or the complete `p=0.0` bypass.

The decisive blocker remains in
`QM5_20123_dailyopen-h1-basket.mq5:549-575`: two planned members each take a preflight draw and the
helper then takes one shared draw. Acceptance is `0.9^3 = 72.9%`, hence rejection is `27.1%`.
`QM_BasketOrder.mqh:204-210` documents and defers the defect; documenting corrected arithmetic does
not remove the duplicate stress rail demanded by my verdict.

### WP-10

Reviewed copy:

`C:/Users/ADMINI~1/AppData/Local/Temp/1/claude/C--QM-repo/811a9693-344c-4685-bcc0-688af45d6a73/scratchpad/q07_multiseed_wp10fix.py`

Recovery is improved: both `_recover_existing_seed_results` and
`_result_from_existing_seed_summary` require a label and effective seed equal to the slot.
However, three original gaps survive:

1. `_effective_seed_from_report` uses
   `r"<b>\s*qm_rng_seed\s*=\s*(\d+)\s*</b>"` over the entire HTML document. That matches the real
   UTF-16 MT5 cell (`<td ...><b>qm_rng_seed=42</b></td>`), but it also authenticates the same bold
   fragment in a comment, caption, or unrelated table. The tests reject plain comment/plain text,
   not a bold fragment outside the Inputs table.
2. `_seed_from_summary_path` recursively finds a `tester.ini` below the summary parent while
   `_effective_seed_from_summary_path` independently recursively finds a `report.htm`. The two
   values can therefore come from different sibling artifacts rather than the report/tester pair
   bound to the accepted summary run.
3. Fresh `_run_seed` validates only `effective_seed is not None and effective_seed != seed`.
   `effective_seed=None` leaves `invalid_reason=None`, and the fresh path never checks the
   Q07/HARSH seeded-setfile label. A completed run with otherwise valid metrics can therefore enter
   its requested slot with neither required authentication axis.

A report mismatch is a hard `INVALID`, an explicit summary-invalid reason remains invalid, and a
timeout with no summary/report gets `timeout_expired`. Those guards do not close the missing-auth
case. A nonzero runner result is also made invalid by `evaluate_seeds` only when trades are below
the minimum, so sufficient unauthenticated metrics are not made safe merely by a launch-fault exit
code.

### WP-11

The function-level and automated defaults are fixed:

- `write_baseline(..., out_dir=None)` selects `STAGING_DIR`;
- `_resolve_out_dir` defaults to staging; and
- `trigger_baseline_capture` explicitly supplies the staging directory.

The claimed exclusive promotion gate is not enforced. `_resolve_out_dir` returns any explicit
`args.out_dir` before checking `args.deploy_live`, and the CLI only rejects using the two flags
together. Consequently:

```text
gen_q10_baseline.py ... --out-dir <exact live BASELINE_DIR>
```

writes Common with neither `--deploy-live` nor the loud warning. A direct function caller can pass
the same directory as well. The code must normalize/compare explicit destinations and refuse the
live directory unless the deploy flag is present.

### WP-2

The advertised mechanical fixes are present:

- a surviving basename-covering `execution_identity.setfile.source.sha256` is compared with the
  current setfile bytes, and a mismatch refuses;
- a missing `tester.ini` Symbol refuses;
- `_load_json` catches the non-UTF evidence case; and
- the Q04 path now completes fail-closed rather than crashing.

My fresh read-only dry-runs produced:

- Q10: 23 planned inserts, 22 hash-verified and 1 unverified
  (`QM5_12567/XNGUSD`, terminal `PASS`);
- Q04: 0 actions and 1 explicit `setfile_unresolved` refusal
  (`QM5_11297/GBPUSD`), with no `UnicodeDecodeError`.

The `verified:false` policy does not meet my original authentication blocker. The unverified Q10
PASS is built as an ordinary `status=done`, `verdict=PASS` work item. Repository-wide Python search
found no downstream consumer that gates use on `setfile_sha256_verified`. The flag therefore
records the missing proof but does not prevent the unproved result from entering the same
portfolio/pipeline paths as a proved PASS. Destruction of proof by a sibling is a reason to refuse
or obtain fresh sealed evidence (or an explicit OWNER exception), not evidence that the run may be
authenticated.

The prior rollback blocker also remains. The snapshot explicitly says the ledger table and
`ea_metrics` columns are intentionally not reverted. Revert fingerprints only the inserted
`work_items` row, then deletes its `ea_metrics` and ledger rows without independently checking
whether either was modified. No separately approved persistent-schema migration/rollback decision
was supplied in this re-check.

### WP-6

The four requested adversarial checks resolve as follows:

| Prior adversarial case | Re-check |
|---|---|
| 40 loaded rows vs 296 authoritative, floor 20 | **Closed.** Count inequality triggers repair regardless of the floor, and unreconciled inequality returns `NEED_MORE_DATA`. |
| Same-count source with wrong recorded SHA | **Closed only inside the repair branch.** Candidate and temporary destination are re-hashed when `content_sha256` exists. **Still bypassed** when the already-loaded destination count equals authoritative, because `needs_repair` is then false and no destination hash is checked before admission. |
| Equal-count foreign Common content in the Q08 writer | **Closed.** Per-row identity mismatch selects authoritative serialization and records `source=serialized_foreign_content_guard`. |
| Malformed/non-finite/non-positive volume | **Closed for the tested path.** The validator requires a finite positive float and the load wrapper returns `NEED_MORE_DATA` instead of leaking `TypeError`/`ValueError`/`KeyError`. |

`run_all` has the correct producer order: it persists/serializes first and immediately calls
`_bind_portfolio_stream_identity` on the returned path, so the hash describes the bytes actually
written.

The remaining consumer/requeue defects are blocking:

- An already present same-count destination is graded without comparing its bytes to the
  aggregate's `content_sha256`.
- With no hash, `lineage_basis=count_only` still accepts a mutable recorded path solely by row
  count. Making that fallback visible is honest telemetry, but it does not satisfy the original
  immutable-lineage requirement.
- `requeue_q09_stranded_sleeves._classify` checks authoritative count,
  `portfolio_stream.n`, and durable row count, but never consumes `content_sha256`. Same-count
  tampering is therefore classified `provenance_validated`, including during the new
  transaction-local reclassification.

The other requeue safety gaps are closed: `--apply` without `--snapshot-out` exits 2 before DB
access, apply re-reads and reclassifies the full row under `BEGIN IMMEDIATE`, and revert restores
the captured original `updated_at`.

## Commit go/no-go and exact grouping

**NO-GO.** All five reviewed packages still have at least one original blocker, so I do not endorse
cutting the fix commits yet.

After those blockers close, the endorsed logical commit boundaries are:

1. **WP-9 alone** — basket header, the QM5_20123 duplicate-preflight removal/suppression, and its
   static regression test.
2. **WP-10 alone, only after the running Q07 batch has stopped** — apply the corrected scratch
   implementation to the repo `q07_multiseed.py` and commit it with
   `test_q05_q07_verdicts.py`. Do not include scratch paths or batch-mutated generated setfiles.
3. **WP-11 alone** — `gen_q10_baseline.py`, `q10_confirmation.py`, and
   `test_q10_confirmation.py`.
4. **WP-2 alone** — `ingest_phase_aggregates.py` and
   `test_ingest_phase_aggregates.py`.
5. **WP-5/WP-6/WP-7 together as one atomic shared-file commit in this dirty tree.** At minimum,
   WP-6 and WP-7 are indivisible: their producer/persistence/identity and dispatch hunks are
   interleaved in `q08_davey/aggregate.py` and `farmctl.py`. The same `aggregate.py` also contains
   the existing WP-5 launch-retry adoption, so a path-level commit that avoids fragile partial-hunk
   surgery must carry the established WP-5/WP-7 files plus the WP-6 contribution/requeue files and
   all corresponding WP-5/WP-6/WP-7 tests. Do not create separate WP-6 and WP-7 commits.

The final review documents may be committed as a separate evidence-only commit; they should not be
used to mix otherwise independent implementation packages.

## Anything not verified

- I did not compile MQL5, run any unit suite in this final pass, run a backtest, or exercise an MT5
  runtime. WP-9 is source/caller analysis, not compiler/runtime proof.
- I inspected eight representative basket callers, not all 173 helper callers.
- I deliberately did not inspect, execute, replace, or diff the live repo
  `framework/scripts/q07_multiseed.py`. I reviewed only the supplied copy and its tests; I did not
  independently execute the builder's three claimed copy-vs-live tests.
- I matched the WP-10 regex against a real archived UTF-16 report shape, but did not produce a new
  tester report.
- I performed only read-only Q10/Q04 ingester dry-runs. I did not apply or revert against the live
  DB or a new backup in this final pass.
- I did not execute a real Q08 re-export/requeue. The WP-6 conclusions come from source/control-flow
  review of the four adversarial paths and their regression tests.
- WP-7 was inspected only where necessary to verify WP-6's writer-to-hash ordering; this is not a
  full independent WP-7 verdict.
