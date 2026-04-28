# Lessons Learned

Kept / changed / discarded entries from incidents, gate reviews, and retrospectives. Owned by Documentation-KM.

Entries (newest first):

## 2026-04-27

- `2026-04-27_pipeline_op_process_loss_pattern.md` - Pipeline-Operator 18% headline failure rate (QUA-211) decomposed into adapter-usage-limit cascade (7/11, historical) + `process_lost` recovered retries (4/11, all auto-retried). Workaround `Test-PipelineOperatorRunHealth.ps1` (commit `de1fa8f`) separates classes; core 30-min grace-window patch (`paperclip/app` commit `6692bace`, server/src/services/heartbeat.ts) defers `process_lost` for detached-alive children. Validated on 26 runs / 0 failures after the 2026-04-27T07:22:27Z batch-reap cut. Pilot validation of QUA-263 + QUA-140 lifecycle follow-ups remain open.
- `2026-04-27_pc1-00_live_incident_qua-167.md` - PC1-00 file-class concurrent-write race on QUA-167 (CTO parallel runs raced on `framework/include/QM/QM_ChartUI.mqh`); CTO safety-stop + CEO halt + DevOps worktree-isolation mitigation (QUA-181) closed the loop. Going-forward: per-agent worktree isolation under `C:\QM\worktrees\<agent>\` for any agent touching `framework/`/`infra/` or other contended paths.
- `2026-04-27_codex_done_before_commit.md` - QUA-180 P0 process correction. CTO marked steps 1..17 of V5 framework `done` with files on disk but uncommitted (15+ untracked at peak); CEO caught via `git status --porcelain` cross-check before promoting downstream gates. Going-forward: any `done` on a coding deliverable must include the commit hash in the close-out comment.
- `2026-04-27_prompt_basis_activation_diff.md` - Two-layer prompt diff captured for the three Wave 0 hires (CTO, Research, Doc-KM). Side artifacts under `paperclip-prompts/diffs/<role>_basis_to_active.diff`. Going-forward: every BASIS revision names a propagation path (`hot_reload` | `re_hire` | `config_patch` | `reference_only`) and Documentation-KM regenerates the diff side artifact.
- `2026-04-27_dwx_spec_patch_v3_handoff.md` - QUA-65 (DEVOPS-006) DWX spec-patch v3 infra handoff: idempotent converger `infra/scripts/Install-DwxSpecPatchRunner.ps1` promotes known-good launcher config from `run_fix_dwx_spec_v2.ini` to v3 via deterministic token replacement.
- `2026-04-27_qua69_registry_mitigation_confirmation.md` - QUA-69 (DEVOPS-009) registry mitigation confirmed via idempotent evidence script `infra/scripts/Confirm-DwxRegistryMitigation.ps1` + machine-readable evidence at `lessons-learned/evidence/qua69_registry_mitigation_confirmation.json`.
- `2026-04-27_qua90_usdjpy_verifier_investigation.md` - QUA-90 (DEVOPS-004 child) USDJPY.DWX verifier failure-signature classification on the QUA-19 re-run, sourced from `infra/smoke/verify_import_run_2026-04-27_qua19.log`.
- `2026-04-27_qua91_ws30_verifier_failure_investigation.md` - QUA-91 (DEVOPS-004 child) WS30.DWX `FAIL_tail_bars` investigated against the QUA-19 verifier re-run; classified as systemic verifier/runtime condition rather than WS30-specific import defect.
- `2026-04-27_qua92_xagusd_verifier_failure_investigation.md` - QUA-92 (DEVOPS-004 child) XAGUSD.DWX `FAIL_tail_bars` classified as systemic verifier/runtime condition; recommended state `blocked` pending verifier implementation hardening.
- `2026-04-27_qua93_xauusd_verifier_failure_investigation.md` - QUA-93 (DEVOPS-004 child) XAUUSD.DWX `FAIL_tail_mid_bars` investigated; classified as systemic verifier/runtime failure rather than symbol-specific DWX corruption. Multiple chunked-probe and tail-alignment evidence artifacts under `evidence/`.
- `2026-04-27_qua94_xngusd_verifier_failure_investigation.md` - QUA-94 evidence showing XNGUSD failure matches systemic verifier/runtime bars-read condition; same-day rerun remained FAIL, structured disposition JSON was generated (`defer`), and escalation is on verifier owner.
- `2026-04-27_qua95_xtiusd_verifier_failure_investigation.md` - QUA-95 rerun evidence for `XTIUSD.DWX`; failure remains systemic verifier/runtime bars-read class (`disposition=defer`) and is blocked on verifier hardening.

## 2026-04-26

- `2026-04-26_dwx_spec_patch_blockers.md` - QUA-15 run evidence and unblock criteria for DWX spec patch verification.

## 2026-04-21

- `V4_LEARNINGS_ARCHIVE_2026-04-21.md` - V4 learnings archive migrated from laptop Notion 2026-04-26 (framing corrected 2026-04-26: V4 learnings are the *basis* of V5, not a legacy archive — phases, framework patterns, hard rules promoted into V5; only V4's strategy *bestand* is excluded).

## 2026-04-20

- `2026-04-20_file_deletion_policy_v1.md` - File-deletion policy v1 (Doc-KM single-writer, OWNER ratification). Defense-in-depth against agent/script-driven destructive filesystem operations; complements the architectural fixes (Drive `.git/` exclusion, per-repo git mutex, stale-lock monitor, agent CWD isolation) that target the proximate Drive-sync race cause.
- `2026-04-20_mass_delete_incident.md` - QUAA-255 P0 mass-delete incident (2026-04-20 00:33 CEST) — repo-broken / dashboard-stale ~5h. Forensic attribution under QUAA-256 cleared both initially-suspected scripts; root cause was Google-Drive-sync conflict triggered by concurrent multi-agent git writes. Architectural fixes tracked under QUAA-421 + CTO follow-ups.

## Evidence files (`evidence/` subdir)

- `evidence/2026-04-27_qua95_xtiusd_probe.md` - QUA-95 targeted preflight + chunked probe: tail ticks recover in preflight, but bars remain zero in one-shot and chunked reads (`Invalid params`), tightening unblock scope to verifier bars-read path.
- `evidence/2026-04-27_qua95_xtiusd_source_vs_custom_api_probe.md` - QUA-95 side-by-side MT5 API probe proves source `XTIUSD` bars are readable while custom `XTIUSD.DWX` bars are not, isolating blocker to custom-symbol/runtime visibility (plus verifier handling).
- `evidence/2026-04-27_qua95_xtiusd_custom_visibility_probe.md` - QUA-95 automated custom-vs-source visibility probe (`probe_custom_symbol_visibility.py`) returned `isolated_custom_bars_visibility_failure=true` with source bars available and custom bars zero.
- `evidence/2026-04-27_qua95_custom_visibility_scope_matrix.md` - six-symbol scope matrix shows custom-bars visibility failure across multiple families (`XTI/XNG/XAU/XAG/EURUSD`), with `WS30.DWX` as a partial exception.
- `evidence/2026-04-27_qua95_xtiusd_warmup_attempt.md` - read-only MT5 warm-up retry (40 iterations) did not restore `XTIUSD.DWX` bars visibility; post-warmup probe and verifier rerun remained `defer`.
- `evidence/2026-04-27_qua94_rates_probe.md` - One-shot vs chunked rates-read probe showing XNG/XTI/XAU hard-zero bars while WS30 returns partial chunked bars; refines escalation scope.
- `evidence/2026-04-27_qua94_chunked_verifier_probe.md` - Verifier-mirror probe with `terminal_maxbars` evidence (100k cap) and differential behavior (`XNG` hard-zero vs `WS30` partial chunked bars).
- `evidence/2026-04-27_qua94_xng_chunked_probe.json` and `evidence/2026-04-27_qua94_ws30_chunked_probe.json` - machine-readable probe payloads for owner handoff.
- `evidence/2026-04-27_qua93_*` and `evidence/2026-04-27_qua92_*` - QUA-92 / QUA-93 rerun evidence + chunked probes + tail-alignment / sidecar checks (JSON artifacts).
- `evidence/qua69_registry_mitigation_confirmation.json` - QUA-69 registry mitigation confirmation evidence (machine-readable).
