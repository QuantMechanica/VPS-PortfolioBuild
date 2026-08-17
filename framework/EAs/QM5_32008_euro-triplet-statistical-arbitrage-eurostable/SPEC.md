# QM5_32008_euro-triplet-statistical-arbitrage-eurostable — Strategy Spec

**EA ID:** QM5_32008
**Slug:** `euro-triplet-statistical-arbitrage-eurostable`
**Source:** `euro-triplet-statistical-arbitrage-eurostable-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

On each newly closed M15 host bar, align closed prices for `EURUSD.DWX`,
`EURGBP.DWX`, and `GBPUSD.DWX`, then compute the fixed triangular residual:

`epsilon = ln(EURUSD) - ln(EURGBP) - ln(GBPUSD)`

Score the newest residual against the mean and sample standard deviation of
the strictly preceding 60 residuals. At `z <= -2.2`, open a long-residual
package: buy EURUSD, sell EURGBP, and sell GBPUSD. At `z >= +2.2`, reverse all
three legs. Exit the complete package at `abs(z) <= 0.2`; stop it at
`abs(z) >= 3.8`. The coefficients are fixed at `(+1, -1, -1)` and are never
estimated or adapted at runtime.

The three volumes are preflighted before the host order is sent. Failed
companion entry, a missing leg, Friday close, or a risk stop flattens every
owned leg. There is no trailing stop, break-even move, partial close,
averaging, grid, or pyramiding.

---

## 2. Parameters

| Parameter | Default | Authorized range | Meaning |
|---|---:|---:|---|
| `strategy_lookback_bars` | 60 | 30–120 | Strictly prior M15 residuals in the z-score baseline |
| `strategy_entry_z` | 2.20 | 1.80–2.80 | Absolute package-entry threshold |
| `strategy_exit_z` | 0.20 | 0.00–0.50 | Absolute mean-reach exit threshold |
| `strategy_stop_z` | 3.80 | fixed | Package-level residual stop |
| `strategy_atr_period` | 14 | fixed | Closed-M15 ATR used by the entry spread gate |
| `strategy_spread_atr_mult` | 1.80 | fixed | Block entry if any leg spread exceeds this ATR multiple |
| `strategy_deviation_points` | 3 | fixed | Maximum market-order deviation |

Entry is also blocked from 23:55 through 00:05 UTC, after a 2% realized
daily loss, when the 2.5% daily-equity or 5% total-equity cap is hit, or when
the account already has an open position. News axes default to OFF/NONE
because the approved card specifies no news blackout. The framework Friday
21 broker-time close is an explicit qualification safety override and is not
an inferred alpha rule.

---

## 3. Symbol Universe

**Designed for one logical basket only:**

- `EURUSD.DWX` — tester host and registry slot 0.
- `EURGBP.DWX` — companion leg and registry slot 1.
- `GBPUSD.DWX` — companion leg and registry slot 2.

All three symbols are mandatory, traded, and warmed before signals are
evaluated. Bare broker symbols, substituted crosses, standalone leg tests,
and live use are outside this build authorization.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe references | none |
| Price sampling | aligned closed M15 bars only |
| Bar gate | `QM_IsNewBar(EURUSD.DWX, PERIOD_M15)` consumed once |

---

## 5. Expected Behaviour

| Metric | Approved-card prior |
|---|---|
| Package entries / year | about 110 |
| Typical holding time | until residual mean reach or package stop; not quantified by source |
| Expected drawdown profile | bounded by 2.5% daily equity and 5% total equity caps |
| Regime preference | temporary dislocation in the EUR/USD/GBP triangular identity |
| Directional beta | intended market-neutral triangular residual, subject to execution mismatch |

These are source priors, not qualification results. Q02 and later gates are
the economic and robustness judges.

---

## 6. Source Citation

**Source ID:** `euro-triplet-statistical-arbitrage-eurostable-official-source`
**Card citation:** “EuroStable Official EA Specification. 422+ days live
verified on BlackBull.”
**Durable approval record:**
`strategy-seeds/cards/approved/QM5_32008_euro-triplet-statistical-arbitrage-eurostable.md`
**Recorded source quality:** Tier A
**G0 status:** OWNER-authorized `APPROVED`

This build relies on the approved card as the immutable implementation
contract; it does not independently promote or extrapolate the cited live
record.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest Q02 onward | `RISK_FIXED` | USD 1,000 per complete package |
| Live burn-in | not authorized | no live setfile produced |
| Full live | not authorized | no T_Live or manifest change |

The fixed package budget is split equally across the three fixed unit-weight
legs by configuring each order for one third of `PORTFOLIO_WEIGHT`. The card
defines only a package z-stop, not a per-leg broker-price mapping. For the
mandatory server-side catastrophe rail, each leg receives the full remaining
residual log-distance to `abs(z)=3.8`; this deliberately underuses rather than
exceeds the package budget if one leg stops alone. Correlated residual moves
are handled by the closed-bar package stop. This mapping is a documented
implementation assumption for downstream review, not a change to the entry
or exit thresholds.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-17 | Initial approved-card build | Farm task `478c7e37-4692-4e7f-a244-24ec443a9596`; FX market-neutral diversity sleeve |
