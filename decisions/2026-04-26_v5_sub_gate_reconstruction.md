# Decision: V5 Sub-Gate Spec Reconstruction

- Date: 2026-04-26
- Status: accepted (defaults provisional pending Quality-Tech)
- Owner: CTO + Quality-Tech (defaults), Claude Board Advisor (reconstruction)
- Spec: `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md`
- Affected docs: `docs/ops/PIPELINE_PHASE_SPEC.md`, `docs/ops/PHASE0_EXECUTION_BOARD.md`

## Context

Codex's first laptop pass (2026-04-26) reported `CODEX_PIPELINE_V2.1_SPEC/IMPACT/DIFF.md` as MISSING. The second-pass (same date) confirmed: full recursive filename + full-text search across all of `G:\` (`G:\My Drive\QuantMechanica`, `G:\Meine Ablage\QuantMechanica - VPS Portfolio Build`, all backups) returned no hits. The only surviving references are the citation in `doc/pipeline-v2-1-detailed.md` itself plus an old HTML adjacent file. Git provenance on the laptop is broken (`fatal: bad object refs/heads/main`).

Defensible conclusion: the three V4 sub-gate spec receipts are **not recoverable**. Whether they once existed and were lost, or were only referenced and never written, cannot be determined from current laptop state.

V5 cannot run any of P5 / P5b / P5c / P6 / P7 / P10 without numerical sub-gate parameters. Either V5 stalls until the missing files are recovered (which Codex has shown is impossible), or V5 authors a fresh sub-gate spec from surviving evidence.

## Decision

V5 authors a fresh sub-gate spec at `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` (V5-local reconstruction). Defaults are derived from the surviving runner code (`Company/scripts/README_V2.1_RUNNERS.md`), the surviving result receipts (P5b YELLOW decision, P5b waiver, P6 waivers, P8 roll-up, V5 risk review, V5 composition lock), and explicit V5 additions where the V4 evidence was silent.

Every default is marked provisional. Quality-Tech recalibrates per-phase once the first V5 EA distributions reach the corresponding phase (P0-26 framework must produce that EA first).

## What Was Reconstructed (and from where)

| V5 sub-gate | V5 default | Source |
|---|---|---|
| P3.5 verdicts (`AUTO_PASS / NEEDS_RERUN / PASS / FAIL / NO_PASS_BASELINE`) | inherited verbatim | `README_V2.1_RUNNERS.md` § P3.5 CSR |
| P3.5 broad-asset-class taxonomy | reconstructed (FX_MAJOR, FX_CROSS, INDEX, COMMODITY, CRYPTO) | derived from V4 SM_XXX symbols actually used |
| P5 calibration source | provisional `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json` | matches V4 file name pattern; V5 must re-measure |
| P5 stress profile (HARSH) | reconstructed | V4 used HARSH-over-MEDIUM preference per `README_V2.1_RUNNERS.md` § P5 Calibrated Noise |
| P5 trade-count guard (`≥ 50% of clean-run`) | V5 addition | not in V4 evidence; addresses stress-induced lot-rejection failure mode |
| P5b defaults (`paths=1000, seed=42, thresholds=50/60/70, breach=0/<=1/<=2`) | inherited verbatim | `README_V2.1_RUNNERS.md` § P5 Calibrated Noise |
| P5b 70% strict gate + YELLOW proxy `<=1 breach` ≥ 70% | inherited | `SM_221_P5B_YELLOW_DECISION_20260418.md` |
| P5b one-YELLOW-per-basket cap | V5 addition | enforces V5 anti-waiver-creep stance per `V5_RESTART_SCOPE_BOUNDARY.md` |
| P5c crisis-slice list | reconstructed (7 events) | standard quant-trading crisis catalog; OWNER may extend |
| P6 5 seeds (`42, 17, 99, 7, 2026`) | inherited verbatim | `pipeline-v2-1-detailed.md` |
| P6 4-state verdict (PASS / MIXED / FAIL / WAIVER) | V5 addition | matches V5 evidence-discipline stance; V4 used binary + ad-hoc waivers |
| P7 PBO < 5%, DSR > 0, MC p < 0.05, FDR q < 0.10 | inherited | `pipeline-v2-1-detailed.md` table cell + Prado-style standard |
| P7 consolidated runner | V5 addition | V4 had no single runner |
| P10 14-day window | inherited | `pipeline-v2-1-detailed.md` table cell |
| P10 KS test, p < 0.01, 6-month lookback, N_fwd ≥ 30 | V5 numeric addition | V4 mentioned "KS-test kill-switch" without numeric thresholds |
| P10 magic offset +9000 for shadow | V5 addition | matches `framework/V5_FRAMEWORK_DESIGN.md` ea_id range allocation |

## Alternatives Considered

- **Wait for the V4 receipts to surface.** Rejected. Codex's full search confirms they cannot be found. Waiting blocks V5 indefinitely.
- **Ship V5 without a sub-gate spec; let each EA's pipeline run improvise.** Rejected. That is V4's "doc/code drift" failure mode — runner guide referenced scripts that did not exist. V5's framework discipline requires the spec to exist before the runner is implemented.
- **Reconstruct the three V4 files literally.** Rejected. Codex suggested this; chose against because reconstructing what V4 *probably* said adds speculation and binds V5 to V4 numerical defaults that may not survive recalibration. Better to write V5-native with provenance back to surviving evidence.
- **Single sub-gate spec file vs. three (SPEC / IMPACT / DIFF).** Chose single. Easier to keep coherent, single-source-of-truth, and the IMPACT and DIFF sections live as headed sections inside the one file. If a downstream consumer wants three files, the spec can be split losslessly.

## Consequences

- `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` becomes the sub-gate authority for V5.
- `docs/ops/PIPELINE_PHASE_SPEC.md` Open Questions section now points to it.
- Quality-Tech becomes the named owner of the recalibration cycle (per § Recalibration Triggers in the spec).
- The five Python runners V5 needs (`p35_csr_runner.py`, `p5_calibrated_noise_runner.py`, `p7_stat_validation_runner.py`, `p10_shadow_runner.py`, `news_impact_runner.py`) are now spec-defined and waiting for Codex implementation under `framework/scripts/`.
- The framework design (P0-26) and the sub-gate spec (P0-27) together constitute the full V5 build / test / deploy harness blueprint. After Codex implements both, V5 can build its first EA.

## Sources

- `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` (the spec itself; this ADR is the meta-record)
- `docs/ops/PIPELINE_PHASE_SPEC.md`
- `framework/V5_FRAMEWORK_DESIGN.md`
- `decisions/2026-04-26_v5_restart_clean_slate.md`
- `decisions/2026-04-26_v5_framework_design.md`
- Codex pack second pass: `Phase0_Migration_Pack_2026-04-25/pipeline_spec_second_pass_provenance.md`
