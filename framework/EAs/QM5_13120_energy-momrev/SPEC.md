# QM5_13120_energy-momrev - Strategy Spec

**EA ID:** QM5_13120  
**Slug:** `energy-momrev`  
**Strategy ID:** `BIANCHI-MOMREV-2015_XTI_XNG_S01`  
**Source:** `BIANCHI-MOMREV-2015`  
**Author of this spec:** Codex  
**Last revised:** 2026-07-10

---

## 1. Strategy Logic

This EA implements the Bianchi-Drew-Fan 12-month momentum / 18-month
contrarian double sort as a constrained XTI/XNG energy package. On the first
D1 bar of each broker month it obtains synchronized completed month-end closes
for each leg. It computes each leg's 12- and 18-completed-month log returns.
It buys the 12-month winner and shorts the 12-month loser only when their
18-month ranking is exactly reversed. When the ranks agree or tie, it stays
flat for that month.

The source uses extreme groups from 27 commodity futures. This two-leg carrier
is intentionally narrower and must establish its own density and economics at
Q02. It is mechanically distinct from raw energy momentum, return-spread
reversion, carry, momentum-IVol, same-calendar, and realized-skewness baskets.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_momentum_months` | 12 | locked | source first-sort horizon |
| `strategy_reversal_months` | 18 | locked | source second-sort horizon |
| `strategy_history_bars` | 520 | 450-600 | bounded D1 endpoint buffer |
| `strategy_max_boundary_gap_days` | 10 | 7-10 | maximum stale month-end endpoint |
| `strategy_atr_period_d1` | 20 | 14-30 | per-leg hard-stop ATR period |
| `strategy_atr_sl_mult` | 3.5 | 2.5-5.0 | frozen ATR stop multiple |
| `strategy_max_hold_days` | 35 | locked | stale package guard |
| `strategy_xti_max_spread_pts` | 1500 | 1000-2500 | XTI entry spread cap |
| `strategy_xng_max_spread_pts` | 3000 | 2000-4500 | XNG entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | market-order deviation |

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` - host, crude-oil leg, magic slot 0.
- `XNGUSD.DWX` - natural-gas leg, magic slot 1.
- `QM5_13120_ENERGY_MOMREV_D1` - logical Q02 basket symbol.

**Explicitly not for:** standalone leg tests, XAU/XAG, other commodities, FX,
or indices. Adding instruments changes the approved narrow carrier.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Signal cadence | first tradable D1 bar of each broker month |
| Formation | synchronized completed month-end closes, 12 and 18 months |
| Skip month | none |
| Holding period | until next month transition, maximum 35 days |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Packages / year | approximately 5-9; retire below 5/year at Q02 |
| Typical hold | one broker month |
| Drawdown profile | high; XNG gaps, legging, and narrow-rank sparsity |
| Regime preference | medium-horizon cross-sectional trend with longer-horizon rank reversal |
| Win rate target | no source-derived two-leg target |

---

## 6. Source Citation

Bianchi, Robert J.; Drew, Michael E.; and Fan, John Hua (2015), "Combining
Momentum with Reversal in Commodity Futures", *Journal of Banking & Finance*
59, 423-444, DOI https://doi.org/10.1016/j.jbankfin.2015.07.006.

Accepted manuscript:
https://research-repository.griffith.edu.au/server/api/core/bitstreams/a06d0c4b-7648-4269-a5d7-0b1f2e4e065a/content.

The source's broad futures portfolio performance and correlations are not
imported into this two-CFD build.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---:|
| Backtest Q02+ | `RISK_FIXED` | 1000 per package, split equally by leg |
| Live | not authorized | no live setfile or manifest |

Each leg receives a frozen `ATR(20) * 3.5` broker-side stop. The manager closes
orphans, unexpected sides, month-old packages, and positions beyond 35 days.
Friday close is disabled only to preserve the source-aligned monthly hold.
Framework kill-switch and news-entry guards remain authoritative.

Equal risk and opposite directions do not guarantee beta neutrality. The
loss of the source's broad cross-section, sparse two-rank disagreement, and
futures-to-CFD basis are hard Q02 risks.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-10 | initial build from approved card | strict compile/build PASS; Q02 pending |
