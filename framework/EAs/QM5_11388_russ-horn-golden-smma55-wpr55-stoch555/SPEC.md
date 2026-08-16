# QM5_11388 — Golden SMMA/WPR/Stochastic

**EA ID:** QM5_11388
**Slug:** russ-horn-golden-smma55-wpr55-stoch555
**Approved card:** `docs/strategy_card.md`
**Last revised:** 2026-08-16

## 1. Strategy Logic

Signals are evaluated once per completed M5 bar and entered on the following
bar. A long requires the completed close above SMMA(55) of High, Williams %R(55)
crossing upward through -25, and Stochastic(5,5,5) %K above %D. A short mirrors
the rule below SMMA(55) of Low with Williams %R crossing downward through -75
and %K below %D.

The strategy is fully deterministic and uses only native SMMA, Williams %R,
Stochastic, and ATR calculations. It contains no adaptive or ML component.
The EA implements `Strategy_NoTradeFilter`, `Strategy_EntrySignal`,
`Strategy_ExitSignal`, and `Strategy_NewsFilterHook`; framework code owns
initialization, sizing, logging, execution, exits, kill-switches, and magic
validation.

## 2. Parameters

| Parameter | P2 value | Meaning |
|---|---:|---|
| `strategy_smma_period` | 55 | High/Low SMMA channel period. |
| `strategy_wpr_period` | 55 | Williams %R period. |
| `strategy_wpr_overbought` | -25 | Long cross threshold. |
| `strategy_wpr_oversold` | -75 | Short cross threshold. |
| `strategy_stoch_k_period` | 5 | Stochastic %K period. |
| `strategy_stoch_d_period` | 5 | Stochastic %D period. |
| `strategy_stoch_slowing` | 5 | Stochastic slowing. |
| `strategy_atr_period` | 14 | Initial-stop volatility period. |
| `strategy_atr_sl_mult` | 1.0 | ATR stop multiplier. |
| `strategy_sl_cap_pips` | 20.0 | Maximum initial stop. |
| `strategy_tp_rr` | 2.0 | Take-profit risk multiple. |
| `strategy_max_spread_pips` | 15 | Entry spread cap. |

The approved card requires news filtering off in P2. Defaults and all sealed
backtest setfiles use `QM_NEWS_TEMPORAL_OFF`, `QM_NEWS_COMPLIANCE_NONE`, and
legacy `QM_NEWS_OFF` (numeric `0/0/0`), avoiding calendar/cache initialization.

## 3. Symbol Universe

| Registry slot | Symbol | Magic |
|---:|---|---:|
| 0 | EURUSD.DWX | 113880000 |
| 1 | GBPUSD.DWX | 113880001 |
| 2 | USDJPY.DWX | 113880002 |

Only these approved `.DWX` FX symbols are in scope.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe references | none |
| Bar gating | one evaluation per new M5 bar |
| Entry timing | next bar after a completed-bar signal |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades per year per symbol | approximately 40 |
| Regime preference | directional channel breaks with dual momentum confirmation |
| Hold profile | bounded by ATR stop or fixed 2R target |
| Position concurrency | one framework-managed position per magic |

## 6. Source Citation

The approved card attributes the mechanics to Russ Horn, *The Golden Strategy*
(RapidResultsMethod.com), source ID
`8e980ec0-c92b-5163-a865-c3e451c5442b`. The line-for-line approved card
snapshot is retained in `docs/strategy_card.md`. G0 is OWNER-authorized
`APPROVED`; R2, R3, and R4 are PASS, and R1 is informational under the current
source-agnostic reputable-source policy.

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| P2/Q02 backtest | `RISK_FIXED` | 1000 |
| P2/Q02 percentage risk | `RISK_PERCENT` | 0 |

The initial stop is ATR(14) × 1.0, capped at 20 pips. Take profit is 2.0 times
the initial stop distance; there is no default trailing or discretionary exit.
Each symbol has its own sealed `RISK_FIXED=1000`, `RISK_PERCENT=0` setfile.
