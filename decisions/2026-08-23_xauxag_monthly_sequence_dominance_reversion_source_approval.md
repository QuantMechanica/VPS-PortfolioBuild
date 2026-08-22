# XAU/XAG Completed-Month Sequence-Dominance Reversion - Source Approval

Date: 2026-08-23

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID and magic allocation, one branch-only non-live build, strict Q01
validation, and one paced target-only Q02 enqueue if tester and whole-host CPU
ceilings permit. This decision does not authorize a manual tester dispatch.

Authority: the current explicit OWNER commodity/energy portfolio mission
delivered to Codex on branch `agents/board-advisor` on 2026-08-23. The mission
asks for one new, non-duplicate, structural low-frequency commodity edge and
explicitly permits a market-neutral `XAUUSD`/`XAGUSD` gold/silver-ratio
reversion basket. It requires reputable-source criteria and `RISK_FIXED`
backtests and excludes live and portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xauxag-mseqdom-rv`
- proposed strategy ID:
  `SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026_S01`
- proposed source ID:
  `SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026`
- carrier: exact synchronized `XAUUSD.DWX` and `XAGUSD.DWX`, D1, one logical
  two-leg basket
- state: the immediately completed broker-calendar month's chronological
  nonzero relative-return signs contain at least as many same-sign adjacent
  sequences as opposite-sign reversals
- action: fade the completed month's net gold/silver log-ratio displacement
  with opposite equal-notional metal legs for the next broker-calendar month
- lifecycle: one persisted attempt per broker month and first-later-month flat

The deterministic allocator owns the EA ID. This record neither reserves nor
predicts an ID.

## Approved Source Basis

The following governed records and primary paper were read completely before
this approval:

1. `strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`, SHA-256
   `4C7DC1741F96502ED1D53FDFD5252E61E2632003C43AF30028ACA3F4125E976B`,
   which preserves named peer-reviewed DOI lineage for Karsten Schweikert
   (2018), *Journal of Banking & Finance* 88, 44-51, DOI
   `10.1016/j.jbankfin.2017.11.010`, and supporting fractional-cointegration
   evidence from Yaya, Vo, and Olayinka (2021), *Resources Policy* 72,
   102045, DOI `10.1016/j.resourpol.2021.102045`.
2. `strategy-seeds/sources/CME-GSR-SPREAD-2025/source.md`, SHA-256
   `2B5903457BD861771821A81F554BE95CA369AD56C1AA45494E0B81555493AF93`,
   which records CME Group's definition of the gold/silver ratio, its
   intermarket-spread carrier, and the metals' differing monetary and
   industrial sensitivities.
3. Alfred Cowles 3rd and Herbert E. Jones (1937), "Some A Posteriori
   Probabilities in Stock Market Action," *Econometrica* 5(3), 280-294, DOI
   `10.2307/1905515`. The complete fifteen-page primary paper was read from
   Yale's Cowles archive at
   `https://economics.yale.edu/sites/default/files/2022-08/cowles-posteriori37.pdf`;
   downloaded bytes had SHA-256
   `4C7D4FCF2E5CB7C25BCB06B9B503E4D1560759197F5C29EA47B4AD23B9B2155C`.

The bounded child extraction will be
`strategy-seeds/sources/SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026/source.md`.

Schweikert supports testing a potentially state-dependent long-run
gold/silver relation rather than assuming one universal equilibrium. CME
supports treating gold and silver as an intermarket relative-value carrier.
Cowles and Jones define a sequence as two consecutive price changes with the
same sign and a reversal as consecutive changes with opposite signs, then use
their counts to inspect time-series structure. They also warn that their
selected monthly interval was chosen with hindsight and that realized profits
were not consistent.

None of the sources tests within-month sequence dominance on a gold/silver
ratio, a contrarian next-month action, continuous CFDs, fixed cash risk, or
equal-notional execution. Cowles and Jones study stock-price series, not
precious-metal spreads, and their reported direction is persistence rather
than this candidate's exhaustion fade. The carrier, statistic, action, and
execution are therefore joined only as a declared QM falsification hypothesis.
No source return, density, threshold, hedge ratio, cost, neutrality, or
portfolio-correlation result transfers.

## Locked Mechanic

