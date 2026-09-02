# USDCHF Weekly Mann-Whitney Shift Trend - Source Approval

- Date: 2026-09-02
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one bounded structural USDCHF hypothesis, one Strategy Card, one
  deterministic identity allocation, one branch-only non-live build, strict
  Q01, and one paced Q02 enqueue
- Proposed slug: `usdchf-ww-shift-tr`
- Proposed strategy ID: `AI-CODEX-USDCHF-WW-SHIFT-20260902_S01`
- Proposed source ID: `AI-CODEX-USDCHF-WW-SHIFT-20260902`

## Authority And Ordering

The current explicit OWNER diversity and funnel-throughput mission on branch
`agents/board-advisor` prioritizes forex and other absent-book instruments,
requires structural low-frequency mechanics, reputable-source criteria, fixed-
risk backtests, branch-only commits, and farm-DB collision control. It permits
one new edge only after the diverse build backlog and genuine Q02-Q03
infrastructure-recovery lanes are exhausted.

The exact backlog audit left only two permanent missing-feed blocks, one source
rule already proven incapable of firing, and one M5 scalper with approximately
400 expected trades per year. The distinct latest-infrastructure audit exposed
no unclaimed low-frequency diverse EA stopped at Q02-Q03 solely by repairable
infrastructure. Farm claim `317b4d6a-3338-4603-8006-a4660ad6d5f1` therefore
owns this priority-3 unit.

This durable record approves the bounded source before card extraction. It
does not pre-approve activity, profitability, robustness, portfolio overlap,
deployment, or live use. The deterministic registries own the EA ID; this
decision neither predicts nor reserves one.

## Approved Evidence And Complete Read

The following bounded records were read completely before this approval:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
   and its complete-paper retrieval receipt, SHA-256
   `ECBCC76CC878F0CC6FBF8C40B23D72084EC6ED03C6375438E3232CC24A33D38F`.
   The governed packet records an end-to-end read of Moskowitz, Ooi, and
   Pedersen (2012), *Time Series Momentum*, *Journal of Financial Economics*
   104(2), 228-250, DOI `10.1016/j.jfineco.2011.11.003`, and preserves the
   broad own-price continuation and fixed renewal family.
2. `strategy-seeds/sources/MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026/source.md`,
   SHA-256
   `8D42ED6DF1415B6EDF7FF29AE9349BCA576F0F66204A8021E2E0B8D73B0AEDE0`,
   and its retrieval receipt, SHA-256
   `F9E300BBF564F12E7F17056EE90458FD728E5BF0A7ADFEDDE9391CFAA3E5086E`.
   That packet records the named Mann and Whitney (1947) peer-reviewed method
   lineage and a complete read of the pinned R Core `stats::wilcox.test`
   implementation and manual at commit
   `7344a2d9d96b3c2b997535d3abc8c3a44af16e82`.
3. The prior durable approval
   `decisions/2026-08-27_wti_monthly_mann_whitney_location_shift_trend_source_approval.md`,
   which freezes the strict no-tie rank-sum/pair-count identity and documents
   all method-access limitations.

The Mann-Whitney article body is not represented as completely read: its
publisher route was classified `DEFERRED:SOURCE_POLICY`. No body text,
probability, critical value, or result is imported. The R files fix the
operative statistic only. The existing MOP repository packet is energy-
oriented and does not independently validate USDCHF, the weekly clock, the
six/six daily-close split, the thresholds, or the hold. Those are explicit
pre-result QuantMechanica translations under the current forex-diversity
mission.

No source return, alpha, significance, hit rate, Sharpe ratio, drawdown, trade
count, cost estimate, CFD equivalence, decorrelation, or portfolio statistic
transfers.

## Approved Mechanic

At the first eligible tick of each genuine new broker week on exact
`USDCHF.DWX` D1:

1. Persist the new framework week key as consumed before history, signal,
   spread, quote, ATR, sizing, margin, or order checks. Never retry a consumed
   week after a flat state, reject, restart, stop, or close failure.
2. Exclude the forming D1 bar. Read exactly twelve completed positive finite
   D1 closes, oldest to newest. Reject duplicate timestamps, missing bars,
   nonchronological bars, nonpositive closes, or any pairwise-equal close.
3. Split once after close six into the older block `O[0..5]` and newer block
   `N[0..5]`. Count all 36 strict cross-block comparisons:

   ```text
   U_new = count(N[j] > O[i] for every i=0..5 and j=0..5)
   U_old = count(O[i] > N[j] for every i=0..5 and j=0..5)
   require U_new + U_old == 36
   ```

4. Buy USDCHF only when `U_new>=24`; sell only when `U_new<=12`; otherwise
   consume the week flat. There is no p-value, average rank, variable split,
   maximum search, endpoint-return confirmation, volatility signal, or
   fallback.
