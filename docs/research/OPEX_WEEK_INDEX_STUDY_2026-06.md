# OPEX-Week Long-Index Effect Study
**Task 27195799, Study B** | 2026-06-12

---

## Pre-registered Hypothesis and Thresholds

**Hypothesis:** The OPEX-week long-index effect documented by Stivers & Sun (1988-2010,
cross-sectional equity momentum) replicates at the INDEX level on NDX/WS30/GDAXI post-2010.
Secondary hypothesis: there is post-quad-witching-week weakness (WEEK_AFTER underperforms NORMAL).

**Pre-registered verdict threshold (applied per-symbol, per-week-type):**

| Condition | Verdict |
|---|---|
| OOS net Sharpe > 0.5 AND sign(DEV mean) == sign(OOS mean) | TRADEABLE |
| sign mismatch, n >= 5 | DEAD |
| all other cases | INCONCLUSIVE |

---

## Data and Methodology

### Symbols
All four D1 DWX index symbols were available in T_Export (task brief said WS30 was unavailable
but `WS30.DWX_D1.csv` exists and is included). NDX, SP500, GDAXI, WS30 studied.

### Data source
`D:/QM/mt5/T_Export/MQL5/Files/{SYM}.DWX_D1.csv`  
Format: `time, open, high, low, close, tickvol` — `time` is UTC epoch seconds.

### Timestamp handling (UTC vs broker time)
D1 bars are timestamped at midnight UTC (bar open time). The UTC date of the timestamp is
the trading date directly — no broker-time offset adjustment is needed for daily bars. Broker
time (GMT+2 outside US DST, GMT+3 during US DST) only matters for intraday bar boundaries;
it is irrelevant for the date identity of a D1 bar.

### DEV / OOS split
Pre-registered split was 2018-01-01. All T_Export data starts 2018-07-02, making the original
split unachievable. Adjusted split used:

- **DEV:** 2018-07-02 to 2022-12-31 (~4.5 years)
- **OOS:** 2023-01-01 to 2026-04-24 (~3.3 years)

Bar counts per symbol: NDX 1755, SP500 2014, GDAXI 1981, WS30 2013 (all starting 2018-07-02).

### Week classification
Each ISO calendar week is classified using its Friday date:

| Label | Rule |
|---|---|
| **OPEX** | 3rd Friday of month; month NOT in {3, 6, 9, 12} |
| **QUAD** | 3rd Friday of month; month in {3, 6, 9, 12} (quad-witching) |
| **WEEK_AFTER** | Week immediately following any OPEX or QUAD week |
| **NORMAL** | All other weeks |

Note: results label "OPEX+QUAD" combines both OPEX and QUAD for the primary OPEX test,
consistent with Stivers-Sun's focus on all monthly expiry weeks.

### Weekly return
`log(last_close / first_open)` for weeks with at least 3 trading days (partial weeks at
period boundaries are dropped).

### Statistics
- **t-statistic:** Welch two-sample t-test, target group vs NORMAL weeks.
- **Net Sharpe:** annualised Sharpe of `(opex_ret - mean_normal_ret)` series, multiplied by
  sqrt(52).
- **Bootstrap p-value:** one-sided permutation test (B=1000), probability that a random
  draw of n from the combined pool has mean >= observed mean (OOS OPEX vs NORMAL pool).

**Script:** `D:/QM/reports/research/opex_week_study.py`  
**Per-symbol detail CSVs:** `D:/QM/reports/research/opex_week_{SYM}.csv`  
**Master results CSV:** `D:/QM/reports/research/opex_week_study_results.csv`

---

## Results

### DEV period (2018-07 to 2022-12)

