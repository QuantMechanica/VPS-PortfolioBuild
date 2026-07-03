# D2-d COMPOSITE PACKAGE: 4-Scenario Frozen-Stream Analysis

**Task:** `106ed489-5914-497b-9ca0-9986372ec8d0`
**Date:** 2026-07-03
**Author:** Claude (orchestration cycle)
**Reference task (frozen snapshot):** `58c324cc-88a9-4e0e-bdbd-7fb941c5dfff` (Variant B v2)

## Purpose

Assembles the quantitative core of the D2-d OWNER decision package. Four scenarios,
all on frozen streams, all using capped inverse-vol policy with total summed RISK = 9.75%
(DXZ VaR-filled; never raised). For OWNER Q12 approval.

## Policy

- Capped inverse-vol weighting (same algorithm as Variant B v2)
- Total summed RISK_PERCENT = **9.75%** (invariant across all scenarios)
- Per-sleeve hard cap = **1.00%**
- Redistribution: iterative pro-rata to uncapped sleeves until stable
- Starting capital reference = $100,000
- Backtest basis: RISK_FIXED=1000; live scale = RISK_PERCENT (same unit)

## Stream Snapshot

13 existing frozen streams copied from Variant B v2 frozen snapshot (`58c324cc`).
3 new streams from durable root (`D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\`):

| file | trades | sha256 (first 16) | source |
|---|---:|---|---|
| 10440_NDX_DWX.jsonl | 441 | 1a14322430634065… | V2_FROZEN |
| 10513_XAUUSD_DWX.jsonl | 22 | af8d0241cd21e37a… | V2_FROZEN |
| 10692_NDX_DWX.jsonl | 443 | 149e83d2b960949c… | V2_FROZEN |
| 10715_USDJPY_DWX.jsonl | 1466 | 18fa7348202f2edc… | V2_FROZEN |
| 10911_GDAXI_DWX.jsonl | 268 | de53d18052af3362… | V2_FROZEN |
| 10939_GBPUSD_DWX.jsonl | 92 | 55a54176330827c3… | V2_FROZEN |
| 10940_XAUUSD_DWX.jsonl | 35 | 2ef38c1fdb3c9703… | V2_FROZEN |
| 11132_SP500_DWX.jsonl | 43 | acd06e79d182b7ff… | V2_FROZEN |
| 11165_AUDCAD_DWX.jsonl | 173 | f55cdf573588c71b… | V2_FROZEN |
| 11421_AUDUSD_DWX.jsonl | 53 | 5741ec494c4aa8bb… | V2_FROZEN |
| 11421_EURUSD_DWX.jsonl | 58 | ab5e22d9a7dd4bde… | V2_FROZEN |
| 12567_XAUUSD_DWX.jsonl | 28 | 2572cf8cf16d9dec… | V2_FROZEN |
| 12567_XNGUSD_DWX.jsonl | 20 | dc3a99581539e1a0… | V2_FROZEN |
| **10919_XTIUSD_DWX.jsonl** | **29** | **2dbbdd1d2eaab4af…** | **DURABLE_ROOT** |
| **10476_USDCAD_DWX.jsonl** | **233** | **419878e3d1d551b1…** | **DURABLE_ROOT** |
| **12989_XAUUSD_DWX.jsonl** | **51** | **c1f56840d6fe7ba7…** | **DURABLE_ROOT** |

Frozen streams location: `D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\frozen_streams\QM\q08_trades\`

## Scenario Comparison

| Scenario | Sleeves | Sum Risk | Annual Return | Sharpe | MaxDD | VaR95/mo | Worst Day | Max Pair Corr |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| S0 flat-13 baseline | 13 | 9.75% | 16.86% | 1.442 | 15.327% | 4.444% | -3.049% | — |
| S1 Variant B v2 (ref) | 13 | 9.75% | 10.61% | 1.674 | 6.407% | 2.206% | -1.945% | — |
| S2 D2-d-15 no swap | 15 | 9.75% | 12.10% | 1.978 | 4.524% | 2.195% | -1.505% | 0.075 |
| **S3 D2-d-15 swap (recommended)** | **15** | **9.75%** | **12.68%** | **2.027** | **4.764%** | **2.073%** | **-1.541%** | **0.076** |

*S0/S1 max-pair-corr not recomputed (reference from V2 JSON). Trade spans: S0/S1 = 1800 days, S2 = 1824 days, S3 = 1826 days.*

**Key finding:** S3 (15-sleeve with 10940→12989 swap) delivers best Sharpe (2.03) and best annual return (12.68%), while keeping MaxDD below 5%. Both S2 and S3 reduce MaxDD dramatically vs S1 (4.5-4.8% vs 6.4%).

## S0 — Flat-13 Baseline (reference only; current live)

13 sleeves × 0.75% = 9.75% total risk. Already deployed on T_Live.

Annual return 16.86% | Sharpe 1.442 | MaxDD **15.327%** | VaR95/mo 4.444% | Worst day −3.049%

*High return but terrible DD — the standard the risk-parity reweight must beat.*

## S1 — Variant B v2 (ratified 2026-07-03; pending deployment)

13 sleeves, capped inv-vol reweight. Not yet deployed on T_Live.

Annual return 10.61% | Sharpe 1.674 | MaxDD **6.407%** | VaR95/mo 2.206% | Worst day −1.945%

*Risk-parity cuts MaxDD in half vs S0 at cost of lower raw return.*

## S2 — D2-d-15 (13 + 10919/XTIUSD + 10476/USDCAD, no swap)

**15 sleeves | Sum RISK = 9.7500% | Trade days = 1824**

Annual return 12.10% | Sharpe **1.978** | MaxDD **4.524%** | VaR95/mo 2.195% | Worst day −1.505% | Max pair-corr 0.075

### S2 RISK_PERCENT Table

| slot | EA | symbol | TF | magic | RISK_PERCENT | hard-capped |
|---:|---|---|---|---:|---:|---|
| 0 | QM5_10440 | NDX.DWX | H1 | 104400003 | 0.1498% | no |
| 1 | QM5_10476 | USDCAD.DWX | H1 | 104760004 | 0.2175% | no |
| 2 | QM5_10513 | XAUUSD.DWX | D1 | 105130003 | 0.8172% | no |
| 3 | QM5_10692 | NDX.DWX | H1 | 106920005 | 0.2045% | no |
| 4 | QM5_10715 | USDJPY.DWX | M15 | 107150004 | 0.3786% | no |
| 5 | QM5_10911 | GDAXI.DWX | H1 | 109110003 | 0.2906% | no |
| 6 | QM5_10919 | XTIUSD.DWX | H4 | 109190001 | **1.0000%** | **yes** |
| 7 | QM5_10939 | GBPUSD.DWX | H4 | 109390001 | 0.4137% | no |
| 8 | QM5_10940 | XAUUSD.DWX | H4 | 109400003 | 0.6406% | no |
| 9 | QM5_11132 | SP500.DWX | D1 | 111320000 | **1.0000%** | **yes** |
| 10 | QM5_11165 | AUDCAD.DWX | H1 | 111650002 | **1.0000%** | **yes** |
| 11 | QM5_11421 | AUDUSD.DWX | D1 | 114210003 | 0.8482% | no |
| 12 | QM5_11421 | EURUSD.DWX | D1 | 114210000 | 0.7890% | no |
| 13 | QM5_12567 | XAUUSD.DWX | D1 | 125670003 | **1.0000%** | **yes** |
| 14 | QM5_12567 | XNGUSD.DWX | D1 | 125670002 | **1.0000%** | **yes** |

### S2 Delta vs S1 (Variant B v2)

| EA | symbol | S1 RISK% | S2 RISK% | delta | change |
|---|---|---:|---:|---:|---|
| QM5_10440 | NDX.DWX | 0.1983% | 0.1498% | −0.0485% | redistributed |
| **QM5_10476** | **USDCAD.DWX** | 0% | **0.2175%** | **+0.2175%** | **ADDED** |
| QM5_10513 | XAUUSD.DWX | 1.0000% | 0.8172% | −0.1828% | redistributed |
| QM5_10692 | NDX.DWX | 0.2707% | 0.2045% | −0.0661% | redistributed |
| QM5_10715 | USDJPY.DWX | 0.5011% | 0.3786% | −0.1224% | redistributed |
| QM5_10911 | GDAXI.DWX | 0.3846% | 0.2906% | −0.0940% | redistributed |
| **QM5_10919** | **XTIUSD.DWX** | 0% | **1.0000%** | **+1.0000%** | **ADDED (capped)** |
| QM5_10939 | GBPUSD.DWX | 0.5475% | 0.4137% | −0.1338% | redistributed |
| QM5_10940 | XAUUSD.DWX | 0.8478% | 0.6406% | −0.2072% | redistributed |
| QM5_11132 | SP500.DWX | 1.0000% | 1.0000% | ±0.0000% | unchanged (capped) |
| QM5_11165 | AUDCAD.DWX | 1.0000% | 1.0000% | ±0.0000% | unchanged (capped) |
| QM5_11421 | AUDUSD.DWX | 1.0000% | 0.8482% | −0.1518% | redistributed |
| QM5_11421 | EURUSD.DWX | 1.0000% | 0.7890% | −0.2110% | redistributed |
| QM5_12567 | XAUUSD.DWX | 1.0000% | 1.0000% | ±0.0000% | unchanged (capped) |
| QM5_12567 | XNGUSD.DWX | 1.0000% | 1.0000% | ±0.0000% | unchanged (capped) |

Note: 10919/XTIUSD hits the 1% cap immediately (low-vol, high inverse-vol weight), redistributing
its excess pro-rata. Existing uncapped sleeves lose ~10-21% each.

## S3 — D2-d-15-swap (10940/XAUUSD replaced by 12989/XAUUSD) — RECOMMENDED

**15 sleeves | Sum RISK = 9.7500% | Trade days = 1826**

Annual return **12.68%** | Sharpe **2.027** | MaxDD **4.764%** | VaR95/mo **2.073%** | Worst day −1.541% | Max pair-corr 0.076

*S3 swaps the original 10940 grimes-nested-pb for the exit-surgery challenger 12989 grimes-nested-pb-v2 (source: D2C 13-sleeve exit surgery audit 2026-07-03). Result: +58bp annual return, +0.05 Sharpe, +24bp MaxDD vs S2 — the swap is net positive.*

### S3 RISK_PERCENT Table

| slot | EA | symbol | TF | magic | RISK_PERCENT | hard-capped |
|---:|---|---|---|---:|---:|---|
| 0 | QM5_10440 | NDX.DWX | H1 | 104400003 | 0.1534% | no |
| 1 | QM5_10476 | USDCAD.DWX | H1 | 104760004 | 0.2227% | no |
| 2 | QM5_10513 | XAUUSD.DWX | D1 | 105130003 | 0.8366% | no |
| 3 | QM5_10692 | NDX.DWX | H1 | 106920005 | 0.2094% | no |
| 4 | QM5_10715 | USDJPY.DWX | M15 | 107150004 | 0.3876% | no |
| 5 | QM5_10911 | GDAXI.DWX | H1 | 109110003 | 0.2975% | no |
| 6 | QM5_10919 | XTIUSD.DWX | H4 | 109190001 | **1.0000%** | **yes** |
| 7 | QM5_10939 | GBPUSD.DWX | H4 | 109390001 | 0.4236% | no |
| 8 | QM5_11132 | SP500.DWX | D1 | 111320000 | **1.0000%** | **yes** |
| 9 | QM5_11165 | AUDCAD.DWX | H1 | 111650002 | **1.0000%** | **yes** |
| 10 | QM5_11421 | AUDUSD.DWX | D1 | 114210003 | 0.8684% | no |
| 11 | QM5_11421 | EURUSD.DWX | D1 | 114210000 | 0.8078% | no |
| 12 | QM5_12567 | XAUUSD.DWX | D1 | 125670003 | **1.0000%** | **yes** |
| 13 | QM5_12567 | XNGUSD.DWX | D1 | 125670002 | **1.0000%** | **yes** |
| 14 | **QM5_12989** | **XAUUSD.DWX** | H4 | **129890003** | **0.5431%** | no |

*10940/XAUUSD (slot 8 in S2) is REMOVED. QM5_12989 grimes-nested-pb-v2 replaces it at slot 14.*

## Staged Presets

### S3 Staged Presets (DRAFT — DO NOT deploy without signed OWNER manifest)

Location: `D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\staged_live_presets_s3\`

15 files (one per sleeve), naming: `slot{N}_{SYM}_{TF}_QM5_{ea}_{slug}_magic{magic}_d2d_s3_live.set`

Key preset properties: `RISK_FIXED=0`, `RISK_PERCENT={computed}`, `PORTFOLIO_WEIGHT=1.0`, `ENV=live`, `qm_filter_news_enabled=1`.

### S2 Staged Presets

Location: `D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\staged_live_presets_s2\`

15 files. Same structure, all 13 original sleeves + 10919 + 10476 (10940 KEPT).

## Reproducibility

- **Computation script:** `D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\compute_d2d_composite.py`
- **Metrics JSON:** `D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\d2d_composite_metrics_2026-07-03.json`
- **Frozen streams:** `D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\frozen_streams\QM\q08_trades\`
- **S2 presets:** `D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\staged_live_presets_s2\`
- **S3 presets:** `D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\staged_live_presets_s3\`
- **V2 reference metrics:** `D:\QM\strategy_farm\artifacts\portfolio\d2c_variant_b_v2_2026-07-03\d2c_variant_b_v2_frozen_metrics_2026-07-03.json`
- Portfolio KPI module: `C:\QM\repo\tools\strategy_farm\portfolio\portfolio_kpi.py`
- `starting_capital = $100,000`, `RISK_FIXED_ref = 1000`, `weight = raw RISK_PERCENT`

## Risks and Notes

1. **10919/XTIUSD low trade count (29 trades)**: Low-vol sleeve gets capped at 1.0% immediately.
   At 29 trades over ~7 years, stream is sparse. OWNER should consider whether this is enough evidence.
2. **Strategy params for existing 13 sleeves**: Staged presets contain card-default params from
   backtest set files. For live deployment, Codex must populate from CURRENT T_Live set files to
   capture any field-tuning done since backtest.
3. **10940 deactivation in S3**: If OWNER chooses S3, the T_Live 10940 position must be managed
   to close before removing. Codex/OWNER deployment manifest must include deactivation step.
4. **S3 corr=0.076**: Very low max pair-corr across 15 sleeves — excellent diversification maintained.
5. **No T_Live writes**: All outputs are staged DRAFT files. Zero T_Live interaction by this task.

## Decision for OWNER

| | S2 (add only) | S3 (swap, recommended) |
|---|---|---|
| Annual return | 12.10% | **12.68%** |
| Sharpe | 1.978 | **2.027** |
| MaxDD | **4.524%** | 4.764% |
| VaR95/mo | 2.195% | **2.073%** |
| Worst day | **−1.505%** | −1.541% |
| New EAs | +2 (10919, 10476) | +2 (10919, 10476) |
| Removed EAs | none | 10940 → 12989 |
| Risk vs S1 | ✅ −1.9pp MaxDD | ✅ −1.6pp MaxDD |

**Recommendation: S3.** Higher Sharpe and return. The 24bp MaxDD disadvantage vs S2 is
more than offset by 58bp more annual return and better tail risk (VaR95 is lower).
The 12989 challenger was audited in the D2-c exit surgery analysis (2026-07-03).
