# QM5_41123_xauxag-mpath-eff-rv - Strategy Spec

**EA ID:** QM5_41123

**Slug:** `xauxag-mpath-eff-rv`

**Strategy ID:** `SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026_S01`

**Source:** `SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026`

**Author:** Development

**Last revised:** 2026-08-23

## 1. Strategy Logic

At the first exact synchronized XAU/XAG D1 boundary of a broker month, the EA
reconstructs every synchronized gold-minus-silver log-ratio close in the
immediately completed calendar month. The month must contain 17 through 23
timestamp-identical pairs. MT5 returns completed bars newest-first, so the EA
reverses them before forming chronological returns:

```text
s[i] = log(XAU_close[i]) - log(XAG_close[i]), i=0..n-1
r[j] = s[j] - s[j-1],                     j=1..n-1
N    = sum(r[j])
P    = sum(abs(r[j]))
E    = abs(N) / P

require finite arithmetic, P > 0, and E in [0,1] within 1e-10
require E >= 0.20 and N != 0

N > 0 => SELL XAU, BUY XAG
N < 0 => BUY XAU, SELL XAG
otherwise => FLAT
```

Every adjacent return contributes exactly once. Exact-zero constituent returns
are valid. A zero total path, zero net, below-threshold efficiency, malformed
month, or invalid numerical state is flat. No current-month price enters the
statistic, and efficiency magnitude above the inclusive threshold cannot alter
side, risk, stops, or lifecycle.

The broker-month attempt is persisted before history, signal, news, spread,
quote, ATR, sizing, or order gates. Any downstream rejection or order failure
consumes the month without retry.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion route |
| `strategy_history_bars_d1` | 45 | bounded synchronized history load |
| `strategy_min_month_sessions` | 17 | completed-month lower bound |
| `strategy_max_month_sessions` | 23 | completed-month upper bound |
| `strategy_entry_grace_minutes` | 180 | raw first-new-month entry window |
| `strategy_efficiency_threshold` | 0.20 | inclusive fixed entry gate |
| `strategy_efficiency_tolerance` | 1e-10 | numerical upper-bound tolerance |
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

- Logical basket: `QM5_41123_XAU_XAG_MPATH_EFF_RV_D1`.
- Host/traded slot 0: exact `XAUUSD.DWX`, D1, magic `411230000`.
- Companion/traded slot 1: exact `XAGUSD.DWX`, D1, magic `411230001`.
- The opposite legs are one logical package; neither is a standalone strategy.

## 4. Timeframe and Lifecycle

- One durable decision attempt per broker month, within 180 elapsed minutes of
  the first exact synchronized D1 bar.
- Formation is exactly the immediately completed 17-to-23-session month.
- Normal exit is the first tick of a later broker month.
- Forty calendar days is a stale-state repair guard.
- Friday close and both news axes are OFF under the approved monthly hold.

## 5. Expected Behaviour

The fixed 0.20 threshold has an ordering prior of roughly five to seven
packages per full post-warm-up year. Q02 must retire below five completed
packages in any full year, at zero packages, or with nonpositive governed
economics. It must also reject wrong month reconstruction, asynchronous
history, current-bar leakage, skipped or duplicated returns, wrong N/P/E,
acceptance of P=0, rejection of threshold equality, wrong contrarian side,
retry behavior, incomplete aggregate-risk sizing, orphan exposure, missing
stops, or nondeterminism.

Opposite equal-notional legs are designed to reduce common outright-metal
direction. They do not establish beta neutrality, profitability, or low book
correlation. Q09 alone owns realized portfolio correlation.

## 6. Source Citation

The governed packet is
`strategy-seeds/sources/SCHWEIKERT-MOP-CME-XAUXAG-MPATH-EFF-RV-2026/source.md`.
It preserves Schweikert (2018), *Journal of Banking & Finance* 88, 44-51, DOI
`10.1016/j.jbankfin.2017.11.010`; Moskowitz, Ooi, and Pedersen (2012),
*Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`; and CME Group's *Gold-Silver Ratio Spread*.

The sources support the related-metal carrier, completed-price path lineage,
monthly clock, and auditable path statistic. They do not test this daily-ratio
month, the 0.20 threshold, contrarian translation, continuous CFDs,
fixed-dollar equal-notional execution, or the QM book. Those are declared QM
falsification choices; no source performance transfers.

## 7. Risk Model

Q02 uses one aggregate `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both volumes are solved jointly from final
broker-normalized `3.5*ATR(20,D1)` stops. Combined normalized stop risk cannot
exceed one budget, and rounded absolute notionals must remain within 20 percent.

Runtime owns zero exposure or exactly two opposite positions. Orphaned,
duplicated, same-side, wrong-symbol, wrong-magic, missing-stop, invalid-volume,
or notional-invalid exposure is flattened. There is no target, trail, partial
exit, add, retry, grid, martingale, pyramid, external feed, trained logic, or
banned indicator.

## Framework Alignment

| Card rule | V5 module | Implementation |
|---|---|---|
| exact host/period, frozen inputs, news/Friday contract | No-Trade | `Strategy_NoTradeFilter` and `OnInit` |
| month clock, synchronized path arithmetic, attempt, sizing/open | Trade Entry | `Strategy_EntrySignal` and basket helpers |
| side/stop/notional validation and atomic repair | Trade Management | `Strategy_ManageOpenPosition` |
| first-later-month and forty-day closure | Trade Close | package lifecycle helpers |

## Validation Plan

Reference tests cover every `n=17..23`; positive and negative net; zero
constituent returns; P=0 and N=0 flat; E below, equal to, and above 0.20;
telescoping arithmetic; chronological reconstruction; malformed
synchronization; month/year boundaries; durable attempts; equal-notional
aggregate risk; and static card/set/manifest identity. Q01 additionally
requires card lint, magic identity, basket-scope validation, setfile schema,
and strict compilation.

No live/demo/shadow/stress/optimization preset, manual tester run, AutoTrading
action, `T_Live` or deploy-manifest mutation, portfolio admission,
correlation waiver, or portfolio-gate change is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-23 | approved build identity | source, G0 card, EA-ID, two magic rows, fixed-risk basket contract, and Q01 validation |

