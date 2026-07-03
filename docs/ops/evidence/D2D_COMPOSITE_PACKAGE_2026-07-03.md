# D2-d Composite Package — 15-Sleeve Frozen-Stream Scenarios — 2026-07-03

Task: `106ed489-5914-497b-9ca0-9986372ec8d0`
Status: **DRAFT OWNER DECISION PACKAGE ONLY.** No T_Live files changed, no AutoTrading action taken, no manifest signed.

## Scope

Four scenarios on frozen Q08 streams. The frozen base is the 13-sleeve Variant B v2 snapshot
(task `58c324cc`), extended with three new streams from the durable root.

| ID | Label | Sleeves | Description |
|---|---|---:|---|
| S0 | flat-13 | 13 | Current live book, flat RISK_PERCENT=0.75 each (baseline) |
| S1 | Variant-B-v2 | 13 | Same 13 sleeves, capped inv-vol reweight (ratified 2026-07-03) |
| S2 | D2-d-15 | 15 | S1 + ADMIT 10919/XTIUSD + ADMIT 10476/USDCAD (no swap) |
| S3 | D2-d-15-swap | 15 | S2 but 10940/XAUUSD replaced by 12989/XAUUSD |

## Policy

- Weighting: capped inverse-vol over per-sleeve population std-dev of daily net-of-cost PnL
- Total summed RISK_PERCENT: **9.75%** (unchanged — DXZ VaR-filled, never raised)
- Per-sleeve hard cap: **1.000%**
- Redistribution: iterative pro-rata by inv-vol to under-cap sleeves until stable
- Account basis: $100,000 (RISK_FIXED=1000 backtest baseline)
- Commission: DXZ/FTMO worst-case model via `tools/strategy_farm/portfolio/commission.py`

## Frozen Streams

All computations use the frozen copy at
`D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\frozen_streams\QM\q08_trades`.

**13 streams from Variant B v2 frozen dir** (`58c324cc`):

| File | Lines | SHA256 (prefix) |
|---|---:|---|
| 10440_NDX_DWX.jsonl | 441 | `1a14322430634065...` |
| 10513_XAUUSD_DWX.jsonl | 22 | `af8d0241cd21e37a...` |
| 10692_NDX_DWX.jsonl | 443 | `149e83d2b960949c...` |
| 10715_USDJPY_DWX.jsonl | 1466 | `18fa7348202f2edc...` |
| 10911_GDAXI_DWX.jsonl | 268 | `de53d18052af3362...` |
| 10939_GBPUSD_DWX.jsonl | 92 | `55a54176330827c3...` |
| 10940_XAUUSD_DWX.jsonl | 35 | `2ef38c1fdb3c9703...` |
| 11132_SP500_DWX.jsonl | 43 | `acd06e79d182b7ff...` |
| 11165_AUDCAD_DWX.jsonl | 173 | `f55cdf573588c71b...` |
| 11421_AUDUSD_DWX.jsonl | 53 | `5741ec494c4aa8bb...` |
| 11421_EURUSD_DWX.jsonl | 58 | `ab5e22d9a7dd4bde...` |
| 12567_XAUUSD_DWX.jsonl | 28 | `2572cf8cf16d9dec...` |
| 12567_XNGUSD_DWX.jsonl | 20 | `dc3a99581539e1a0...` |

**3 new streams from durable root** (`D:\QM\reports\portfolio\sleeve_streams`):

| File | Lines | SHA256 (prefix) |
|---|---:|---|
| 10476_USDCAD_DWX.jsonl | 233 | `419878e3d1d551b1...` |
| 10919_XTIUSD_DWX.jsonl | 29 | `2dbbdd1d2eaab4af...` |
| 12989_XAUUSD_DWX.jsonl | 51 | `c1f56840d6fe7ba7...` |

Spot-check: `10939_GBPUSD_DWX.jsonl` SHA256 = `55a54176330827c3...`
matches Variant B v2 reference `55a54176330827c3c797080a6385a35ad4506ba14005490031196aa0feac2078` ✓

