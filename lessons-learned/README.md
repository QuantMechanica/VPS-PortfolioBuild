# Lessons Learned

Kept / changed / discarded entries from incidents, gate reviews, and retrospectives. Owned by Documentation-KM.

**Publish process:** See [`LESSONS_PUBLISH_PROCESS.md`](LESSONS_PUBLISH_PROCESS.md) — defines the three mandatory trigger classes (gate finding, incident close, episode publish) and the format for each.

Recent entries:

- `2026-05-15_p2_zero_pass_eas_dropped.md` - CEO hard-reset closeout: four P2-zero-pass EAs (QM5_1003/1004/1017/SRC04_S03) dropped to lessons-learned on 2026-05-15; source themes remain on approved list for fresh Research dispatch; revival = new card per QUA-1562 Non-Goal #4.
- `2026-05-09_p2_runner_gate_gap.md` - QUA-1076 audit finding: `p2_baseline.py` and `run_smoke.ps1` capture PF and DD in summary JSON but never evaluate them against G1d (PF>1.30) and G1e (DD<12%) thresholds. No false PASS rows materialised for the audited cohort (QM5_1001/1004), but the gap must be patched by CTO before any next P2 run. Also: QM5_1001 phantom pipeline state (index.json with P3.5-P8 results but no P2 directory) — pipeline-VOID until valid V5 P2 run.
- `2026-04-27_pc1-00_live_incident_qua-167.md` - PC1-00 file-class concurrent-write race on QUA-167 (CTO parallel runs raced on `framework/include/QM/QM_ChartUI.mqh`); CTO safety-stop + CEO halt + DevOps worktree-isolation mitigation (QUA-181) closed the loop. Going-forward: per-agent worktree isolation under `C:\QM\worktrees\<agent>\` for any agent touching `framework/`/`infra/` or other contended paths.
- `2026-04-27_codex_done_before_commit.md` - QUA-180 P0 process correction. CTO marked steps 1..17 of V5 framework `done` with files on disk but uncommitted (15+ untracked at peak); CEO caught via `git status --porcelain` cross-check before promoting downstream gates. Going-forward: any `done` on a coding deliverable must include the commit hash in the close-out comment.
- `2026-04-27_prompt_basis_activation_diff.md` - Two-layer prompt diff captured for the three Wave 0 hires (CTO, Research, Doc-KM). Side artifacts under `paperclip-prompts/diffs/<role>_basis_to_active.diff`. Going-forward: every BASIS revision names a propagation path (`hot_reload` | `re_hire` | `config_patch` | `reference_only`) and Documentation-KM regenerates the diff side artifact.
- `2026-04-26_dwx_spec_patch_blockers.md` - QUA-15 run evidence and unblock criteria for DWX spec patch verification.
- `2026-04-27_qua95_xtiusd_verifier_failure_investigation.md` - QUA-95 rerun evidence for `XTIUSD.DWX`; failure remains systemic verifier/runtime bars-read class (`disposition=defer`) and is blocked on verifier hardening.
- `evidence/2026-04-27_qua95_xtiusd_probe.md` - QUA-95 targeted preflight + chunked probe: tail ticks recover in preflight, but bars remain zero in one-shot and chunked reads (`Invalid params`), tightening unblock scope to verifier bars-read path.
- `evidence/2026-04-27_qua95_xtiusd_source_vs_custom_api_probe.md` - QUA-95 side-by-side MT5 API probe proves source `XTIUSD` bars are readable while custom `XTIUSD.DWX` bars are not, isolating blocker to custom-symbol/runtime visibility (plus verifier handling).
- `evidence/2026-04-27_qua95_xtiusd_custom_visibility_probe.md` - QUA-95 automated custom-vs-source visibility probe (`probe_custom_symbol_visibility.py`) returned `isolated_custom_bars_visibility_failure=true` with source bars available and custom bars zero.
- `evidence/2026-04-27_qua95_custom_visibility_scope_matrix.md` - six-symbol scope matrix shows custom-bars visibility failure across multiple families (`XTI/XNG/XAU/XAG/EURUSD`), with `WS30.DWX` as a partial exception.
- `evidence/2026-04-27_qua95_xtiusd_warmup_attempt.md` - read-only MT5 warm-up retry (40 iterations) did not restore `XTIUSD.DWX` bars visibility; post-warmup probe and verifier rerun remained `defer`.
- `2026-04-27_qua94_xngusd_verifier_failure_investigation.md` - QUA-94 evidence showing XNGUSD failure matches systemic verifier/runtime bars-read condition; same-day rerun remained FAIL, structured disposition JSON was generated (`defer`), and escalation is on verifier owner.
- `evidence/2026-04-27_qua94_rates_probe.md` - One-shot vs chunked rates-read probe showing XNG/XTI/XAU hard-zero bars while WS30 returns partial chunked bars; refines escalation scope.
- `evidence/2026-04-27_qua94_chunked_verifier_probe.md` - Verifier-mirror probe with `terminal_maxbars` evidence (100k cap) and differential behavior (`XNG` hard-zero vs `WS30` partial chunked bars).
- `evidence/2026-04-27_qua94_xng_chunked_probe.json` and `evidence/2026-04-27_qua94_ws30_chunked_probe.json` - machine-readable probe payloads for owner handoff.
