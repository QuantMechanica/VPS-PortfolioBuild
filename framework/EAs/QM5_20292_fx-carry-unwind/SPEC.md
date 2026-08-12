# QM5_20292_fx-carry-unwind - Strategy Spec

- **EA ID:** QM5_20292
- **Slug:** fx-carry-unwind
- **Strategy ID:** `SRC04_S11b`
- **Source:** Kathy Lien (2015), *Day Trading and Swing Trading the Currency
  Market*, 3rd edition, Wiley, Chapter 18, pp. 153-160
- **Last revised:** 2026-08-12

## 1. Strategy Logic

On the first tradable `AUDCHF.DWX` D1 bar of a broker week, the EA measures
whether realized volatility is unusually high across seven liquid FX majors.
If the median 21-day volatility ratio is at least 1.50, it ranks six CHF/JPY
crosses by positive broker-swap cash per unit of ATR risk and opens the reverse
of the top two current carry directions. Both legs are pre-sized as one atomic
package. The EA closes the package when stress falls to 1.10, after five
completed D1 bars, at the standard Friday close, or when any leg becomes
orphaned or malformed.

The rule contains no policy-rate file, static carry direction, momentum
fallback, residual spread, trained output, or adaptive threshold. A symbol
whose declared swap mode cannot be converted comparably is simply ineligible.

## 2. Parameters

| Parameter | Locked value | Meaning |
|---|---:|---|
| `strategy_rv_window_d1` | 21 | completed log returns in each realized-volatility estimate |
| `strategy_rv_baseline_observations` | 252 | prior rolling volatilities in each symbol median |
| `strategy_min_valid_signal_symbols` | 5 | minimum valid major-FX ratios |
| `strategy_stress_entry_ratio` | 1.50 | minimum median ratio for entry |
| `strategy_stress_exit_ratio` | 1.10 | maximum median ratio for stress exit |
| `strategy_selected_legs` | 2 | carry directions reversed per package |
| `strategy_atr_period_d1` | 20 | completed-bar stop/rank risk estimator |
| `strategy_atr_sl_mult` | 2.5 | frozen hard-stop distance per leg |
| `strategy_max_hold_d1_bars` | 5 | completed D1 bars before forced exit |
| `strategy_spread_history_d1` | 20 | completed spreads in entry median |
| `strategy_spread_mult` | 3.0 | maximum current-to-median spread ratio |
| `strategy_history_bars` | 320 | bounded D1 warm-up/copy request |
| `strategy_max_endpoint_gap_days` | 10 | latest completed-bar freshness bound |
| `strategy_deviation_points` | 20 | basket-order deviation allowance |

All framework, risk, news, Friday-close, stress-hook, and strategy inputs fail
closed against the single authorized Q02 baseline.

## 3. Symbol Universe

Traded targets and deterministic slots are:

- slot 0 `AUDCHF.DWX` — commodity/high-beta currency versus CHF funding;
- slot 1 `AUDJPY.DWX` — commodity/high-beta currency versus JPY funding;
- slot 2 `GBPCHF.DWX` — GBP versus CHF funding;
- slot 3 `GBPJPY.DWX` — GBP versus JPY funding;
- slot 4 `NZDCHF.DWX` — commodity/high-beta currency versus CHF funding; and
- slot 5 `NZDJPY.DWX` — commodity/high-beta currency versus JPY funding.

Signal-only breadth uses `EURUSD.DWX`, `GBPUSD.DWX`, `AUDUSD.DWX`,
`NZDUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, and `USDCAD.DWX`. The one logical
basket is hosted on `AUDCHF.DWX`; standalone target-leg interpretation is not
authorized. Indices, commodities, crypto, external rate instruments, and any
symbol outside the deterministic `.DWX` matrix are excluded.

## 4. Timeframe

The host and every signal/target series use D1. Calculations consume only
completed bars. `QM_CalendarPeriodKey(PERIOD_W1)` identifies the first D1 bar
of a new broker week without relying on W1 history. A terminal-persistent
attempt marker is written before weekly history, signal, spread, quote,
sizing, or order gates.

## 5. Expected Behaviour

The card expects roughly 4-12 two-leg packages per year, or about 2-6 entries
per target symbol, with one consumed opportunity per week and long flat
periods in normal volatility. Holds are at most five completed D1 bars and
normally end sooner when the stress ratio mean-reverts or the Friday rail
fires. The intended regime is elevated global FX volatility and carry
deleveraging; clustered gap/slippage risk and correlated stops are expected.
The research prior is PF 1.3 and DD 12%, but neither estimate is evidence.

## 6. Source Citation

Source ID `SRC04`, strategy ID `SRC04_S11b`: Kathy Lien (2015), *Day Trading
and Swing Trading the Currency Market*, 3rd edition, Wiley, Chapter 18,
pp. 153-160. The complete bounded extract is
`strategy-seeds/sources/SRC04/raw/ch17-20_fundamental.txt`, lines 71-455.
R1 lineage and R2-R4 PASS are recorded in
`strategy-seeds/cards/approved/QM5_20292_fx-carry-unwind_card.md` and
`decisions/2026-08-12_qm5_20292_fx_carry_unwind_g0.md`. Source performance is
not inherited by this Darwinex-native translation.

## 7. Risk Model

| Environment | Active input | Required value | Inactive input |
|---|---|---:|---:|
| Backtest Q01-Q10 | `RISK_FIXED` | 1000 USD | `RISK_PERCENT=0` |
| Full live after all gates | `RISK_PERCENT` | manifest-authorized 0.5% | `RISK_FIXED=0` |

The only artifact built here is a backtest setfile with `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Each of the two legs receives half
of the fixed package stop-risk budget. There is one position maximum per
registered magic/symbol; no grid, martingale, scale-in, partial close,
pyramiding, live setfile, deployment manifest, or live authorization exists.

## Revision History

| Version | Date | Reason | Build task |
|---|---|---|---|
| v1 | 2026-08-12 | Initial build from approved carry-unwind card | `012556a6-b64c-4ac6-973c-91098e898fed` |