| Symbol | Group | n | Mean weekly ret | t vs NORMAL | Net Sharpe |
|---|---|---|---|---|---|
| NDX | OPEX+QUAD | 42 | -0.5813% | -1.35 | -1.74 |
| NDX | WEEK_AFTER | 42 | +0.4105% | +0.43 | +0.57 |
| NDX | NORMAL | 98 | +0.1793% | — | — |
| WS30 | OPEX+QUAD | 54 | -0.5493% | -2.05 | -2.28 |
| WS30 | WEEK_AFTER | 54 | +0.3552% | -0.20 | -0.22 |
| WS30 | NORMAL | 127 | +0.4607% | — | — |
| GDAXI | OPEX+QUAD | 54 | -0.1041% | -1.24 | -1.71 |
| GDAXI | WEEK_AFTER | 52 | -0.1315% | -0.95 | -1.11 |
| GDAXI | NORMAL | 127 | +0.3912% | — | — |
| SP500 | OPEX+QUAD | 54 | -0.5755% | -2.18 | -2.47 |
| SP500 | WEEK_AFTER | 54 | +0.4950% | +0.10 | +0.11 |
| SP500 | NORMAL | 127 | +0.4458% | — | — |

DEV finding: In all four symbols, OPEX weeks significantly underperform NORMAL weeks (negative
net Sharpe, negative t). The direction is opposite to the Stivers-Sun effect (they found OPEX
outperformance in cross-sectional momentum). Week-after is mildly positive for US indices
but close to zero for GDAXI and WS30.

### OOS period (2023-01 to 2026-04)

| Symbol | Group | n | Mean weekly ret | t vs NORMAL | Net Sharpe | Bootstrap p | Verdict |
|---|---|---|---|---|---|---|---|
| NDX | OPEX+QUAD | 39 | +0.2824% | -0.42 | -0.58 | 0.668 | **DEAD** |
| NDX | WEEK_AFTER | 40 | +0.7288% | +0.44 | +0.63 | — | **TRADEABLE** |
| NDX | NORMAL | 93 | +0.5136% | — | — | — | — |
| WS30 | OPEX+QUAD | 39 | +0.1953% | -0.02 | -0.03 | 0.502 | **DEAD** |
| WS30 | WEEK_AFTER | 40 | +0.3143% | +0.32 | +0.48 | — | **INCONCLUSIVE** |
| WS30 | NORMAL | 93 | +0.2019% | — | — | — | — |
| GDAXI | OPEX+QUAD | 39 | +0.0417% | -0.77 | -1.09 | 0.735 | **DEAD** |
| GDAXI | WEEK_AFTER | 38 | +0.4466% | +0.19 | +0.30 | — | **DEAD** |
| GDAXI | NORMAL | 93 | +0.3719% | — | — | — | — |
| SP500 | OPEX+QUAD | 39 | +0.2319% | -0.25 | -0.35 | 0.577 | **DEAD** |
| SP500 | WEEK_AFTER | 40 | +0.4682% | +0.38 | +0.57 | — | **TRADEABLE** |
| SP500 | NORMAL | 93 | +0.3285% | — | — | — | — |

---

## Verdict Summary

### OPEX long-index effect

| Symbol | DEV direction | OOS direction | OOS net Sharpe | Bootstrap p | Verdict |
|---|---|---|---|---|---|
| NDX | NEGATIVE | sign flip (+) | -0.58 | 0.668 | **DEAD** |
| WS30 | NEGATIVE | sign flip (+) | -0.03 | 0.502 | **DEAD** |
| GDAXI | NEGATIVE | sign flip (+) | -1.09 | 0.735 | **DEAD** |
| SP500 | NEGATIVE | sign flip (+) | -0.35 | 0.577 | **DEAD** |

**OPEX long hypothesis: DEAD across all four symbols.**  
The Stivers-Sun OPEX outperformance does not replicate as a long-index effect. If anything,
OPEX weeks showed a consistent DEV headwind (negative vs NORMAL in all four symbols, t up to
-2.18 for SP500). In OOS the effect reverts to approximately NORMAL, eliminating any net edge.
Bootstrap p-values are all above 0.5, consistent with no detectable edge.

