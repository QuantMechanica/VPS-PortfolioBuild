# DL — Q06 spec re-ratification (extension of the 2026-07-05 Q05 decision)

**Date:** 2026-07-06 · **Status:** RATIFIED (same decision class and option as
`decisions/2026-07-05_q05_spec_reratification.md`, OWNER-ratified option (b);
flagged as follow-up in that DL's review ea21909d and the wave-2 ticket)

## Finding (verified in code, 2026-07-06)

The Q06 documentation ("HARSH: slip +5 pips · spread ×3 · commission ×3 ·
10% trade rejection") describes a cost-stress that was **never implemented**:

- `gen_stress_setfile.py` emits only `qm_stress_reject_probability=0.10` into
  the Q06 setfile (verified: `stress_setfile_text`, REJECT_KEY handling).
- `q06_stress_harsh.py` passes **no** commission/spread/slippage parameters to
  `run_smoke.ps1` (verified: the full args list). The "companion tester .ini
  generator (for slip/spread)" referenced in the docstring does not exist as
  an invoked component; run_smoke's own ini generation configures the test
  window, not stress costs.
- Therefore Q06-as-implemented = **full-history robustness under 10%
  random trade rejection** (the FW2 EA hook — real, seeded, deterministic),
  gross costs like every tester run (.DWX commission-free).

## Decision (option b — spec follows implementation)

Q06 is re-ratified as **Trade-Rejection Stress (HARSH)**: full history on Q03
plateau-median params with `qm_stress_reject_probability = 0.10`; pass
criteria unchanged (PF > 1.0, DD < 15%, ≥ 20 trades). All historical Q06
verdicts remain valid — they were produced by exactly this test. No re-runs.

Cost STRESS remains where the 2026-07-05 DL located it: **Q08 DL-072
cost-cushion** (gross must cover ≥ 2× worst-case commission — strictly harder
than any 3× multiplier on a $0 tester baseline). Cost REALISM remains Q04.

## Applied with this DL

- `q06_stress_harsh.py` + `gen_stress_setfile.py` docstrings corrected (no
  cost-stress claims; Q05 line corrected likewise per the 07-05 DL).
- Vault page `03 Pipeline/Q06 Stress HARSH.md` rewritten to as-implemented
  (the interim UNVERIFIED banner from review ea21909d replaced).

Evidence trail: review ea21909d verdict (2026-07-06), audit register
`docs/ops/FRAMEWORK_LATENT_DEFECT_AUDIT_2026-07-06.md`.
