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

## Progress 2026-09-06 23:30Z (Claude) — third rerun INVALID with a known cause, identity fix, fourth rerun

- Both reruns were starved by the XAUUSD.DWX symbol serialization (census cells re-claiming the symbol); at 22:42Z both got `payload.priority_track=true` (`farmctl mark-priority-track`, GRÜN, reversible).
- **19c9df13 (11167) → INVALID at 23:00:58Z, but the DSR context was SEALED at claim** (window from payload, claim-time reseal worked). Sub-gate 8.2 = `DSR_V2_SINGLE_CONFIG_CANDIDATE_MISMATCH`: farmctl launches `q08_davey/aggregate.py --ea-id 11167` (int, prefix stripped) while the sealed candidate carries `QM5_11167`; `validate_context` compared the strings literally. Economic picture on the same run: 8.4 seasonal FAIL (losing months 6/8/11), 8.7 PBO FAIL (40.00 % at max 40 %) → expected final verdict **FAIL**; 8.5/8.6/8.8–8.11 PASS.
- **Fix 866e3f2d78:** `canonical_ea_id()` (strip `QM5_`, numeric core) in `validate_context`; different EAs still fail closed; 57 DSR tests pass. The evaluator runs as a subprocess per aggregation, so the running 11196 rerun 9ec3b856 (T1, claimed 22:41Z) evaluates with the fix.
- **Fourth 11167 rerun `89ea5894`** (append-only rerun of 19c9df13, from 42ca0f18, EX5 4b349d21…, priority_track) — justified by the known cause, not blind. Codex adversarial review of the identity contract enqueued (P90).

## RESULT 2026-09-07 00:10Z (Claude) — acceptance criterion met

| Row | EA / symbol | Claimed | Terminal | Verdict | 8.2 DSR | Other sub-gates |
|---|---|---|---|---|---|---|
| `9ec3b856` | QM5_11196 / XAUUSD.DWX (replacement set 7cc424d2…) | T1 22:41Z | 00:03:42Z | **PASS** | PASS `DSR_V2_COMPUTED` (n_days 3287, net_return 0.745, sharpe_daily 0.042) | 8.4 seasonal FAIL (losing months 2/6/8/9/11), 8.6 chopping block FAIL (pf 0.890 < 1.0); 8.5/8.7/8.8–8.11 PASS |
| `89ea5894` | QM5_11167 / XAUUSD.DWX (ablation_01 set) | T4 23:20Z | 23:49:50Z | **FAIL_SOFT** | PASS `DSR_V2_COMPUTED` (net_return 0.292) | 8.4 seasonal FAIL (6/8/11), 8.7 PBO FAIL (40.00 % at max 40 %) |

- Both reruns end with a real verdict (PASS / FAIL_SOFT), **not INVALID**; sub-gate 8.2 evaluated the declared single configuration under DSR V2 for the first time in production. All predecessor rows (d7ab61ae, 045bed75, 19c9df13, b280892a, a79887e3) preserved; no threshold or contract criterion changed; T_Live/AutoTrading untouched.
- Defects surfaced and fixed on the way (all APPROVED): producer window on append-only reruns (acf3637b / b2b3d35d65), 11196 replacement set (e638e0de), governed `--replacement-setfile` (9ecdd2f9 / e73af54859), producer/aggregator EA-identity format (Claude 866e3f2d78 + Codex adversarial hardening a430c1aeda, 4bf2eb39). Queue lever used: `mark-priority-track` on both rows (XAUUSD symbol serialization).
- Consequence for the counter: 11167/XAUUSD is out (FAIL_SOFT); 11196/XAUUSD continues (Q08 PASS → pump cascade to Q09; see OPEN_ITEMS for the follow-up). Counter stays 12/25 until the chain reaches its terminal Q14 pair.
- Sweep list of the remaining DSR-V2-INVALID rows (11015 etc.) = Q14 proposal per the OWNER card; not part of this execution.

## Acceptance 2026-09-07 00:12Z — independent (Sonnet) review: ACCEPT, no caveat

Verified read-only: both rows terminal with real verdicts (PASS / FAIL_SOFT), 8.2 `DSR_V2_COMPUTED` on both (dsr_p 0.00551 / 0.000855), `dsr_context_status=SEALED`, replacement set sha bound on 9ec3b856, five predecessor rows untouched (updated_at before 23:01Z), `gate_manifest.v4.json` and `q08_davey/aggregate.py` without commits since 16:00Z, fixes limited to identity normalization / plumbing, no T_Live or AutoTrading action, Q09 successor 6b6a3913 present. Task 8fe2bac0 closed **APPROVED** by the Orchestrator.
