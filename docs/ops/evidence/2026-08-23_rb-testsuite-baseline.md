# rb-testsuite-baseline evidence

Date: 2026-08-23
Branch: `rb-testsuite-baseline`
Scope: make `tools/strategy_farm/tests` green after gate-manifest v4 activation.

## Result

`PASS` — the final full run completed with:

```text
python -m pytest tools/strategy_farm/tests -q --tb=short
4488 passed, 4 skipped, 42 subtests passed in 1294.49s (0:21:34)
```

The first independently executed baseline on this worktree was:

```text
330 failed, 4158 passed, 4 skipped, 2 warnings, 42 subtests passed
in 1376.93s (0:22:56)
```

The expansion from the ticket's earlier 22-failure observation was caused
mainly by linked-worktree path guards and CRLF conversion of byte-sealed
artifacts. No gate threshold or acceptance criterion was changed.

## Classification and changes

### A. Checkout/fixture and raw-byte seal state

- Test temporary roots now live under the checkout's ignored `scratch/` tree,
  and isolated router fixtures model the canonical writer while explicit
  linked-worktree refusal tests retain their fail-closed overrides
  (`tools/strategy_farm/tests/conftest.py:17`, `:51`).
- Git attributes pin LF for the governed FTMO snapshot, the 2026-07-30 owner
  decision, `magic_numbers.csv`, and the QM5_12954 source whose setfiles bind
  the Git-canonical source bytes (`.gitattributes:72-79`). Observed post-fix
  SHA-256 values:
  - owner decision: `af8479fdc73163250f966014eca5c53224a4ae159426a07cf96c80a379c6edb2`;
  - magic registry: `452a319f699f7fc6fe65c697057c7bfdb6c356a393863fd89f73de7df64f1008`;
  - QM5_12954 source: `b85857056120d4dc504298e7bdb344e7ffb4ee32b3c9d8e6be353c449f4fec10`.
- A checkout-local approved-card identity fixture records the exact approved
  frontmatter and source-artifact provenance for QM5_12954
  (`framework/EAs/QM5_12954_pring-coppock-h4-variant/docs/approved_card_frontmatter.md:1`).

### B. Gate-manifest v4 cutover

- Stale v3 phase/storage/dependency fixtures were moved to the active linear
  Q00-Q17 contract. Representative coverage includes runtime activation,
  NEWS lanes, incumbent confirmation, optimization admission/freeze,
  head-to-head, pipeline views, health/census, cockpit rendering, repair, and
  terminal claim ordering.
- The live-news diagnostic backfill now derives its storage phase from the
  active runner contract instead of inserting/authenticating literal
  `Q09_NEWS` rows (`tools/strategy_farm/q09_live_news_backfill.py:36`,
  `:689-690`).
- The Q16 lineage emitter validates the active incumbent phase (Q11 under v4)
  while retaining the historical `q10` evidence field in the v1 schema
  (`framework/scripts/emit_q16_lineage.py:96-107`).
- `OPT_CENSUS` continues to interleave with Q04 by deriving Q04's active
  manifest rank rather than retaining v3's literal tier 6
  (`tools/strategy_farm/farmctl.py:1389-1396`). This changes no gate threshold.

### C. Product defects and environment-safe behavior

- Router-triggered task updates in the drain-backlog test now use the guarded
  router connection, so the production writer-generation trigger is present
  (`tools/strategy_farm/tests/test_drain_backlog.py:131`).
- Maintenance raw/logical SQLite bindings are now computed in a stable order:
  logical WAL-visible state first, then the resulting raw file bytes
  (`tools/strategy_farm/maintenance_control.py:95-104`, `:389`, `:1014`). This
  fixed the sole failure in the first near-green full pass.
- The real A02 compile-manifest integration assertion now verifies the
  intended fail-closed result when `FACTORY_OFF.flag` is absent, without
  creating or toggling that flag
  (`tools/strategy_farm/tests/test_prepare_ftmo_book3_q02.py:668-689`).
