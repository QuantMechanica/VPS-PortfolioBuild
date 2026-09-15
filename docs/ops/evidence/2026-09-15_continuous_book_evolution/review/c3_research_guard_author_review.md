# Adversarial review — slice `c3_research_guard_author`

**Reviewer:** Claude (adversarial, read-only) · **Date:** 2026-09-15
**Verdict:** ACCEPT
**Patch:** `scratchpad/patches_bc/c3_research_guard_author.patch` (applies cleanly; `git apply --check` exit 0 onto `agents/board-advisor` tip `55fb2bf5fc`, which equals current HEAD)
**Authority:** OWNER master directive 2026-09-15 §34, §36, §37, §70; audit `research_disk_guard.md`, `rule_inventory_code.md`.

Method: read the full patch (1113 lines), the directive §34/§36/§37/§70, the `research_disk_guard.md` audit, and the R1 contract. Applied the patch to the working tree, ran the four test files (56 passed in 3.83s — matches the implementer summary), ran the live guard CLI, checked imports and callers, then reverse-applied and restored the tree to pristine HEAD (verified `git diff` empty for all touched files).

---

## 1. RED boundaries — none crossed

| RED item | Finding |
|---|---|
| Gate threshold / criterion change | NONE. The 20 GB scratch floor and 60 GB factory floor are infrastructure yield-latches, not Q-gate criteria or verdicts. Explicitly documented as "NOT a gate threshold or contract criterion" in `research_env.py`. `RESEARCH_DISK_MIN_FREE_GB` is not consumed by any pipeline gate. |
| Qualification weakening | NONE. Author generalization is directive-mandated (§37) and **tightens** provenance: a new fail-closed `UNAUTHORIZED_AUTHOR` reason is added; all pre-existing fail-closed paths (NOT_FOUND, hash mismatch, MISSING_FIELD, ledger status, non-Kimi-critic invariant) are unchanged. R1 remains fail-closed `INTERNAL_SOURCE_UNRESOLVED`. |
| T_Live / AutoTrading / purchase | NOT TOUCHED. |
| Evidence rewrite | NONE. Docs use dated `SUPERSEDED` markers + append-only `Annex 2026-09-15b`; the `tester_cache_purge.ps1` history comment is preserved ("2026-07-21 raised 80->150, superseded 2026-09-15 back to 60"). No history deleted. |
| Token / credential exposure | NONE. New config JSONs carry no secrets. |
| Farm DB write | NONE. Both `research_guard` and `research_source.verify` are read-only. |

`red_boundary_crossed = false`.

## 2. Directive fidelity — met

- **§34 (evidence-based guard).** Replaced the flat `D: < 80 GB` block (which permanently refused research because the tester purge parks D: at its 60 GB low-water — live guard returned `DISK_LOW:61.2<80` on every call) with: (a) scratch root configurable via `QM_RESEARCH_SCRATCH`, default the actual C: dataset-output location; (b) measured floor `QM_RESEARCH_MIN_FREE_GB` default 20; (c) a D:-only factory-protection floor read from the shared `factory_disk_policy.v1.json` (60), applied **only when scratch is on D:**; (d) CPU/RAM/mutation-lock latches unchanged. Matches audit R1 (primary) + R2 (factory-yield intent). Live guard now returns `allowed:true` (verified via CLI: scratch on C:, `scratch_on_factory_drive=false`). The 20 GB is a documented safety margin (`max(measured need ~0.3 GB ×2, 20)`), **not** an invented arbitrary permanent cap, and is env-overridable.
- **§36 (Kimi authorship / R1).** Preserved: `author=<name>` without a resolvable, hash-verified durable artifact remains INVALID (test `test_verify_author_without_artifact_still_fails` → NOT_FOUND). The author check reads the **durable artifact** `research.json.author`, not the spoofable card frontmatter — correct.
- **§37 (Fable + other authors).** Authorized set `{Kimi, Fable, Claude, Codex, Antigravity}` + `multi-agent:<list>` from `config/research_source.v1.json` (OWNER-tunable, env override `QM_RESEARCH_AUTHORIZED_AUTHORS`); every other provenance requirement kept identical.
- **§70 (both named tests present & meaningful).** "Fable/internal author provenance works" → `test_verify_fable_authored_source_passes`, `test_r1_internal_fable_authored_passes` (seal a real artifact with rewritten author, re-anchor the hash, verify KEEP through prescreen AND farmctl). "Kimi internal source remains fail-closed" → unchanged Kimi worked-example passes; `test_verify_unauthorized_author_fails_closed` + `test_r1_internal_unauthorized_author_fails` prove UNAUTHORIZED_AUTHOR flows through both intake surfaces; hash-mismatch/NOT_FOUND tests still pass. Meaningful, not tautological.

