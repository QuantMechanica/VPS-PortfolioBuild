# Adversarial review — log-bomb family fix & "age escalation"

Date: 2026-07-27
Reviewer: Claude (board-advisor worktree), adversarial pass
Mandate: verify the two code changes against **source and the live DB**, never the
documents. CONFIRMED/REFUTED per point, ranked by severity.

Sources of truth used (all read-only):
- Source tree at `agents/board-advisor` (this worktree) + `git show` on the fix commits.
- Live DB `D:/QM/strategy_farm/state/farm_state.sqlite` (`?mode=ro`, mtime 2026-07-27 22:49,
  i.e. *after* the fix commits at 22:38–22:40).
- `git log`/`git diff` across all refs for provenance and collision checks.

---

## Verdict summary (severity-ranked)

| # | Claim under review | Verdict |
|---|---|---|
| **F1** | An "age escalation" was added to the claim path so starved rows can win | **REFUTED — the change does not exist in shipped source** (HIGH) |
| F2 | Log-bomb family fix = reclassifier change, 0 in-place EA fixes, exactly the recipe | **CONFIRMED clean** (no defect) |
| F3 | The one genuine EA fix (QM5_11072) is exactly point→pip and nothing else | **CONFIRMED clean** (no defect) |
| F4 | No mass DB/file mutation from either change | **CONFIRMED** — 0 rows mutated (an 11,062-row `--apply` is PENDING, not landed) |

---

## F1 — "AGE ESCALATION" (HIGH): REFUTED. No such change exists.

Point 2 presupposes an age-based escalation in the **claim path** that lets a starved
(old) pending row win, with a "shipped factor", a computable "crossover", and a regression
test asserting it. **None of that is present in the source.** Traced end to end:

- The one and only pending-work selector is `farmctl.pending_claim_order_sql()`
  (`tools/strategy_farm/farmctl.py:779–860`), consumed by the production claimant
  `terminal_worker._priority_pending_query()` (`terminal_worker.py:272–279`) and the
  farmctl secondary claimant. Its `ORDER BY` (`farmctl.py:857–859`) is:
  `_recovery_rank, _priority_track_rank, _phase_rank, _basket_q02_rank, _winner_rank,
  _asset_rank, w.updated_at ASC, w.created_at ASC`. **There is no age term, no age factor,
  no escalation** — `created_at ASC` is a last-resort FIFO tie-break (oldest sorts *later*
  in precedence, i.e. it never lifts a row above any functional rank).
- The claim loop (`terminal_worker.py:1154–1254`) iterates that order and claims the first
  eligible row. It applies resource/history/recovery filters only — **no age arithmetic,
  no per-claim age I/O**.
- Git history confirms absence: the claim ordering was touched by exactly one commit,
  `ac2477ca5` (WS-A recovery-last rank). `git log --all -S "julianday"` and
  `-S "_age_rank"` over `farmctl.py`/`terminal_worker.py` return **nothing**.

The regression test that actually exists asserts the **opposite** of the premise:
`tools/strategy_farm/tests/test_priority_track_new_q02.py:32–56`
(`test_fresh_build_q02_is_priority_and_outranks_aged_fifo`) inserts an aged FIFO row
(`created_at=2026-05-01`) and a fresh build, then asserts the ordered head is
`[QM5_9000 (fresh), QM5_8000 (aged)]` — a **fresh** row outranks the **aged** one. Commit
`f19eb2e76 "prioritize fresh Q02"` shows the shipped policy is deliberately fresh-first,
not age-escalated.

Point-2 sub-questions, answered against source:
1. *Runs per claim on the hot path with new I/O/query cost?* — N/A: no escalation exists;
   the claim hot path adds no age I/O.
2. *Fails open on malformed `created_at`?* — N/A: no `created_at`-age branch exists in the
   claim path.
3. *Can a starved row win — crossover from the shipped factor, regression test asserts it?*
   — **No shipped factor → no crossover.** The only relevant regression test asserts the
   reverse (fresh > aged). A starved row cannot win by age.
