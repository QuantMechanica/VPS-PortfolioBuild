# QM5_41174 XAU/XAG Monthly Spearman Rank Reversion - G0 Decision

Date: 2026-08-27

Verdict: `APPROVED` at G0 for one non-live V5 build, strict Q01 validation,
and one paced logical-basket Q02 enqueue under the active factory resource
ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor`, bounded by the durable source approval at
`decisions/2026-08-27_xauxag_monthly_spearman_rank_reversion_source_approval.md`.
The mission asks for one genuinely new structural, low-frequency commodity
sleeve, expressly permits a market-neutral-style `XAUUSD~XAGUSD` basket,
requires reputable-source criteria and `RISK_FIXED` backtests, and forbids
live and portfolio-gate mutations.

## Approved Identity

- EA: `QM5_41174`
- slug: `xauxag-mspearman-rv`
- strategy ID:
  `SCHWEIKERT-SPEARMAN-CME-XAUXAG-MRANK-RV-2026_S01`
- source ID: `SCHWEIKERT-SPEARMAN-CME-XAUXAG-MRANK-RV-2026`
- slot 0: `XAUUSD.DWX`, D1, intended magic `411740000`
- slot 1: `XAGUSD.DWX`, D1, intended magic `411740001`
- logical tester symbol: `QM5_41174_XAU_XAG_MSPEARMAN_RV_D1`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41174_xauxag-mspearman-rv_card.md`

The ID was not inferred or hand-written into the registry. The atomic command
`python tools/strategy_farm/farmctl.py reserve-ea-ids --slug
xauxag-mspearman-rv --strategy-id
SCHWEIKERT-SPEARMAN-CME-XAUXAG-MRANK-RV-2026_S01 --start-after 41173`
returned `reserved:true`, `count:1`, and EA ID `41174` on 2026-08-27. Magic
allocation remains a separate deterministic build preflight after the EA
directory exists.

## Source And Extraction Gate

Source approval commit: `6d967cde8`.

The source of record is
`strategy-seeds/sources/SCHWEIKERT-SPEARMAN-CME-XAUXAG-MRANK-RV-2026/source.md`,
SHA-256 `FBE965262B3FC03F1EEB3BBDE4151A22A1A81F52DB9220BCBFB4BAB7F4B5CE4E`.
It joins one bounded lineage from:

- Karsten Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
  `10.1016/j.jbankfin.2017.11.010`, plus official CME Group gold/silver
  ratio-spread research: state-dependent related-price evidence, a tradable
  intermarket carrier, and economically different metal demand drivers; and
- C. Spearman (1904), *The American Journal of Psychology* 15(1), DOI
  `10.2307/1412159`, plus complete pinned R Core `stats::cor` source and manual
  from public mirror commit
  `7344a2d9d96b3c2b997535d3abc8c3a44af16e82`: named rank-correlation lineage
  and exact rank-transform-then-correlation arithmetic.

The original Spearman body is not represented as completely read. The exact
thirteen-endpoint sample, score boundary, contrarian direction, synchronized
continuous CFDs, equal-notional target, fixed risk, stops, atomic sequence,
attempt state, and lifecycle are disclosed QM mechanizations. No source
performance, conventional significance, profitability, CFD equivalence,
neutrality, or decorrelation claim transfers.

Both `skill_card_schema_lint.py` and `skill_g0_card_lint.py` must return
`status: ok` before build.

## G0 R1-R4 Decision

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: named-author,
  peer-reviewed gold/silver relationship evidence; official CME carrier
  research; named original Spearman record; and complete pinned R Core method
  files. The trading conjunction is explicitly untested.
- R2 `PASS`: thirteen consecutive synchronized month ends, strict ranks,
  exact D/T invariants, integer threshold, contrarian sides, consumed month,
  aggregate fixed risk, hard stops, atomicity, rollover, and stale repair are
  deterministic.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 native histories plus MT5 state supply every
  runtime input.
- R4 `PASS`: logarithms, ranks, integer arithmetic, calendar, ATR risk, and
  execution state only; no trained signal, prohibited runtime feed, adaptive
  PnL parameter, grid, martingale, scale-in, or pyramid.

## Locked Baseline

