# XAU Around-Fix Drift Study — H1

**Author:** Claude · **Date:** 2026-06-12 · **Task:** 27195799 (study A)
**Method:** H1 proxy analysis — M1 data not available in T_Export at time of study
**Script:** `D:/QM/reports/research/analyze_xau_fix_drift.py`
**CSVs:** `D:/QM/reports/research/xau_fix_drift_am.csv`, `xau_fix_drift_pm.csv`

## Pre-registered hypothesis

**H1:** XAUUSD shows systematic intraday drift around the LBMA auctions (10:30 AM and 15:00 PM
London time) 2016-2026. Hypothesised direction (Nilsson 2015 pattern): *decline into AM fix,
rise after PM fix.*

**Tradeable threshold (pre-registered):** OOS net Sharpe > 0.5 AND same sign as DEV.

**Costs assumed:** 0.07% round-trip (worst-case DXZ XAUUSD spread).

## Data and methodology

- Symbol: XAUUSD.DWX H1 bars (T_Export, exported 2026-06-09)
- Range: 2017-10-02 to 2025-12-31 (48,621 H1 bars)
- DEV: 2016-01-01 to 2021-12-31; OOS: 2022-01-01 to 2026-06-12
  (DEV de-facto starts 2017-10-02, the earliest available H1 bar)
- Fix identification: fix window = H1 bar CONTAINING the fix time
  - UK winter (GMT+0): AM fix at UTC 10:30 → bar UTC 10:00; PM fix at UTC 15:00 → bar UTC 15:00
  - UK summer (BST = UTC+1): AM fix → bar UTC 09:00; PM fix → bar UTC 14:00
  - UK DST: last Sunday March → last Sunday October
- Observations per window: 1,096 DEV + 1,027 OOS (AM and PM each)

**Critical limitation:** The LBMA fix events occur at a specific sub-hour moment. H1 bars
capture the *full hour* containing the fix, averaging drift over ~60 minutes. True pre/post-fix
micro-dynamics (which the Nilsson 2015 and Caminschi-Heaney 2014 papers measure at M1/tick)
are diluted. Results should be interpreted as *directional indicators*, not definitive verdicts.

## Results

### AM Fix (10:30 London)

| Period | n | Pre-1 bar mean | Fix bar mean | Post bar mean | Pre-1 gross Sharpe | Post gross Sharpe | Pre-1 net Sharpe | Post net Sharpe |
|---|---|---|---|---|---|---|---|---|
| DEV | 1,096 | +0.0050% | +0.0022% | +0.0097% | -0.54 | +0.91 | -8.03 | -5.64 |
| OOS | 1,027 | -0.0025% | +0.0014% | -0.0003% | +0.23 | -0.02 | -6.30 | -5.75 |

All t-statistics < 2 (highest: DEV post-bar t = 1.90). No significant pattern.

### PM Fix (15:00 London)

| Period | n | Pre-1 bar mean | Fix bar mean | Post bar mean | Pre-1 gross Sharpe | Post gross Sharpe | Pre-1 net Sharpe | Post net Sharpe |
|---|---|---|---|---|---|---|---|---|
| DEV | 1,096 | -0.0051% | -0.0017% | -0.0062% | +0.56 | -0.34 | -7.04 | -4.19 |
| OOS | 1,027 | -0.0010% | +0.0005% | -0.0053% | +0.10 | -0.25 | -6.39 | -3.60 |

All t-statistics < 2. No significant directional bias. Short pre-PM bar gives gross Sharpe 0.56
in DEV (consistent with "decline into PM fix") but the effect does not hold OOS and is destroyed
by transaction costs.

## Verdict

**H1 = INCONCLUSIVE at H1 resolution.**

- No statistically significant directional drift in hourly windows around either fix.
- Net Sharpe deeply negative across all conditions due to transaction cost dominance vs per-bar
  drift magnitude (~0.005% per bar vs 0.07% cost per trade).
- The *gross* Sharpe of short-pre-1-bar-PM in DEV (0.56) is weakly consistent with the Nilsson
  2015 pattern but does not survive OOS or costs.

**H1 is NOT dead** — this result does not rule out a within-bar M1 signal. The Nilsson 2015
finding operates on 5-minute windows; our H1 bars are 12× coarser. A proper M1 study (exporting
XAUUSD.DWX M1 bars from T_Export, ~10 years × ~23 hours × 60 bars = ~8M rows) is required for
a definitive verdict. The M1 study is low-priority until a TRADEABLE signal emerges at coarser
resolution.

**Caminschi-Heaney 2014 note:** The documented pre-reform edge (insider leakage 2010-2012) was
public-information zero post-publication per deep-research verification (3-0). The post-reform
structural drift (Nilsson 2015 claim for 2015) remains unresolved — exactly as the deep-research
report stated. No card before a proper M1 study.

## Evidence files

| File | Description |
|---|---|
| `D:/QM/reports/research/analyze_xau_fix_drift.py` | Study script |
| `D:/QM/reports/research/xau_fix_drift_am.csv` | AM fix observations (2,123 rows) |
| `D:/QM/reports/research/xau_fix_drift_pm.csv` | PM fix observations (2,123 rows) |
