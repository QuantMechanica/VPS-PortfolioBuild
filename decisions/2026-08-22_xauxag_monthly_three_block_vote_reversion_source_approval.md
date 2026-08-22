# XAU/XAG Completed-Month Three-Block Vote Reversion - Source Approval

Date: 2026-08-22

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and whole-host CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor` on 2026-08-22. The mission
asks for one new, non-duplicate, structural low-frequency commodity edge and
explicitly permits a market-neutral `XAUUSD`/`XAGUSD` gold/silver-ratio
reversion basket. It requires reputable-source criteria and `RISK_FIXED`
backtests and excludes live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-mthirdvote-rv`
- proposed strategy ID: `SCHWEIKERT-CME-XAUXAG-MTHIRDVOTE-RV-2026_S01`
- proposed source ID: `SCHWEIKERT-CME-XAUXAG-MTHIRDVOTE-RV-2026`
- carrier: exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX`, D1, one logical
  two-leg basket
- state: a strict majority of the three exhaustive chronological cumulative
  relative-return blocks inside the immediately completed calendar month
  shares one sign
- action: fade that majority-sign gold/silver-ratio displacement for the next
  broker-calendar month
- lifecycle: one persisted attempt per broker month and first-later-month flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following governed records were read completely before this approval:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, SHA-256
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`,
   which preserves named peer-reviewed DOI lineage for Karsten Schweikert
   (2018), *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, and supporting fractional-cointegration
   evidence from Yaya, Vo, and Olayinka (2021), *Resources Policy* 72, 102045,
   DOI `10.1016/j.resourpol.2021.102045`.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
   which records CME Group's definition of the gold/silver ratio, its
   intermarket-spread carrier, and the metals' differing monetary and
   industrial sensitivities.

No new online page, inaccessible content, inferred source table, or
unrecorded performance claim is used.

Schweikert supports testing a potentially state-dependent long-run
gold/silver relation rather than assuming one universal equilibrium. CME
supports treating gold and silver as an intermarket relative-value carrier.
Neither source tests three chronological blocks inside one completed month,
a magnitude-blind block-sign vote, a one-month fade, Darwinex continuous CFDs,
fixed cash risk, or equal-notional execution. Those are declared QM
falsification choices. No source return, density, hedge ratio, cost,
neutrality, or portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact host `XAUUSD.DWX`, exact companion `XAGUSD.DWX`, D1, slots
   zero and one, fixed-risk backtest inputs, both news axes OFF, and Friday
   close OFF.
2. On the first tradable synchronized D1 bar of a new broker-calendar month,
   within 180 elapsed minutes of its raw host-bar open, reconstruct the two
   immediately preceding consecutive completed calendar months. Require 17
   through 23 unique synchronized close pairs in each month and no current-
   month observation.
3. Let `P` be the parent month's chronological final synchronized log ratio
   and let `Q[0]...Q[n-1]` be every chronological ratio in the immediately
   completed month. Set `a=floor(n/3)` and `b=floor(2*n/3)`. Define
   `block_1=Q[a-1]-P`, `block_2=Q[b-1]-Q[a-1]`, and
   `block_3=Q[n-1]-Q[b-1]`. Shared ratios are endpoints and anchors, not
   duplicated returns, so every adjacent return from `P` through `Q[n-1]`
   belongs to exactly one block.
4. When at least two blocks are strictly positive, sell gold and buy silver.
   When at least two are strictly negative, buy gold and sell silver. Zero
   casts no vote. No strict majority, asynchronous history, mixed month
   labels, an invalid partition, or invalid endpoints consumes the month flat.
   Block magnitude and the full-month endpoint sign do not affect eligibility
   or sizing.
5. Persist the exact decision `yyyymm` attempt before every fallible
   downstream gate. Rejection, order failure, or restart cannot retry that
   broker month.
6. Size an equal-absolute-notional opposite-leg package so combined normalized
   hard-stop risk cannot exceed one `RISK_FIXED=1000` budget. Freeze a
   `3.5 * ATR(20,D1)` stop on each leg, reject notional mismatch above 20
   percent, and use no target.
7. Close both legs on the first tick of a later broker-calendar month or after
   forty calendar days. Malformed, orphaned, duplicated, same-side, stopless,
   or notional-invalid ownership flattens immediately. Never retry, trail,
   partially close, scale in, grid, martingale, pyramid, or read an external
   runtime feed.

## Non-Duplicate Decision

