# QM5_41188_xtixng-mrepmedian-rv — Strategy Spec

**EA ID:** QM5_41188
**Slug:** `xtixng-mrepmedian-rv`
**Strategy ID:** `VILLAR-SIEGEL-XTIXNG-MREPMEDIAN-RV-2026_S01`
**Last revised:** 2026-08-27

## Logic

At the first executable synchronized `XTIUSD.DWX`/`XNGUSD.DWX` D1 bar of a
new broker month, exclude the current month and select the latest exactly
timestamp-matched close pair from each of the immediately prior thirteen
consecutive broker months.

For every pair calculate `L=ln(XTI_close)-ln(XNG_close)`. For each endpoint
`i`, form twelve forward-oriented slopes to every other endpoint, sort them,
and average zero-based indexes 5 and 6. Sort the thirteen pivot medians and
take index 6. Fade a positive repeated median with SELL XTI / BUY XNG and a
negative value with BUY XTI / SELL XNG. Exact zero or malformed state
consumes the month flat.

The exposure is one atomic, opposite-side, equal-target-notional package held
to the next broker month with one aggregate fixed-risk ceiling and frozen
per-leg ATR hard stops.

## Locked Baseline

| Parameter | Value |
|---|---:|
| `strategy_xng_symbol` | `XNGUSD.DWX` |
| `strategy_month_end_count` | 13 |
| `strategy_history_bars_d1` | 900 |
| `strategy_entry_window_minutes` | 180 |
| `strategy_max_endpoint_gap_days` | 10 |
| `strategy_atr_period_d1` | 20 |
| `strategy_atr_sl_mult` | 3.5 |
| `strategy_notional_ratio` | 1.0 |
| `strategy_max_notional_mismatch_fraction` | 0.20 |
| `strategy_max_hold_days` | 40 |
| `strategy_xti_max_spread_points` | 1500 |
| `strategy_xng_max_spread_points` | 3000 |

- Slot 0: `XTIUSD.DWX`, magic `411880000`.
- Slot 1: `XNGUSD.DWX`, magic `411880001`.
- Logical symbol: `QM5_41188_XTI_XNG_MREPMEDIAN_RV_D1`.
- Backtest risk: aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Both news axes, legacy news mode, and Friday close are OFF.

## Source And Boundary

The governed source is
`strategy-seeds/sources/VILLAR-SIEGEL-XTIXNG-MREPMEDIAN-RV-2026/source.md`.
It binds complete government and peer-reviewed oil/gas evidence, adverse
regime findings, and official repeated-median lineage. The exact ratio fade,
CFD mapping, risk, and execution contract are QM falsification choices; no
source performance transfers.

Q02 retires below five completed packages per full post-warm-up year, at zero
trades, or with nonpositive governed economics. Q09 alone may establish
portfolio correlation. No manual backtest, live artifact, `T_Live`, deploy
manifest, portfolio-gate change, or component-leg Q02 row is authorized.

## Framework Alignment

- no_trade: exact symbols, period, ID, slots, inputs, risk, news, and Friday
  contract.
- trade_entry: consumed month, synchronized endpoints, exact nested medians,
  fixed-risk equal-notional sizing, and atomic XTI-then-XNG submission.
- trade_management: malformed-package repair, next-month exit, and forty-day
  stale repair before entry gates.
- trade_close: framework close helper, frozen broker stops, and kill switch.