No silent no-op warning: refusals populate `reasons` and CLI exits 3.

## 3. Correctness — sound

- **No broken callers.** `research_guard` has no production caller besides the CLI (which the patch updates) and tests; the 4 pre-existing calls in `test_research_observe_projector.py` use the retained `disk_free_gb=`/`cpu_percent=`/`free_ram_gb=`/`lock_status=` seams and still pass. Removed `DEFAULT_RESEARCH_DRIVE` / `_default_disk_free_gb` / `research_drive=` have no external references (grep of `tools/` clean post-apply). The `.measurements` key rename (`disk_free_gb`→`scratch_free_gb`) has no external consumer — the `disk_free_gb` hits in `health.py`/`resource_headroom.py`/`terminal_worker.py` are unrelated snapshots.
- **Fail-closed measurement** (`_measure_free_gb` returns None on error → `DISK_UNMEASURED`/`FACTORY_DISK_UNMEASURED`), deliberately distinct from the worker's fail-open `_disk_free_gb`. Correct for a subordinate consumer.
- **Config fallbacks fail safe, not open.** Missing/corrupt config → committed default author set (not "anything"); a garbage env value yields an empty set → everything refuses. Good.
- **Windows paths** handled via `os.path.splitdrive`, case-insensitive drive compare; tests exercise C:/D: matrix, env overrides, unknown volume. Both new JSON configs are valid JSON (parsed at runtime in tests).
- **Author check** on the durable artifact; multi-agent prefix requires ≥1 named agent (`multi-agent:` alone rejected).
- Imports of `research_env`, `research_source`, `card_intake_prescreen`, `farmctl` all succeed post-apply.

## 4. Tests — present, meaningful, passing

`python -X utf8 -m pytest <4 files> -q` → **56 passed in 3.83s** (reproduced locally). New `test_research_env_guard.py` (12: C:/D: floor matrix, env overrides, unknown-volume fail-closed, shared-config wiring, layering invariant). Extended `test_research_source.py` (+8) and `test_card_r1_internal_source.py` (+2). Stale 80→20 floor assertion updated in `test_research_observe_projector.py`.

## 5. Docs — clean

English comments throughout; dated SUPERSEDED markers; append-only Annex 2026-09-15b in the contract; `qb_reputable_source_criteria.md` R1 annex generalized ("Kimi-authored" → "internally authored by an authorized research agent") with the OWNER-DEC-CBE-20260915 attribution; no history removed.

---

## Blocking
(none)

## Major
(none)

## Minor
1. **`tester_cache_purge.ps1` default 150→60 is not strictly in task scope and changes ad-hoc manual-run behavior.** The task asked only that the *Python* guard read the 60 from a shared config (done — `research_env` reads `factory_disk_policy.v1.json`). The `.ps1` still declares its own literal `60` (PowerShell does not parse the JSON), so the number technically lives in two places, both 60. The live scheduled task passes `-LowWaterGB 60` explicitly, so factory runtime is unchanged; only flagless manual runs shift from a 150 to a 60 floor. Sanctioned by audit R3 and disclosed in the report's not-done list — acceptable, but the "single source of truth" is only realized on the Python side.
2. **Multi-agent authors are not themselves validated against the authorized set.** `multi-agent:Mallory+Eve` passes `is_authorized_author` (only non-emptiness is checked). Low risk — a durable hash-verified artifact is still required and the set is OWNER-tunable — but a documented collaboration could name an unauthorized agent. Consider validating each named participant in a follow-up.
3. **Card `source_author` vs durable-artifact author is not cross-checked** in `verify()` (the check reads the artifact author only). A card could declare `source_author: Fable` while the artifact says `Kimi`. Pre-existing behavior, not introduced by this slice; note for a provenance-integrity follow-up.
4. **Guard enforcement wiring unchanged.** `research_guard` remains CLI/test-only with no production research-runner consumer; the recalibration is correct but no orchestration path yet enforces it (pre-existing condition, out of scope).
5. **Audit R5 layering invariant** is documented in the config `_doc`, module docstring, and contract annex, but not in `CLAUDE.md` as R5 suggested. Not a task requirement.

Tree left pristine (patch reverse-applied; `git diff` empty on all touched paths).