## Scenario Comparison

All scenarios span 2017-10-19 to 2025-12-30 (99 months, 8.200 years).
Trade-days: S0/S1 = 1800 | S2 = 1824 | S3 = 1826 (higher count = new sleeves add active days).

| Scenario | Sleeves | Total Net | Annual% | Sharpe | MaxDD% | VaR95m% | Worst Day% | Max Pair Corr |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| S0 flat-13 (current live) | 13 | $138,219 | 16.856 | 1.442 | 15.327 | 4.643 | -3.049 | 0.075 |
| S1 Variant-B-v2 (ratified) | 13 | $86,962 | 10.605 | 1.674 | 6.407 | 2.397 | -1.945 | 0.075 |
| **S2 D2-d-15 (no swap)** | **15** | **$87,568** | **10.679** | **1.978** | **4.524** | **2.195** | **-1.505** | **0.075** |
| **S3 D2-d-15-swap** | **15** | **$91,900** | **11.208** | **2.027** | **4.764** | **2.073** | **-1.541** | **0.076** |

### Key Observations

**S2 vs S1:** Adding XTIUSD and USDCAD raises Sharpe 1.674 -> 1.978 (+18%) and reduces MaxDD
6.407 -> 4.524% (-29%) at nearly identical annual return. Max pair-corr unchanged at 0.075.
Pure diversification gain with no return sacrifice.

**S3 vs S2:** Swapping 10940/XAUUSD for 12989/XAUUSD (exit-surgery challenger) raises annual
return 10.679 -> 11.208% (+53bp) and Sharpe 1.978 -> 2.027, at +24bp MaxDD cost. VaR95 improves
(2.195 -> 2.073). Net: better return for marginal risk increase.

**S3 vs S1 (deployment comparison):** Sharpe 2.027 vs 1.674, MaxDD 4.764% vs 6.407%, Annual
11.208% vs 10.605%. S3 is strictly better on all major metrics.

**Max pair-corr 0.076** across 15 sleeves — excellent diversification maintained.

## S2 RISK_PERCENT Table (D2-d-15)

| Slot | EA | Symbol | TF | Magic | S1 RISK% | S2 RISK% | Delta | Capped |
|---:|---|---|---|---:|---:|---:|---:|---|
| 3 | QM5_10440 | NDX.DWX | H1 | 104400003 | 0.1983 | 0.1498 | -0.0485 | - |
| 4 | **QM5_10476** | **USDCAD.DWX** | **H1** | **104760004** | **NEW** | **0.2175** | **+NEW** | **-** |
| 3 | QM5_10513 | XAUUSD.DWX | D1 | 105130003 | 1.0000 | 0.8172 | -0.1828 | - |
| 5 | QM5_10692 | NDX.DWX | H1 | 106920005 | 0.2707 | 0.2045 | -0.0662 | - |
| 4 | QM5_10715 | USDJPY.DWX | M15 | 107150004 | 0.5011 | 0.3786 | -0.1225 | - |
| 3 | QM5_10911 | GDAXI.DWX | H1 | 109110003 | 0.3846 | 0.2906 | -0.0940 | - |
| 1 | **QM5_10919** | **XTIUSD.DWX** | **H4** | **109190001** | **NEW** | **1.0000** | **+NEW** | **YES** |
| 1 | QM5_10939 | GBPUSD.DWX | H4 | 109390001 | 0.5475 | 0.4137 | -0.1338 | - |
| 3 | QM5_10940 | XAUUSD.DWX | H4 | 109400003 | 0.8478 | 0.6406 | -0.2072 | - |
| 0 | QM5_11132 | SP500.DWX | D1 | 111320000 | 1.0000 | 1.0000 | 0.0000 | YES |
| 2 | QM5_11165 | AUDCAD.DWX | H1 | 111650002 | 1.0000 | 1.0000 | 0.0000 | YES |
| 3 | QM5_11421 | AUDUSD.DWX | D1 | 114210003 | 1.0000 | 0.8482 | -0.1518 | - |
| 0 | QM5_11421 | EURUSD.DWX | D1 | 114210000 | 1.0000 | 0.7890 | -0.2110 | - |
| 3 | QM5_12567 | XAUUSD.DWX | D1 | 125670003 | 1.0000 | 1.0000 | 0.0000 | YES |
| 2 | QM5_12567 | XNGUSD.DWX | D1 | 125670002 | 1.0000 | 1.0000 | 0.0000 | YES |