4. *Collided with / reverted Codex's reaper?* — No claim-path age change exists, so nothing
   could collide. Codex's reaper commit `850784f97` is present and intact
   (`_detect_active_age_timeout`, `farmctl.py:5035–5137`); the claim ordering and the
   reaper are separate code paths.

**The only "age" code that shipped is the REAPER, and it is NOT this change.**
`_detect_active_age_timeout` (Codex, `850784f97`) is an *active-run kill timeout*: it
measures `age_min` from `updated_at` (elapsed since claim), reaps on stalled progress or an
absolute ceiling (`farmctl.py:5052,5059–5062,5074–5080`), fails open on malformed
`updated_at` (`farmctl.py:5050–5051: if updated is None: continue`) and on unknown progress
inside budget (`test_progress_aware_reaper.py:79–91`). It kills active runs — it does **not**
promote starved pending rows, uses `updated_at` not `created_at`, and the task itself frames
it as the separate "Codex reaper work" the age change must not collide with. It is therefore
not the change point 2 describes.

> Adversarial conclusion: if the "age escalation" was represented anywhere as *delivered*,
> that representation is false — it is absent from the shipped claim path. Nothing to
> approve; nothing regressed.

## F2 — LOG-BOMB FAMILY FIX: CONFIRMED clean (reclassifier only, 0 EA edits).

The "family fix" is **not** a population of EA fixes to sample. It is one reclassifier
change plus zero in-place EA edits — the evidence-correct outcome for a mislabel. Verified:

- **The recipe, exactly.** Commit `8e0e81f47` edits only
  `tools/strategy_farm/classify_summary_missing.py::_has_log_bomb`: it removes the bare
  `attempt_count >= LOG_BOMB_ATTEMPT_FLOOR (99)` trigger and requires a **genuine kill
  marker** — `verdict_reason=='LOG_BOMB'`, `'LOG_BOMB' in reason_classes`, or any
  `log_bomb_journal*` payload key. This is exactly the marker set the genuine-kill path
  stamps (`terminal_worker.py:2595–2633`) and exactly the diagnosis §7-Class-C recipe.
  Nothing beyond the recipe changed; the only other file is its test.
- **Zero EA edits in the family commits.** `git show --stat` on the three family commits
  (`b85bee1ac`, `8e0e81f47`, `61e8df466`) touches **no** `.mq5`/`.mqh` — only the
  reclassifier, its test, and three docs.
- **No stranded-but-real strategy was contaminated.** The two family EAs that *are* modified
  on this branch (QM5_11028, QM5_11224) were changed on **2026-07-25** (`e1ec95ab7`,
  `bc14956e2` — "recover FX Q02 funnel"), two days before the 07-27 log-bomb task —
  unrelated older work, not this change. The diagnosis's spot-check EAs (QM5_10923,
  QM5_10296) are **unchanged** on the branch. The one latent bomb (QM5_10923), which holds
  real verdicts, was correctly **not** edited.
- **Forbidden case did not occur.** No EA holding a real gate verdict was edited (0 EAs
  edited at all). The only genuinely edited EA (11072, see F3) holds no real verdict (DB).
- **Row count correct against the `failure_subclass` table** (live DB, read-only):
  - Q02 `failure_subclass='log_bomb'`: **4,236 rows / 139 distinct EAs** ✓ (claim: 4,236/139)
  - genuine-marker rows within the family: **0 / 4,236** ✓
  - family `verdict` column: `INFRA_FAIL` on all 4,236; `final_failure=
    summary_missing_retries_exhausted` on all 4,236; `verdict_reason=
    summary_missing_retries_exhausted` on 4,233 (+3 stragglers) ✓
  - disjoint genuine population (`verdict_reason='LOG_BOMB'`): **80 rows / 50 EAs** ✓
  - family EAs holding a real verdict at any phase: **122 / 139** ✓
  - "compile 0/0": no `.mq5` was compiled in the family fix (nothing to compile) — correct.

## F3 — QM5_11072 EA FIX: CONFIRMED clean (exactly point→pip).

