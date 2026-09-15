# Portfolio Tail-Risk Research — design for the wave-2 tail-risk engine

**Authority:** OWNER-DEC-D3-20260915 (directive 3, sections 19, 20, 44).
Verbatim: `docs/ops/evidence/2026-09-15_continuous_book_evolution/owner_directive_3_max_factory_utilization_verbatim.md`.
**Status:** research DESIGN. It defines metrics, datasets, an acceptance rule, and the wave-2
engine contract. It does not select, size, deploy, or authorize any book or weight.
**Companion doctrine:** `docs/research/STRATEGY_ELIGIBILITY_V2.md`.

---

## 1. The question (§19)

Can multiple **individually aggressive** strategies (martingale / grid / negative pyramiding /
recovery / basket) form a **safer, profitable total portfolio through genuine diversification**?

The OWNER decision is explicit: **do NOT assume this effect — measure it.** Normal-period
correlation alone is insufficient. Diversification is accepted only when the evidence supports
it. The failure mode to detect is a **hidden common ruin mode**: sleeves that look
uncorrelated in calm periods but escalate together in a shock and jointly breach the account.

## 2. Metrics the engine must compute (§19)

For any candidate set of sleeves (each with a `strategy_risk_contract.v1`):

1. **Simultaneous adverse regimes** — fraction of time / number of days in which ≥ k sleeves are
   simultaneously in adverse (open-loss or basket-escalating) state.
2. **Correlation convergence** — rolling pairwise return correlation, tail vs body: does
   correlation rise as returns move into the loss tail? (compare calm-window vs shock-window
   correlation matrices).
3. **Common-symbol exposure** — net + gross exposure per symbol across sleeves at each bar;
   worst simultaneous same-symbol basket depth.
4. **Common-volatility exposure** — shared sensitivity to a volatility factor (e.g. realized-vol
   buckets, VIX regime) across sleeves.
5. **News / gap events** — behaviour of each sleeve's basket across the news-calendar and
   weekend-gap events; joint gap exposure (do baskets sit open into the same gap?).
6. **Margin usage** — joint `max_margin_pct` consumption path; peak simultaneous margin.
7. **Drawdown clustering** — temporal clustering of sleeve drawdowns (are DDs independent draws
   or do they bunch?).
8. **Worst-day overlap** — for each sleeve's worst N days, how many coincide across sleeves.
9. **Tail dependence** — lower-tail dependence coefficient (λ_L) between sleeve daily returns,
   estimated non-parametrically; a high λ_L is a common-ruin warning even at low Pearson r.
10. **Joint basket escalation** — the core aggressive-strategy metric: probability and depth of
    ≥ 2 sleeves reaching high `max_levels` fraction simultaneously, and the joint account-loss
    that implies against each sleeve's `max_basket_loss_pct`.

## 3. Datasets available today

| Metric input | Source available now |
| --- | --- |
| Per-sleeve sealed trade streams (entry/exit, per-deal P&L) | Q08 stress streams and Q14 head-to-head streams under `D:/QM/strategy_farm/` sleeve artifacts + `D:/QM/exports`; consumed already by `portfolio/concentration_tail.py` and `portfolio/sleeve_correlation.py`. |
| Interval equity / daily net per sleeve | `portfolio/interval_equity_export.py`, `portfolio/ftmo_daily_net_export.py`. |
| Realized correlation between sleeves | `portfolio/portfolio_correlation.py`, `portfolio/sleeve_correlation.py`, `portfolio/ftmo_decorrelation_test.py`. |
| Concentration / common-tail (symbol/asset/family/session) | `portfolio/concentration_tail.py` (+ `config/concentration_tail_limits.v1.json`). |
| Monte-Carlo joint paths | `portfolio/portfolio_montecarlo.py`, `portfolio/build_joint_sim_manifest.py`, `portfolio/ftmo_bar_joint_book_sim.py`. |
| News-calendar / gap windows | `D:/QM/data/news_calendar` (factory evidence only; never a live source). |
| Demo (money-adjacent) trades | FTMO demo journal + `portfolio/live_deal_attribution.py`, `portfolio/tlive_journal_execution_quality.py` (read-only). |
| Per-sleeve declared risk bounds | `strategy_risk_contract.v1` (`max_levels`, `max_basket_loss_pct`, `max_margin_pct`, `max_open_positions`). |

