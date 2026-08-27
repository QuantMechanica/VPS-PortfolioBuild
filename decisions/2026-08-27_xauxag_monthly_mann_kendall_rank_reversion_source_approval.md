# XAU/XAG Monthly Pairwise-Rank Reversion — Source Approval

Date: 2026-08-27

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live logical-basket Q02 enqueue. Enqueue does not authorize a
manual tester dispatch or work above the active factory CPU ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
the `agents/board-advisor` branch. It requests one genuinely different,
structural, low-frequency commodity edge, expressly permits a market-neutral-
style XAUUSD/XAGUSD basket, requires reputable-source criteria and fixed-risk
backtests, and excludes live and portfolio-gate work.

## Candidate Identity

- proposed slug: `xauxag-mkendall-rv`
- proposed strategy ID:
  `SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026_S01`
- proposed source ID:
  `SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026`
- proposed host/traded slot 0: `XAUUSD.DWX`, D1
- proposed companion/traded slot 1: `XAGUSD.DWX`, D1
- decision clock: first synchronized executable tick of a genuine new broker
  month
- signal: fade an inclusive `abs(S)>=14` all-78-pair ordinal trend in
  thirteen completed synchronized gold-minus-silver log ratios

The governed allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The following bounded repository records were read completely before this
decision:

1. `strategy-seeds/sources/SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026/source.md`,
   SHA-256
   `D5E8C4CD0112724D66E64C13B20B7B41CCE1B4CDC2061BA21A979374F04531A8`.
   It preserves Karsten Schweikert (2018), *Journal of Banking & Finance*
   88, 44-51, DOI `10.1016/j.jbankfin.2017.11.010`, and official CME Group
   ratio-spread research. It supports a related but state-dependent
   gold/silver relation and distinct metal demand drivers.
2. `strategy-seeds/sources/MOP-WTI-RANKTREND-2026/source.md`, SHA-256
   `A5AE6AC763357307C55141495985BFDD8359642454B52A83D6FEAE151DAD2EEC`.
   Its complete-read peer-reviewed parent establishes monthly commodity
   price-path persistence, while the bounded packet fixes the no-tie all-
   pair ordinal score. Its WTI carrier and continuation direction do not
   transfer.
3. The governed composite packet
   `strategy-seeds/sources/SCHWEIKERT-MANNKENDALL-CME-XAUXAG-MRANK-RV-2026/source.md`.

No new public URL was supplied or needed. The trading conjunction is a QM
hypothesis. No source performance, probability, significance, cost,
neutrality, CFD-equivalence, decorrelation, or portfolio statistic transfers.

## Locked Mechanic

At the first synchronized executable D1 tick after each genuine broker-month
transition:

1. Persist the current broker `yyyymm` before every fallible gate.
2. Reconstruct the latest exactly timestamp-matched XAU/XAG close pair in
   each of the thirteen immediately prior consecutive completed months;
   reject malformed, stale, current-month, or tied ratio history.
3. Form chronological `r[i]=ln(XAU[i])-ln(XAG[i])`. For every
   `0<=i<j<=12`, add `+1` when `r[j]>r[i]` and `-1` otherwise. Require
   exactly 78 comparisons, even `S`, and `-78<=S<=78`.
4. If `S>=14`, SELL XAU and BUY XAG. If `S<=-14`, BUY XAU and SELL XAG.
   Otherwise consume the month flat. No p-value, displacement weight,
   fitted hedge ratio, center, scale, or fallback exists.
5. Open at most one opposite-side equal-target-notional package under
   aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
   `PORTFOLIO_WEIGHT=1`, with frozen `3.5*ATR(20,D1)` hard stops, no targets,
   and bounded spreads/notional mismatch.
6. Submit XAU first and XAG second, retain only a complete valid package,
   close at the next broker-month transition or after forty days, and repair
   malformed owned exposure immediately.

Both news axes, legacy news mode, and Friday close are OFF. Exact enumeration
of all 13! no-tie rank paths gives a two-tail qualification rate of
`0.4353804483839206`, approximately 5.22 monthly opportunities per random-
order year. The pre-result threshold is a density design choice to respect
the unchanged five-per-year Q02 floor, not a market result or significance
claim.

## Reputable-Source Criteria

- R1 `PASS_WITH_STATISTIC_AND_CARRIER_TRANSLATION_RISK`: peer-reviewed
  gold/silver relationship evidence, official exchange carrier research,
  and complete governed rank arithmetic; exact conjunction untested.
- R2 `PASS`: synchronized endpoints, all 78 comparisons, score invariants,
  threshold, contrarian sides, attempt, risk, atomicity, and lifecycle fixed.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native XAU/XAG D1 histories plus MT5-native state supply every input.
- R4 `PASS`: deterministic timestamps, logarithms, comparisons, integer
  arithmetic, calendar, and execution state only; no ML, banned signal,
  external runtime feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The fail-closed checker scanned 4,680 registry identities, 1,331 cards, and
45 Strategy Wiki nodes. It found no exact identity and returned the expected
fuzzy neighbor `QM5_41174_xauxag-mspearman-rv`. Evidence is
`artifacts/qm5_xauxag_mkendall_rv_preallocation_dedup_20260827.json`.

Manual resolution is deterministic: `QM5_41174` weights squared time-rank
displacements, while this rule gives each of all 78 older/newer pairs one
sign vote. Rank vector `[9,8,7,2,6,4,1,10,3,12,5,13,11]` is Spearman-only
(`T=118`, `S=12`); `[1,6,13,3,7,4,12,8,10,5,9,2,11]` is this-rule-only
(`S=14`, `T=80`). WTI/XNG rank-trend builds use outright energy carriers,
follow the score, and own one position; this candidate fades a paired-metal
ratio and owns an atomic equal-notional package. Verdict:
`FUZZY_MATCH_RESOLVED_DISTINCT_XAUXAG_MONTHLY_ALL78_PAIR_RANK_S14_CONTRARIAN_BASKET`.

## Kill And Safety Boundary

Retire below five completed packages in any full post-warm-up year, at zero
trades, with nonpositive governed economics, or on any endpoint, score,
threshold, side, attempt, risk, atomicity, lifecycle, or determinism defect.
No result may be rescued by changing the sample, threshold, direction,
carrier, risk, hold, or by adding a filter.

Equal target notionals reduce common outright-metal direction but do not
prove neutrality or decorrelation; unchanged Q09 owns realized overlap. This
approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or live manifests;
portfolio-gate changes; portfolio admission; correlation waivers; terminal
control; and a second queue row. Q02 may be enqueued once only after a current
strict compile/review PASS and only below the factory CPU ceiling.
