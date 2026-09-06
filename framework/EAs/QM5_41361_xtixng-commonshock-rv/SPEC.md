# QM5_41361_xtixng-commonshock-rv - Strategy Spec

**EA ID:** QM5_41361

**Slug:** `xtixng-commonshock-rv`

**Strategy ID:** `AI-CODEX-XTIXNG-COMMONSHOCK-RV-20260906_S01`

**Source:** `AI-CODEX-XTIXNG-COMMONSHOCK-RV-20260906`

**Author:** Codex

**Last revised:** 2026-09-06

## 1. Strategy Logic

On the first tradable `XTIUSD.DWX` D1 bar of a new broker week, reconstruct
the final synchronized close pairs from the immediately completed broker week
and its consecutive parent week. Each week must contain three to five
synchronized sessions. Compute each leg's completed weekly log return.

When WTI and natural gas returns share a strict sign, sell the relative
outperformer and buy the relative underperformer for one broker week.
Equality within `1e-10`, mixed signs, zero, invalid endpoints, or late
attachment consumes the week flat. The package targets equal absolute
notionals, shares one fixed-risk budget, and carries frozen per-leg ATR stops.

## 2. Locked Parameters

| Parameter | Value |
|---|---:|
| `strategy_history_bars_d1` | 30 |
| `strategy_min_sessions_per_week` | 3 |
| `strategy_max_sessions_per_week` | 5 |
| `strategy_signal_epsilon` | 1e-10 |
| `strategy_entry_grace_minutes` | 180 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_notional_ratio` | 1.0 |
| `strategy_max_notional_mismatch_pct` | 20.0 |
| `strategy_max_hold_days` | 10 |
| `strategy_xti_max_spread_points` | 1500 |
| `strategy_xng_max_spread_points` | 3000 |
| `qm_friday_close_enabled` | false |

## 3. Symbol Universe And Lifecycle

- Host: exact `XTIUSD.DWX`, D1, slot 0.
- Companion: exact `XNGUSD.DWX`, D1, slot 1.
- Logical symbol: `QM5_41361_XTI_XNG_COMMONSHOCK_RV_D1`.
- Expected cadence: 15-35 packages/year; Q02 retires below five.
- Exit: next broker-week boundary or ten-calendar-day stale repair.
- One consumed attempt per week; second-leg failure triggers orphan rollback.

## 4. Source And Claim Boundary

Villar/Joutz (U.S. EIA, 2006) and Ramberg/Parsons (*The Energy Journal*,
2012, DOI `10.5547/01956574.33.2.2`) support a weak, time-varying oil/gas
relationship and preserve adverse instability. The weekly common-shock
dispersion fade is an untested QM translation; no source result transfers.

Canonical packet:
`strategy-seeds/sources/AI-CODEX-XTIXNG-COMMONSHOCK-RV-20260906/source.md`.

## 5. Risk And Safety

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both news axes and Friday close are OFF. Equal notional
does not prove neutrality; Q09 alone owns realized portfolio correlation.

No live/demo/shadow/stress/optimization setfile, manual backtest, AutoTrading,
`T_Live`, deploy/live manifest, portfolio-gate change, portfolio admission,
correlation waiver, external feed, retry, scale-in, grid, pyramid, target,
trail, break-even move, or partial exit is authorized.

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-09-06 | approved build identity |

