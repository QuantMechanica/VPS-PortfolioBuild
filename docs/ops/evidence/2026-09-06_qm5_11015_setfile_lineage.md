# QM5_11015 EURUSD setfile-lineage diagnosis and governed repair handoff

Date: 2026-09-06  
Router task: `7d6eb2eb-4a30-49e5-ab03-152090b3469b`  
EA / pair: `QM5_11015_the5ers-weekly-ny` / `EURUSD.DWX` / `H1`  
Disposition: **ROOT CAUSE CONFIRMED; REPAIR + Q02 GUARD IN ISOLATED REVIEW BRANCH; NO FACTORY RERUN PERFORMED**

## Executive finding

The strategy is not parameterless. `SPEC.md:21-31` and the compiled EA source at
`QM5_11015_the5ers-weekly-ny.mq5:32-42` define the same 11 `strategy_*`
defaults. The canonical baseline setfile contains none of them and ends at
`card_defaults_source=not_found` (`...EURUSD.DWX_H1_backtest.set:34`). Its
materialized SHA-256 is
`72e9a371f80053fd0e98b1b0b33e01ab8fb02dd013dc7b53cab1d78fa32dc63b`.

The loss occurred in commit
`dcd299f5f1ff808962ec7c89ece5ffc2ac1ca663` at 2026-06-18 05:21:20Z. The pump
rewrote all five QM5_11015 backtest presets with the then-current
`framework/scripts/gen_setfile.ps1` output. That generator searched only
`strategy-seeds/cards`; no QM5_11015 card existed in that commit. Its
`Find-CardPath` therefore returned null, lines 294-311 appended only
`card_defaults_source=not_found`, and lines 313-314 overwrote the existing
file. It neither preserved the 11 assignments already present nor fell back to
the EA input defaults. The EURUSD diff deletes exactly those 11 assignments.

This is a **setfile-generation defect**, not a strategy-mechanics defect. Q02
through Q07 could still execute because MT5 used the compiled EA defaults, but
the Q08.5 neighborhood contract requires explicit perturbable `strategy_*`
assignments. Q08 correctly rejected the lineage rather than inventing them.

## Exact loss generation

The EURUSD setfile history has three material generations before this repair:

| Commit / time (UTC) | Repository-byte SHA-256 | Materialized state | Strategy assignments | Meaning |
|---|---|---|---:|---|
| `3636213ee3d9` / 2026-06-18 05:05:36 | `f62eadfca269db3605716e1e37ea0d1daf5d4ff24a75b979f852b23f25df2633` | pre-defect | 11 | Correct explicit defaults were present, even though the source marker already said `not_found`. |
| `dcd299f5f1ff` / 2026-06-18 05:21:20 | `2da6acaa0d854fc95e230d927072fb9742f78cfb58d63b4ae4415a5e89f5db61` | generated with `build_hash=pending` | 0 | Pump/setgen overwrite deletes all 11 assignments. |
| `8b10d0bdf03f` / 2026-06-18 09:15:31 | `a9cce7b0b59f3f542d0a23fbc15bee63fd1f12654435c06e309bbc263e3e5b7f` | build-hash stamp; Windows file SHA `72e9a371...dc63b` | 0 | Only the header hash changed; the defect remained. |

Historical file:line evidence at `dcd299f5f1ff`:

- `framework/scripts/gen_setfile.ps1:23` bound the sole card root to
  `strategy-seeds/cards`.
- `framework/scripts/gen_setfile.ps1:37-44` derived only
  `<slug>_card.md` under that root.
- `framework/scripts/gen_setfile.ps1:294-311` emitted defaults only when that
  lookup succeeded; the null branch emitted only `card_defaults_source=not_found`.
- `framework/scripts/gen_setfile.ps1:313-314` replaced the complete target.
- Commit `dcd299f5f1ff` changed five setfiles by `5 insertions, 60 deletions`,
  exactly one marker inserted and 12 lines removed per file (the old source
  marker plus 11 strategy assignments).

The writer attribution is supported by the commit's `build: pump auto-commit`
message and by the rewritten bytes matching that generator's header, filter
block, `build_hash=pending`, and null-card branch. No retained June worker log
was needed to infer a different writer.

The generator was subsequently hardened, but the legacy preset was never
regenerated:

- `3fd4fef65dea` (2026-07-02) added multi-root card lookup.
- `395eb5fc8479` (2026-07-19) added EA-input fallback.
- Current `gen_setfile.ps1:276-312` parses EA inputs, line 601 loads them, and
  lines 703-707 emit `card_defaults_source=ea_input_defaults` plus the strategy
  defaults when a card is absent.

## Strategy contract that should have been carried

The SPEC table (`SPEC.md:21-31`) and MQ5 declarations
(`QM5_11015_the5ers-weekly-ny.mq5:32-42`) agree exactly:

| Parameter | Default |
|---|---:|
| `strategy_ny_start_hour` | `16` |
| `strategy_ny_end_hour` | `22` |
| `strategy_sma_period` | `20` |
| `strategy_atr_period` | `14` |
| `strategy_session_move_atr` | `0.5` |
| `strategy_breakout_buf_atr` | `0.0` |
| `strategy_sl_atr_mult` | `1.5` |
| `strategy_sl_atr_floor` | `1.0` |
| `strategy_tp_rr` | `2.0` |
| `strategy_time_stop_bars` | `36` |
| `strategy_friday_exit_hour` | `18` |

## Q02-Q08 database lineage

All rows below name the same canonical baseline path:

`C:\QM\repo\framework\EAs\QM5_11015_the5ers-weekly-ny\sets\QM5_11015_the5ers-weekly-ny_EURUSD.DWX_H1_backtest.set`

`work_items.setfile_sha256` is shown exactly as stored. `NULL` is not filled by
inference. Later phases stamp the derived stress/seed artifact rather than the
baseline; the baseline binding is called out separately.

| Phase | Work item | Verdict | Row setfile SHA-256 | Baseline / lineage evidence |
|---|---|---|---|---|
| Q02 | `4e7c0dc3-6fcf-47c5-9c54-cd811728ca13` | PASS | `72e9a371...dc63b` | Payload `expected_setfile_sha256` is the same empty baseline hash. |
| Q03 | `83cd5d6c-7919-429a-bd1a-9cc31f1c959d` | PASS | `72e9a371...dc63b` | Same exact baseline binding. |
| Q04 | `c55fedcd-89dc-4d22-862c-7379aeec8309` | PASS | `NULL` | Same mutable canonical path; payload expected hash is also null. |
| Q05 | `b4393c78-e289-4876-8c86-5fccc5af10b2` | PASS | `NULL` | Same mutable canonical path; promoted from Q04. |
| Q06 | `63728ba1-d7cb-4593-a47a-5237ec32c29c` | PASS | `cbc6d465...ff8df` | Q06 aggregate `set_sha256` confirms the generated harsh-stress artifact; it was derived from the empty baseline. |
| Q07 | `e7b7067b-f247-41d4-b3ab-d911f323b649` | INFRA_FAIL | `39a6b90c...3a65f` | Seed artifact; aggregate reason `seeds_invalid_evidence` (`aggregate.json:138`). |
| Q07 | `6f2875e0-2c4e-4488-a982-fd68f6dc4326` | INFRA_FAIL | `39a6b90c...3a65f` | Append-only rerun of `e7b7067b`; payload still binds baseline `72e9a371...dc63b`; aggregate again says `seeds_invalid_evidence` (`aggregate.json:153`). |
| Q07 | `0060d528-098d-48be-a05a-f6ee9f597bf0` | PASS | `39a6b90c...3a65f` | Last valid PASS and direct Q08 predecessor. |
| Q08 | `60f98a58-5f06-4862-8908-16a8efe8332e` | INVALID | `NULL` | Aggregate lines 355-356 bind baseline path + `72e9a371...dc63b`; subgate 8.5 at line 177 reports `baseline_setfile_defect:empty_strategy_params`. |

The inspected current Q05/Q06/seed derivatives also contain zero
`strategy_*` assignments, which is consistent with derivation from the same
empty baseline. Their hashes can change when phase tooling regenerates them;
the append-only DB/evidence hashes above are the authoritative run identities.

The bound source and binary stayed constant across the authenticated chain:

- MQ5 SHA-256: `6ea891d158711cbbafea1bf4d9960e72caee83aff1df16068a91a0f02723d75d`
- EX5 SHA-256: `f6ded69ea84b99aa587a913fc5653d8a7fe80583275994fdc9f0cbe9b3b7ffaf`

## Isolated repair and guard

Review branch: `agents/codex-11015-setfile-lineage-20260906`

- `1a163d492acb7accc13a9053942acda8d64f2598` restores the 11 explicit EURUSD
  baseline assignments, adds a fail-closed Q02 intake contract, and adds tests.
- `1311d0f4d25d1766fb04807a045a20d84c3aaad7` stamps the repaired preset's
  build provenance.
- Repaired Windows-materialized setfile SHA-256:
  `aa66394560638c37c1a94e6799f250505d67e6f93166101d348862c7f0f8b981`.
- `farmctl.py:26009-26062` parses the executable set contract and refuses
  missing assignments as stable reason `empty_strategy_params` (also refuses
  duplicate/invalid and empty-value shapes).
- `_first_q02_setfile_plan` invokes the contract at
  `farmctl.py:32246-32255` before any canary can be selected or inserted.
- The existing first-Q02 fixture now carries an explicit strategy parameter;
  `test_first_q02_intake.py:256-264,315` proves the historical empty shape is
  refused without a Q02 insert.