The single genuine log-bomb EA fix (reference for the family), commit `54efb0c66`:
- Edits only `framework/EAs/QM5_11072_binario-ma-band/QM5_11072_binario-ma-band.mq5`
  (+ its recompiled `.ex5`, 323,200→347,306 bytes). The code change is **two lines**:
  `MathAbs(target_sl - current_sl) > point` → `> pip` and the matching TP line `> point` →
  `> pip`, plus an explanatory comment. Nothing else — exactly the documented
  threshold point→pip recipe, no scope creep.
- Commit records "Compiled 0 errors / 0 warnings on the canonical path"; the committed
  `.ex5` delta is consistent with a real recompile (atomic build+commit).
- **Holds no real verdict** (DB, read-only): Q02 = {pending ×4, INFRA_FAIL/done ×3,
  INFRA_FAIL/failed ×45}; no PASS/FAIL/RETIRE/ZERO_TRADES/NEED_MORE_DATA anywhere. So the
  in-place edit was permitted and corrupts no gate evidence — the commit's stranded-pair
  claim is confirmed.

Note (not a defect): the diagnosis Class-A recipe offered "and/or" a monotonic compare in
addition to point→pip; 11072 applied point→pip only. That satisfies the recipe (the band is
read from closed bars and the one-pip floor already exceeds the sub-pip spread jitter), and
the task's own recipe statement is "threshold point→pip". No contamination.

## F4 — MASS MUTATION: CONFIRMED none landed.

- **DB rows mutated by the log-bomb fix: 0.** The corrective `--apply` re-stamp was blocked
  by the sandbox write-classifier (fixed doc §5); the live DB still shows **4,236**
  `log_bomb` rows (read-only count == 4,236, all phases), i.e. nothing was re-stamped. No
  bulk DB write occurred.
  - PENDING (flag, do not run blind): the sanctioned `--apply` would rewrite ~**11,062**
    payload rows (4,236 re-bucket + ~6,826 SUPERSEDED/IN_FLIGHT drift). It is payload-only,
    guarded (skip-not-clobber), reversible (snapshot), and never requeues — but it is a bulk
    op and needs OWNER approval before running. Not landed → not a finding, but noted.
- **Files changed by the log-bomb fix:** 2 source (`classify_summary_missing.py` + its
  test) + 3 docs; separately 1 EA (`11072` .mq5/.ex5). No bulk file mutation.
- **Age escalation:** 0 rows, 0 files (does not exist).

---

## Evidence appendix

- Claim ordering (no age term): `tools/strategy_farm/farmctl.py:779–860` (`ORDER BY` at
  857–859); consumers `terminal_worker.py:272–279`, claim loop `1154–1254`.
- Fresh-outranks-aged regression test: `tools/strategy_farm/tests/test_priority_track_new_q02.py:32–56`.
- Reaper (the only shipped "age" code, Codex `850784f97`): `farmctl.py:5035–5137`; fail-open
  `5050–5051`; absolute ceiling `5059–5062`; reap gate `5074–5080`; tests
  `tools/strategy_farm/tests/test_progress_aware_reaper.py:48–97`.
- Reclassifier fix: commit `8e0e81f47`, `classify_summary_missing.py::_has_log_bomb`
  (bare-99 floor removed; genuine-marker required). Genuine-kill stamp:
  `terminal_worker.py:2595–2633`.
- Family commits touching no EA source: `b85bee1ac`, `8e0e81f47`, `61e8df466` (`git show
  --stat`).
- Unrelated family-EA edits (not this change): `e1ec95ab7`, `bc14956e2` (2026-07-25).
- 11072 fix: commit `54efb0c66`,
  `framework/EAs/QM5_11072_binario-ma-band/QM5_11072_binario-ma-band.mq5` (point→pip, SL+TP).
- Live DB (read-only, `?mode=ro`): `D:/QM/strategy_farm/state/farm_state.sqlite`
  (mtime 2026-07-27 22:49). Q02 `failure_subclass` histogram: `''` 29,300 ·
  `pair_has_verdict` 26,651 · `never_worked` 8,130 · `pair_open` 4,504 · `log_bomb` 4,236 ·
  `input_missing` 181 · `transient_token` 34. Family: 4,236 rows / 139 EAs, 0 genuine
  markers, 122/139 hold a real verdict. Disjoint genuine: 80 rows / 50 EAs. QM5_11072:
  no real verdict.