1. Require exact host `XAUUSD.DWX`, exact companion `XAGUSD.DWX`, D1, slots
   zero and one, fixed-risk backtest inputs, both news axes OFF, and Friday
   close OFF.
2. On the first tradable synchronized D1 bar of a new broker-calendar month,
   within 180 elapsed minutes of its raw host-bar open, reconstruct every
   synchronized close pair in the immediately completed calendar month.
   Require 17 through 23 unique timestamp-identical positive close pairs and
   no current-month observation.
3. Order the completed-month gold-minus-silver log ratios oldest to newest:
   `s[i]=ln(XAU_close[i])-ln(XAG_close[i])`, `i=0..n-1`. Form the `m=n-1`
   adjacent relative returns `r[j]=s[j]-s[j-1]`, `j=1..n-1`. Every return
   must be finite and nonzero; one exact zero consumes the month flat.
4. Across the `m-1=n-2` adjacent return-sign transitions, count
   `sequences=count(sign(r[j])==sign(r[j-1]))` and
   `reversals=count(sign(r[j])!=sign(r[j-1]))` for `j=2..n-1`. Require the
   exhaustive identity `sequences+reversals=n-2` and accept only
   `sequences>=reversals`.
5. Let `net=s[n-1]-s[0]`. For qualifying sequence dominance, `net>0` opens
   SELL XAU / BUY XAG and `net<0` opens BUY XAU / SELL XAG. Exact-zero net,
   reversal dominance, zero component returns, or malformed history consumes
   the month flat. Sequence surplus and net magnitude never alter direction,
   sizing, stops, or lifecycle.
6. Persist the exact decision `yyyymm` attempt before every fallible
   downstream gate. Rejection, order failure, or restart cannot retry that
   broker month.
7. Size an equal-absolute-notional opposite-leg package so combined normalized
   hard-stop risk cannot exceed one `RISK_FIXED=1000` budget. Freeze a
   `3.5 * ATR(20,D1)` stop on each leg, reject notional mismatch above 20
   percent, and use no target.
8. Close both legs on the first tick of a later broker-calendar month or after
   forty calendar days. Malformed, orphaned, duplicated, same-side, stopless,
   or notional-invalid ownership flattens immediately. Never retry, trail,
   partially close, scale in, grid, martingale, pyramid, or read an external
   runtime feed.

## Sequence Arithmetic Contract

For `n=17..23` synchronized close pairs, there are `m=16..22` nonzero
relative returns and `n-2=15..21` exhaustive adjacent sign transitions. A
sequence is exactly a same-sign transition; a reversal is exactly an
opposite-sign transition. The inclusive majority `sequences>=reversals` is a
fixed integer rule. When `n-2` is even, equality qualifies; when it is odd,
equality is impossible. The direction comes only from the completed month's
first-to-last log-ratio displacement after the persistence state qualifies.

There is no rolling center, fitted scale, return magnitude threshold,
price-distance threshold, current-month price, future price, p-value, or
optimization surface. Cowles-Jones significance calculations and reported
profit estimates are not reproduced or imported.

## Non-Duplicate Decision

The fail-closed pre-allocation checker used the proposed slug, strategy ID,
named source authors, complete mechanic, and actual Company Reference Wiki
root. It scanned 4,620 registry identities, 1,289 repository cards, and 45
Strategy-Wiki nodes, found no exact or fuzzy match, and returned `CLEAN`.
Evidence:
`artifacts/qm5_xauxag_mseqdom_rv_preallocation_dedup_20260823.json`.

Manual semantic review fixes the closest-family boundaries:

- `QM5_20275_gsr-runfade` requires a fresh terminal run of five consecutive
  same-sign D1 relative returns and exits on ratio-center reversion or a short
  time stop. This candidate classifies every adjacent sign transition in one
  completed calendar month, does not require a terminal run, uses net monthly
  direction, and exits only on the next month or stale repair.
- `QM5_41078_xauxag-wstreak3-rv` uses three consecutive completed weekly
  ratio-direction observations. This candidate uses all daily relative-return
  transitions inside one completed month and an inclusive sequence/reversal
  majority rather than one fixed streak.
