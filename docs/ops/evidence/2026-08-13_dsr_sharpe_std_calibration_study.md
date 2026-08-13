# DSR `sharpe_std` calibration study — 2026-08-13

P0 of the pattern-filter plan v2 (finding A3) required either calibrating the
`sharpe_std = 1.0` placeholder in `framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py`
or documenting it as an explicit limitation. This is the study. **Outcome: the
placeholder is kept, deliberately.**

## What DSR needs

Bailey & López de Prado's deflated Sharpe deflates the observed SR by
`E[max(SR_1..SR_N)]`, which scales linearly with `sharpe_std` — the **cross-sectional
standard deviation of Sharpe estimates across the candidate set the winner was selected
from**. That set must include the losers. A larger `sharpe_std` produces a larger
expected max and therefore a harsher bar.

## Empirical harvest

All historical Q08 aggregates were walked for their recorded Sharpe
(`D:/QM/reports/pipeline/*/Q08/**/aggregate.json`, 53 files):

| n | mean | sample std | min | p25 | median | p75 | max |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 26 | 1.5497 | **0.8920** | 0.204 | 0.962 | 1.487 | 1.841 | 4.064 |

## Why 0.892 must NOT be adopted

1. **The sample is the survivors, not the candidates.** Only EAs that reached Q08 have a
   recorded Sharpe. Everything killed at Q02–Q07 — the overwhelming majority, and the
   low-Sharpe tail by construction — is absent. Selection truncates the distribution and
   *shrinks* its variance, so 0.892 is an estimate of survivor dispersion, not candidate
   dispersion. The true candidate-set dispersion is almost certainly larger.
2. **Adopting it would loosen the gate.** 0.892 < 1.0, so `E[max]` would shrink and every
   DSR p-value would fall. Swapping in a survivor-biased estimate would silently weaken
   Q08 while looking like a calibration improvement — the exact failure mode our gate
   doctrine exists to prevent.
3. **n = 26 is too small** to pin a dispersion parameter that multiplies the whole
   deflation term.
4. **Gate recalibration is OWNER-ratified.** Changing a Q08 threshold input is a gate
   recalibration with a quantified before/after re-verdict impact, not a side effect of
   a filter build (Operating Rules).

## Decision

`sharpe_std` stays at the conservative `1.0`. As of the P0 commit, every cohort-mode DSR
verdict now carries `sharpe_std_estimate` and `sharpe_std_calibrated: false` in its
evidence block, so no DSR number can be cited without its caveat visible.

## What a real calibration would require

A Sharpe (or daily-return series) recorded for **every candidate configuration**,
including those killed before Q08 — i.e. Sharpe capture pushed down to Q02/Q04 evidence,
or the census trial ledger itself once it runs (154 trials per sleeve produce exactly the
loser-inclusive dispersion this parameter needs). The census is therefore a *source* of
the calibration, which is a further reason not to pre-empt it with a biased estimate.

Follow-up ticket: capture per-candidate Sharpe at the earlier gates so the candidate-set
dispersion becomes measurable; then propose the recalibration to OWNER with a
before/after re-verdict impact table.
