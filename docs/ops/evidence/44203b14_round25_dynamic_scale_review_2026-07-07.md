# Codex Review: Round25 Dynamic-Scale Study

Task: `44203b14-e5db-4454-9fca-408998cfaa62`  
Review target: `round25 dynamic-scale MC study (SELF_REVIEW per R21)`  
Date: 2026-07-07  
Artifact reviewed: `D:/QM/strategy_farm/artifacts/portfolio/round25_dynamic_scale_20260705/`

## Verdict

PASS_CONDITIONAL. The study artifacts are internally consistent and reproduce the stated static anchors through the original simulator machinery. The decision claim is suitable as evidence for G2 scale-policy review, with one wording caveat: `dd-3%->5.0` is `+2.44pp` on the 2025 fold, so the headline `+2.0-2.4pp` is exact only if rounded to one decimal.

## Evidence Reviewed

- `dynamic_scale_results.json`
- `DYNAMIC_SCALE_SUMMARY.md`
- `round25_dynamic_scale_study.py`
- `run.log`
- Upstream horizon anchor directory: `D:/QM/strategy_farm/artifacts/portfolio/round25_horizon_20260705`

## Claim Checks

1. Static anchors reproduce `prop_challenge_optimizer --screen-candidate`: VERIFIED. The study reconstructs the same daily PnL series and validates the static baselines against the horizon artifacts/grid-log anchors. JSON validation fields show exact seed/per-seed/grid matches where anchors are present.

2. Policy engine matches original phase-1 simulator for static rows: VERIFIED. `phase1_engine_crosscheck` reports `n_checks=80`, `exact_match=true`, and `max_abs_diff_pct=1.4210854715202004e-14`.

3. `dd-3%->5.0` lift claim: VERIFIED WITH ROUNDING NOTE.
   - Full fold: `+2.06pp`, median days `+4`.
   - 2025 fold: `+2.44pp`, median days `+5`.
   - This is consistent with `+2.0-2.4pp` if rounded to one decimal; strict two-decimal wording should say `+2.06-2.44pp`.

4. Progress step-down lift claim: VERIFIED.
   - Full fold progress-policy pass-lift range: `+0.06pp` to `+0.30pp`.
   - 2025 fold progress-policy pass-lift range: `+0.26pp` to `+0.42pp`.

5. Metric note consistency: VERIFIED. `94.78` is the full-fold static-9 two-phase robust baseline (`baselines.full.9.crossval_min_robust_pass_pct`). `97.24` is the phase-1-only conservative pass rate for `static_9.0` (`policy_results.full.static_9.0.pass_cons_pct`). They are different metrics, not a contradiction.

## Focused Verification

Commands run from `C:/QM/repo`:

```text
python <json verifier over dynamic_scale_results.json>
python -m py_compile D:\QM\strategy_farm\artifacts\portfolio\round25_dynamic_scale_20260705\round25_dynamic_scale_study.py
```

Verifier output:

```text
data_validation_match: True
phase1_engine_crosscheck: {'max_abs_diff_pct': 1.4210854715202004e-14, 'exact_match': True, 'n_checks': 80}
full dd-3%->5.0 delta: {'pass_cons_pct': 2.06, 'pass_mean_pct': 2.016, 'days_to_pass_p50_cons': 4.0}
2025 dd-3%->5.0 delta: {'pass_cons_pct': 2.44, 'pass_mean_pct': 2.288, 'days_to_pass_p50_cons': 5.0}
progress pass delta range full: (0.06, 0.3)
progress pass delta range 2025: (0.26, 0.42)
metric_note: {'two_phase_full_scale9': 94.78, 'phase1_full_static9': 97.24}
```

## Review Notes

- The study is phase-1-only for dynamic policy evaluation. It is not a two-phase robust pass estimate.
- Scale changes are causal by construction: policy state is decided from closed equity and applied to the next trading day.
- Fired rules only lower scale; no policy raises exposure after risk has been reduced.
- The run log shows the full artifact was generated with `5000` paths per seed, seeds `0..4`, block bootstrap and shuffle methods, with total runtime `158s`.