Total summed RISK_PERCENT S2: **9.7500%** ✓

Note: 10919/XTIUSD immediately hard-capped (29 trades / sparse stream = very low vol = very high
inv-vol weight -> over 1% cap). Adding XTIUSD + USDCAD adds 1.2175% total new risk; the
redistribution algorithm reduces uncapped sleeves proportionally.

## S3 RISK_PERCENT Table (D2-d-15-swap)

| Slot | EA | Symbol | TF | Magic | S2 RISK% | S3 RISK% | Delta | Capped |
|---:|---|---|---|---:|---:|---:|---:|---|
| 3 | QM5_10440 | NDX.DWX | H1 | 104400003 | 0.1498 | 0.1534 | +0.0036 | - |
| 4 | QM5_10476 | USDCAD.DWX | H1 | 104760004 | 0.2175 | 0.2227 | +0.0052 | - |
| 3 | QM5_10513 | XAUUSD.DWX | D1 | 105130003 | 0.8172 | 0.8366 | +0.0194 | - |
| 5 | QM5_10692 | NDX.DWX | H1 | 106920005 | 0.2045 | 0.2094 | +0.0049 | - |
| 4 | QM5_10715 | USDJPY.DWX | M15 | 107150004 | 0.3786 | 0.3876 | +0.0090 | - |
| 3 | QM5_10911 | GDAXI.DWX | H1 | 109110003 | 0.2906 | 0.2975 | +0.0069 | - |
| 1 | QM5_10919 | XTIUSD.DWX | H4 | 109190001 | 1.0000 | 1.0000 | 0.0000 | YES |
| 1 | QM5_10939 | GBPUSD.DWX | H4 | 109390001 | 0.4137 | 0.4236 | +0.0099 | - |
| 3 | ~~QM5_10940~~ | ~~XAUUSD.DWX~~ | ~~H4~~ | ~~109400003~~ | ~~0.6406~~ | **REMOVED** | | |
| 0 | QM5_11132 | SP500.DWX | D1 | 111320000 | 1.0000 | 1.0000 | 0.0000 | YES |
| 2 | QM5_11165 | AUDCAD.DWX | H1 | 111650002 | 1.0000 | 1.0000 | 0.0000 | YES |
| 3 | QM5_11421 | AUDUSD.DWX | D1 | 114210003 | 0.8482 | 0.8684 | +0.0202 | - |
| 0 | QM5_11421 | EURUSD.DWX | D1 | 114210000 | 0.7890 | 0.8078 | +0.0188 | - |
| 3 | QM5_12567 | XAUUSD.DWX | D1 | 125670003 | 1.0000 | 1.0000 | 0.0000 | YES |
| 2 | QM5_12567 | XNGUSD.DWX | D1 | 125670002 | 1.0000 | 1.0000 | 0.0000 | YES |
| 3 | **QM5_12989** | **XAUUSD.DWX** | **H4** | **129890003** | **SWAP-IN** | **0.5431** | **+NEW** | **-** |

Total summed RISK_PERCENT S3: **9.7500%** ✓

Magic collision check: 10513 (105130003), 12567 (125670003), 12989 (129890003) all on
XAUUSD.DWX slot 3 — three distinct magics. 10940 (109400003) is REMOVED in S3. No collision.

## Staged Presets for S3

