# Working-tree forensics — path to a clean tree for Factory_ON minting

Branch `agents/board-advisor`, repo `C:/QM/repo`. Read-only forensics; **no git mutations performed.**
Snapshot `git status --porcelain=v1`: **402 modified (` M`), 138 untracked (`??`)**.
Untracked count is misleading: git collapses new directories. `git status -uall` expands
to **820 untracked files** (753 `.set`, 53 `.ex5`, 7 `.md`, 5 `.json`, 1 `.py`, 1 `.mq5`).

Of the 402 modified: **393 are `.set` files** + 9 non-set
(`agent_router.py`, `tests/test_agent_router.py`, `artifacts/evidence_cohort_baseline.json`, 6 `.mq5`).

---

## 1) The 393 modified `.set` files — origin + safety verdict

### Origin (measured)
- Header stamp `set_version: s20260822-001` is written by **`framework/scripts/gen_setfile.ps1:488`**
  (`"; set_version:  s$($today.Replace('-','') )-001"`). So the sweep = **gen_setfile regeneration**.
- **Not one sweep**: set mtimes span **07:09 → 17:12 local in per-EA batches** (e.g. 88 files @15:00 = QM5_1567,
  46 @15:05 = QM5_11132, 44 @15:06 = QM5_11165). This is the fingerprint of many tasks each regenerating one
  EA's sets, not a single unscoped `build_check`-without-`-EALabel` event.
- Concurrent drivers seen in today's logs/DB touching exactly these EAs: DXZ requal packets
  (`dxz_10939_repair_packet.py`, `dxz_10706_requal_packet_validate.py`; codex log
  `codex_orchestration_slot1_20260822T130001Z.live.log`) → 10939, 10706, 11165; and the 41xxx
  compile handoffs (`docs/ops/evidence/2026-08-22_qm5_4109x_*compile*.md`) → 41095-41104.

### No recompile happened
`.ex5` **are tracked** (3470 in repo) and **NONE are modified**. The `.ex5` of every re-stamped EA is
byte-identical to HEAD. Verified for the demonstrator QM5_12969: ex5 sha256
`938a35aa6b6dff54ec0e94a4a253a71730e63f9347b91877da786ec395715f06` == the Q09 include-closure's
`ex5_sha256` in `D:/QM/reports/pipeline/_q09_include_closures/QM5_12969_include_closure.json`.
The re-stamped header `build_hash` (12969: `94802d93…` → `3757a5bf…`) matches **neither** the old nor the
ex5 hash → `build_hash` is a source/include digest, **restamped without a rebuild**. Cosmetic; orthogonal to
Q09 (the ex5 still matches its closure).

### Diff classification (393 files) — NOT header-only
Per-file, counting only non-comment changed lines (comm on sorted key-name sets, reorder-proof):

| Class | Files | EAs | What changed | Behaviour |
|---|---:|---|---|---|
| **HEADER-ONLY** | 326 | 24 | only `set_version`/`build_hash`/`date` comment lines | neutral |
| **KEY_LOSS** | 7 | 41095,41096,41098,41099,41100,41101,41102 (all `_backtest.set`) | dropped framework keys `qm_news_*`,`qm_rng_seed`,`qm_friday_close_*`,`qm_stress_reject_probability` | **neutral — every removed value equalled the mq5-declared default; MT5 uses the same default when a key is absent** |
| **SCHEMA_SWAP** | 36 | 10919,10939,11132,11165,11421,11708,12989,1556 | removed stale `qm_filter_*` (news/regime/volatility), added `strategy_*` params | **correction — HEAD sets referenced inputs the EA does not declare and were MISSING the real strategy params; new sets match the current `.mq5` (e.g. 10919.mq5 declares 18 `strategy_*`, 0 `qm_filter_*`)** |
| **VALUE_ONLY** | 12 | 13301 | `strategy_range_start_hour 0→3`, `range_end 7:30→6:00` | **correction — new values match the EA's own `SPEC.md` (start 3 / end 6)** |
| **OTHER** | 12 | 13213 (added `strategy_*`), 1567 (added `qm_ea_id`; CRLF/EOL churn) | schema add + line-ending normalisation | neutral / correction |