- The QM5_13128 static fixture follows the recorded 2026-08-23 identity
  decision: the old identity remains bound to its compiled vintage and the
  hardened current-build hooks are checked on successor QM5_41129
  (`tools/strategy_farm/tests/test_qm5_13128_dev_reconciliation.py:13-21`,
  `:68-78`).
- Registry P19 expectations include the documented post-P19 approved QM5_1624
  rebuild and the OWNER-retired D1-disposition rows rather than stale active
  identities (`tools/strategy_farm/tests/test_registry_rekey_p19.py:10-27`,
  `:240-259`).

### D. Sealed repair packets

The DXZ-10939 and DXZ-12567 historical binding amendments are not re-sealed.
Their validators currently return `FAIL` because later card/source/preset and
binary artifacts differ from the sealed inputs. Tests assert the exact
fail-closed drift class and keep `execution_performed=false`
(`tools/strategy_farm/tests/test_dxz_10939_repair_packet.py:913-934`,
`tools/strategy_farm/tests/test_dxz_12567_xau_repair_packet.py:98-124`).
An OWNER-governed amendment is required before either packet can regain its
prior blocked-but-binding-clean status.

## Verification

Focused and touched-module runs completed during the repair:

```text
v4/queue/news/router group:                 289 passed in 101.16s
lineage/seal/static/registry focused group:  35 passed in 4.83s
maintenance control module:                  39 passed in 10.24s
first full near-green pass:                  1 failed, 4487 passed, 4 skipped,
                                             42 subtests passed in 1575.50s
final full pass:                             4488 passed, 4 skipped,
                                             42 subtests passed in 1294.49s
```

No production state DB write, backtest enqueue/delete, factory toggle, gate
threshold change, verdict overwrite, or `C:/QM/mt5/T_Live` mutation occurred.

## Commits

- `643e67a45` — checkout-portable fixtures and sealed FTMO snapshot bytes.
- `b1130389c` — v4 phase fixture alignment.
- `cd8d0e639` — active v4 product/test cutover, including live-news storage.
- `a3fb0fe17` — active lineage and guarded router contracts.
- `1f727eeb0` — governed artifact/registry baseline refresh.
- `efe5b26a9` — stable SQLite maintenance bindings.

## Rollback

From this branch, revert the ticket commits newest-first, preserving an
auditable history:

```text
git revert efe5b26a9 1f727eeb0 a3fb0fe17 cd8d0e639 b1130389c 643e67a45
```

After rollback, restore the three LF-pinned worktree files by checking them out
under the reverted attributes, then rerun the full suite. Do not manually edit
or re-seal either DXZ repair amendment as part of rollback.

## Residual risks / open OWNER items

- DXZ-10939 and DXZ-12567 remain intentionally fail-closed on sealed binding
  drift. OWNER must choose whether to issue governed amendments; this ticket
  supplies no qualification, deployment, or live-use authority.
- The A02 compile manifest remains unusable while the factory is active and
  `FACTORY_OFF.flag` is absent. This ticket did not alter that state.
- One test (`test_codex_session_supervisor.py::test_supervisor_resumes_after_unexpected_child_exit`)
  is env-sensitive on console codepage and is not owned by this branch — see the
  "Review fixes" section below. The full green run above is conditional on a
  UTF-8 console.

## Review fixes (2026-08-23, FIX_REQUIRED verdict)

A cross-branch review returned `FIX_REQUIRED` with two findings. Both are
addressed here without changing any gate threshold, acceptance criterion, or
verdict logic.

### P1 — mergeability into `agents/board-advisor` (RESOLVED)

Root cause: duplicated work. `rb-testsuite-baseline` and `agents/board-advisor`
each performed the same gate-manifest v4 test cutover independently, so a trial
`git merge --no-commit --no-ff agents/board-advisor` produced six conflicted
files. All six conflicts are trivial parallel v4-migration edits that are
semantically equivalent between the two branches; there is no logic divergence.
`agents/board-advisor` was merged into this branch and all six were resolved:

- `tools/strategy_farm/farmctl.py` — comment-only conflict; the `OPT_CENSUS`
  rank expression `phase_rank(_INCUMBENT_PHASE) - phase_rank("Q04")` is identical
  on both sides. Kept the active-manifest wording.