**Gap in today's data:** intra-basket per-level state (how deep each basket was at each bar) is
not universally captured in the current sealed streams; the wave-2 engine either derives it from
the trade stream (open-position reconstruction) or requires the EA to emit a basket-depth
telemetry column. This is a documented EVIDENCE gap, not something to fill by guessing.

## 4. Acceptance rule — "diversification proven"

A candidate aggressive-sleeve set qualifies as *diversifying* only when **all** hold on sealed
+ demo data (never normal-period correlation alone):

1. **Joint tail bound holds.** The simulated joint worst-day / worst-sequence account loss stays
   within the book's venue daily-loss budget (`concentration_tail_limits.v1.json`:
   `venue_daily_loss_limit_pct` × `maximum_fraction_of_daily_limit`) **and** within total
   stop-risk budget, under the joint-escalation scenario (metric 10), not just the marginal one.
2. **No hidden common ruin mode.** Lower-tail dependence (metric 9) and joint basket escalation
   (metric 10) do not exceed a preregistered threshold; worst-day overlap (metric 8) is not
   materially worse than the independence baseline.
3. **Diversification is additive, not illusory.** The joint book's tail (CVaR / worst-sequence)
   is materially better than the exposure-weighted sum of sleeve tails — i.e. the sleeves
   genuinely offset, and the improvement survives the shock windows, not only calm windows.
4. **Every sleeve is individually bounded.** Each sleeve carries a valid, non-`UNBOUNDED_RECOVERY`
   `strategy_risk_contract.v1` (§18). A book cannot be rescued by diversification if any single
   sleeve can terminate the account on its own (§20).

Any threshold introduced here is a §30 economic-selection change: counterfactual first,
versioned contract, tests, reversible. It is never a gate-integrity change.

## 5. What the wave-2 tail-risk engine must compute (deliverable contract)

A deterministic, read-only engine (proposed `portfolio/tail_risk_engine.py`) that, given a
sleeve set + their risk contracts + sealed/demo streams, emits a read-model
`D:/QM/reports/state/portfolio_tail_risk.json` (`schema` + `generated_at_utc`) with:

- the ten metrics of §2, per pair and joint;
- the four acceptance-rule outcomes of §4 with explicit `PASS` / `FAIL` / `EVIDENCE_MISSING`;
- the joint-escalation scenario result vs each venue budget;
- a **hard guard object** (`tail_risk_reject`) mirroring `concentration_tail.py`'s
  surviving-hard-guard pattern: the portfolio-level joint-tail / venue-daily-loss breach is a
  refusal; per-dimension concentration stays advisory; data-validity is fail-closed
  (`unknown_report`).

The engine is advisory evidence into the OWNER book ceremony; it never sizes or deploys.

## 6. §20 portfolio risk-layer capability map (what exists / what is missing)

| §20 capability | Exists today | Missing (wave-2) |
| --- | --- | --- |
| limit sleeve risk | `portfolio/book_sizing.py`, `portfolio/portfolio_resize.py`; per-sleeve worst-fraction 0.05 (`concentration_tail_limits.v1.json`) | — |
| limit simultaneous basket risk | `portfolio/concentration_tail.py` joint-tail divisor + common-tail; intake `max_open_positions`/`max_basket_exposure` bounds | cross-sleeve **joint basket-escalation** guard (metric 10) — not yet computed |
| limit account-wide open risk | venue daily-loss 5% × 0.8 fraction (surviving hard guard, `portfolio/risk_diagnostics.py`) | — |
| detect risk escalation | intake `max_levels` (declared); Q06 HARSH stress | runtime/simulated **cross-sleeve escalation detector** — not yet built |
| stop further additions | EA-level fail-closed at `max_levels` (framework `QM_TradeManagement`); contract `emergency_exit` rule | portfolio-level "stop all basket additions on joint-tail breach" — not yet built |
| apply venue-specific constraints | `portfolio/ftmo_rule_contract.py`, `portfolio/ftmo_rules_engine.py`; venue daily-loss limit | venue-specific joint-escalation budget wiring into the engine |

The MISSING column is the wave-2 engine's scope. Until it exists, an aggressive multi-sleeve
book must be treated as `EVIDENCE_MISSING` for §19 diversification and must not be presented as
"diversification proven".

## 7. Boundaries

- Read-only over sealed evidence + demo journal. No farm-DB writes, no terminal64 starts, no
  book construction, no live weights.
- The FTMO demo and T_Live terminals are read-only inputs.
- Economic thresholds change only via the §30 procedure.
