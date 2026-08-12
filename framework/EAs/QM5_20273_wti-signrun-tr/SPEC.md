# QM5_20273_wti-signrun-tr - Strategy Spec

**EA ID:** QM5_20273  
**Slug:** `wti-signrun-tr`  
**Source:** `MOP-TSMOM-2012_XTI_SIGNRUN12_S22`  
**Card:** `strategy-seeds/cards/approved/QM5_20273_wti-signrun-tr_card.md`  
**Last revised:** 2026-08-10

## 1. Strategy Logic

On the first processed `XTIUSD.DWX` D1 bar of a genuine broker-month
transition, reconstruct thirteen consecutive completed broker-month-end closes
in chronological order. Form twelve adjacent monthly log returns and scan
their strict signs. Exact-zero returns reset both current runs. Buy when the
longest positive run is at least four and strictly longer than the longest
negative run; sell under the symmetric negative rule; consume all other states
flat.

Close the prior package at the next month boundary before considering the new
month. Maintain one persisted attempt per broker month, one position, one
frozen ATR hard stop, and no take-profit. This is a variable-location longest-
run path statistic, not a cumulative return, unordered sign count, fixed block
vote, regression, rank trend, robust average, calendar rule, or oscillator.

## 2. Parameters

| Parameter | Default | Authorized values | Meaning |
|---|---:|---|---|
| `strategy_endpoint_count` | 13 | 13 | Completed month-end observations |
| `strategy_min_run_months` | 4 | 4 | Minimum unique longest sign run |
| `strategy_history_bars_d1` | 800 | 800 | Bounded D1 endpoint reconstruction |
| `strategy_atr_period_d1` | 20 | 20 | Completed D1 ATR stop estimator |
| `strategy_atr_sl_mult` | 3.5 | 3.5 | Frozen broker hard-stop distance |
| `strategy_max_hold_days` | 40 | 40 | Monthly stale guard |
| `strategy_max_spread_points` | 1500 | 1500 | WTI entry spread ceiling |

No baseline parameter sweep is authorized.

## 3. Symbol Universe

- `XTIUSD.DWX` only.
- Magic slot 0, intended magic `202730000`.
- Single-position, single-symbol EA.
- Runtime uses only native MT5 price, calendar, ATR, quote, position, deal, and
  framework state.

## 4. Timeframe

- Host timeframe: D1 only.
- Formation endpoints: completed broker-month closes reconstructed from D1
  bars; no current-month endpoint is allowed.
- Decision/renewal clock: first processed D1 bar of each genuine new broker
  month.

## 5. Expected Behaviour

- Approximately six completed monthly packages per full post-warm-up year
  under the independent-sign enumeration; Q02 retires the EA below five.
- Symmetric long/short WTI exposure only after a unique directional longest
  run of at least four months.
- Prior package closes before any replacement entry, even when direction is
  unchanged.
- Friday close and news axes are disabled for the full-month native-price
  package. A forty-day stale exit and broker hard stop remain binding.

## 6. Source Citation

Moskowitz, T. J., Ooi, Y. H., and Pedersen, L. H. (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`.

The complete-read parent packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`; the bounded extraction is
`strategy-seeds/sources/MOP-WTI-SIGNRUN-2026/source.md`. The longest-run rule
is a transparent QM hypothesis, not a source performance claim.

## 7. Risk Model

| Environment | Active mode | Value |
|---|---|---:|
| Q02-Q10 backtest | `RISK_FIXED` | 1000 |
| Live | not authorized | n/a |

The backtest setfile locks `RISK_PERCENT=0` and `PORTFOLIO_WEIGHT=1`. Each
entry receives one frozen `3.5 * ATR(20,D1)` broker hard stop. No profit target,
trail, break-even, partial close, scale-in, grid, martingale, or pyramid is
allowed.

## 8. Framework Alignment

- **No-Trade:** exact EA/symbol/D1/slot, locked inputs, fixed risk/news/Friday
  contract, and cheap state guards.
- **Trade Entry:** persist month attempt, reconstruct endpoints, calculate the
  twelve adjacent returns and exact longest-run state, then validate spread,
  quote, ATR, stop, sizing, and place one order.
- **Trade Management:** repair malformed owned state and close prior-month or
  forty-day-stale exposure before entry-only gates.
- **Trade Close:** framework close helper, frozen broker stop, and kill switch.

## 9. Non-Duplicate Boundary

The pre-allocation checker found no exact or fuzzy identity across 4,333
registry rows and 446 cards. The exact thirteen month ends, twelve adjacent
chronological log returns, strict signs, zero reset, directional maximum-run
state, four-month threshold, unique-direction tie rule, monthly attempt, and
renewal lifecycle are load-bearing. Cumulative-horizon, unordered-sign,
quarter-block, OLS, rank, median, trimmed-mean, and Theil-Sen WTI paths use
materially different estimators.

## 10. Safety Boundary

Only research, deterministic allocation, build, strict compile/Q01, one
`RISK_FIXED` backtest setfile, and one paced non-live Q02 handoff are
authorized. Do not run a manual backtest or touch live artifacts, AutoTrading,
`T_Live`, deploy manifests, the portfolio gate, portfolio admission, or a
correlation waiver.

## 11. Q01 Status

- Strict compile: PASS, zero errors and zero warnings; summary
  `D:/QM/reports/compile/20260810_173101/summary.csv`.
- Target build check: PASS, zero failures and zero warnings; report
  `D:/QM/reports/framework/21/build_check_20260810_173101.json`.
- P1 artifact validation: PASS at
  `D:/QM/reports/pipeline/QM5_20273/P1/P1_QM5_20273_result.json`.
- Backtest set build hash:
  `a0b0ffbd2e81ff11303d427e4e036df6790e673571edd84f1a7900232a724083`.

## 12. Q02 Handoff

Not enqueued. A path-anchored T1-T10 capacity sample must remain below the
binding ceiling before one current-binary Q02 item may be inserted.
