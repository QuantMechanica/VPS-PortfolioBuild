# QM5_41119_xauxag-mclose-quartile-rv - Strategy Spec

**EA ID:** QM5_41119

**Slug:** `xauxag-mclose-quartile-rv`

**Strategy ID:** `SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026_S01`

**Source:** `SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026`

**Author:** Development

**Last revised:** 2026-08-22

## 1. Strategy Logic

At the first exact synchronized XAU/XAG D1 boundary of a broker month, the EA
reconstructs every synchronized close pair in the immediately completed
calendar month. The month must contain 17 through 23 timestamp-identical
pairs. Ratios are conceptually chronological, while the implementation uses
MT5 series order with the final completed-month ratio at index zero:

```text
s[i] = log(XAU_close[i]) - log(XAG_close[i]), chronological i=0..n-1
z    = s[n-1]
rank = count(s[i] < z)
tail = ceil(n/4) = (n+3)//4

any earlier s[i] == z => FLAT
rank < tail            => BUY XAU, SELL XAG
rank >= n-tail         => SELL XAU, BUY XAG
otherwise              => FLAT
```

The final close participates once. Each outer set contains five or six ranks
over the locked session range. Equality, an interior rank, an incomplete or
non-adjacent month, asynchronous timestamps, invalid closes, or current-month
leakage consumes the month flat. Rank distance does not affect risk.

The attempt is persisted before history, signal, spread, quote, ATR, sizing,
news, or order gates. The opposite legs target equal absolute USD notionals,
share one fixed-dollar stop budget, use frozen `3.5 * ATR(20,D1)` hard stops,
have no target, and close together at the first observed following-month
boundary.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion route |
| `strategy_history_bars_d1` | 45 | bounded completed-month scan |
| `strategy_min_month_sessions` | 17 | month lower bound |
| `strategy_max_month_sessions` | 23 | month upper bound |
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

- Logical basket: `QM5_41119_XAU_XAG_MCLOSE_QUARTILE_RV_D1`.
- Host/traded slot 0: exact `XAUUSD.DWX`, D1, magic `411190000`.
- Companion/traded slot 1: exact `XAGUSD.DWX`, D1, magic `411190001`.
- Both legs form one package. Neither leg is a standalone strategy.

## 4. Timeframe

- Decision cadence is one durable attempt per broker month, within 180 raw
  session minutes of the first exact synchronized D1 bar.
- Formation is the immediately completed 17-to-23-session month.
- Signal is a unique final ratio close inside a fixed outer rank set.
- Normal hold is through the first observed next-month boundary; forty
  calendar days is a stale repair guard.

## 5. Expected Behaviour

The fixed-rank combinatorial prior is approximately 5-7 completed packages per
full post-warm-up year. Q02 retires below five rather than changing the rule.
A lower-quartile final close produces BUY XAU / SELL XAG; an upper-quartile
close produces SELL XAU / BUY XAG. A tie or interior close stays flat.

Q02 also retires the baseline for zero trades, nonpositive governed economics,
wrong direction, wrong month/session reconstruction, leakage, retries,
incomplete aggregate-risk sizing, orphan exposure, missing hard stops, or
nondeterminism. Opposite legs and equal notionals do not prove market
neutrality or low correlation; Q09 alone owns any realized portfolio finding.

## 6. Source Citation

The governed packet is
`strategy-seeds/sources/SCHWEIKERT-CME-XAUXAG-MCLOSE-QUARTILE-RV-2026/source.md`.
It derives from Schweikert (2018), *Journal of Banking & Finance* 88, 44-51,
DOI `10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; and CME
Group's *Gold & Silver Ratio Spread* education.

Those sources support investigating a state-dependent gold/silver relation
and the intermarket ratio carrier. The completed-month close rank, fixed outer
quartile, tie rule, contrarian side, CFD mapping, risk, and lifecycle are
disclosed QM hypotheses. No source return, hedge ratio, neutrality, CFD
equivalence, or correlation result transfers.

## 7. Risk Model

Q02 uses one logical `RISK_FIXED=1000` budget, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Both volumes are solved jointly from final broker-
normalized stops so combined normalized stop risk cannot exceed one package
budget while rounded absolute notionals stay within 20 percent. Both news axes
and framework Friday close are OFF.

The runtime owns exactly zero or two opposite positions. An orphaned,
duplicated, same-side, wrong-symbol, wrong-magic, missing-stop, invalid-volume,
or notional-invalid package is flattened immediately. No retry, pending order,
target, trail, scale-in, grid, martingale, pyramid, partial exit, overlay hedge,
or current-month signal input exists.

No live, demo, shadow, stress, or optimization preset; AutoTrading action;
`T_Live` or deploy manifest; portfolio admission; correlation waiver; or
portfolio-gate change is authorized.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-22 | approved build identity | source, G0 card, EA-ID, two deterministic magic rows, and locked build contract complete |
