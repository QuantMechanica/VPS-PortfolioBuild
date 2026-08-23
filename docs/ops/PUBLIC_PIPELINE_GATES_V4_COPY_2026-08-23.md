# Public Pipeline Gates — Website Copy Deck

Status: website-ready public copy for the active linear v4 gate contract.

This deck describes what each validation gate does without publishing thresholds, parameter rules, performance figures, internal identifiers, or infrastructure details. The wording is the public, current-ID rendering of the first Purpose/Zweck paragraph on each corresponding Pipeline page.

## Strategy proves itself

| Gate | Name | Public purpose |
|---|---|---|
| Q00 | Research Intake | Reviews whether a strategy source and its extracted ideas are ready to enter the validation pipeline. |
| Q01 | Build & Spec | Confirms that the trading system builds correctly and that its mechanical specification is complete before backtesting. |
| Q02 | Baseline Screening | Screens whether the strategy produces a meaningful, profitable signal across its intended markets before deeper validation. |
| Q03 | Parameter Sweep | Tests whether the result persists across a stable parameter neighbourhood rather than depending on a single tuned setting. |
| Q04 | Walk-Forward + Commission | Uses walk-forward testing with a realistic venue cost model to check whether the strategy generalises beyond development data. |
| Q05 | Gross Full-History Robustness | Replays robust parameters across the full available history to test whether the edge persists across market regimes. |
| Q06 | Stress HARSH | Applies execution stress to test whether the strategy remains reliable when fills are disrupted. |
| Q07 | Multi-Seed | Repeats the test across multiple random seeds to distinguish a genuine signal from lucky execution ordering. |
| Q08 | Davey Statistical Validation | Combines statistical and robustness checks into a target-neutral evidence dossier for the frozen baseline. |

## Strategy is optimised and requalified

| Gate | Name | Public purpose |
|---|---|---|
| Q09 | Baseline Full Run | Freezes a full-history pre-news baseline as the reference for the later sealed comparison. |
| Q10 | News Impact + FTMO Recommendation | Uses controlled news-condition comparisons to select a news mode and assess venue compliance. |
| Q11 | Incumbent Full-History Confirmation | Confirms the locked configuration over full history with realistic costs and the selected news mode. |
| Q12 | Pattern Filter Selection | Evaluates preregistered pattern filters while allowing the unfiltered strategy to remain the valid choice. |
| Q13 | Parameter Optimization & Freeze | Optimises numerical parameters on development data and freezes the selected configuration for independent comparison. |
| Q14 | Best-Settings Head-to-Head | Compares the frozen challenger with its baseline and incumbent to decide whether to promote it or keep the incumbent. |

## Strategy is assessed for the portfolio

| Gate | Name | Public purpose |
|---|---|---|
| Q15 | Final Portfolio Construction | Evaluates correlation, tail behaviour, clustering, marginal contribution and fit within an authorised portfolio. |
| Q16 | Operational Readiness | Runs the operational pre-flight that must pass before an approved portfolio can proceed toward deployment. |
| Q17 | Live Burn-In DXZ | Observes the approved strategy in live burn-in under monitoring and kill-switch controls before full live use. |

## Website contract

The exporter places this copy in `pipeline_gates.gates`. Each record carries only `id`, `name`, `macro_phase`, and `purpose`. The public Strategy Archive consumes the same ordered gate IDs and displays only `PASS`, `FAIL`, `UNTESTED`, or `IN_PROGRESS` for each opaque card ID.
