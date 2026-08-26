# QM5_41168 XAU/XAG Monthly Cox-Stuart Paired-Sign Reversion — G0 Decision

Date: 2026-08-26

Verdict: `APPROVED` at G0 for one non-live V5 build, strict Q01 validation,
and one paced logical-basket Q02 enqueue under the active factory resource
ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor`. It asks for one genuinely new structural,
low-frequency commodity/energy sleeve, explicitly permits a market-neutral-
style `XAUUSD~XAGUSD` ratio-reversion basket, requires reputable-source
criteria and `RISK_FIXED` backtests, and forbids live and portfolio-gate
mutations.

## Approved Identity

- EA: `QM5_41168`
- slug: `xauxag-mcoxstuart-rv`
- strategy ID:
  `SCHWEIKERT-COX-STUART-CME-XAUXAG-MPAIRSIGN-RV-2026_S01`
- source ID: `SCHWEIKERT-COX-STUART-CME-XAUXAG-MPAIRSIGN-RV-2026`
- slot 0: `XAUUSD.DWX`, D1, intended magic `411680000`
- slot 1: `XAGUSD.DWX`, D1, intended magic `411680001`
- logical tester symbol: `QM5_41168_XAU_XAG_MCOXSTUART_RV_D1`

The ID was not inferred. The atomic command
`python tools/strategy_farm/farmctl.py reserve-ea-ids --strategy-id
SCHWEIKERT-COX-STUART-CME-XAUXAG-MPAIRSIGN-RV-2026_S01 --slug
xauxag-mcoxstuart-rv` returned `reserved:true`, `count:1`, and EA ID `41168`
on 2026-08-26. Magic allocation remains a separate deterministic build
preflight after the EA directory exists.

## Source And Extraction Gate

The source of record is
`strategy-seeds/sources/SCHWEIKERT-COX-STUART-CME-XAUXAG-MPAIRSIGN-RV-2026/source.md`,
SHA-256 `3A33AE04B3326D763E0E851DFA66049B367D216D645E1E32FD1411B2E92759EB`.
Its durable source approval is
`decisions/2026-08-26_xauxag_monthly_cox_stuart_paired_sign_reversion_source_approval.md`,
committed as `d5e5a0c79` before this card extraction.

The bounded packet joins one canonical lineage from:

- Karsten Schweikert (2018), *Journal of Banking & Finance*, DOI
  `10.1016/j.jbankfin.2017.11.010`, plus official CME Group gold/silver ratio-
  spread research: state-dependent related-price evidence, an intermarket
  carrier, and economically different gold and silver demand drivers; and
- Cox and Stuart (1955), *Biometrika*, DOI
  `10.1093/biomet/42.1-2.80`, plus the official NIST Dataplot implementation:
  peer-reviewed trend-sign lineage and exact even-sample half-to-half pairing.

The original Cox-Stuart body is paywalled and not represented as completely
read. The exact fourteen-endpoint sample, 5-of-7 threshold, contrarian
direction, synchronized continuous CFDs, fixed risk, stops, spread caps,
atomic order sequence, attempt state, and lifecycle are disclosed QM
mechanizations. No source performance, conventional significance,
profitability, CFD equivalence, neutrality, or decorrelation claim transfers.

## G0 R1-R4 Decision

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: one governed source ID;
  named-author peer-reviewed gold/silver relationship evidence; official CME
  intermarket carrier research; an official peer-reviewed Cox-Stuart record;
  and a complete official NIST pairing description. The trading conjunction
  is explicitly untested.
- R2 `PASS`: fourteen consecutive synchronized month ends, seven fixed lag-
  seven comparisons, tie rejection, 5-of-7 contrarian sides, consumed month,
  aggregate fixed risk, hard stops, atomicity, rollover, and stale repair are
  deterministic.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  `XAUUSD.DWX` and `XAGUSD.DWX` D1 native histories plus MT5 state supply every
  runtime input.
- R4 `PASS`: fixed logarithms, comparisons, integer sign counts, calendar,
  ATR risk, and execution state only; no trained signal, banned signal
  indicator, adaptive PnL parameter, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Locked Baseline

At the first synchronized executable D1 tick of a genuine new broker month,
consume the month before any fallible gate. Reconstruct the latest exactly
timestamp-matched XAU/XAG close pair in each of the immediately prior fourteen
consecutive completed broker months, oldest to newest, excluding the current
month. Require a current prior-month endpoint, positive finite closes, strict
chronology, and no endpoint more than ten calendar days stale.

Form `s[i]=ln(XAU_close[i])-ln(XAG_close[i])`. For `i=0..6`, compute
`d[i]=s[i+7]-s[i]`. Any zero or nonfinite difference consumes the month flat.
At least five positive differences open SELL XAU / BUY XAG; at least five
negative differences open BUY XAU / SELL XAG; a 4/3 split is flat.

Open one equal-target-absolute-USD-notional package with aggregate
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, frozen per-leg
`3.5*ATR(20,D1)` hard stops, no targets, a 1,500-point XAU and 500-point XAG
spread cap, and at most 20% realized notional mismatch. Submit XAU first and
XAG second; flatten every owned leg after any package-validation failure.
Exit at the next broker-month boundary or after forty calendar days.

Both news axes, legacy news mode, and Friday close are OFF. No retry occurs in
the consumed month.

The 5-of-7 threshold was fixed without a market result. A fair independent-
sign thought experiment qualifies 58/128 sign paths, implying 5.4375 monthly
packages/year. That is a density prior only; Q02 must prove at least five
completed packages in every full post-warm-up year.

## Non-Duplicate Decision

The pre-allocation checker scanned 4,667 registry rows, 1,318 cards, and 45
Strategy Wiki nodes with verdict `CLEAN` and no exact or fuzzy match. Receipt:
`artifacts/qm5_xauxag_mcoxstuart_rv_preallocation_dedup_20260826.json`,
SHA-256 `B89423A13EFCE50F40FE8977561924FADA69281C8ACAFB475AEC6B8D701BE594`.

Manual review separates the candidate from:

- `QM5_41167`, which uses the same statistic on one outright WTI series,
  follows the sign, and owns one position; this candidate constructs and
  fades a synchronized two-metal ratio with atomic package semantics;
- `QM5_41157`, `QM5_41160`, `QM5_41164`, and `QM5_41166`, which retain
  magnitude through robust-slope geometry; this candidate discards magnitude
  after seven disjoint comparisons and fits no slope;
- endpoint, Mann-Kendall, quarterly-vote, within-month-half, sign-breadth,
  path, sequence, location, OLS, CADF, quantile, MAD, and z-score cards, which
  observe different state objects; and
- certified `QM5_12567`, which is a short-horizon long-only XNG oscillator
  pullback.

Two locked rank vectors prove functional separation. The first produces five
positive fixed pairs and a short-ratio action while latest-thirteen Mann-
Kendall, endpoint, and quarterly-vote neighbors do not share that action. The
second produces a 4/3 flat decision while those three neighbors qualify a
short-ratio action.

Verdict:
`CLEAN_XAUXAG_MONTHLY_COX_STUART_SEVEN_PAIR_FIVE_SIGN_RATIO_REVERSION`.

## Kill And Authorization Boundary

Q02 retires the candidate at zero trades, below five completed packages in any
full post-warm-up year, with nonpositive governed economics, or on any
timestamp, month, synchronization, ratio, pair, tie, count, side, attempt,
risk, atomicity, lifecycle, or determinism defect. No failed result may be
rescued by changing the sample, pairing, threshold, direction, carrier, risk,
stop, hold, spread cap, order sequence, or by adding another gate.

Opposite equal-notional legs are economically different from the stated
directional XAU/SP500/NDX/XNG book but do not prove low or negative realized
correlation. Q09 alone owns the overlap verdict. This decision does not
authorize a manual backtest; live, demo, shadow, stress, or optimization
setfile; AutoTrading; `T_Live`; deploy or live manifest; portfolio-gate
change; portfolio admission; correlation waiver; terminal control; or a
second Q02 row.
