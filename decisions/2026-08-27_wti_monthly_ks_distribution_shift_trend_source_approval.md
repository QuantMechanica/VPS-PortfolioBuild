# WTI Monthly Signed-KS Distribution-Shift Trend — Source Approval

Date: 2026-08-27

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue does not authorize tester dispatch or
work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. It requests one genuinely different,
structural, low-frequency commodity/energy edge, expressly permits a
structural `XTIUSD` trend edge, requires reputable-source criteria and
`RISK_FIXED` backtests, and excludes live and portfolio-gate work.

## Candidate Identity

- proposed slug: `wti-mks-shift-tr`
- proposed strategy ID: `MOP-NIST-KS2-WTI-MDIST-SHIFT-2026_S01`
- proposed source ID: `MOP-NIST-KS2-WTI-MDIST-SHIFT-2026`
- proposed host/traded slot 0: `XTIUSD.DWX`, D1
- decision clock: first executable tick of a genuine new broker month
- signal: continue the dominant signed empirical-CDF shift between fixed old
  and new six-month blocks when the maximum count gap is at least three

The governed deterministic allocator owns the EA ID. This record does not
reserve or predict an ID.

## Approved Source Basis

The following bounded records were read completely before this decision:

1. `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
   It preserves a complete-paper review of Moskowitz, Ooi, and Pedersen
   (2012), *Journal of Financial Economics* 104(2), DOI
   `10.1016/j.jfineco.2011.11.003`, including monthly continuation, monthly
   renewal, and explicit NYMEX WTI membership.
2. The official NIST Dataplot Reference Manual page "Kolmogorov-Smirnov
   Two-Sample Goodness of Fit Test" at
   `https://www.itl.nist.gov/div898/software/dataplot/refman1/auxillar/ks2samp.htm`.
   The complete page defines two empirical distribution functions, their
   evaluation at all observations from both samples, and the maximum gap.
   Retrieval evidence is
   `strategy-seeds/sources/MOP-NIST-KS2-WTI-MDIST-SHIFT-2026/retrieval_route_20260827.json`,
   SHA-256
   `15EB4DF37FB991D41A6AE16CEF8CD341124C24DB8A7B7078B11DC42E2C90A289`.
3. The complete governed composite packet
   `strategy-seeds/sources/MOP-NIST-KS2-WTI-MDIST-SHIFT-2026/source.md`.

Moskowitz, Ooi, and Pedersen support a falsifiable monthly WTI own-price
continuation experiment. NIST supplies the operative two-sample ECDF method.
No source tests this exact fixed-block trading conjunction. The signed count,
boundary, continuous-CFD mapping, fixed risk, stop, attempt, and lifecycle are
disclosed QM choices.

No source return, alpha, probability, significance, trade density, Sharpe
ratio, drawdown, cost, CFD equivalence, decorrelation, or portfolio statistic
transfers.

## Locked Mechanic

On the first executable `XTIUSD.DWX` D1 tick after each genuine broker-month
transition:

1. Persist the current broker `yyyymm` before every fallible gate.
2. Reconstruct the latest D1 close from exactly twelve immediately prior
   consecutive completed broker months; reject ties and malformed history.
3. Fix `C[0..5]` as the older sample and `C[6..11]` as the newer sample. Scan
   the combined values from low to high. After each value, calculate
   `delta=old_seen-new_seen`; retain `D_plus_count=max(delta)` and
   `D_minus_count=max(-delta)`.
4. Buy only at `D_plus_count>=3` with `D_plus_count>D_minus_count`; sell only
   at `D_minus_count>=3` with `D_minus_count>D_plus_count`. Central or tied
   maxima consume the month flat. No p-value, table, variable split, or
   fallback exists.
5. Use one position, `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   `PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard stop, no target, and a
   1,500-point spread ceiling.
6. Close at the next broker-month transition or after forty calendar days;
   immediately repair invalid owned exposure.

Both news axes, legacy news mode, and Friday close are OFF. Exact enumeration
gives 218 BUY and 218 SELL assignments among 924 fixed six/six rank
assignments, for directional qualification `109/231` or approximately 5.662
opportunities per random-rank year. This is a pre-result density fact, not a
market or significance claim.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete-read,
  peer-reviewed WTI trading evidence and a complete official NIST method page;
  exact conjunction untested.
- R2 `PASS`: clock, endpoints, fixed blocks, strict ties, combined scan, signed
  maxima, boundary, direction, consumed attempt, risk, stop, and lifecycle are
  deterministic and locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 history
  and MT5 state supply every runtime input.
- R4 `PASS`: native comparisons, counts, calendar, ATR risk, and execution
  state only; no trained output, prohibited signal, external runtime feed,
  grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed canonical invocation explicitly bound the current Company
Reference vault and returned `CLEAN` after scanning 4,682 registry identities,
1,333 cards, and 45 Wiki nodes. Evidence is
`artifacts/qm5_wti_mks_shift_tr_preallocation_dedup_20260827.json`.

This is not `QM5_41176_wti-mwilcoxon-shift-tr`: Mann-Whitney sums all 36
cross-block wins, while this rule retains the maximum vertical ECDF gap.
Rank path `[1,2,3,5,11,12,4,6,7,8,9,10]` buys here at signed maxima `(3,2)`
while Mann-Whitney is flat at `U_new=23`; path
`[1,2,4,6,8,10,3,5,7,9,11,12]` is flat here at `(2,0)` while Mann-Whitney
buys at `U_new=26`. Side-reflected paths prove SELL symmetry.

The fixed split also differs from Pettitt's variable change-point maximum,
Mann-Kendall's 78 chronological comparisons, Spearman's time-rank
displacement, and the median-runs rule's chronological regime-transition
count. The certified `QM5_12567` is a long-only, two-day XNG oscillator
pullback and shares neither carrier, cadence, direction set, nor state
function.

Verdict:
`CLEAN_WTI_MONTHLY_FIXED_SIX_BY_SIX_SIGNED_KS_ECDF_GAP3_DISTRIBUTION_SHIFT_CONTINUATION`.

## Kill And Safety Boundary

Q02 retires the locked candidate at zero trades, below five completed
positions in any full post-warm-up year, with nonpositive governed economics,
or on any endpoint, split, tie, ECDF-count, threshold, side, attempt, risk,
lifecycle, or determinism defect. No failed result may be rescued by changing
the sample, split, boundary, direction, carrier, risk, hold, or by adding a
filter.

Direct WTI exposure adds a crude-oil driver absent from the stated
XAU/SP500/NDX/XNG book, but does not prove low realized correlation. Unchanged
Q09 owns overlap. This approval excludes manual backtests; live, demo,
shadow, stress, and optimization setfiles; AutoTrading; `T_Live`; deploy or
live manifests; portfolio-gate changes; portfolio admission; correlation
waivers; terminal control; and a second queue row. Q02 may be enqueued once
only after a current strict compile/review PASS and only below the factory CPU
ceiling.
