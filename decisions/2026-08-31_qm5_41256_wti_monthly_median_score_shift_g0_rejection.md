# QM5_41256 WTI Monthly Median-Score Shift - G0 Rejection

Date: 2026-08-31

Decision: `REJECTED_FREQUENCY_PRIOR`

The source approval at
`decisions/2026-08-31_wti_monthly_median_score_shift_trend_source_approval.md`
is preserved as immutable pre-result audit history. No Strategy Card was
approved, no EA directory or magic was created, no compile or tester was run,
and no Q02 row was enqueued.

The locked `H<=1 or H>=5` pooled median-score rule admits exactly 74 of the
924 six-of-twelve rank assignments. Its market-free cadence prior is therefore
`12 * 74 / 924 = 0.961` decisions per year, below the binding Q02 floor of five
completed positions per full scored year. Building this identity would create
a candidate that is structurally expected to fail activity before economics
can be evaluated.

The failure was detected after deterministic identity reservation but before
card approval. `QM5_41256` must be retired without ID reuse. Any denser rule is
a separately sourced and deduplicated candidate, not an edit to this immutable
source contract.

This decision authorizes no tester, Q02, live, portfolio, deploy, `T_Live`, or
AutoTrading action.