**Location:** `D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\staged_s3_live_presets\`

15 `.set` files, one per S3 sleeve. Naming:
`slot{N}_{SYM}_{TF}_QM5_{ea}_{slug}_magic{magic}_d2d_s3_live.set`

All files enforce:
- `RISK_FIXED=0` (hard rule: backtest is FIXED, live is PERCENT)
- `RISK_PERCENT={capped_invvol_value}` (4 decimal places)
- `PORTFOLIO_WEIGHT=1.0`
- `qm_filter_news_enabled=1`, `qm_filter_news_mode=3`
- `DRAFT_ONLY ... DO_NOT_COPY_TO_T_LIVE_WITHOUT_SIGNED_OWNER_MANIFEST`

Strategy params inherited from canonical backtest set files. For live deployment, Codex
must verify params match current T_Live set files (field tuning may have occurred since
backtest).

Key new/changed set files:
- `slot3_XAUUSD_H4_QM5_12989_grimes-nested-pb-v2_magic129890003_d2d_s3_live.set` — RISK_PERCENT=0.5431 (swap-in)
- `slot1_XTIUSD_H4_QM5_10919_grimes-overshoot_magic109190001_d2d_s3_live.set` — RISK_PERCENT=1.0000 (new, capped)
- `slot4_USDCAD_H1_QM5_10476_mql5-pamxa_magic104760004_d2d_s3_live.set` — RISK_PERCENT=0.2227 (new)

**S2 delta CSV:** `D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\d2d_s2_risk_delta_2026-07-03.csv`

## Deployment Guardrails (S3 path)

Before any T_Live manifest is signed:
1. 10940/XAUUSD position must close (or be managed to close) before 10940 is deactivated
2. 12989 EA must be verified compiled + news calendar current
3. OWNER manifest with SHA256 of all 15 set files signed
4. Claude verifies magic registry consistent + set files match manifest
5. OWNER or Claude enables AutoTrading on T_Live (per T_Live governance)

## Reproducibility

```
Script:        D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_compute_2026-07-03.py
Metrics JSON:  D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\d2d_composite_metrics_2026-07-03.json
S2 delta CSV:  D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\d2d_s2_risk_delta_2026-07-03.csv
Staged S3:     D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\staged_s3_live_presets\
Frozen dir:    D:\QM\strategy_farm\artifacts\portfolio\d2d_composite_2026-07-03\frozen_streams\
Source V-Bv2:  D:\QM\strategy_farm\artifacts\portfolio\d2c_variant_b_v2_2026-07-03\frozen_streams\
Durable root:  D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\
```

Verification against reference (S0 flat-13, S1 Variant B v2 frozen):
- S0 annual: 16.856% (ref 16.862%) — delta <0.01pp ✓
- S0 Sharpe: 1.442 (ref 1.442) ✓
- S0 MaxDD: 15.327% (ref 15.327%) ✓
- S1 Sharpe: 1.674 (ref 1.674) ✓
- S1 MaxDD: 6.407% (ref 6.407%) ✓
- S1 annual: 10.605% (ref 10.609%) — delta <0.01pp ✓

Monthly VaR95 uses 5th-percentile of calendar-monthly returns; values may differ from
the Variant B v2 reference by 10-15% due to percentile interpolation rounding (99 months,
5th percentile at index 4 vs 4.95 interpolated).

## Risks and Open Items

1. **10919/XTIUSD sparse stream (29 trades)**: Hard-capped at 1.0% due to low volatility.
   Low trade count = wide OOS confidence interval. OWNER should decide if 29 trades is
   sufficient evidence to accept at 1.0% risk.

2. **10476/USDCAD commission model**: Stream has embedded commission; DXZ worst-case
   model applies additional cost. Net is conservative.

3. **12989/XAUUSD (swap-in)**: Exit-surgery challenger per D2C_13SLEEVE_EXIT_SURGERY_AUDIT
   2026-07-03. 51 trades, RISK_PERCENT=0.5431 (well below cap). Lower inv-vol than 10940.

4. **S2 delta vs S1**: 13 existing sleeves all see reduced RISK_PERCENT (additional risk
   budget absorbed by 2 new sleeves). Max reduction: 10513 -0.1828% (1.00 -> 0.82%).

5. **No staged S2 presets**: S2 staged presets were not generated (S3 is the recommended path).
   If OWNER chooses S2 over S3, re-run script targeting S2.
