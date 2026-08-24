# Review — task 740049db (T_Live set-file provenance repair plan)

Date: 2026-08-24
Reviewer: Claude (review lane)
Task: `740049db-4a8c-48cd-b84f-449152897de1` (ops_issue, assigned codex, REVIEW)
Worker artifact: `docs/ops/evidence/2026-08-23_tlive_setfile_provenance_repair_plan.md`
Worker verdict: PASS (10/10 exact staged provenance; missing final generator disclosed; value-preserving OWNER-gated repair + fail-closed guard designed)

## Verdict: APPROVED

Diagnosis + repair plan + guard design deliverable. All five acceptance criteria met, every load-bearing citation independently verified read-only. No T_Live change made during this review (read-only only).

## Acceptance-criteria check

1. Per-defective-preset provenance line or explicit "not reconstructable" with rationale — MET. Section 1 gives a SHA256 lineage table (DXZ24 parent -> DXZ-final source -> T_Live) for all ten, with the exact one-line `RISK_PERCENT` delta per file (13128 byte-identical). Final staging script explicitly declared not reconstructable, with the committed admission cited.
2. Deploy path ignoring DO_NOT_COPY marker named with file:line — MET. `decisions/2026-07-19_t_live_dxz_sunday_final_book.md:86-91` (file-side deploy record, no marker/header check), `DXZ24_2026-07-17/evidence/stage_dxz24.py:45-57` (continuing-sleeve stage validates only risk replacement), and the explicit finding that no marker parser existed at any of the three boundaries.
3. Value-preserving regeneration plan with byte-diff method described (not merely asserted) — MET. Section 4: provenance-only template mode, header allowlist, binary byte-span diff + duplicate-aware ordered-multimap parse, explicit equality proofs for RISK_PERCENT/RISK_FIXED/PORTFOLIO_WEIGHT/qm_magic_slot_offset/all qm_filter_*, 9.7499 total invariant, HOLD on any failure.
4. Fail-closed guard design with negative-test sketch — MET. Section 5: reusable deploy-boundary validator, refusal list (marker tokens, build_hash pending/non-hex, env!=live, risk_mode!=PERCENT, RISK_FIXED!=0, binary-hash mismatch), atomic all-or-nothing copy, four negative tests + one positive test, raw Copy-Item prohibited.
5. Evidence doc under docs/ops/evidence/ — MET.

## Independent read-only verification

- `framework/scripts/gen_setfile.ps1` — confirmed. Now carries `$BuildHash` (line 17), `ExpectedBuildHash` validation (line 444), and `PROVENANCE_TEMPLATE_REPAIR_REQUIRES_LIVE_AND_BUILD_HASH` template mode (lines 550-556); ordinary path still emits `build_hash: pending` (line 626). The artifact's writing-time claim ("no BuildHash param") was accurate on 2026-08-23; the plan's step-2 generator extension has since been implemented.
- `decisions/2026-07-19_t_live_dxz_sunday_final_book.md:86-91` — confirmed: 24/24 staging->T_Live SHA, RISK_FIXED=0, magic formula, sum 9.7499, AutoTrading untouched; no marker/header check listed. Matches the deploy-path claim.
- `tools/strategy_farm/portfolio/stage_tlive_presets_risk.py:3-7` — confirmed the contemporaneous admission that the 2026-07-19 generator was session-local and never committed.
- `C:/QM/deploy/DXZ24_2026-07-17/evidence/stage_dxz24.py` and `C:/QM/deploy/DXZ_FINAL_2026-07-19` — both exist.
- Current T_Live state (10 presets): all ten now carry `environment: live`, `risk_mode: PERCENT`, a valid 64-hex `build_hash` equal to the section-3 deployed-`.ex5` SHA, and zero DRAFT_ONLY/DO_NOT_COPY markers. The OWNER-gated repair described by this plan has since been executed exactly as designed (build_hash bound to the deployed binary). This validates the plan a posteriori and is outside this diagnosis-only task's scope.

## Notes

- The artifact's point-in-time SHA-equality checks (T_Live == DXZ-final source) are now stale because T_Live has since been repaired; this does not weaken the deliverable, which was a diagnosis+plan, and the durable evidence chain (scripts, decision records, commits) verifies.
- The artifact honestly corrects the task's narrower framing (live-set absence affects 10706/10919/12989/13128, not only 10919/12989), improving on the ticket.
- Task hard constraints (no T_Live change, no AutoTrading, no risk change, plan not executed pre-OWNER) respected within the deliverable.