- `QM5_41112_xauxag-mdaybreadth-rv` counts positive and negative adjacent
  returns without regard to their order. This candidate is invariant to the
  count imbalance only when chronology yields the same sequence/reversal
  state; permuting identical signs can reverse its verdict.
- `QM5_41113_xauxag-mhalfagree-rv` and
  `QM5_41116_xauxag-mthirdvote-rv` aggregate magnitudes into two or three
  fixed calendar blocks. This candidate ignores magnitudes after sign and
  evaluates every adjacent transition without block sums.
- `QM5_41120_xauxag-mopen-residence-rv` counts close levels against one fixed
  first-close anchor. This candidate counts return-sign adjacency and uses the
  first close only to determine final net direction.
- rolling ratio and residual systems estimate a center, regression, scale,
  score, or empirical tail; this candidate estimates none.
- `QM5_12533` supplies the validated logical-basket manifest/order recipe but
  trades an EURJPY/GBPJPY cointegration package.
- certified `QM5_12567_cum-rsi2-commodity` is a single-symbol, long-only,
  two-day XNG oscillator pullback with no paired intermetal state.

The exact paired carrier, immediately completed calendar month,
17-to-23-session synchronization, chronological nonzero relative-return signs,
exhaustive sequence/reversal transitions, fixed inclusive sequence majority,
contrarian net-month package, consumed monthly attempt, equal-notional
aggregate-risk package, and next-month exit are jointly load-bearing. Manual
verdict:
`CLEAN_XAUXAG_COMPLETED_MONTH_SEQUENCE_DOMINANCE_REVERSION_AFTER_FAMILY_REVIEW`.

## Reputable-Source Criteria

- R1 `PASS_WITH_CROSS_ASSET_SEQUENCE_AND_DIRECTION_TRANSLATION_RISK`:
  peer-reviewed gold/silver DOI lineage, an official-exchange carrier, and a
  completely read primary *Econometrica* method paper with durable hashes;
  the equity-to-metals and persistence-to-exhaustion translations are explicit
  and no result transfers.
- R2 `PASS`: synchronized month membership, chronology, nonzero return signs,
  exhaustive transition arithmetic, inclusive majority, net direction, pair
  sides, attempt, risk, stops, atomicity, and lifecycle are locked before
  testing.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  native `XAUUSD.DWX` and `XAGUSD.DWX` D1 histories plus MT5 state supply
  every runtime input; Q02 owns history, holiday attrition, density, costs,
  fills, financing, and CFD-basis sufficiency.
- R4 `PASS`: deterministic timestamps, completed prices, logarithms, signs,
  integer counts, comparisons, ATR, quotes, positions, deals, and terminal
  state only; no trained logic, banned signal, external feed, grid,
  martingale, scale-in, or pyramid.

## Frequency, Portfolio Claim, And Falsification

The fixed inclusive sequence-majority state is expected to select
approximately six to eight completed paired packages per full post-warm-up
year. This is a symmetric-sign cadence prior, not test evidence. Q02 retires
below the unchanged five-trades/year/symbol floor, at zero trades or
nonpositive governed economics, or on any synchronization, month, ordering,
zero-return, transition-count, majority, net-direction, attempt, risk,
atomicity, lifecycle, or determinism defect.

The opposite equal-notional legs are intended to suppress common outright-
metal direction. They do not prove beta, factor, volatility, market, or
portfolio neutrality. Q09 alone may establish realized correlation with the
certified XAU/SP500/NDX/XNG book. No decorrelation, admission, replacement, or
waiver claim is made here.

No weak result may be rescued by changing the inclusive majority, assigning
zero returns a sign, reversing the side, changing the hold, loosening session
bounds, or adding a fitted center, scale, magnitude, volatility, volume,
calendar, event, external, or prior-result state.

## Implementation And Safety Boundary

Only one logical D1 backtest preset is permitted, with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `ENV=backtest`. No live, demo, shadow, stress, or
optimization preset is authorized. This approval forbids manual backtests,
terminal control, AutoTrading, `T_Live`, deploy or T_Live manifest mutation,
portfolio-gate changes, portfolio admission, decorrelation claims, and
correlation waivers. Strict Q01 must precede one Q02 enqueue, and the fresh
tester/host-CPU ceiling remains fail closed.