At the first synchronized executable D1 tick of a genuine new broker month,
consume the month before any fallible gate. Reconstruct the latest exactly
timestamp-matched XAU/XAG close pair in each of the immediately prior
thirteen consecutive completed broker months, oldest to newest, excluding the
current month. Require a current prior-month endpoint, positive finite closes,
strict chronology, pairwise-distinct log ratios, and no endpoint more than ten
calendar days stale.

Form `s[i]=ln(XAU_close[i])-ln(XAG_close[i])`, assign strict ranks `R[i]`, and
compute `D=sum((R[i]-(i+1))^2)` and `T=364-D`. Require the exact permutation
1..13, `0<=D<=728`, `-364<=T<=364`, and even D/T. If `T>=104`, SELL XAU and
BUY XAG. If `T<=-104`, BUY XAU and SELL XAG. Otherwise consume the month flat.
This is exactly `abs(rho)>=2/7`; no p-value, average-rank tie handling, fitted
hedge, center, scale, or fallback is allowed.

Open one equal-target-absolute-USD-notional package with aggregate
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, frozen per-leg
`3.5*ATR(20,D1)` hard stops, no targets, a 1,500-point XAU and 500-point XAG
spread cap, and at most 20% realized notional mismatch. Submit XAU first and
XAG second; flatten every owned leg after any package-validation failure.
Exit at the next broker-month boundary or after forty calendar days.

Both news axes, legacy news mode, and Friday close are OFF. No retry occurs in
the consumed month.

Exact enumeration of every 13! no-tie rank path gives a two-tail
qualification rate of `0.3436382463986631`, approximately 4.12 qualified
months/year. This is a pre-result density design fact only. Q02 must prove at
least four completed packages in every full post-warm-up year.

## Non-Duplicate Decision

The pre-allocation checker scanned 4,673 registry rows, 1,324 cards, and 45
Strategy Wiki nodes with verdict `CLEAN` and no exact or fuzzy match. Receipt:
`artifacts/qm5_xauxag_mspearman_rv_preallocation_dedup_20260827.json`,
SHA-256 `7C6C2348095D17941118509E84F3E8A5F6C62FCFD684875AC7176397F40469B8`.

Manual review separates the candidate from:

- `QM5_41173`, which uses the same statistic on one outright WTI series,
  follows the sign, and owns one position; this candidate constructs and
  fades a synchronized two-metal ratio with atomic package semantics;
- `QM5_41168`, which uses fourteen ratios and seven fixed Cox-Stuart
  half-sample comparisons; this candidate uses thirteen ratios and every
  observation's exact time-rank displacement;
- XAU/XAG z-score, OLS, CADF, quantile, MAD, variance-ratio, endpoint,
  quarterly-vote, Theil-Sen, LAD, repeated-median, and robust-consensus cards,
  which observe different state objects; and
- certified `QM5_12567`, which is a short-horizon long-only XNG oscillator
  pullback.

Two locked rank vectors prove separation from the closest all-pairs rank
neighbor. `[3,2,10,1,4,12,11,8,7,9,6,5,13]` gives Spearman `T=170` but
Mann-Kendall `S=20`; `[13,1,4,12,5,2,3,6,7,8,9,10,11]` gives Spearman
`T=98` but Mann-Kendall `S=28`.

Verdict:
`CLEAN_XAUXAG_MONTHLY_SPEARMAN_TIME_RATIO_RANK_T104_CONTRARIAN_BASKET`.

## Kill And Authorization Boundary

Q02 retires the candidate at zero trades, below four completed packages in
any full post-warm-up year, with nonpositive governed economics, or on any
timestamp, month, synchronization, ratio, rank, score, side, attempt, risk,
atomicity, lifecycle, or determinism defect. No failed result may be rescued
by changing the sample, threshold, direction, carrier, risk, stop, hold,
spread cap, order sequence, or by adding another gate.

Opposite equal-notional legs are economically different from the stated
directional XAU/SP500/NDX/XNG book but do not prove low or negative realized
correlation. Q09 alone owns the overlap verdict. Q02 may be enqueued exactly
once only after a current strict compile/Q01 PASS and independent review PASS.
If the backtest CPU ceiling is binding, stop without tester dispatch or
terminal control and preserve the committed build state.

This decision does not authorize a manual backtest; live, demo, shadow,
stress, or optimization setfile; AutoTrading; `T_Live`; deploy or live
manifest; portfolio-gate change; portfolio admission; correlation waiver;
terminal control; or a second Q02 row.
