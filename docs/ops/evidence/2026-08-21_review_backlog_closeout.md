# Review-EA backlog close-out — 2026-08-21

**Actor:** Claude (mechanical execution of an already-adjudicated judgment).
**Scope:** 50 `review_ea` tasks stuck in state `REVIEW`, closed to their adjudicated
terminal states; the 50 source `build_ea` tasks settled to match.

## Cause

50 `review_ea` tasks sat in `REVIEW` and head-blocked ~55 `build_ea` tasks, leaving the
agent lane idle for ~3 days. All 50 reviewed builds come from the agy ("gemini") lane and
were reviewed by Codex; every one carries a negative verdict. No AI seat had closed the
reviews, so no downstream `build_ea` work could route.

## Adjudication basis

The judgment was made before this execution and is not re-litigated here. Two independent
triage passes (batch 1 = indices 0–24, ea_ids 34008–37004; batch 2 = indices 25–49) read
each Codex review artifact strictly, cross-checked the most-cited conventions against repo
source (broker-time GMT+2/+3, `build_check.ps1` build_hash + raw-series rules,
`QM_Common.mqh:298` generic DD default 3.0/0.0, `QM_StopRules.mqh` pip double-conversion,
`QM_Common.mqh:457-465` execution-contract INIT_FAILED, `RISK_FIXED` convention). Findings:

- **No wrong reviews.** Every spot-checked convention verified at file:line.
- **Review bar consistent.** Same defect taxonomy applied uniformly; where a finding is
  absent it tracks a genuine build/card difference, not a shifting bar (e.g. strict-build
  raw-series FAIL vs. cleared `QM_IsNewBar()`-gated warning; loss-limit finding only where
  the card carries the 2/2.5/5% DD contract).
- **Split:** 44 RECYCLE (generator/template-level defects — fixable at rebuild) and 6
  BLOCKED (card-level defects — a naive rebuild of the same card reproduces the failure;
  card must be amended/redefined or the class is charter-ineligible before any rebuild).

Systemic cause across the cohort: the agy build lane mechanizes a *nearby* idea rather than
the approved card — substituted indicator formulas, collapsed 50% TP1+runner lifecycle into
a single full-position broker TP, open-position guard making in-trade management unreachable,
GMT windows evaluated in broker time, ×10 pip double-conversion, declared-D1-on-sub-D1
INIT_FAILED, and dropped contract elements (card loss limits, committed build identity).

## Execution

Each `review_ea` task closed with:
`agent_router.py close-review <id> --state <RECYCLE|BLOCKED> --verdict "CLAUDE CLOSE
2026-08-21: <rec> -- <reason> [tags: <tags>]" --artifact-path <review artifact>`.

Each source `build_ea` task (`payload.source_task_id`), **only if still in `REVIEW`**, moved
to the same state with `update-task ... --verdict "CLAUDE CLOSE 2026-08-21: follows review
<rev8> -- <reason>"`. Source tasks already terminal were left untouched.

**Result: all 50 review closes succeeded, zero failures.** 47 source `build_ea` tasks were
settled; 3 were already `BLOCKED` and left alone (38007 src `2dd67414`, 39007 src `8b09ed22`,
41011 src `fdaac67c`).

## 50-row outcome

| review_task | ea_id | state applied | source build settled |
|-------------|-------|---------------|----------------------|
| 72b63c06 | 34008 | RECYCLE | y |
| 9a869adc | 35001 | RECYCLE | y |
| bc910727 | 35002 | BLOCKED | y |
| c7f41f38 | 35004 | RECYCLE | y |
| cf62861c | 34006 | BLOCKED | y |
| 3281881e | 35005 | RECYCLE | y |
| ae389d95 | 35003 | RECYCLE | y |
| b8886e40 | 35006 | BLOCKED | y |
| df6959b3 | 35008 | RECYCLE | y |
| 7a9aa79c | 35007 | BLOCKED | y |
| b4c223a0 | 36003 | RECYCLE | y |
| 80b2cb2a | 36004 | RECYCLE | y |
| d47d0803 | 36001 | RECYCLE | y |
| b7868b8c | 36002 | RECYCLE | y |
| ddb87b6b | 36005 | RECYCLE | y |
| e349534a | 36007 | RECYCLE | y |
| 599e1cb1 | 36006 | RECYCLE | y |
| 22e95cd4 | 37001 | RECYCLE | y |
| c57623a2 | 36008 | RECYCLE | y |
| e8869500 | 37002 | RECYCLE | y |
| 06b9a3cb | 37006 | RECYCLE | y |
| 1f4ea58d | 37007 | RECYCLE | y |
| 8406a8c0 | 37003 | RECYCLE | y |
| 8d44760b | 37005 | RECYCLE | y |
| c344bb4a | 37004 | RECYCLE | y |
| 0a687cb4 | 38002 | RECYCLE | y |
| 4c9d202f | 38003 | RECYCLE | y |
| ce1b2ad8 | 38001 | RECYCLE | y |
| fe559a03 | 37008 | RECYCLE | y |
| 67e670f0 | 38006 | RECYCLE | y |
| 91b5a55b | 38004 | RECYCLE | y |
| b004519e | 38007 | BLOCKED | n — source already BLOCKED |
| d840a938 | 38005 | RECYCLE | y |
| 6076e5b8 | 38008 | RECYCLE | y |
| 70395b6d | 39002 | RECYCLE | y |
| 5e1b4b08 | 39001 | RECYCLE | y |
| ec8363cd | 39003 | RECYCLE | y |
| 6b47ceec | 39004 | RECYCLE | y |
| 28396e6d | 40008 | RECYCLE | y |
| 8893bf1e | 39006 | RECYCLE | y |
| 96b77b6a | 40005 | RECYCLE | y |
| a2055dc7 | 39005 | RECYCLE | y |
| c0a06995 | 39007 | RECYCLE | n — source already BLOCKED |
| 64fb0c90 | 41005 | RECYCLE | y |
| 7c616d3f | 41003 | RECYCLE | y |
| fc3ed902 | 41001 | RECYCLE | y |
| 0249f85f | 41006 | RECYCLE | y |
| 1bd8fddf | 41009 | RECYCLE | y |
| 86e63523 | 41011 | RECYCLE | n — source already BLOCKED |
| ba6be389 | 41010 | BLOCKED | y |

**Totals:** 44 RECYCLE + 6 BLOCKED review closes; 47 source builds settled (42 → RECYCLE,
5 → BLOCKED), 3 left alone.

## Failures

None. All 50 `close-review` calls and all 47 `update-task` source settlements returned rc=0.

## Post-state (read-only DB verification, `farm_state.sqlite`)

- `review_ea` in `REVIEW`: **0** (target met).
- `build_ea` in `REVIEW`: **10** (down from 57) — 8 `gemini`, 2 `codex:agents/board-advisor`;
  these are builds whose reviews were not part of this 50-task cohort.
- Repo-wide terminal counts after close-out: `RECYCLE` = 556, `BLOCKED` = 124 (this batch
  contributed 86 RECYCLE and 11 BLOCKED transitions across the 97 tasks it moved).
- Router `status`: agent lane no longer head-blocked — `build_ea` in `APPROVED`: 18 `gemini`,
  37 `claude`, 4 `codex:agents/board-advisor`, 1 `codex` — routable work is queued.

## Provenance

Adjudication tables: `review_triage_batch1.md`, `review_triage_batch2.md`.
Task index (full ids, source ids, artifact paths): `review_backlog_review_ea.json`.
Per-review evidence artifacts: `docs/ops/evidence/<rev8>_qm5_<ea>_*_review_2026-08-1{7,8}.md`.
