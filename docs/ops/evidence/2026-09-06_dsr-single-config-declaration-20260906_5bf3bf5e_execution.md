# Execution record — OWNER-DEC-DSR-SINGLE-CONFIG-DECLARATION-20260906 = YES (Option A)

- Receipt: `5bf3bf5e-e3a9-40f8-8346-d2df9ca9b1e2` (OWNER via chat, 2026-09-06 ~16:20Z: "DSR-Single-Config-Deklaration: Ja."; recorded by the Orchestrator on explicit OWNER instruction; card + plan SHA-bound).
- Execution task (Claude lane): `8fe2bac0-5cb7-5c51-873f-af506a851867` (mode APPLY_AND_VERIFY).
- Boundary: no threshold, no stored verdict, no T_Live/AutoTrading; append-only Q08 reruns only after the card declarations exist.

## Steps
1. **Codex ticket `f9ce2102-e858-435f-b83d-33ca7b9506dd`** (Sol/high, P90): declaration blocks for QM5_11167 and QM5_11196 via the approve-card path (both card locations), producer machine check for condition (i) (no optimisation row before the Q08 claim), card-linter rule "sweep list = Q14 proposal", tests, evidence. Status: commissioned 16:25Z.
2. After integration: `farmctl enqueue-backtest --phase Q08 --append-only-rerun-of d7ab61ae-c7eb-400c-81d3-94b30a1a74e2` (11167/XAUUSD) and the 11196/XAUUSD INVALID row; 11015 excluded until its set-lock question is resolved.
3. OPEN_ITEMS + Vault (03 Pipeline/Q08 addendum "sweep list = Q14 proposal").

## Acceptance (independent, after step 2)
Q08 reruns end PASS or FAIL (not INVALID); old INVALID rows preserved; no threshold/verdict change.

## Progress 2026-09-06 20:30Z (Claude)

- Step 1 done: f9ce2102 integrated (declarations in both card locations); second reruns 045bed75 (11167) and a79887e3 (11196) ended INVALID with `CANDIDATE_WINDOW_UNAVAILABLE` (producer read only Q08 payload/row dates) → Codex acf3637b **APPROVED** (b2b3d35d65: window recovered from the Q07 lineage; 90 tests + 13 subtests), 11196 set defect → Codex e638e0de **APPROVED** (replacement set `_s20260906-001.set`, sha 7cc424d2…).
- Workers reloaded staggered (chunk 56) so the claim-time `dsr_cohort.attach` runs the fixed module: 9/10 at 20:20Z, T9 still on a Q07 cell (f654273d).
- **Third Q08 rerun 11167/XAUUSD enqueued: `19c9df13-f81e-473e-9ebc-dc045b03dd1b`** (from 42ca0f18, append-only rerun of 045bed75, expected EX5 4b349d21…dd99 verified; first attempt refused on a mis-typed hash — fail-closed worked).
- 11196/XAUUSD: no production path binds a versioned replacement set to an append-only rerun (only `--target-setfile` for universe expansion) → Codex **9ecdd2f9** (P90, IN_PROGRESS): governed `--replacement-setfile`, DSR binding against the replacement set, then enqueue (from 42154e17, rerun-of a79887e3, EX5 d3b1aef0…).
- Acceptance unchanged: PASS or FAIL (not INVALID) on both reruns; old rows preserved.

## Progress 2026-09-06 21:20Z (Claude)

- Codex 9ecdd2f9 delivered `--replacement-setfile` (e73af54859) and enqueued the **third Q08 rerun 11196/XAUUSD = `9ec3b856`** (replacement set sha 7cc424d2…, pre-status `Q08_CLAIM_ROW_REQUIRED` = claim-time seal expected; evidence `2026-09-06_qm5_11196_replacement_rerun_enqueue/`).
- Both reruns (`19c9df13` 11167, `9ec3b856` 11196) pending behind the XAUUSD.DWX symbol serialization (census cells + T9 Q07); T9 still runs the pre-fix module (reload idle-only pending) — a T9 claim would reseal with the old producer.