5. Open at most one position with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`, sized against a frozen `3.0*ATR(20,D1)` normalized
   broker hard stop. Attach no target and require entry spread at or below 50
   points.
6. Use the standard framework Friday close so the package is flat before the
   next weekly decision. Close and quarantine malformed, duplicate, wrong-
   magic, wrong-symbol, wrong-side, invalid-volume, or stopless owned exposure.
   A seven-calendar-day stale guard is authoritative if the Friday close is
   not observed.

Both news axes and legacy news mode are OFF. Runtime uses only completed native
USDCHF D1 prices, the corrected framework week key, ATR, quotes, symbol
metadata, positions, deals, terminal global variables, and V5 services.

Exact enumeration of the `choose(12,6)=924` no-tie rank-label assignments
yields 182 assignments at `U_new>=24` and 182 at `U_new<=12`: 364 qualifying
states, or `39.3939%` of combinatorial weekly attempts. That corresponds to a
market-free ordering prior of about 20 signal states per 52 opportunities,
before invalid history, spreads, execution, Friday closure, and market serial
dependence. It is not a probability, independence assumption, expected trade
count, or performance claim.

## Reputable-Source Criteria

| gate | verdict | basis |
|---|---|---|
| R1 | `PASS_WITH_METHOD_AND_CARRIER_CADENCE_TRANSLATION_RISK` | Complete-read peer-reviewed broad own-price-continuation evidence, named peer-reviewed Mann-Whitney lineage, complete pinned R Core method files, and explicit disclosure that the USDCHF weekly conjunction is untested synthesis. |
| R2 | `PASS` | Exact week clock, completed bars, fixed six/six blocks, strict ties, all 36 comparisons, complement invariant, thresholds, side, attempt, fixed risk, hard stop, Friday exit, and stale repair are locked. |
| R3 | `PASS` | `USDCHF.DWX` is a registered canonical forex symbol with native D1 history; MT5 and framework state provide every runtime input. No rates, futures curve, macro series, or external feed is required. |
| R4 | `PASS` | Deterministic comparisons, integer counts, ATR risk control, and execution state only; no trained output, prohibited signal indicator, grid, martingale, averaging, scale-in, or pyramid. |

## Duplicate Decision

The corrected-root fail-closed receipt
`artifacts/qm5_usdchf_ww_shift_tr_preallocation_dedup_20260902.json`, SHA-256
`E0FD0C192E36312BA520D214FF3A4A800A36E42B0CF4A6FD5C860A7050881741`,
found no exact or fuzzy identity across 4,779 registry rows, 1,415 card files,
and all 45 Strategy Wiki nodes.

Manual formula review separates the closest functional neighbors:

- `QM5_41176_wti-mwilcoxon-shift-tr` uses the same named pair-count statistic
  on twelve completed WTI month-end levels, consumes one month, and exits next
  month. This candidate uses native USDCHF D1 closes, a genuine weekly latch,
  and mandatory Friday flattening; carrier, observation cadence, opportunity
  set, cost surface, and lifecycle all change.
- `QM5_10145_tsm-meanret` evaluates an endpoint/rolling-mean-return sign every
  D1 bar across a broad universe and expects roughly 50 trades per year. This
  candidate is USDCHF-only, fixed-rank-block, invariant to order inside each
  block, and can attempt only once per week.
- `QM5_1111_qp-fx-momentum-12m` ranks seven currencies cross-sectionally over
  252 D1 bars and trades top/bottom three monthly. This candidate has no
  cross-symbol rank, currency inversion, 252-bar return, or basket.
- the USDCHF cointegration family (`QM5_20232`, `QM5_20240`, `QM5_20250`,
  `QM5_20252`, `QM5_20255`) requires a second tradable leg and frozen beta.
  This candidate is a single-symbol own-history ordinal shift with no hedge
  ratio or spread z-score.

Verdict:
`DISTINCT_USDCHF_WEEKLY_FIXED_SIX_BY_SIX_D1_CLOSE_MANN_WHITNEY_U24_LOCATION_SHIFT_CONTINUATION_FRIDAY_FLAT`.

## Falsification And Safety Boundary

The pre-result operating prior is 10-25 completed positions per full post-
warm-up year. Q02 must retire at zero trades, below ten distinct completed
positions in any full year, with nonpositive governed economics, or on any
week, bar, block, tie, pair-count, threshold, direction, attempt, risk, stop,
Friday-close, or determinism defect. No failed result may be rescued by
changing the carrier, cadence, sample, split, tie policy, boundaries,
direction, stop, or hold.

USDCHF adds a direct forex carrier absent from the stated certified
index/metal/energy book, but that does not prove low realized correlation.
Q09 alone owns portfolio overlap.

Authorized after G0 and clean registries: one source/card extraction, one
branch-only non-live build, deterministic reference fixtures, strict Q01, one
`RISK_FIXED` USDCHF D1 backtest preset, and one paced Q02 work item if the CPU
ceiling permits. Excluded: manual tester launches, optimization, live/demo/
shadow/stress presets, portfolio-gate edits, correlation waivers, portfolio
admission, deploy/live manifests, `T_Live`, AutoTrading, and terminal control.
