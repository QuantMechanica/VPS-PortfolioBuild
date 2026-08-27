# XAU/XAG Monthly Signed-KS Distribution-Shift Reversion — Source Approval

Date: 2026-08-27

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live logical-basket Q02 enqueue. Enqueue does not authorize a
manual tester dispatch or work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. It requests one genuinely different,
structural, low-frequency commodity edge, expressly permits an XAU/XAG
market-neutral-style basket, requires reputable-source criteria and
`RISK_FIXED` backtest presets, and excludes live and portfolio-gate work.

## Candidate Identity

- proposed slug: `xauxag-mks-rv`
- proposed strategy ID:
  `SCHWEIKERT-NIST-KS2-CME-XAUXAG-MDIST-RV-2026_S01`
- proposed source ID: `SCHWEIKERT-NIST-KS2-CME-XAUXAG-MDIST-RV-2026`
- proposed host/traded slot 0: `XAUUSD.DWX`, D1
- proposed companion/traded slot 1: `XAGUSD.DWX`, D1
- decision clock: first synchronized executable tick of a genuine new broker
  month
- signal: fade the dominant signed empirical-CDF displacement between fixed
  older and newer six-month blocks of synchronized completed gold-minus-
  silver log ratios when the maximum count gap is at least three

The canonical allocator owns the EA ID. This record neither predicts nor
reserves an ID.

## Approved Source Basis

The following bounded repository records were read completely before this
decision:

1. `strategy-seeds/sources/SCHWEIKERT-QC-2018/source.md`, SHA-256
   `7C409472768550C1F3A4A58CB22E12A6E915EB752B09ABC8E9B98F3E99048FFA`.
   It records an end-to-end read of Karsten Schweikert (2018), *Journal of
   Banking & Finance* 88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`.
   Gold and silver exhibit a state-dependent, asymmetric relationship, while
   constant-vector and ex-ante spread-profit claims receive material adverse
   evidence.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`.
   The official exchange packet defines the gold/silver ratio, identifies
   distinct monetary and industrial drivers, and documents the intermarket
   spread carrier.
3. `strategy-seeds/sources/MOP-NIST-KS2-WTI-MDIST-SHIFT-2026/source.md`,
   SHA-256
   `CDCEC4537A50040C1074C94FA5B29EF1038B9E72EB0798FF24D940021C2054BA`.
   Its operative method record is the complete official NIST Dataplot page
   "Kolmogorov-Smirnov Two-Sample Goodness of Fit Test." The authenticated
   receipt is
   `strategy-seeds/sources/MOP-NIST-KS2-WTI-MDIST-SHIFT-2026/retrieval_route_20260827.json`,
   SHA-256
   `8ECE87DFC5FE98897BFA24BE99B09C2FE85543CED809B796C47F0BC90911D18F`.
   NIST defines two empirical distribution functions evaluated over both
   samples and their maximum absolute separation.

No new public URL or unbounded source is introduced. The NIST record is
reused only for its two-sample ECDF construction. No critical value, p-value,
or significance claim is imported.

None of the sources tests the exact synchronized XAU/XAG ratio sample, fixed
split, integer boundary, contrarian package, continuous CFDs, equal-notional
construction, risk, stops, or lifecycle. Those are transparent QM
falsification choices. No source alpha, return, density, transaction cost,
neutrality, CFD equivalence, decorrelation, or portfolio statistic transfers.

## Locked Mechanic

At the first synchronized executable D1 tick after a genuine broker-month
transition:

1. Persist current broker `yyyymm` before every fallible gate and never retry
   that month.
2. Exclude the current month. Reconstruct the latest exactly timestamp-
   matched XAU/XAG D1 close pair from each of exactly twelve immediately prior
   consecutive completed broker months. Require positive finite closes,
   strict chronological order, distinct month keys, and a newest endpoint no
   more than ten calendar days stale.
3. Form chronological ratios
   `L[i]=ln(XAU_close[i])-ln(XAG_close[i])`. Reject any nonfinite value or
   exact tie. Preserve fixed older block `O=L[0..5]` and newer block
   `N=L[6..11]` while scanning all twelve values in strict ascending order.
4. Increment `old_seen` or `new_seen` at each ordered value. Track
   `Dplus=max(old_seen-new_seen)` and
   `Dminus=max(new_seen-old_seen)`. Prove twelve scanned observations, exact
   six/six membership, and both maxima in `0..6`.
5. A dominant `Dplus>=3` means the newer ratio distribution is displaced
   higher and opens SELL XAU / BUY XAG. A dominant `Dminus>=3` means it is
   displaced lower and opens BUY XAU / SELL XAG. Weak or tied maxima consume
   the month flat. This is contrarian distribution-shift reversion, not the
   continuation direction of the outright-WTI parent.
6. Split one aggregate `RISK_FIXED=1000` stop budget equally, target equal
   absolute USD notionals, attach frozen `3.5*ATR(20,D1)` hard stops, and
   enforce 1,500/500-point spread and 20% notional-mismatch ceilings.