The fail-closed pre-allocation checker scanned 4,612 registry identities,
1,284 repository cards, and 45 Strategy-Wiki nodes. It found no exact
collision and one expected fuzzy family neighbor,
`QM5_41112_xauxag-mdaybreadth-rv`. Evidence:
`artifacts/qm5_xauxag_mthirdvote_rv_preallocation_dedup_20260822.json`.

Manual family review separates this identity from the fuzzy neighbor and the
nearest cards:

- `QM5_41112_xauxag-mdaybreadth-rv` counts every adjacent daily relative-
  return sign and requires a daily-sign majority plus full-month endpoint
  agreement. This candidate casts exactly three cumulative block votes and
  deliberately imposes no endpoint-agreement filter.
- `QM5_41113_xauxag-mhalfagree-rv` requires unanimity across two cumulative
  halves. This candidate accepts one opposing block through a strict
  two-of-three majority. The even/odd partition endpoints and eligible path
  sets therefore differ.
- `QM5_41115_wti-mthirdvote-mom` shares a three-block partition shape but is a
  single-symbol direct-WTI continuation trade. This candidate computes
  synchronized XAU-minus-XAG relative returns and opens the inverse
  equal-notional two-leg package.
- `QM5_20260_xauxag-mom-vote` votes cross-sectional one-, three-, and
  twelve-month return ranks and follows the winner. This candidate votes
  three non-overlapping blocks inside one month and fades the majority.
- `QM5_20275_gsr-runfade` classifies a fixed six-return rolling run rather than
  an exhaustive partition of one complete calendar month.
- `QM5_12577`, `QM5_20157`, `QM5_20161`, `QM5_20263`, and `QM5_20268`
  estimate a rolling center, regression, scale, robust score, or empirical
  tail. This candidate estimates none.
- `QM5_12533` supplies the validated logical-basket manifest/order recipe but
  trades a EURJPY/GBPJPY cointegration package.
- certified `QM5_12567_cum-rsi2-commodity` is a single-symbol, long-only,
  two-day XNG oscillator pullback with no paired intermetal state.

The exact paired carrier, consecutive completed calendar months,
17-to-23-session synchronization, parent-final ratio anchor, deterministic
floor-third endpoints, exhaustive non-overlapping cumulative-return blocks,
strict two-of-three sign vote, magnitude-blind contrarian package direction,
consumed monthly attempt, equal-notional aggregate-risk package, and next-
month exit are jointly load-bearing. Manual verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_THREE_EXHAUSTIVE_BLOCK_STRICT_MAJORITY_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_MONTHLY_THREE_BLOCK_TRANSLATION_RISK`: one bounded child
  source ID will preserve peer-reviewed DOI and official-exchange lineage;
  the untested three-block vote is disclosed and no performance result
  transfers.
- R2 `PASS`: synchronized month labels, endpoints, partition indices, return
  orientation, zero handling, strict vote, sides, attempt, risk, stops,
  spread, atomicity, and lifecycle are locked before testing.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered native
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state supply all runtime
  inputs; Q02 owns history, holiday attrition, density, cost, fill, financing,
  and CFD-basis sufficiency.
- R4 `PASS`: deterministic timestamps, completed prices, logarithms,
  indexing, arithmetic, comparisons, ATR, quotes, positions, deals, and
  terminal state only; no trained logic, banned signal, external feed, grid,
  martingale, scale-in, or pyramid.

## Portfolio Claim Boundary

The candidate is one symmetric long/short intermetal package designed to
reduce common outright-metal direction in the signal. Equal-notional opposite
legs are not proof of beta, factor, volatility, market, or portfolio
neutrality. Q09 alone may establish realized correlation with the certified
XAU/SP500/NDX/XNG book. This approval makes no decorrelation, admission, or
replacement claim.

## Kill And Safety Boundary

Expected cadence is approximately ten to twelve completed paired packages per
full post-warm-up year. Q02 must retire below five completed packages per full
year, at zero trades or nonpositive governed economics, or on any
synchronization, month-boundary, partition, endpoint, return-orientation,
zero-vote, side, attempt, risk, atomicity, lifecycle, or determinism defect.
No weak result may be rescued by moving the partition, changing session
bounds, weighting magnitudes, requiring endpoint agreement, changing
direction or hold, or adding a fitted center, volatility, volume, calendar,
event, external, or prior-result state.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization presets; terminal dispatch or control; AutoTrading; `T_Live`;
deploy or T_Live manifests; portfolio-gate changes; portfolio admission;
decorrelation claims; and correlation waivers. Q02 may be enqueued once only
after fresh exact-path tester and whole-host CPU checks are below their
ceilings. At the ceiling, stop before queue mutation and record a non-live
handoff.
