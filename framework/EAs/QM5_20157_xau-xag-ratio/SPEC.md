# QM5_20157_xau-xag-ratio — Strategy Spec

**EA ID:** QM5_20157  
**Slug:** xau-xag-ratio  
**Source:** SCHWEIKERT-XAUXAG-RATIO-2026  
**Last revised:** 2026-07-25

## 1. Strategy Logic

Trade the D1 gold/silver relative-price spread
`ln(XAUUSD.DWX) - ln(XAGUSD.DWX)`. Normalize its latest completed value over
60 completed bars. Open a two-leg short spread above +2 or long spread below
-2; close both legs after reversion inside +/-0.5. An orphan leg is closed.

## 2. Parameters

| Parameter | Baseline | Meaning |
|---|---:|---|
| `strategy_z_lookback_d1` | 60 | completed D1 spread observations |
| `strategy_beta` | 1.0 | XAG log-price coefficient |
| `strategy_entry_z` | 2.0 | absolute entry threshold |
| `strategy_exit_z` | 0.5 | convergence exit threshold |
| `strategy_atr_period_d1` | 20 | completed D1 ATR horizon |
| `strategy_atr_sl_mult` | 2.0 | frozen per-leg hard stop |
| `strategy_deviation_points` | 20 | order deviation |

## 3. Symbol Universe

The logical basket is fixed to `XAUUSD.DWX` slot 0 and `XAGUSD.DWX` slot 1.
`XAUUSD.DWX` is the D1 host. No other symbols are authorized.

## 4. Timeframe

D1 only. Spread state uses completed bars beginning at shift 1 and entry is
gated by the framework new-bar check.

## 5. Expected Behaviour

Expected cadence is 5–20 completed packages per year, held for days to weeks.
Q02 must demonstrate at least five packages/year and valid two-leg execution
or retire/rework the candidate. The basket seeks relative-value exposure but
does not claim proven market or portfolio neutrality.

## 6. Source Citation

Karsten Schweikert (2018), *Journal of Banking & Finance* 88, 44–51,
DOI `10.1016/j.jbankfin.2017.11.010`; Yaya, Vo and Olayinka (2021),
*Resources Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`.
The governed extraction is in
`strategy-seeds/sources/SCHWEIKERT-XAUXAG-RATIO-2026/source.md`.

## 7. Risk Model

Q02–Q10 use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and portfolio weight 1.
The budget is split equally across legs and each leg is ATR-sized to its own
2 ATR hard stop. No live setfile or live authorization exists.