### Stress-integrity check (the load-bearing safety test) — PASS
The generator drops framework keys **only when they sit at default** and **preserves non-default values**.
Verified on the Q06 stress/seed sets:
- `QM5_10919 …_XTIUSD.DWX_H4_q06_stress_harsh_seed42.set` — header-only diff; still carries
  `qm_rng_seed=42`, `qm_stress_reject_probability=0.1000`.
- `QM5_10280 …_XAUUSD.DWX_D1_q06_stress_harsh_seed17.set` — header-only; still `qm_rng_seed=17`,
  `qm_stress_reject_probability=0.1000`.
- Sweep of **every** modified `*stress*`/`*seed*` set: **0** removed a non-default `qm_rng_seed`
  or `qm_stress_reject_probability`. No stress cell was degraded.

### Verdict: **COMMIT** (restore is unsafe)
This is **not** the 2026-08-13 `build_check`-without-`-EALabel` accident (that was an unscoped 9072-file
degradation). Today's sweep is scoped to 30 EAs under active requal/build/compile work and every content
change is a **correction toward the current `.mq5`/`SPEC`**. `restore` would re-introduce the broken
`qm_filter_*`-only sets (SCHEMA_SWAP) and revert 13301 off its SPEC — a regression. `.ex5` unchanged, stress
integrity intact → committing is behaviour-safe.

**Caveat for the orchestrator:** use `git commit -- <pathspec>` (or `git add -u`), **never `git add <dir>`** —
the same `sets/` dirs also hold *untracked* new sets (group 5) that must NOT be swept into this commit.

---

## 2) The 9 non-set modified files

| File(s) | mtime | Owning lane / task | Action | Rationale |
|---|---|---|---|---|
| `tools/strategy_farm/agent_router.py` + `tests/test_agent_router.py` | 22:14 / 22:15 local | **ACTIVE codex session** — `codex_orchestration_slot1_20260822T183001Z.live.log` (mtime 22:27, still writing) contains live diffs to both; IN_PROGRESS tasks `6a131ec6` (updated 19:38Z, payload names agent_router) & `6e512650` (20:12Z) | **stash** (`git stash push -u -- …`, pop after ON) | In-flight foreign edit. Do NOT commit (unreviewed) or restore (destroys live work). NB: stash only in a paused instant — coordinate, the session is writing this file *now*; ideally let it finish and land via REVIEW. |
| `artifacts/evidence_cohort_baseline.json` | 06:54 | automated cohort-integrity monitor; diff = one appended record `checked_at_utc 2026-08-22T02:20:04Z watched/intact 1205` | **commit** | Append-only monitoring heartbeat, behaviour-neutral evidence-trail entry. |
| `QM5_12930…h4.mq5` (+ untracked `.ex5`,`sets/`) | 06:54 | `review_ea` **APPROVED** (claude, 08-21) & build_ea APPROVED | **commit** | Governed, approved build deliverable. |
| `QM5_36007…momentum.mq5` (+ untracked `.ex5`,`sets/`) | 06:54 | `build_ea` **PASSED** (gemini, 08:45Z) | **commit** | Governed, passed build deliverable. |
| `QM5_12929…h1.mq5` | 06:54 | `build_ea` **TODO** (codex) — never claimed | **stash** | Pre-work source edit on an unstarted task; no approval, no binary. |
| `QM5_1401…h4.mq5`, `QM5_1402…h4.mq5` (+ untracked `SPEC.md`,`sets/`,`.ex5` & evidence docs `12829c50_…`,`4fc08ad9_…`) | 11:5x | `build_ea` **BLOCKED** (gemini, 09:53Z) | **stash** | Build outputs of blocked tasks; preserve for when unblocked, do not bake in. |
| `QM5_36005…harvester.mq5` (+ untracked `.ex5`,`sets/`) | 06:54 | `review_ea` **RECYCLE** (codex, 08-21) | **stash** | Rebuild attempt, not yet re-reviewed/approved. |

---

## 3) The 820 untracked files

86 distinct EA dirs. Governing `build_ea` state decides the action.

