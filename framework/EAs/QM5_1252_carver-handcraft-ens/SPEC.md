# QM5_1252 Carver Handcrafted Live-Rule Ensemble - Strategy Spec

**EA ID:** QM5_1252

**Slug:** `carver-handcraft-ens`

**Source ID:** `2a380bee-1ec4-50d1-a348-b10fac642c7a`

**Last revised:** 2026-08-28

## 1. Strategy Logic

On each newly completed D1 bar, the EA combines six deterministic rule
families: EWMAC momentum, rolling-range breakout, normalized momentum,
absolute skew, in-asset mean reversion, and forecast acceleration. Each family
is built only from completed broker D1 OHLC/spread data. A family without
enough history or above the fixed cost-speed limit is omitted, and the
remaining fixed handcrafted weights are renormalized. At least three valid
families are required.

The combined forecast is capped to `[-20,+20]`. A forecast strictly above
`+5` opens long and one strictly below `-5` opens short. A long closes at or
below `+1`; a short closes at or above `-1`. A reversal therefore requires a
later completed bar to cross the opposite entry threshold. Entries also fail
closed when the current spread exceeds twice the median completed-D1 spread.

Carry and relative-carry rules are intentionally absent because no
deterministic point-in-time DWX carry series is available. Their absence does
not change or adapt the weights of the six implemented families beyond the
disclosed fixed renormalization.

## 2. Parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `strategy_entry_forecast` | 5.0 | strict absolute entry threshold |
| `strategy_exit_forecast` | 1.0 | neutralization exit threshold |
| `strategy_min_families` | 3 | minimum available rule families |
| `strategy_atr_period_d1` | 20 | completed-D1 ATR period |
| `strategy_atr_sl_mult` | 3.0 | frozen initial emergency-stop multiple |
| `strategy_spread_median_days` | 20 | completed-D1 median-spread window |
| `strategy_spread_mult` | 2.0 | maximum current/median spread ratio |
| `strategy_cost_limit` | 0.13 | fixed turnover-cost exclusion ceiling |
| `strategy_ewmac_weight` | 0.28 | EWMAC family weight |
| `strategy_breakout_weight` | 0.22 | breakout family weight |
| `strategy_normmom_weight` | 0.16 | normalized-momentum family weight |
| `strategy_skew_weight` | 0.10 | absolute-skew family weight |
| `strategy_mr_weight` | 0.14 | mean-reversion family weight |
| `strategy_accel_weight` | 0.10 | acceleration family weight |

All weights and thresholds are fixed inputs. There is no optimizer-selected,
PnL-adaptive, or online-learned state.

## 3. Symbol Universe

The registered research universe is `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`,
`AUDUSD.DWX`, `USDCAD.DWX`, `NZDUSD.DWX`, `XAUUSD.DWX`, `XTIUSD.DWX`,
`NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, and `UK100.DWX`, using magic slots 0-11
respectively. Each run reads and trades only its exact host symbol. One
position per symbol/magic is allowed.

This infrastructure recovery requalifies only the FX canary identity selected
by the farm. It does not broaden the approved universe or claim that any
symbol has an economic PASS.

## 4. Timeframe

Signals, exits, spread history, ATR, and rule-family inputs use completed D1
bars. Entry evaluation is bounded to one decision per new host-symbol D1 bar.
Position integrity, emergency-stop enforcement, MAE tracking, kill-switch
handling, Friday close, and strategy exits remain reachable before the new-bar
entry gate.

## 5. Expected Behaviour

The approved card estimates approximately 35 trades per year per symbol before
pipeline gates. The ensemble is deliberately low-frequency and structural;
Q02 owns observed density and expectancy. The current work is an
infrastructure requalification of historically summary-missing FX rows, not a
performance adjustment, certification claim, or portfolio admission.

## 6. Source Citation

Rob Carver (2021), "My trading system," qoppac blog:
`https://qoppac.blogspot.com/2021/12/my-trading-system.html`.

Supplemental open-source rule implementations are in the `pysystemtrade`
provided-rules tree:
`https://github.com/pst-group/pysystemtrade/tree/develop/systems/provided/rules`.

The source supports the rule-family and handcrafted-combination structure.
Entry/exit thresholds, cost gate, spread filter, and emergency stop are the
explicit OWNER-approved QuantMechanica card contract.

## 7. Risk Model

Each entry request carries a frozen initial stop at `3.0 * ATR(20,D1)` from
the executable price. The stop is never widened or removed. Framework sizing
uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and the registered portfolio weight
in every Q02 backtest setfile. Quote, stop-distance, tick-value, volume, magic,
and one-position guards fail closed.

Forecast neutralization is the only strategy exit; the framework kill switch,
account controls, Friday close, and broker stop remain authoritative. There is
no ML, banned indicator, external runtime data API, averaging, grid,
martingale, scale-in, pyramid, partial exit, or discretionary input.

This package is a build/Q02 research handoff only. It creates no live, demo,
shadow, optimization, stress, portfolio, or deployment authorization and does
not touch AutoTrading, `T_Live`, a deploy manifest, or the portfolio gate.

## Revision history

| Version | Date | Reason | Task |
|---|---|---|---|
| v1 | 2026-05-26 | Initial approved-card implementation | historical build |
| v2 | 2026-08-28 | Current build-contract and Q02 infrastructure recovery | `25d7265a-332b-4d4c-8c5e-6518c7caa52a` |
