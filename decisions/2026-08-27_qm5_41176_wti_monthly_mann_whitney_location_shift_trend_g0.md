# QM5_41176 WTI Monthly Mann-Whitney Location-Shift Trend - G0 Decision

Date: 2026-08-27

Verdict: `APPROVED` at G0 for one non-live V5 build, strict Q01 validation,
and one paced Q02 enqueue under the active factory resource ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor`, bounded by the durable source approval at
`decisions/2026-08-27_wti_monthly_mann_whitney_location_shift_trend_source_approval.md`.
The mission asks for one genuinely new structural, low-frequency commodity
sleeve, requires reputable-source criteria and `RISK_FIXED` backtests, and
forbids live and portfolio-gate mutations.

## Approved Identity

- EA: `QM5_41176`
- slug: `wti-mwilcoxon-shift-tr`
- strategy ID: `MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026_S01`
- source ID: `MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026`
- slot 0: `XTIUSD.DWX`, D1, intended magic `411760000`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41176_wti-mwilcoxon-shift-tr_card.md`

The ID was not inferred or hand-written into the registry. The atomic command
`python tools/strategy_farm/farmctl.py reserve-ea-ids --slug
wti-mwilcoxon-shift-tr --strategy-id
MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026_S01 --owner "Research+Development
(OWNER commodity/energy portfolio mission 2026-08-27)" --created-at
2026-08-27 --start-after 41175` returned `reserved:true`, `count:1`, and EA ID
`41176`. Magic allocation remains a separate deterministic build preflight
after the EA directory exists.

## Source And Extraction Gate

Source approval commit: `38c2df295`.

The source of record is
`strategy-seeds/sources/MOP-MANNWHITNEY-WTI-MSHIFT-TREND-2026/source.md`,
SHA-256 `8D42ED6DF1415B6EDF7FF29AE9349BCA576F0F66204A8021E2E0B8D73B0AEDE0`.
It joins one bounded lineage from:

- Moskowitz, Ooi, and Pedersen's complete-read peer-reviewed monthly
  time-series-momentum paper with explicit NYMEX WTI membership; and
- Mann and Whitney's named peer-reviewed method record plus complete pinned R
  Core `stats::wilcox.test` source and manual files defining the operative
  rank-sum and pair-count identity.

The original 1947 article body is not represented as completely read. The
exact twelve-endpoint sample, six/six split, fixed thresholds, continuous CFD,
fixed risk, stop, attempt state, and lifecycle are disclosed QM
mechanizations. No source performance, significance, profitability, CFD
equivalence, independence, or decorrelation claim transfers.

Both `skill_card_schema_lint.py` and `skill_g0_card_lint.py` must return
`status: ok` before build.

## G0 R1-R4 Decision

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete-read,
  peer-reviewed WTI trading evidence, a named original Mann-Whitney record,
  and complete pinned R Core method files. The conjunction is untested.
- R2 `PASS`: twelve consecutive completed month ends, fixed block membership,
  strict tie rejection, all 36 pair comparisons, complementary-count
  invariant, boundaries, side, consumed month, fixed risk, hard stop, renewal,
  and stale repair are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 native
  history plus MT5 state supplies every runtime input.
- R4 `PASS`: comparisons, integer arithmetic, calendar, ATR risk, and execution
  state only; no trained signal, prohibited runtime feed, adaptive PnL
  parameter, grid, martingale, scale-in, or pyramid.

## Locked Baseline

At the first executable D1 tick of a genuine new broker month, consume the
month before any fallible gate. Reconstruct the latest close in each of the
immediately prior twelve consecutive completed broker months, oldest to
newest, excluding the current month. Require an immediately prior-month
endpoint, positive finite closes, strict chronology, pairwise-distinct prices,
and no newest endpoint more than ten calendar days stale.

Fix `O=C[0..5]` and `N=C[6..11]`. Count
`U_new=count(N[j]>O[i])` over all 36 cross-block pairs and independently prove
`U_new+U_old=36`. Buy at `U_new>=24`, sell at `U_new<=12`, and otherwise
consume the month flat. No p-value, average-rank tie handling, variable split,
maximum search, endpoint fallback, fitted center, or fitted scale is allowed.

Open one WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard stop, no target, and a
1,500-point entry-spread cap. Exit at the next broker-month boundary or after
forty calendar days. Both news axes, legacy news mode, and Friday close are
OFF. No retry occurs in the consumed month. Q02 must prove at least four
completed positions in every full post-warm-up year.

## Non-Duplicate Decision

The pre-allocation checker scanned 4,675 registry rows, 1,326 cards, and 45
Strategy Wiki nodes with verdict `CLEAN` and no exact or fuzzy match. Receipt:
`artifacts/qm5_wti_mwilcoxon_shift_tr_preallocation_dedup_20260827.json`,
SHA-256
`C2F817B5CFAE47788BC8261553D32855191869912B8438858E90EB3CAEA17640`.

Manual review separates the candidate from:

- `QM5_20264`, which counts all older/newer pairs over thirteen endpoints;
  this candidate counts only the cross-block pairs at one fixed split among
  the latest twelve endpoints;
- `QM5_41172`, which searches every split for one dominant central Pettitt
  maximum; this candidate never searches or maximizes;
- `QM5_41173`, which weights squared displacement between price and calendar
  ranks; this candidate is invariant to within-block ordering;
- `QM5_41137`, which compares daily log-price samples from two adjacent
  months; this candidate compares two six-month blocks of monthly endpoints;
- return-block votes, slopes, channels, calendar states, and XTI/XNG baskets,
  which use different state objects or exposure; and
- certified `QM5_12567`, which is a short-horizon long-only XNG oscillator
  pullback.

Fixed paths in the source packet prove candidate/neighbor flat and direction
disagreements. Verdict:
`CLEAN_WTI_MONTHLY_FIXED_SIX_BY_SIX_MANN_WHITNEY_U24_LOCATION_SHIFT_CONTINUATION`.

## Kill And Authorization Boundary

Q02 retires the candidate at zero trades, below four completed positions in
any full post-warm-up year, with nonpositive governed economics, or on any
timestamp, month, split, tie, pair-count, threshold, side, attempt, risk,
lifecycle, or determinism defect. No failed result may be rescued by changing
the sample, split, boundary, direction, carrier, risk, stop, hold, or by adding
another gate.

Direct WTI exposure is different from the stated XAU/SP500/NDX/XNG carriers
but does not prove low or negative realized correlation. Q09 alone owns the
overlap verdict. Q02 may be enqueued exactly once only after a current strict
compile/Q01 PASS and independent review PASS. If the backtest CPU ceiling is
binding, stop without tester dispatch or terminal control and preserve the
committed build state.

This decision does not authorize a manual backtest; live, demo, shadow,
stress, or optimization setfile; AutoTrading; `T_Live`; deploy or live
manifest; portfolio-gate change; portfolio admission; correlation waiver;
terminal control; or a second Q02 row.
