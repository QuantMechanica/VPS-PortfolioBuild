# QM5_13126_energy-momcarry - Strategy Spec

**EA ID:** QM5_13126
**Slug:** `energy-momcarry`
**Strategy ID:** `FMR-MOMTS-2010_XTI_XNG_S01`
**Source:** Fuertes, Miffre, and Rallis (2010), DOI `10.1016/j.jbankfin.2010.04.009`
**Last revised:** 2026-07-10

## 1. Strategy Logic

The EA runs one D1 logical basket from `XTIUSD.DWX`. On the first host bar of a
new broker month it ranks XTI and XNG by synchronized last-completed-month log
return and independently ranks `SYMBOL_SWAP_LONG - SYMBOL_SWAP_SHORT`. It buys
the relative winner and shorts the loser only when both ranks agree. Missing or
nonzero-tied swap metadata means no trade. Because `.DWX` tester symbols expose
zero swap, the locked Q02 setfile supplies a fixed `+1` carry rank (prefer XTI)
and still requires the independent one-month momentum rank to agree.

The fixed package risk is split equally. Each leg receives a frozen
`ATR(20) * 3.5` hard stop. The package closes at the next month transition,
after 35 calendar days, or immediately on an orphan/invalid composition.

## 6. Source Citation

The source trades a 37-future cross-section, observes nearby and second-nearby
contracts, and measures annualized front-end roll return. Darwinex CFD history
does not expose that curve. Broker-native swap differential is therefore a
falsifiable proxy, not an asserted equivalent. The two-instrument narrowing,
CFD/futures basis, and the fixed tester carry rank are explicit translation
risks. Q02 tests the return interaction conditional on that prior, not
historical carry changes. No source performance is imported.

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---|---|
| `strategy_momentum_months` | 1 | 1, 3, 12 | completed-month source formation horizon |
| `strategy_history_bars` | 120 | 90-450 | bounded endpoint history |
| `strategy_max_boundary_gap_days` | 10 | 7-10 | endpoint freshness cap |
| `strategy_min_carry_rank_gap` | 0.0 | 0.0 | strict carry non-tie threshold |
| `strategy_zero_swap_fallback_direction` | 1 | -1, 0, 1 | predeclared `.DWX` tester carry rank; 0 disables |
| `strategy_atr_period_d1` | 20 | 14-30 | D1 hard-stop ATR |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | frozen stop multiple |
| `strategy_max_hold_days` | 35 | 35 | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | 1000-2500 | XTI spread cap |
| `strategy_xng_max_spread_pts` | 3000 | 2000-4500 | XNG spread cap |
| `strategy_deviation_points` | 20 | 10-50 | basket order deviation |

Q02 is locked to the one-month baseline. The source-declared 3- and 12-month
variants are not permission to tune after failure.

## 3. Symbol Universe

- Logical symbol: `QM5_13126_ENERGY_MOMCARRY_D1`.
- Host/traded slot 0: `XTIUSD.DWX`, D1, magic `131260000`.
- Traded slot 1: `XNGUSD.DWX`, D1, magic `131260001`.
- No other symbol or timeframe is authorized.

## 4. Timeframe

The host and both signal legs use D1 bars. Signal formation runs only on the
first new host D1 bar of each broker month, using completed month endpoints.
There are no cross-timeframe reads.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Backtest Q02+ | `RISK_FIXED` | 1000 per package, split 50/50 |
| Live | not authorized | none |

The EA uses `QM_LotsForRisk` before applying the 0.5 package share, validates
broker volume metadata, and flattens a failed two-leg entry. There is no TP,
trail, break-even, partial close, scale-in, grid, martingale, or pyramiding.

## 8. Four-Module Mapping

- **No-Trade:** host, baseline, history, endpoint, arithmetic, swap, spread,
  ATR, volume, and package-state guards.
- **Entry:** momentum/carry rank agreement, two basket orders, equal risk,
  frozen hard stops.
- **Management:** next-month close, 35-day time stop, orphan and composition
  repair.
- **Close:** `QM_TM_ClosePosition` for package exits plus broker hard stops.

## 5. Expected Behaviour

Retire on fewer than five completed packages/year, nondeterminism, invalid
endpoint construction, persistent orphan exposure, or risk-mode mismatch.
Nonzero tied carry still stands down; all-zero tester metadata uses only the
locked fallback. Q09 alone may establish realized portfolio correlation.

## 9. Safety Boundary

No live setfile, T_Live change, AutoTrading action, deploy manifest, portfolio
gate change, or admission artifact is authorized.