7. Submit XAU first and XAG second. Retain exposure only when exactly one
   correctly directed, stopped position exists in each slot; otherwise close
   every owned leg immediately without retry.
8. Close the complete package at the next broker-month transition, after
   forty calendar days, or on malformed owned state.

Both news axes, legacy news mode, and Friday close are OFF. Runtime uses only
registered MT5 history, timestamps, logarithms, comparisons, integer counts,
ATR, quotes, symbol metadata, positions, deals, and persistent terminal state.

## Pre-Result Density Boundary

For strict values, the statistic depends only on which six of twelve combined
ranks belong to the newer block. Exact enumeration of all `C(12,6)=924`
assignments gives 218 high-shift fades, 218 low-shift fades, 486 weak flats,
and two tied-extreme flats. Directional qualification is therefore
`436/924=109/231`, approximately `0.4718614719`, or 5.662 opportunities over
twelve random-rank monthly decisions. This is only a pre-market density
calculation used to remain above the unchanged five-trades/year Q02 floor; it
is not a market probability or significance claim.

## Reputable-Source Criteria

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: complete peer-reviewed
  gold/silver relationship evidence with adverse findings, official exchange
  carrier research, and a complete official NIST method page; the exact
  trading conjunction is untested.
- R2 `PASS`: synchronization, months, ratio orientation, fixed blocks, strict
  ties, both signed ECDF count maxima, inclusive boundary, contrarian sides,
  attempt state, aggregate risk, atomicity, and lifecycle are fixed.
- R3 `PASS_WITH_SYNCHRONIZATION_AND_CONTINUOUS_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories and MT5-native state supply every runtime input.
- R4 `PASS`: deterministic arithmetic, comparisons, counts, and state only;
  no trained output, prohibited signal, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed checker found no exact identity across 4,686 registry rows,
1,337 card files, and the actual 45-node Strategy Wiki. It conservatively
returned `FUZZY_MATCH` for the shared XAU/XAG carrier. Evidence is
`artifacts/qm5_xauxag_mks_rv_preallocation_dedup_20260827.json`, SHA-256
`C2DF4289E83E77847B7BDA7D2A6BA620A555E7846F91CAF1B3CC0EF44112FA7D`.

Manual semantic review resolves the family matches as distinct:

- `QM5_41177_xauxag-mwilcoxon-shift-rv` sums all 36 old/new ordinal wins;
  this candidate retains only the largest vertical ECDF separation. Fixed
  rank paths can qualify one statistic while leaving the other flat.
- `QM5_41183_wti-mks-shift-tr` uses the same ECDF functional on one outright
  WTI carrier and follows the displacement; this candidate applies it to
  synchronized gold-minus-silver ratios, fades it, and owns an atomic two-leg
  package.
- `QM5_20263_xauxag-mad-rv` estimates a 63-D1 rolling median and MAD, requires
  a fresh standardized-score threshold cross, and may exit on convergence;
  this candidate fits no center or scale, compares two fixed monthly blocks,
  and exits only on calendar/stale/integrity rules.
- `QM5_20161_xauxag-ols-rv` fits a rolling hedge ratio and residual z-score;
  this candidate fits no coefficient or residual.
- `QM5_12724_cme-xauxag-brk` follows a D1 ratio channel breakout; this
  candidate fades a monthly distribution displacement and has no channel.
- `QM5_20202_xauxag-rev18` ranks two separate 18-month leg returns; this
  candidate evaluates twelve synchronized ratio levels with a fixed two-
  sample ECDF statistic.
- `QM5_20234_xauxag-rsj` ranks relative signed jumps from one completed month;
  this candidate uses no jump, moment, or cross-sectional rank.
- Fractional-difference, Spearman, Mann-Kendall, Pettitt, Cox-Stuart, LAD,
  Theil-Sen, repeated-median, variance-ratio, calendar, flow, and endpoint
  cards observe different state objects or statistics.

Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_FIXED_SIX_BY_SIX_SIGNED_KS_GAP3_DISTRIBUTION_SHIFT_REVERSION_BASKET`.

## Kill And Safety Boundary

Q02 must retire at zero trades, below five completed packages in any full
post-warm-up year, with nonpositive governed economics, or on any month,
endpoint, synchronization, ratio, split, tie, count, boundary, direction,
attempt, risk, atomicity, lifecycle, or determinism defect. No failed result
may be rescued by changing the sample, split, threshold, carrier, direction,
risk, hold, or by adding another gate.

Opposite equal-target-notional legs reduce outright metal direction but do
not prove dollar, beta, volatility, factor, market, or portfolio neutrality.
Unchanged Q09 alone owns realized overlap. This approval excludes manual
backtests; live, demo, shadow, stress, and optimization presets; AutoTrading;
`T_Live`; deploy or live manifests; portfolio-gate changes; portfolio
admission; correlation waivers; terminal control; and component-leg Q02 rows.
Q02 may be enqueued once only after a source-current strict compile/review PASS
and only below the factory CPU ceiling.
