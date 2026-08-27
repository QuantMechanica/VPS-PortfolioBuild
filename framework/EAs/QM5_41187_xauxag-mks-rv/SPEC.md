# QM5_41187_xauxag-mks-rv - Strategy Spec

**EA ID:** QM5_41187

**Slug:** `xauxag-mks-rv`

**Strategy ID:** `SCHWEIKERT-NIST-KS2-CME-XAUXAG-MDIST-RV-2026_S01`

**Source:** `SCHWEIKERT-NIST-KS2-CME-XAUXAG-MDIST-RV-2026`

**Author of this spec:** Codex

**Last revised:** 2026-08-27

## 1. Strategy Logic

On the first executable synchronized `XAUUSD.DWX`/`XAGUSD.DWX` D1 bar of a
new broker-calendar month, exclude the current month and select the latest
exactly timestamp-matched close pair in each of the immediately prior twelve
consecutive broker months. Form
`L[i]=ln(XAU_close[i])-ln(XAG_close[i])`, oldest to newest.

Keep fixed older `L[0..5]` and newer `L[6..11]` labels while sorting all
twelve ratios in strict ascending order. Scan the labels and track
`Dplus=max(old_seen-new_seen)` and
`Dminus=max(new_seen-old_seen)`. A dominant `Dplus>=3` maps to SELL XAU / BUY
XAG; a dominant `Dminus>=3` maps to BUY XAU / SELL XAG. A weaker or tied
maximum, any ratio tie, or invalid synchronization consumes flat.

The exposure is one atomic, opposite-side, equal-target-notional precious-
metals package held to the next broker month with one aggregate fixed-risk
ceiling and frozen per-leg ATR hard stops.

## 2. Parameters

| Parameter | Value | Meaning |
|---|---:|---|
| `strategy_xag_symbol` | `XAGUSD.DWX` | exact companion |
| `strategy_endpoint_count` | 12 | synchronized completed months |
| `strategy_block_size` | 6 | fixed older/newer sample size |
| `strategy_min_gap_count` | 3 | inclusive dominant signed ECDF count gap |
| `strategy_history_bars_d1` | 900 | bounded synchronized D1 scan per symbol |
| `strategy_entry_window_minutes` | 180 | first-month-bar execution window |
| `strategy_max_endpoint_gap_days` | 10 | newest endpoint freshness guard |
| `strategy_atr_period_d1` | 20 | completed-bar risk range |
| `strategy_atr_sl_mult` | 3.5 | frozen hard-stop distance |
| `strategy_notional_ratio` | 1.0 | equal target absolute notionals |
| `strategy_max_notional_mismatch_fraction` | 0.20 | package validity cap |
| `strategy_max_hold_days` | 40 | stale-position repair |
| `strategy_xau_max_spread_points` | 1500 | XAU entry-cost guard |
| `strategy_xag_max_spread_points` | 500 | XAG entry-cost guard |
| `strategy_deviation_points` | 20 | framework order deviation contract |
| `qm_friday_close_enabled` | false | preserve full-month ownership |

All strategy parameters are singleton-locked for the Q02 baseline.

## 3. Symbol Universe

- Host/traded slot 0: exact `XAUUSD.DWX`, D1, magic `411870000`.
- Companion/traded slot 1: exact `XAGUSD.DWX`, D1, magic `411870001`.
- Logical symbol: `QM5_41187_XAU_XAG_MKS_RV_D1`.
- The two legs are one strategy package; neither is a standalone signal.

## 4. Timeframe

- Signal and execution timeframe: D1.
- Formation: twelve consecutive synchronized completed broker month ends.
- Trigger: one dominant signed ECDF count gap at inclusive count three,
  traded contrarian.
- Hold: first tick in a later broker month, with forty-day stale repair.

## 5. Expected Behaviour

- Approximately 5 to 8 completed packages per full post-warm-up year; Q02
  retires below five in any such year.
- Contrarian gold/silver relative-value exposure with opposite legs.
- One aggregate fixed-risk package and one consumed attempt per broker month.
- Any tied ratio, invalid block/count invariant, weak maximum, or tied
  directional maximum consumes flat.
- Q09 alone owns any realized portfolio-correlation conclusion.

## 6. Source Citation

Karsten Schweikert (2018), *Are gold and silver cointegrated? New evidence
from quantile cointegrating regressions*, *Journal of Banking & Finance* 88,
44-51, DOI `10.1016/j.jbankfin.2017.11.010`; CME Group, *Gold & Silver Ratio
Spread*; and the NIST Dataplot Reference Manual, *Kolmogorov-Smirnov Two-
Sample Goodness of Fit Test*.

Canonical bounded packet:
`strategy-seeds/sources/SCHWEIKERT-NIST-KS2-CME-XAUXAG-MDIST-RV-2026/source.md`.

The sources support state-dependent gold/silver relation, the intermarket
carrier, and the named two-sample ECDF maximum-gap method. The exact sample,
integer boundary, contrarian direction, continuous-CFD mapping, execution,
and risk are disclosed QM hypotheses; no source result transfers.

## 7. Risk Model

Q02 uses aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Each leg begins at half the aggregate frozen-stop risk
allowance; balancing may only reduce the larger target notional. The EA
requires no more than 20% realized notional mismatch. Both news axes and
Friday close are OFF.

There is no live/demo/shadow/stress/optimization setfile, manual backtest,
AutoTrading, `T_Live`, deploy or live manifest, portfolio admission,
correlation waiver, portfolio-gate change, current-month signal price,
average-rank tie handling, p-value, fitted center or scale, fitted hedge
ratio, signal-strength sizing, external feed, retry, scale-in, grid,
martingale, pyramid, target, trail, break-even move, or partial exit.

## Framework Alignment

- no_trade: exact symbols/period/ID/slots and locked risk/news/Friday inputs.
- trade_entry: consumed month, synchronized endpoints, chronological ratios,
  fixed blocks, strict combined ordering, both signed count maxima, inclusive
  contrarian gate, spread/quote/ATR/stop checks, equal-notional sizing, and
  atomic submission.
- trade_management: malformed-package repair, later-month exit, and stale
  repair before entry-only gates.
- trade_close: framework close helper, broker hard stops, and kill switch.

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v0 | 2026-08-27 | approved source build | G0-approved card; governed magics `411870000`/`411870001`; one logical Q02 preset |
