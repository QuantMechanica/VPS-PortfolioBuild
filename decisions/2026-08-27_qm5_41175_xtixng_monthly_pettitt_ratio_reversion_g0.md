# QM5_41175 XTI/XNG Monthly Pettitt Ratio Reversion - G0 Decision

Date: 2026-08-27

Verdict: `APPROVED` at G0 for one non-live V5 build, strict Q01 validation,
and one paced logical-basket Q02 enqueue under the active factory resource
ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor`, bounded by the durable source approval at
`decisions/2026-08-27_xtixng_monthly_pettitt_ratio_reversion_source_approval.md`.
The mission asks for one genuinely new structural, low-frequency commodity
sleeve, requires reputable-source criteria and `RISK_FIXED` backtests, and
forbids live and portfolio-gate mutations.

## Approved Identity

- EA: `QM5_41175`
- slug: `xtixng-mpettitt-rv`
- strategy ID: `VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026_S01`
- source ID: `VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026`
- slot 0: `XTIUSD.DWX`, D1, intended magic `411750000`
- slot 1: `XNGUSD.DWX`, D1, intended magic `411750001`
- logical tester symbol: `QM5_41175_XTI_XNG_MPETTITT_RV_D1`
- canonical card:
  `strategy-seeds/cards/approved/QM5_41175_xtixng-mpettitt-rv_card.md`

The ID was not inferred or hand-written into the registry. The atomic command
`python tools/strategy_farm/farmctl.py reserve-ea-ids --slug
xtixng-mpettitt-rv --strategy-id
VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026_S01 --owner
"Research+Development (OWNER commodity/energy portfolio mission 2026-08-27)"
--created-at 2026-08-27 --start-after 41174` returned `reserved:true`,
`count:1`, and EA ID `41175`. Magic allocation remains a separate
deterministic build preflight after the EA directory exists.

## Source And Extraction Gate

Source approval commit: `39aeee243`.

The source of record is
`strategy-seeds/sources/VILLAR-PETTITT-XTIXNG-MSHIFT-RV-2026/source.md`,
SHA-256 `4919B9F71CEAA0D38FF22117A7E1AEBB419022B096FDFCD022D5311187A002B1`.
It joins one bounded lineage from:

- Villar and Joutz's complete U.S. EIA oil/gas report, Ramberg and Parsons'
  complete peer-reviewed *Energy Journal* article and adverse modern EIA
  evidence: a time-varying, weak oil/gas relationship without a permanent
  fixed ratio; and
- A. N. Pettitt's named peer-reviewed method record plus complete pinned CRAN
  `trend` 1.1.7 files: exact ranks, cumulative rank sums, maximum absolute
  path value, and change-point location.

The original Pettitt body is not represented as completely read. The exact
thirteen-endpoint sample, central band, contrarian direction, synchronized
continuous CFDs, equal-notional target, fixed risk, stops, atomic sequence,
attempt state, and lifecycle are disclosed QM mechanizations. No source
performance, significance, profitability, CFD equivalence, neutrality, or
decorrelation claim transfers.

Both `skill_card_schema_lint.py` and `skill_g0_card_lint.py` must return
`status: ok` before build.

## G0 R1-R4 Decision

- R1 `PASS_WITH_RELATION_AND_METHOD_TRANSLATION_RISK`: complete government
  and peer-reviewed oil/gas relationship evidence including adverse findings,
  a named original Pettitt record, and complete pinned CRAN method files. The
  trading conjunction is explicitly untested.
- R2 `PASS`: thirteen consecutive synchronized month ends, strict ranks,
  every cumulative rank sum, unique central maximum, contrarian sides,
  consumed month, aggregate fixed risk, hard stops, atomicity, rollover, and
  stale repair are deterministic.
- R3 `PASS_WITH_CALENDAR_SYNCHRONIZATION_AND_CFD_BASIS_RISK`: registered
  `XTIUSD.DWX` and `XNGUSD.DWX` D1 native histories plus MT5 state supply every
  runtime input.
- R4 `PASS`: logarithms, ranks, integer arithmetic, calendar, ATR risk, and
  execution state only; no trained signal, prohibited runtime feed, adaptive
  PnL parameter, grid, martingale, scale-in, or pyramid.

## Locked Baseline

At the first synchronized executable D1 tick of a genuine new broker month,
consume the month before any fallible gate. Reconstruct the latest exactly
timestamp-matched XTI/XNG close pair in each of the immediately prior
thirteen consecutive completed broker months, oldest to newest, excluding the
current month. Require a current prior-month endpoint, positive finite closes,
strict chronology, pairwise-distinct log ratios, and no endpoint more than ten
calendar days stale.

Form `s[i]=ln(XTI_close[i])-ln(XNG_close[i])`, assign strict ranks `R[i]`, and
compute `U[k]=2*sum(R[0..k-1])-14*k` for `k=1..12`. Require the exact
permutation 1..13, even `U[k]` in `[-42,42]`, one and only one absolute
maximum, and `4<=K<=9`. If `U[K]<0`, SELL XTI and BUY XNG. If `U[K]>0`, BUY
XTI and SELL XNG. Otherwise consume the month flat. No p-value, average-rank
tie handling, fitted hedge, center, scale, or fallback is allowed.

Open one equal-target-absolute-USD-notional package with aggregate
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, frozen per-leg
`3.5*ATR(20,D1)` hard stops, no targets, a 1,500-point XTI and 3,000-point XNG
spread cap, and at most 20% realized notional mismatch. Submit XTI first and
XNG second; flatten every owned leg after any package-validation failure.
Exit at the next broker-month boundary or after forty calendar days.

Both news axes, legacy news mode, and Friday close are OFF. No retry occurs in
the consumed month. Q02 must prove at least four completed packages in every
full post-warm-up year.

## Non-Duplicate Decision

The pre-allocation checker scanned 4,674 registry rows, 1,325 cards, and 45
Strategy Wiki nodes with verdict `CLEAN` and no exact or fuzzy match. Receipt:
`artifacts/qm5_xtixng_mpettitt_rv_preallocation_dedup_20260827.json`, SHA-256
`03FECB559F3EC214799DDF8D7A570D7479B23A8C6C26C652EFDF1620174DBACB`.

Manual review separates the candidate from:

- `QM5_41172`, which applies Pettitt to one outright WTI series, follows the
  sign, and owns one position; this candidate constructs and fades a
  synchronized oil/gas ratio with atomic package semantics;
- `QM5_20237`, which fits a 252-D1 trend-augmented OLS residual and trades a
  z-score crossing; this candidate has no regression, fitted beta, center, or
  scale and consumes thirteen completed month ends;
- fixed oil/gas ratio, return-spread, channel, momentum, carry, same-calendar,
  tail, volatility, factor-rank, and weekday baskets, which use different
  state objects or clocks; and
- certified `QM5_12567`, which is a short-horizon long-only XNG oscillator
  pullback.

Verdict:
`CLEAN_XTIXNG_MONTHLY_PETTITT_UNIQUE_CENTRAL_RATIO_SHIFT_CONTRARIAN_BASKET`.

## Kill And Authorization Boundary

Q02 retires the candidate at zero trades, below four completed packages in
any full post-warm-up year, with nonpositive governed economics, or on any
timestamp, month, synchronization, ratio, rank, split, side, attempt, risk,
atomicity, lifecycle, or determinism defect. No failed result may be rescued
by changing the sample, central band, direction, carrier, risk, stop, hold,
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
