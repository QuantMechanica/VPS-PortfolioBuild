# QM5_20253_wti-vr3-mom — Strategy Spec

## Identity

- EA ID: QM5_20253
- Slug: wti-vr3-mom
- Strategy ID: MEHLITZ-AUER-MEM-2024_XTI_R3Q4_S02
- Symbol / slot: XTIUSD.DWX / 0
- Timeframe: D1
- Magic: 202530000
- Canonical card: strategy-seeds/cards/approved/QM5_20253_wti-vr3-mom_card.md

## Strategy Logic

At the first processed XTI D1 bar of a genuine new broker month, the EA
reconstructs 33 consecutive completed month-end closes and 32 chronological
monthly log returns. It computes the source-declared Mehlitz-Auer R3-q4 state:

- R3 is the sum of the latest three completed monthly log returns.
- VR(4) is 1 + 1.5*rho(1) + rho(2) + 0.5*rho(3).
- The heteroskedastic robust variance uses delta weights 2.25, 1.0, and 0.25.
- The state is actionable only when abs(z) exceeds 1.64485362695147.
- Significant persistence follows R3; significant anti-persistence reverses R3.
- Insignificant or invalid memory consumes the month flat.

An actionable state buys or sells one XTI position with a frozen
3.0*ATR(20,D1) hard stop. The EA closes at the next month boundary or after
35 calendar days. There is no take-profit or active stop adjustment.

## Non-Duplicate Boundary

QM5_13134 implements R1-q2: one-month rank, lag one, and one robust term.
QM5_20253 implements the separately source-declared R3-q4 member: three-month
rank, lags one through three, and three differently weighted robust terms.
Plain WTI three-month momentum has no memory significance gate or
anti-persistence reversal.

## Parameters

| Parameter | Default | Locked role |
|---|---:|---|
| strategy_vr_window_months | 32 | robust VR sample |
| strategy_rank_months | 3 | R3 ranking return |
| strategy_vr_q | 4 | q4 order |
| strategy_significance_z | 1.64485362695147 | two-sided 10% threshold |
| strategy_history_bars_d1 | 1200 | D1 month-end recovery buffer |
| strategy_atr_period_d1 | 20 | hard-stop ATR |
| strategy_atr_sl_mult | 3.0 | hard-stop distance |
| strategy_max_hold_days | 35 | stale guard |
| strategy_max_spread_points | 1500 | entry spread cap |

Only 900, 1200, or 1600 are accepted for the history plumbing buffer. Signal
sample, ranking horizon, q, significance, stop, lifecycle, and spread baseline
are otherwise fail-closed.

## Framework Alignment

- No-trade: exact XTIUSD.DWX D1 host, EA/slot identity, locked inputs, valid
  history/arithmetic, spread, ATR, open-position, and attempt checks.
- Trade entry: one source R3-q4 direction per broker month through the V5
  fixed-stop-risk path.
- Trade management: close at next broker month, 35-day stale guard, and
  restart-safe terminal-global/deal-history attempt ledger.
- Trade close: framework close helper plus the broker-side hard stop.
- Framework safety: kill switch, Q08 MAE sampling, equity stream, two-axis
  entry-news gate, magic resolver, symbol guard, and framework transaction
  callbacks remain active.

## Risk And Environment

The only setfile is XTIUSD.DWX D1 backtest with RISK_FIXED=1000,
RISK_PERCENT=0, and PORTFOLIO_WEIGHT=1. Friday close is disabled to preserve
the source month-to-month hold. No live, demo, shadow, stress, or optimization
setfile is part of this build.

## Source

Mehlitz, Julia S., and Benjamin R. Auer (2024), "Memory-enhanced momentum in
commodity futures markets," The European Journal of Finance 30(8), 773-802,
DOI 10.1080/1351847X.2023.2220118. The complete governed review is recorded in
strategy-seeds/sources/MEHLITZ-AUER-MEM-2024/source.md; the bounded extraction
is strategy-seeds/sources/MEHLITZ-AUER-WTI-R3Q4-2026/source.md.

## Kill Criteria

Retire below five completed trades per full post-warm-up year, on wrong or
nonconsecutive month ends, wrong R3/q4 arithmetic, missing significance gate,
wrong continuation/reversal matrix, repeated monthly attempt, risk-mode
mismatch, nondeterminism, unacceptable Q02 economics, or any later unchanged
gate failure. No post-result parameter rescue is authorized.