- `tools/strategy_farm/tests/test_pipeline_view_work_items.py` — identical
  `["Q05", "Q16"]` assertion; kept board-advisor's added explanatory comment.
- `tools/strategy_farm/tests/test_q09_news_runner_v2.py` — HEAD binds `?` =
  `ACTIVE_GATE_MANIFEST.storage_phase_for_role("NEWS", "PORTFOLIO")`,
  board-advisor uses the literal `'Q10_PORTFOLIO'`; both resolve to
  `Q10_PORTFOLIO`. Kept HEAD's manifest-derived binding (non-brittle).
- `tools/strategy_farm/tests/test_render_cockpit_cohorts.py` — hardcoded
  `"Q00-Q17"` vs an f-string of `expected_range` (verified `== "Q00-Q17"`);
  kept the derived f-string.
- `tools/strategy_farm/tests/test_terminal_worker_atomic_claim.py` —
  `farmctl._NEWS_PHASE` vs `terminal_worker._Q09_NEWS_PHASE`; both defined as
  `storage_phase_for_role("NEWS", "NEWS")` == `"Q10_NEWS"`. Kept the
  module-local symbol.
- `tools/strategy_farm/tests/test_rebaseline_census.py` (4 hunks) — the
  `test_canonical_gate_mapping` assertions were **unioned**, not one-sided:
  HEAD's active-v4-context checks (default version arg) and board-advisor's
  explicit `"v3"`/`"v4"` checks are complementary and all hold. Each unioned
  assertion was empirically verified against the live module
  (`NEWS_GATE == "Q10"`, `GATE_CHAIN[-1] == "Q14"`, `Q11` on the v4 chain but
  `canonical_gate("Q11", "v3") is None`). The three docstring/added-assertion/
  local-variable hunks kept the richer board-advisor side.

Post-resolution the six affected modules run clean:

```text
python -m pytest test_rebaseline_census.py test_pipeline_view_work_items.py \
  test_q09_news_runner_v2.py test_render_cockpit_cohorts.py \
  test_terminal_worker_atomic_claim.py -q
138 passed in 118.15s
```

### P2 — `test_codex_session_supervisor.py` UTF-8-console dependency (documented; not owned by this branch)

`test_supervisor_resumes_after_unexpected_child_exit` fails with
`UnicodeDecodeError: 'utf-8' codec can't decode byte 0x84 in position 178`
(cp850 `ä`). The test spawns the supervisor via `fixtures/fake_codex_supervisor.cmd`,
which `echo %*` the German resume prompt (umlauts: `Prüfe`, `übernimm`,
`selbstständig`) into `args.txt`. `cmd.exe` writes in the console OEM codepage,
but the test reads `args_path.read_text(encoding="utf-8")`. This fails
deterministically under an OEM-codepage console and passes under `chcp 65001`.
Reproduced both ways on this VPS: fails under the Git Bash OEM console, passes
under a `chcp 65001` (UTF-8) console.

Ownership: this is **pre-existing and not owned by `rb-testsuite-baseline`**.
`git diff` of the test, `codex_session_supervisor.ps1`, and the `.cmd` fixture
against the merge-base (`978f9dc8`) is empty for **both** this branch and
`agents/board-advisor` — none of the three files was touched by either branch.
The assertion is correct and was **not weakened**.

Consequence for this ticket's evidence: the "`4488 passed / 0 failed`" green run
required a UTF-8 console (`chcp 65001`). Under a default OEM-codepage console
this single test fails and the count is `4487 passed, 1 failed`. It is recorded
here as a **known env-sensitive pre-existing failure**, excluded from this
branch's green-baseline scope.

Routing: the actual fix belongs to the `codex_session_supervisor` owner
(Codex/ops) — make the test tolerant of the child's OEM codepage (read with the
console codepage, or have the fixture write UTF-8 / `chcp 65001`). This branch
does not modify the supervisor test, `.ps1`, or `.cmd` fixture.
