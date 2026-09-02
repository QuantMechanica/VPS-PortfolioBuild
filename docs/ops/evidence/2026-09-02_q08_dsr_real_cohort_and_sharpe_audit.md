# Q08 8.2 real-cohort DSR report and MT5 Sharpe audit — 2026-09-02

Task: `2900ac3d-a328-4e54-802b-b765946d2648` (priority 86).

## Delivered

- Q08 sub-gate 8.2 now emits a `cohort_dsr_report` for both audited funnel counts: 3,001 distinct EAs and 13,398 distinct (EA, symbol) pairs. It uses the Bailey–López de Prado expected-maximum formula, annualized units, and records DSR probability.
- This is deliberately `REPORT_ONLY_OWNER_REVIEW`: `threshold_changed=false`; the existing sealed 8.2 status, `p < 0.05` threshold, and DL-066 first-entry behavior are unchanged.
- The report appears even on the legacy no-peer trivial-PASS branch, closing the 141/166 observability gap without retroactively re-grading rows.
- The main HTML dashboard no longer displays the MT5 summary Sharpe as “Sharpe”. It computes and labels `Return Sharpe (per deal)` from consecutive report balance changes and retains `mt5_reported_sharpe` only as explicitly named diagnostic evidence.
- Q09 still consumes its legacy MT5 Sharpe threshold input because replacing it would change a sealed decision threshold's units. The collector now publishes `mt5_reported_sharpe`, `return_based_sharpe_per_deal`, and `sharpe_semantics=LEGACY_MT5_REPORTED_THRESHOLD_INPUT_OWNER_REVIEW_REQUIRED` together, making the remaining OWNER decision explicit rather than silently mixing metrics.
- The `ea_metrics` CLI labels its heterogeneous legacy column `SHARPE(SOURCE-DEFINED)`.

## Production-surface audit

| Surface | Before | Disposition |
|---|---|---|
| `framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py` | 85% no-peer trivial PASS with no real-funnel statistic | real-cohort report added; verdict unchanged |
| `tools/strategy_farm/dashboards/render_dashboards.py` | parsed/displayed MT5 `Sharpe Ratio` generically | replaced display with per-deal return Sharpe; raw field explicitly named |
| `tools/strategy_farm/q09_news_runner.py` | MT5 field stored generically as `sharpe` and used by the sealed delta rule | compatibility retained; raw and return metrics now separately labeled; OWNER flag emitted |
| `tools/strategy_farm/ea_metrics.py` | generic mixed-provenance `SHARPE` column | labeled source-defined |
| portfolio modules (`portfolio_kpi`, `portfolio_resize`, `shadow_booklab`) | calculate Sharpe from return/PnL series | no change required |

## Verification

`pytest framework/scripts/q08_davey/tests/test_sub_8_2_selection_multiplicity.py framework/scripts/tests/test_q08_davey_subgates.py tools/strategy_farm/tests/test_q09_news_runner_v2.py -q` → **148 passed, 10 subtests passed**.

Verdict: **REVIEW — report-only DSR is wired and unsafe display ambiguity removed; OWNER must decide whether/when the Q09 sealed metric is migrated to return-based units.**
