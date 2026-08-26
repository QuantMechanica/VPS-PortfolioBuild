# QM5_41167 WTI Monthly Cox-Stuart Paired-Sign Trend — G0 Authorization

Date: 2026-08-26

Verdict: `APPROVED` at G0 for one non-live V5 build, strict Q01 validation,
and one paced Q02 enqueue under the current factory resource ceiling.

Authority: the current explicit OWNER commodity/energy portfolio mission on
`agents/board-advisor`. It asks for one genuinely new structural,
low-frequency commodity/energy sleeve, permits a WTI trend/seasonality edge,
requires reputable-source criteria and `RISK_FIXED` backtests, and forbids
live and portfolio-gate mutations.

## Approved Identity

- EA: `QM5_41167`
- slug: `wti-coxstuart-tr`
- strategy ID: `MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026_S01`
- source ID: `MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026`
- slot 0: `XTIUSD.DWX`, D1, intended magic `411670000`

The ID was not inferred. The atomic command
`farmctl reserve-ea-ids --strategy-id
MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026_S01 --slug wti-coxstuart-tr`
returned `reserved:true`, `count:1`, and EA ID `41167` on 2026-08-26.
Magic allocation remains a separate deterministic build preflight.

## Source And Extraction Gate

The source of record is
`strategy-seeds/sources/MOP-COX-STUART-WTI-MPAIRSIGN-TREND-2026/source.md`,
SHA-256 `7E0D0F9595CCBDB2CA2B2FEDD02BE2E969CC129CE293C48F44C42BDDC9CBC629`.
Its durable source approval is
`decisions/2026-08-26_wti_monthly_cox_stuart_paired_sign_trend_source_approval.md`,
committed as `4501c361a9` before this card extraction.

The bounded packet joins one canonical lineage, the governed composite source
ID above, from:

- Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*, DOI
  `10.1016/j.jfineco.2011.11.003`: complete-paper provenance, monthly
  own-price continuation, and explicit NYMEX WTI membership; and
- Cox and Stuart (1955), *Biometrika*, DOI
  `10.1093/biomet/42.1-2.80`, plus the official NIST Dataplot implementation:
  peer-reviewed trend-sign lineage and exact half-sample pairing.

The original Cox-Stuart body is paywalled and not represented as completely
read. The exact 14-endpoint sample, 5-of-7 trading boundary, continuous CFD,
fixed risk, stop, spread cap, attempt state, and lifecycle are disclosed QM
mechanizations. No source performance, WTI-only efficacy, conventional
significance, CFD equivalence, or decorrelation claim transfers.

## G0 R1-R4 Decision

- R1 `PASS_WITH_METHOD_AND_CARRIER_TRANSLATION_RISK`: exactly one governed
  source ID; complete-read tier-A WTI trading evidence; official peer-reviewed
  method record; and complete official NIST pairing description. The trading
  conjunction is explicitly untested.
- R2 `PASS`: fourteen consecutive completed month ends, seven fixed lag-seven
  comparisons, tie rejection, 5-of-7 direction, month-consume order, fixed
  risk, hard stop, rollover, and stale repair are deterministic.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 native
  history and MT5 state supply every runtime input.
- R4 `PASS`: fixed logarithms, comparisons, sign counts, calendar, ATR risk,
  and execution state only; no trained signal, banned signal indicator,
  adaptive PnL parameter, external runtime feed, grid, martingale, scale-in,
  or pyramid; one position per magic.

## Locked Baseline

At the first executable D1 tick of a genuine new broker month, consume the
month before any fallible gate. Reconstruct the latest close in each of the
immediately prior fourteen consecutive completed broker months, oldest to
newest, excluding the current month. Require a current prior-month endpoint,
positive finite closes, strict chronology, and no endpoint more than ten
calendar days stale.

For `i=0..6`, calculate `d[i]=ln(C[i+7])-ln(C[i])`. Any zero or nonfinite
difference consumes the month flat. Buy when at least five differences are
positive; sell when at least five are negative; a 4/3 split is flat. Open one
WTI position with `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`, a frozen `3.5*ATR(20,D1)` hard stop, no target, and a
1,500-point entry-spread cap. Exit at the next broker-month boundary or after
forty calendar days.

Both news axes, legacy news mode, and Friday close are OFF. No retry occurs in
the consumed month.

The 5-of-7 boundary was fixed without a market result. A fair independent-sign
thought experiment qualifies 58/128 sign paths, implying 5.4375 monthly
decisions/year. That is a density prior only; Q02 must prove at least five
completed positions in every full post-warm-up year.

## Non-Duplicate Decision

The pre-allocation checker scanned 4,666 registry rows, 1,317 cards, and 45
Strategy Wiki nodes with verdict `CLEAN` and no exact or fuzzy match. Receipt:
`artifacts/qm5_wti_coxstuart_tr_preallocation_dedup_20260826.json`, SHA-256
`60CFBF3306A8EC69CD34B439D8EDFF300B05BB644E705D89224FAE0C94ABE8B7`.

Manual review separates the candidate from:

- `QM5_20264`: every-pair Mann-Kendall score over thirteen endpoints;
- `QM5_20272`: four non-overlapping three-month return blocks;
- `QM5_41114`: two cumulative daily-return halves inside one month;
- `QM5_41165`: magnitude-sensitive Theil-Sen/LAD/repeated-median slopes; and
- `QM5_12567`: long-only two-day XNG cumulative-RSI pullback.

The two locked vectors in the source approval prove both directions of
functional separation: one makes Cox-Stuart buy while endpoint,
Mann-Kendall, and quarterly-vote neighbors do not buy; another makes
Cox-Stuart flat while all three neighbors buy.

Verdict: `CLEAN_WTI_MONTHLY_COX_STUART_SEVEN_PAIR_FIVE_SIGN_TREND`.

## Kill And Authorization Boundary

Q02 retires the candidate at zero trades, below five completed positions in
any full post-warm-up year, with nonpositive governed economics, or on any
month, endpoint, pair, tie, count, side, attempt, risk, stop, lifecycle, or
determinism defect. No failed result may be rescued by changing the sample,
pairing, threshold, direction, carrier, stop, hold, or adding another gate.

Direct WTI exposure is economically different from the stated
XAU/SP500/NDX/XNG book, but realized correlation is unknown and Q09 alone owns
that verdict. This decision does not authorize a manual backtest; live, demo,
shadow, stress, or optimization setfile; AutoTrading; `T_Live`; deploy or
live manifest; portfolio-gate change; portfolio admission; correlation
waiver; terminal control; or a second Q02 row.
