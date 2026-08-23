# QM5_41120_xauxag-mopen-residence-rv - Strategy Spec

**EA ID:** QM5_41120

**Slug:** `xauxag-mopen-residence-rv`

**Strategy ID:** `SCHWEIKERT-CME-XAUXAG-MOPEN-RESIDENCE-RV-2026_S01`

**Source:** `SCHWEIKERT-CME-XAUXAG-MOPEN-RESIDENCE-RV-2026`

**Author:** Development

**Last revised:** 2026-08-23

## 1. Strategy Logic

At the first exact synchronized XAU/XAG D1 boundary of a broker month, the EA
reconstructs every synchronized gold-minus-silver log-ratio close in the
immediately completed calendar month. The month must contain 17 through 23
timestamp-identical pairs. MT5 returns completed bars newest-first, so the EA
explicitly reverses the ratios into chronological order:

```text
s[i]     = log(XAU_close[i]) - log(XAG_close[i]), i=0..n-1
anchor   = s[0]
m        = n - 1
above    = count(s[i] > anchor, i=1..n-1)
below    = count(s[i] < anchor, i=1..n-1)
required = ceil(3*m/4) = (3*m+3)//4

above >= required and s[n-1] > anchor => SELL XAU, BUY XAG
below >= required and s[n-1] < anchor => BUY XAU, SELL XAG
otherwise                              => FLAT
```

The anchor is excluded from the denominator. Exact later ties consume one of
the `m` observations but count toward neither side. For 17 through 23 closes,
`m` is 16 through 22 and `required` is 12 through 17. Residence surplus and
endpoint distance never affect side, sizing, stops, or lifecycle.

The broker-month attempt is persisted before history, signal, news, spread,
quote, ATR, sizing, or order gates. A tie-heavy or nonqualifying path,
malformed month, downstream rejection, or order failure consumes the month
without retry.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion route |
| `strategy_history_bars_d1` | 45 | bounded synchronized history load |
| `strategy_min_month_sessions` | 17 | completed-month lower bound |
| `strategy_max_month_sessions` | 23 | completed-month upper bound |
| `strategy_entry_grace_minutes` | 180 | raw first-new-month entry window |
| `strategy_residence_numerator` | 3 | locked residence fraction numerator |
| `strategy_residence_denominator` | 4 | locked residence fraction denominator |
| `strategy_atr_period_d1` | 20 | completed-bar stop estimator |
| `strategy_atr_sl_mult` | 3.5 | frozen stop distance per leg |
| `strategy_notional_ratio` | 1.0 | XAU/XAG absolute-notional target |
| `strategy_max_notional_mismatch_pct` | 20.0 | rounded-package tolerance |
| `strategy_max_hold_days` | 40 | stale-package repair guard |
| `strategy_xau_max_spread_points` | 1500 | XAU entry spread ceiling |
| `strategy_xag_max_spread_points` | 500 | XAG entry spread ceiling |
| `strategy_deviation_points` | 20 | market-order deviation ceiling |

All baseline values are locked. There is no optimization surface.

## 3. Symbol Universe

- Logical basket: `QM5_41120_XAU_XAG_MOPEN_RESIDENCE_RV_D1`.
- Host/traded slot 0: exact `XAUUSD.DWX`, D1, magic `411200000`.
- Companion/traded slot 1: exact `XAGUSD.DWX`, D1, magic `411200001`.
- The two opposite legs are one logical package. Neither leg is evaluated as
  a standalone strategy.

## 4. Timeframe

- One durable decision attempt per broker month, within 180 elapsed minutes
  of the first exact synchronized D1 bar.
- Formation is exactly the immediately completed 17-to-23-session month.
- Normal exit is the first tick of a later broker month.
- Forty calendar days is a stale-state repair guard.
- Friday close and both news axes are OFF under the approved monthly hold.

## 5. Expected Behaviour

The fixed three-quarter residence tails have a pre-result cadence prior of
roughly six to nine packages per full post-warm-up year. Q02 must retire below
five completed packages in any full year, at zero packages, or with
nonpositive governed economics. It must also reject wrong month/session
reconstruction, asynchronous history, current-bar leakage, wrong anchor or
denominator, non-strict tie assignment, wrong ceiling arithmetic, missing
final-side confirmation, wrong contrarian side, retry behavior, incomplete
aggregate-risk sizing, orphan exposure, missing stops, or nondeterminism.

Opposite equal-notional legs are intended to reduce common outright-metal
direction. They do not prove beta neutrality, profitability, or low portfolio
correlation. Q09 alone owns the realized portfolio result.

## 6. Source Citation

The governed packet is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MOPEN-RESIDENCE-RV-2026/source.md`.
It preserves Schweikert (2018), *Journal of Banking & Finance* 88, 44-51,
DOI `10.1016/j.jbankfin.2017.11.010`; supporting fractional-cointegration
lineage from Yaya, Vo, and Olayinka (2021), *Resources Policy* 72, 102045;
and CME Group's *Gold & Silver Ratio Spread*.

Those sources support a related-metal carrier and intermarket-spread
interpretation. They do not test the within-month fixed-open residence state,
continuous CFDs, fixed-dollar equal-notional execution, or the QM book. The
calendar package, strict three-quarter gate, inverse direction, execution, and
risk values are declared QM falsification choices; no source performance
transfers.

## 7. Risk Model

Q02 uses one aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both volumes are solved jointly from final broker-
normalized `3.5*ATR(20,D1)` stops. Combined normalized stop risk cannot exceed
one budget, and rounded absolute notionals must remain within 20 percent.

The runtime owns exactly zero or two opposite positions. An orphaned,
duplicated, same-side, wrong-symbol, wrong-magic, missing-stop, invalid-volume,
or notional-invalid package is flattened immediately. There is no target,
trail, partial exit, add, retry, grid, martingale, pyramid, external feed, or
trained/adaptive logic.

## Framework Alignment

| Card rule | V5 module | Implementation |
|---|---|---|
| exact host/period, frozen inputs, news/Friday contract | No-Trade | `Strategy_NoTradeFilter` and `OnInit` contract |
| month clock, synchronized history, anchor/residence state, attempt, package sizing/open | Trade Entry | `Strategy_EntrySignal` plus basket-order helper |
| side/stop/notional validation and atomic repair | Trade Management | `Strategy_ManageOpenPosition` |
| first-later-month and forty-day closure | Trade Close | package lifecycle helpers; no independent signal exit |

## Validation Plan

Reference tests cover every `n=17..23`, exact ceiling arithmetic, upper and
lower tails, threshold equality, strict ties, final-side confirmation,
chronological anchor sensitivity, malformed synchronization, month/year
boundaries, durable attempts, equal-notional aggregate risk, and static
card/set/manifest identity. Q01 additionally requires card lint, magic
identity, basket-scope validation, setfile schema, and strict compilation.

No live/demo/shadow/stress/optimization preset, manual tester run,
AutoTrading action, `T_Live` or deploy-manifest mutation, portfolio admission,
correlation waiver, or portfolio-gate change is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-23 | approved build identity | source, G0 card, EA-ID, two magic rows, fixed-risk basket contract, and Q01 validation |