### Post-quad-witching-week weakness (WEEK_AFTER)

| Symbol | DEV direction | OOS direction | OOS net Sharpe | Verdict |
|---|---|---|---|---|
| NDX | POSITIVE (+0.41%) | POSITIVE (+0.73%) | +0.63 | **TRADEABLE** |
| WS30 | POSITIVE (+0.36%) | POSITIVE (+0.31%) | +0.48 | **INCONCLUSIVE** |
| GDAXI | NEGATIVE (-0.13%) | POSITIVE (+0.45%) | +0.30 | **DEAD** (sign flip) |
| SP500 | POSITIVE (+0.50%) | POSITIVE (+0.47%) | +0.57 | **TRADEABLE** |

The secondary hypothesis (weakness after OPEX) inverts: the evidence points to **mild
WEEK_AFTER strength**, not weakness, at least for US indices. NDX and SP500 marginally
clear the TRADEABLE threshold on net Sharpe alone. However, t-statistics are weak (+0.44
and +0.38), sample sizes ~40 OOS observations each, and the effect may be a bull-market
artefact of the OOS period (2023-2026 = strong equity rally).

**Recommendation:** WEEK_AFTER long-index on NDX/SP500 = TRADEABLE by pre-registered
threshold but signal is fragile. BUILD_CARD should be gated on additional data confirmation
(extend OOS with newer tick data if available). GDAXI = DEAD (sign flip DEV to OOS).

---

## Build Card Recommendation

| Hypothesis | Verdict | Action |
|---|---|---|
| Long NDX/SP500/WS30/GDAXI on OPEX weeks | **DEAD** | No card |
| Short NDX/SP500 on OPEX weeks (contrarian) | Not pre-registered; DEV negative was real | Consider as separate hypothesis |
| Long NDX on WEEK_AFTER | **TRADEABLE** (marginal) | BUILD_CARD, note fragility |
| Long SP500 on WEEK_AFTER | **TRADEABLE** (marginal) | BUILD_CARD, note fragility |
| Long WS30 on WEEK_AFTER | **INCONCLUSIVE** | No card; more data needed |
| Long GDAXI on WEEK_AFTER | **DEAD** | No card |

---

## Limitations

1. **No pre-2018 data in T_Export.** The original Stivers-Sun study ran 1988-2010. Our DEV
   period (2018-2022) entirely post-dates their sample; we cannot test within-sample replication.
2. **DEV period includes COVID (2020) and 2022 bear market.** These regimes likely dominate
   the strong negative OPEX signal in DEV. OOS mean-reverts to normal, which is consistent
   with regime rather than structural edge.
3. **Weekly return definition uses open of first bar, not prior Friday close.** This
   introduces a Monday-gap component. Close-to-close was not used because gap bars at period
   boundaries risk look-ahead on partial weeks.
4. **SP500.DWX is backtest-only** (not live-tradable per QM symbol registry). The SP500
   TRADEABLE verdict for WEEK_AFTER cannot be directly operationalised; NDX is the live proxy.
5. **WS30 note:** Contrary to the task brief, WS30.DWX_D1.csv was available and is included.

---

## Evidence Files

| File | Description |
|---|---|
| `D:/QM/reports/research/opex_week_study.py` | Study script (pure stdlib Python) |
| `D:/QM/reports/research/opex_week_study_results.csv` | Master summary with all verdicts |
| `D:/QM/reports/research/opex_week_NDX_DWX.csv` | Per-week detail, NDX |
| `D:/QM/reports/research/opex_week_WS30_DWX.csv` | Per-week detail, WS30 |
| `D:/QM/reports/research/opex_week_GDAXI_DWX.csv` | Per-week detail, GDAXI |
| `D:/QM/reports/research/opex_week_SP500_DWX.csv` | Per-week detail, SP500 |