- **commit — governed, approved/passed build bundles** (`.ex5` + `sets/` + `build_identity.json`):
  EAs **12930, 36007, 1539, 1583, 1606, 1612, 1613, 1623, 9696** (build_ea APPROVED/PASSED). These are the
  deliverables the pending REVIEW rows will read; landing them is correct.
- **commit — evidence trail** (pure docs, append-only, harm-free):
  `docs/ops/evidence/2026-08-21_verify_website_archive_contract.md`,
  `docs/ops/evidence/12829c50_qm5_1401_…build_ea_2026-08-22.md`,
  `docs/ops/evidence/4fc08ad9_qm5_1402_…build_ea_2026-08-22.md`.
- **stash — ungoverned / in-progress build outputs** (the bulk: ~78 EAs, ~740 `.set` + ~45 `.ex5`):
  every untracked `framework/EAs/**` whose governing `build_ea` is **TODO / FAILED / BLOCKED / NO_TASK**
  (sampled: 9113/9908/9972/11291/11496/12931/12932 = TODO; 30005 = FAILED; 10367 = no task). These are
  compiled binaries + sets produced outside a completed governed build (mq5 tracked, ex5 never tracked) — the
  ungoverned-build hazard. **Must not** enter the runtime-activation baseline unreviewed; **must not** be
  deleted. `git stash push -u` preserves them; they land later via their normal REVIEW→APPROVED artifact flow.
- **stash — new-EA source bundles, no completed task**: `QM5_41119_…/` (whole dir: mq5, SPEC, basket_manifest,
  docs) + `artifacts/qm5_41119_compile_wave_release_20260822.json`; `QM5_41105_…/SPEC.md`.

---

## Consolidated action plan

| # | Action | Pathspec (use `git commit --` / `git stash push -u --`, never `git add <dir>`) | Count | Why |
|---|---|---|---:|---|
| 1 | **commit** | the 393 modified tracked `.set` under the 30 EA `sets/` dirs (`git commit -- $(git diff --name-only -- '*/sets/*.set')`) | 393 | gen_setfile regeneration; behaviour-safe corrections; restore would regress SCHEMA_SWAP/VALUE_ONLY |
| 2 | **stash** | `tools/strategy_farm/agent_router.py tools/strategy_farm/tests/test_agent_router.py` | 2 | active codex session writing now (`6a131ec6`) |
| 3 | **commit** | `artifacts/evidence_cohort_baseline.json` | 1 | automated monitor append |
| 4 | **commit** | governed build bundles: `framework/EAs/QM5_12930_* framework/EAs/QM5_36007_*` (mod mq5 + untracked ex5/sets) and untracked approved bundles `framework/EAs/QM5_{1539,1583,1606,1612,1613,1623,9696}_*` | ~30 | build_ea APPROVED/PASSED |
| 5 | **commit** | `docs/ops/evidence/2026-08-21_verify_website_archive_contract.md docs/ops/evidence/12829c50_qm5_1401_*.md docs/ops/evidence/4fc08ad9_qm5_1402_*.md` | 3 | evidence trail |
| 6 | **stash** | ungoverned/blocked source+build: `framework/EAs/QM5_12929_* framework/EAs/QM5_1401_* framework/EAs/QM5_1402_* framework/EAs/QM5_36005_*` (mod mq5 + their untracked bundles) | ~20 | TODO/BLOCKED/RECYCLE — not approved |
| 7 | **stash** | all remaining untracked `framework/EAs/**` (ungoverned builds, ~78 EAs) + `framework/EAs/QM5_41119_* framework/EAs/QM5_41105_* artifacts/qm5_41119_compile_wave_release_20260822.json` | ~745 | ungoverned/in-progress; preserve, never delete, never bake into activation baseline |

**Sequencing for the mint:** apply 1,3,4,5 (commits) → 2,6,7 (`git stash push -u`) leaves a clean tree incl.
untracked → mint `build_runtime_activation_decision.py` → commit decision+sidecar → `Factory_ON` → `git stash pop`
(items 2/6/7) after ON. **Do not stash item 2 while the codex session is mid-write** — pause/await it or land
its output through REVIEW first, else its work is truncated.