- `test_qm5_11015_setfile_lineage.py:29-47` proves all 11 repaired assignments
  are nonempty and match the EA input defaults.

Focused verification from the isolated branch:

```text
python -m pytest tools/strategy_farm/tests/test_first_q02_intake.py tools/strategy_farm/tests/test_qm5_11015_setfile_lineage.py -q
.....................                                                    [100%]
21 passed in 6.09s
```

Direct contract probe:

```text
canonical_before_review -> empty_strategy_params; count=0
isolated_repair         -> strategy_params_present; count=11
```

No source logic or EX5 bytes were changed. Explicit values equal the compiled
defaults, so the repair makes the already-executed defaults reproducible; it
does not change strategy mechanics.

## Governed repair / append-only command

`canonical_setfile_paths.py` is not the repair here: the DB already names the
one canonical path, and that utility repairs path identity, not missing file
content. The governed sequence is therefore:

1. Claude+OWNER review and integrate the two isolated-branch commits above.
   This Codex cycle does not cherry-pick, merge, or advance main.
2. Re-run the two focused tests and verify that the canonical EURUSD preset has
   exactly 11 nonempty `strategy_*` assignments. Recompute the canonical
   materialized set SHA after integration; do not assume a hash across a
   line-ending/materialization change.
3. Confirm current EX5 remains
   `f6ded69ea84b99aa587a913fc5653d8a7fe80583275994fdc9f0cbe9b3b7ffaf`
   and that no pending/active Q08 successor already cites `60f98a58...`.
4. An authorized operator may then run exactly one append-only Q08 successor
   from the last valid Q07 PASS:

```powershell
python C:/QM/repo/tools/strategy_farm/farmctl.py --root D:/QM/strategy_farm enqueue-backtest `
  --ea QM5_11015 `
  --phase Q08 `
  --from-work-item-id 0060d528-098d-48be-a05a-f6ee9f597bf0 `
  --append-only-rerun-of 60f98a58-5f06-4862-8908-16a8efe8332e `
  --rerun-reason "Task 7d6eb2eb: restore the 11 explicit strategy defaults in the canonical EURUSD baseline; preserve Q08 INVALID 60f98a58 and append from last Q07 PASS 0060d528; no strategy mechanics change." `
  --expected-current-ex5-sha256 f6ded69ea84b99aa587a913fc5653d8a7fe80583275994fdc9f0cbe9b3b7ffaf
```

Do not enqueue Q02-Q07 again: the last valid PASS is Q07
`0060d528-098d-48be-a05a-f6ee9f597bf0`, the explicit repaired values equal
the compiled defaults used by that run, and the requested recovery is the
fresh Q08 child that can now construct reproducible neighborhoods. Preserve
all prior verdicts and evidence.

## Dry-run verification of the exact command

`enqueue-backtest` has no `--dry-run` switch. To verify the full mutation path
without touching production, this cycle:

1. made an online SQLite backup of the canonical farm DB into a temporary root;
2. changed only the copied QM5_11015 EURUSD setfile paths to the isolated
   worktree equivalent;
3. ran the exact command above against that copied root with the documented
   `QM_ALLOW_NONCANONICAL=1` worktree-test override; and
4. removed the temporary database after verification.

Result:

```json
{
  "enqueued": true,
  "phase": "Q08",
  "previous_phase": "Q07",
  "created": [{
    "id": "747d89f4-ce2a-4a07-9d80-ba3c64032ab1",
    "symbol": "EURUSD.DWX",
    "rerun_of_work_item_id": "60f98a58-5f06-4862-8908-16a8efe8332e"
  }],
  "skipped": []
}
```

The copied pending row sealed:

- `promoted_from_work_item=0060d528-098d-48be-a05a-f6ee9f597bf0`
- `append_only_rerun_of_work_item=60f98a58-5f06-4862-8908-16a8efe8332e`
- `expected_ex5_sha256=f6ded69e...b7ffaf`
- `expected_setfile_sha256=aa663945...f8b981`

The copied worktree MQ5 was CRLF-materialized (`5ebf3575...fad76`), whereas
the current canonical MQ5 is LF-materialized (`6ea891d1...3d75d`). The
production command calculates and seals the canonical current MQ5/setfile
hashes at execution; the only operator-supplied artifact hash is the verified
EX5 hash above.

A read-only query of the canonical database returned zero Q08 rows citing
`append_only_rerun_of_work_item=60f98a58...` both before and after this test.
No `enqueue-backtest`, pipeline runner, dispatch tick, tester, or terminal was
run against the canonical farm.

## Review decision

Recommend **ACCEPT FOR OWNER/CLOSEOUT INTEGRATION**, then execute the single
append-only Q08 command only after the four preconditions above pass. Keep the
router artifact in REVIEW until that integration decision; this document and
the isolated branch do not authorize a factory rerun or live use.
