# QM5_20257_wti-vr12-mom — Strategy Spec

## Identity

- EA ID: QM5_20257
- Slug: wti-vr12-mom
- Strategy ID: MEHLITZ-AUER-MEM-2024_XTI_R12Q13_S04
- Symbol / slot: XTIUSD.DWX / 0
- Timeframe: D1
- Magic: 202570000
- Canonical card: strategy-seeds/cards/approved/QM5_20257_wti-vr12-mom_card.md

## Strategy Logic

At the first processed XTI D1 bar of a genuine new broker month, the EA
reconstructs 33 consecutive completed month-end closes and 32 chronological
monthly log returns. It computes the source-declared Mehlitz-Auer R12-q13 state:

- R12 is the sum of the latest twelve completed monthly log returns.
- VR(13) is `1 + 24/13*rho(1) + 22/13*rho(2) + 20/13*rho(3) +
  18/13*rho(4) + 16/13*rho(5) + 14/13*rho(6) + 12/13*rho(7) +
  10/13*rho(8) + 8/13*rho(9) + 6/13*rho(10) + 4/13*rho(11) +
  2/13*rho(12)`.
- The heteroskedastic robust variance uses the squares of those same twelve
  fixed Lo-MacKinlay weights.
- The state is actionable only when `abs(z)` exceeds `1.64485362695147`.
- Significant persistence follows R12; significant anti-persistence reverses R12.
- Insignificant or invalid memory consumes the month flat.

An actionable state buys or sells one XTI position with a frozen
`3.5*ATR(20,D1)` hard stop. The EA closes at the next month boundary or after
35 calendar days. There is no take-profit or active stop adjustment.

## Non-Duplicate Boundary

QM5_13134 implements R1-q2: one-month rank, lag one, and one robust term.
QM5_20253 implements R3-q4: three-month rank, lags one through three, and
three robust terms. QM5_20256 implements R6-q7: six-month rank and six lags.
QM5_20257 implements the separately source-declared R12-q13 member:
twelve-month rank, lags one through twelve, and twelve differently weighted
robust terms. QM5_12603 is plain twelve-month WTI momentum without a memory
significance gate, anti-persistence reversal, or flat state. QM5_20249 is an
XAU/XAG relative basket rather than a direct WTI memory carrier.

## Parameters

| Parameter | Default | Locked role |
|---|---:|---|
| strategy_vr_window_months | 32 | robust VR sample |
| strategy_rank_months | 12 | R12 ranking return |
| strategy_vr_q | 13 | q13 order |
| strategy_significance_z | 1.64485362695147 | two-sided 10% threshold |
| strategy_history_bars_d1 | 1200 | D1 month-end recovery buffer |
| strategy_atr_period_d1 | 20 | hard-stop ATR |
| strategy_atr_sl_mult | 3.5 | hard-stop distance |
| strategy_max_hold_days | 35 | stale guard |
| strategy_max_spread_points | 1500 | entry spread cap |

Every strategy parameter is fail-closed to the one authorized baseline.

## Framework Alignment

- No-trade: exact XTIUSD.DWX D1 host, EA/slot identity, fixed-risk inputs,
  locked news/Friday/stress contract, valid history/arithmetic, and spread,
  quote, ATR, open-position, and attempt checks.
- Trade entry: one source R12-q13 direction per broker month through the V5
  fixed-stop-risk path.
- Trade management: close at the next broker month, use a 35-day stale guard,
  and repair duplicate, wrong-symbol, invalid-type, or missing-stop exposure
  bearing this EA's unique magic.
- Trade close: framework close helper plus the broker-side hard stop.
- Framework safety: kill switch, Q08 MAE sampling, equity stream, news hooks,
  magic resolver, symbol guard, and transaction callbacks remain active.

## Risk And Environment

The only setfile is XTIUSD.DWX D1 backtest with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Both news axes and legacy news are
off, and Friday close is disabled to preserve the source month-to-month hold.
No live, demo, shadow, stress, or optimization setfile is part of this build.

## Source

Mehlitz, Julia S., and Benjamin R. Auer (2024), "Memory-enhanced momentum in
commodity futures markets," *The European Journal of Finance* 30(8), 773-802,
DOI 10.1080/1351847X.2023.2220118. The complete governed review is recorded in
`strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md`; the bounded extraction
is `strategy-seeds/sources/MEHLITZ-AUER-WTI-R12Q13-2026/source.md`.

## Kill Criteria

Retire below five completed trades per full post-warm-up year, on wrong or
nonconsecutive month ends, wrong R12/q13 arithmetic, a missing significance
gate, wrong continuation/reversal matrix, repeated monthly attempt, risk-mode
mismatch, nondeterminism, unacceptable Q02 economics, or any later unchanged
gate failure. No post-result parameter rescue is authorized.
