# QM5_41112_xauxag-mdaybreadth-rv - Strategy Spec

**EA ID:** QM5_41112

**Slug:** `xauxag-mdaybreadth-rv`

**Strategy ID:** `SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026_S01`

**Source:** `SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026`

**Author:** Development

**Last revised:** 2026-08-22

## 1. Strategy Logic

At the first exact synchronized XAU/XAG D1 boundary of a broker month, the EA
reconstructs the two immediately preceding completed calendar months. Each
month must contain 17 through 23 timestamp-identical close pairs. The parent
month's chronological final log ratio anchors every close-to-close relative
return in the newest completed month:

```text
P    = log(XAU_parent_final) - log(XAG_parent_final)
Q[i] = log(XAU_i) - log(XAG_i), chronological i = 0..n-1
d[0] = Q[0] - P
d[i] = Q[i] - Q[i-1]
net  = Q[n-1] - P

2*count(d>0) > n and net>0 => SELL XAU, BUY XAG
2*count(d<0) > n and net<0 => BUY XAU, SELL XAG
otherwise                   => FLAT
```

A zero return remains in `n` and counts toward neither sign. The month is
consumed flat on a tie, missing strict majority, endpoint disagreement,
equality, incomplete/nonconsecutive month, asynchronous pair, or invalid
close. Signal magnitude never changes eligibility or risk.

The attempt is persisted before history, signal, spread, quote, ATR, sizing,
news, or order gates. The opposite legs target equal absolute USD notionals,
share one fixed-dollar stop budget, use frozen `3.5 * ATR(20,D1)` hard stops,
have no target, and close together at the first observed following-month
boundary.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion route |
| `strategy_history_bars_d1` | 70 | bounded two-month history scan |
| `strategy_min_month_sessions` | 17 | per-month lower bound |
| `strategy_max_month_sessions` | 23 | per-month upper bound |
| `strategy_entry_grace_minutes` | 180 | first-new-month entry window |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen stop distance per leg |
| `strategy_notional_ratio` | 1.0 | XAU/XAG absolute-notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | rounded-package tolerance |
| `strategy_max_hold_days` | 40 | stale-package repair guard |
| `strategy_xau_max_spread_points` | 1500 | XAU entry spread ceiling |
| `strategy_xag_max_spread_points` | 500 | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | market-order deviation ceiling |

Every Q02 baseline parameter is locked; there is no optimization surface.

## 3. Symbol Universe

- Logical basket: `QM5_41112_XAU_XAG_MDAYBREADTH_RV_D1`.
- Host/traded slot 0: exact `XAUUSD.DWX`, D1, magic `411120000`.
- Companion/traded slot 1: exact `XAGUSD.DWX`, D1, magic `411120001`.
- Both legs form one package. Neither leg is a standalone strategy.

## 4. Timeframe

- Decision cadence is one durable attempt per broker month, within 180 raw
  session minutes of the first exact synchronized D1 bar.
- Normal hold is through the first observed next-month boundary; forty
  calendar days is a stale repair guard.

## 5. Expected Behaviour

The prior is approximately 7-10 completed packages per full post-warm-up
year. Q02 retires below five rather than changing the rule. A positive strict
majority with positive endpoint net produces SELL XAU / BUY XAG; the negative
case produces BUY XAU / SELL XAG. Equal returns stay in the denominator.

Q02 also retires the baseline for zero trades, nonpositive governed economics,
wrong direction, wrong month/session reconstruction, leakage, retries,
incomplete aggregate-risk sizing, orphan exposure, missing hard stops, or
nondeterminism. Opposite legs and equal notionals do not prove market
neutrality or low correlation; Q09 alone owns any realized portfolio finding.

## 6. Source Citation

The governed packet is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MDAYBREADTH-RV-2026/source.md`.
It derives from Schweikert (2018), *Journal of Banking & Finance* 88, 44-51,
DOI `10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; and CME
Group's *Gold & Silver Ratio Spread* education.

Those sources support investigating a state-dependent gold/silver relation
and the intermarket ratio carrier. The completed-month daily-sign breadth,
endpoint conjunction, contrarian side, CFD mapping, risk, and lifecycle are
disclosed QM hypotheses. No source return, hedge ratio, neutrality, CFD
equivalence, or correlation result transfers.

## 7. Risk Model

Q02 uses one logical `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both volumes are solved jointly from final broker-
normalized stops so combined normalized stop risk cannot exceed one package
budget while rounded absolute notionals stay within 20 percent. Both news axes
and framework Friday close are OFF.

The runtime owns exactly zero or two opposite positions. An orphaned,
duplicated, same-side, wrong-symbol, wrong-magic, missing-stop,
invalid-volume, or notional-invalid package is flattened immediately. No
retry, pending order, target, trail, scale-in, grid, martingale, pyramid,
partial exit, overlay hedge, or current-month signal input exists.

No live, demo, shadow, stress, or optimization preset; AutoTrading action;
`T_Live` or deploy manifest; portfolio admission; correlation waiver; or
portfolio-gate change is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-22 | approved build identity | source, G0 card, EA-ID, and two deterministic magic rows complete |
