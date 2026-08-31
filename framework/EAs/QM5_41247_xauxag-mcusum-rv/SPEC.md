# QM5_41247 — XAU/XAG Monthly Centered-CUSUM Reversion

## Build contract

- Approved card: `strategy-seeds/cards/approved/QM5_41247_xauxag-mcusum-rv_card.md`
- Host: `XAUUSD.DWX`, D1, slot 0, magic `412470000`
- Companion: `XAGUSD.DWX`, D1, slot 1, magic `412470001`
- Logical symbol: `QM5_41247_XAU_XAG_MCUSUM_RV_D1`
- Environment: backtest only
- Risk: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

This EA is one logical paired package. Neither physical-symbol setfile is a
standalone strategy or an authorization to enqueue a separate leg.

## Signal

On the first synchronized executable D1 tick of a genuine broker month, the
EA consumes the month and reconstructs thirteen exact consecutive completed
broker-month endpoints for both metals. From chronological pairs it computes:

```text
L[i] = ln(XAU[i]) - ln(XAG[i])            i=0..12
r[i] = L[i+1] - L[i]                     i=0..11
mean = sum(r) / 12
S[k] = sum(r[0..k-1]) - k*mean            k=1..11
```

The maximum absolute `S[k]` must exceed `1e-12`, be unique within `1e-12`,
and occur at split `4..8`. The terminal cumulative sum is identically zero
and never participates. The EA then fades the post-split arithmetic mean:

- positive post mean: sell XAU, buy XAG;
- negative post mean: buy XAU, sell XAG;
- zero, tied maximum, edge split, or invalid state: flat for the consumed
  month.

CUSUM and post-mean magnitudes never affect size.

## Synchronization and state

- Exactly one matched XAU/XAG D1 timestamp supplies each endpoint.
- Endpoints must be from the immediately prior thirteen months with no gap.
- The current broker month never contributes a signal price.
- The newest endpoint may be at most ten calendar days behind the current
  host bar.
- The terminal-persistent `yyyymm` attempt is recorded before history,
  signal, news, spread, quote, ATR, sizing, margin, or order gates.
- Restart, stop-out, reject, or partial order failure never retries a month.
- Late attachment consumes the current month flat.

## Package execution

The package splits the aggregate fixed stop-risk budget across two legs,
attaches a frozen `3.5*ATR(20,D1)` hard stop to each, and reduces volume only
to align target absolute USD notionals. Realized mismatch must not exceed
20%. XAU is submitted first and XAG second; any incomplete, wrong-side,
orphaned, duplicated, stopless, wrong-magic, or imbalanced package is flattened
immediately.

Entry spread ceilings are 1,500 XAU points and 500 XAG points. Both news axes,
legacy news, and Friday close are disabled. There is no target, trail,
break-even, partial close, scale-in, grid, martingale, or pyramid.

## Lifecycle

The pair closes on the first processed tick in a later normalized broker
month or after forty elapsed calendar days. Package repair and lifecycle exits
run before entry-only filters. The framework kill switch and broker stops
remain authoritative.

## Locked inputs

| Input | Value |
|---|---:|
| `strategy_xag_symbol` | `XAGUSD.DWX` |
| `strategy_endpoint_count` | 13 |
| `strategy_min_split` | 4 |
| `strategy_max_split` | 8 |
| `strategy_tie_epsilon` | `1e-12` |
| `strategy_history_bars_d1` | 900 |
| `strategy_entry_window_minutes` | 180 |
| `strategy_max_endpoint_gap_days` | 10 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_notional_ratio` | 1.0 |
| `strategy_max_notional_mismatch_fraction` | 0.20 |
| `strategy_max_hold_days` | 40 |
| `strategy_xau_max_spread_points` | 1500 |
| `strategy_xag_max_spread_points` | 500 |
| `strategy_deviation_points` | 20 |

No optimization surface is authorized.

## Falsification

Q02 retires the baseline on zero packages, fewer than five completed packages
in any full post-warm-up year, nonpositive governed economics, or an
implementation discrepancy. Q09 alone owns realized portfolio correlation.
This package does not claim neutrality, decorrelation, certification, or live
authorization.
