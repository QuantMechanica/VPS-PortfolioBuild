# V5 Sub-Gate Spec

Created: 2026-04-26
Owner: CTO + Quality-Tech (defaults), OWNER (acceptance)
Reviewer: Claude Board Advisor (architecture + V5 boundary)
Replaces: the three missing V4 receipts `CODEX_PIPELINE_V2.1_SPEC.md`, `CODEX_PIPELINE_V2.1_IMPACT.md`, `CODEX_PIPELINE_V2.1_DIFF.md` (Codex 2026-04-26 second-pass confirmed they do not exist anywhere on the laptop or in Drive backups).

## Status

V5-local sub-gate reference. Rebuilt from surviving evidence on the laptop. **Defaults are provisional** — Quality-Tech recalibrates per-phase once the V5 framework (P0-26) produces the first V5 EA distributions. Until then, the defaults below are binding for any V5 EA reaching the corresponding phase.

## Provenance

Built from:

- **Surviving spec**: laptop `doc/pipeline-v2-1-detailed.md` (the one persisted V2.1 spec table, mirrored on VPS at `docs/ops/PIPELINE_PHASE_SPEC.md`).
- **Surviving runner guide**: laptop `Company/scripts/README_V2.1_RUNNERS.md` — concrete CLI flags, default parameter values, output schema.
- **Surviving result receipts**:
  - `V5_PORTFOLIO_RISK_REVIEW_20260418.md` — outlier metrics, P5b compliance numbers
  - `V5_COMPOSITION_LOCK_20260418.md` — locked basket + open waivers
  - `V5_P6_MULTISEED_WAIVERS_20260418.md` — P6 waiver shape
  - `SM_221_P5B_YELLOW_DECISION_20260418.md` — strict-vs-proxy compliance, YELLOW rule
  - `SM_221_P8_NEWS_IMPACT_20260418.md` — P8 output matrix shape and example values
  - `P5_CALIBRATED_NOISE_RECAL_SM_124_UK100_20260418_R002.md` — waiver-shape evidence
- **Older adjacent**: `Backups/pre_claude_design_20260418/Website/blog-pipeline-v2x.html` (HTML reference, reviewed but not literally cited).

What is **not** in the provenance: the three missing CODEX_PIPELINE_V2.1_* receipts. Their absence means the per-phase numerics below are reconstructed from the runner code's defaults plus the result receipts' actual usage, not from a written design document. Any number marked `(reconstructed)` should be re-validated by Quality-Tech.

## Phase Map (mirror)

```
G0  Research Intake
P1  Build Validation
P2  Baseline Screening              PF > 1.30, T > 200, DD < 12%, DEV 2017-2022, Model 4
P3  Parameter Sweep                 30-50 configs, > 50% profitable, plateau check
P3.5 Cross-Sectional Robustness    [this doc]
P4  Walk-Forward                   ≥ 6 anchored folds, DEV→HO embargo, regime labels
P5  Stress Test                    [this doc]
P5b Calibrated Noise Add-on        [this doc]
P5c Crisis Event Slices            [this doc]
P6  Multi-Seed                     [this doc]
P7  Statistical Validation         [this doc]
P8  News Impact                    OFF/PAUSE/SKIP_DAY mode selection (matrix per symbol)
P9  Portfolio Construction         family cap 3, symbol cap 2, ENB + marginal Sharpe
P9b Operational Readiness          checklist (compile/deploy/risk/restart/news/filter/commission)
P10 Shadow Deploy                  [this doc]
```

P2, P3, P4, P8, P9, P9b are described in `PIPELINE_PHASE_SPEC.md`. P3.5, P5, P5b, P5c, P6, P7, P10 are detailed below because their gate criteria need numeric definition, runner specs, and acceptance rules that the one-line spec table did not carry.

## P3.5 — Cross-Sectional Robustness

**Purpose**: prove the EA's edge is not a single-symbol artifact. Tests the EA against an orthogonal asset-class basket.

### Verdicts

| Verdict | Meaning |
|---|---|
| `AUTO_PASS` | baseline PASS set already covers ≥ 2 broad asset classes |
| `NEEDS_RERUN` | only 1 broad class in PASS set → run the 4-symbol CSR pack |
| `PASS` | post-rerun: ≥ 2 broad classes pass on the rerun symbols |
| `FAIL` | post-rerun: still single-class |
| `NO_PASS_BASELINE` | no usable PASS rows in baseline CSV → cannot run CSR |

### Broad asset classes

V5 starts with the V4 class taxonomy (provisional):

- `FX_MAJOR` (EURUSD, GBPUSD, USDJPY, USDCHF, USDCAD, AUDUSD, NZDUSD)
- `FX_CROSS` (EURGBP, EURJPY, GBPJPY, AUDNZD, EURCAD, etc.)
- `INDEX` (UK100, US30, WS30, NAS100, GER40, SPX500)
- `COMMODITY` (XAUUSD, XAGUSD, XTIUSD, XBRUSD)
- `CRYPTO` (BTCUSD, ETHUSD)

### CSR runner

`framework/scripts/p35_csr_runner.py` (V5 reimplementation of laptop's `Company/scripts/p35_csr_runner.py`).

Required inputs: `--ea <V5 ea_id>`, `--baseline-csv <sweep results>`. Optional: `--csr-results-csv <4-symbol rerun>`, `--out-prefix`.

### Acceptance

- `AUTO_PASS` → continue to P4
- `NEEDS_RERUN` → V5 runs the 4-symbol CSR pack (one symbol per missing broad class), then re-evaluates
- `PASS` (post-rerun) → continue to P4
- `FAIL` → block; document why and either down-scope EA to single-class or kill

## P5 — Stress Test

**Purpose**: confirm edge survives a single calibrated stress scenario over full history.

### Calibration source

V5 default: **`framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json`** (V5-rebuilt from the V4 calibration shape; V4 file existed at `Company/Results/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json` and `Company/Results/VPS_SLIPPAGE_LATENCY_CALIBRATION.json`). V5 calibration JSON must contain:

- per-symbol average and tail slippage (in points) measured on the actual VPS / Darwinex demo
- per-symbol commission cents-per-lot
- per-symbol average and tail latency (in ms)
- broker-side spread distribution (median / p95) per symbol

V5 must produce its own calibration JSON before P5 runs against any V5 EA — V4 numbers do not transfer to V5 EAs running on the new VPS.

### Stress profile

V5 default: **HARSH** (preferred over MEDIUM):

- triple median spread
- p95 slippage applied to every fill
- p95 latency applied to every fill
- 5-pip extra slippage on news-tier-1 windows (compatible with `QM_NewsFilter`)

### Acceptance

- post-stress `PF > 1.0` over full history (V2.1 inheritance)
- post-stress trade count ≥ 50% of clean-run trade count (V5 addition — guards against scenarios where stress kills the EA via lot rejection)

### Output

V5 P5 receipt template: `D:\QM\reports\pipeline\<ea_id>\P5_<ea>_<symbol>_<timestamp>.md` with sections:
- clean anchor (PF / Sharpe / DD / Trades)
- stress profile applied
- post-stress metrics
- trade-count delta
- verdict + rationale

## P5b — Calibrated Noise Add-on

**Purpose**: MC robustness against noise / latency / jitter beyond the single calibrated stress scenario.

### Defaults (from V4 surviving runner)

| Parameter | V5 default | Source |
|---|---|---|
| `--paths` | 1000 | V4 default |
| `--seed` | 42 | V4 default |
| `--reject-rate-floor` | 0.001 | V4 default reconstructed |
| `--compliance-thresholds` | `50,60,70` | V4 default |
| `--breach-rules` | `0,<=1,<=2` | V4 default |
| `--min-remaining-cushion-pct` | (per-symbol) | reads from calibration JSON |
| `--recovery-fraction-limit` | (per-symbol) | reads from calibration JSON |

### Compliance gate

V5 inherits the **70% strict** gate as the primary acceptance. V5 also retains **proxy compliance** as a YELLOW path:

| Compliance | Verdict |
|---|---|
| strict-70 ≥ 70% | **PASS / GREEN** |
| strict-70 < 70% AND proxy `<=1 breach` ≥ 70% | **YELLOW** — sleeve down-weight to ≤ 0.25x permitted, requires explicit acceptance note |
| both fail | **FAIL** |

The YELLOW rule is inherited from V4 (`SM_221_P5B_YELLOW_DECISION_20260418.md`) but V5 treats YELLOW as a counted exception, not a default — a basket may carry at most one YELLOW sleeve, and the basket-level risk budget must absorb the YELLOW down-weight.

### Acceptance criteria summary

- PF / Sharpe / DD distribution must remain bounded (recovery-fraction-limit not exceeded)
- compliance verdict per above
- path risk features within configured floors

### Runner

`framework/scripts/p5_calibrated_noise_runner.py` (V5 rewrite of V4 runner, same CLI surface so existing receipts stay readable).

## P5c — Crisis Event Slices

**Purpose**: optional report-first slice over named historical crises.

### V5 named slices

V5 starts with this list (provisional, OWNER may add):

- `2008Q4_GFC_Sep_Oct_2008` (Lehman)
- `2010_Flash_Crash_2010-05-06`
- `2015_CHF_Removal_2015-01-15`
- `2016_Brexit_2016-06-24`
- `2020_COVID_Crash_2020-02-15_to_2020-03-31`
- `2022_LDI_2022-09-22_to_2022-10-14`
- `2023_SVB_2023-03-08_to_2023-03-20`

### Acceptance

P5c is **report-first**. There is no automatic FAIL — the report flags abnormal behaviour (DD spike, trade dropout, PF inversion) and the human reviewer (CEO + Quality-Tech) decides whether the EA is fit for live in regimes where similar crises may recur.

### Output

`D:\QM\reports\pipeline\<ea_id>\P5c_<ea>_<symbol>_<timestamp>.md` with one section per slice and an overall heatmap.

## P6 — Multi-Seed

**Purpose**: prove edge is not a single-seed artefact.

### Defaults

- **5 seeds**: `42, 17, 99, 7, 2026` (V2.1 inherited, kept for cross-version comparability)
- **Acceptance**: PASS on majority (≥ 3 of 5 seeds) AND no seed shows PF < 1.0
- Seeds run on the canonical R002 calibration (matches P5b)

### Verdicts

| Condition | Verdict |
|---|---|
| ≥ 3 seeds PASS, no seed PF < 1.0 | `MULTI_SEED_PASS` |
| ≥ 3 seeds PASS, ≥ 1 seed PF < 1.0 | `MULTI_SEED_MIXED` — Quality-Tech reviews per-seed metrics |
| < 3 seeds PASS | `MULTI_SEED_FAIL` |
| evidence missing for ≥ 1 seed | `MULTI_SEED_WAIVER` — counted as exception per `V5_RESTART_SCOPE_BOUNDARY.md` waiver rule (max one per basket) |

### Output

`D:\QM\reports\pipeline\<ea_id>\P6_<ea>_<symbol>_<timestamp>.md` with per-seed metrics table + overall verdict.

## P7 — Statistical Validation

**Purpose**: protect against overfitting via multiple statistical tests.

### Hard gates

| Gate | V5 threshold | Source |
|---|---|---|
| **PBO** (Probability of Backtest Overfitting, Bailey-Borwein-Lopez de Prado) | **< 5%** hard fail above | V2.1 inheritance |
| **DSR** (Deflated Sharpe Ratio) | **DSR > 0** required (positive after deflation) | V2.1 inheritance |
| **MC permutation p-value** (1000 permutations) | **p < 0.05** | V2.1 inheritance |
| **FDR** (Benjamini-Hochberg) across the EA's parameter sweep | **q < 0.10** at chosen parameter | V2.1 inheritance |

### V5 additions

- **Sample-size guard**: P7 refuses to run if `T < 200` (matches P2 minimum)
- **Multi-test correction note**: each gate computed independently; combined verdict is "all four PASS" — no soft-vote

### Runner

`framework/scripts/p7_stat_validation_runner.py` (V5 new — V4 had no consolidated runner, the four tests were run separately).

### Output

`D:\QM\reports\pipeline\<ea_id>\P7_<ea>_<symbol>_<timestamp>.md`:
- per-test computed value
- per-test PASS / FAIL
- combined verdict
- raw bootstrap distributions attached as JSON

## P10 — Live Burn-In Window (KS-Test Kill-Switch)

**Purpose**: 2-week first-live window at minimum lot, with an automatic KS-test kill-switch if forward distribution diverges from backtest distribution. **No demo intermediary** — DarwinexZero is live-only (per OWNER 2026-04-26), so P10 is the first money-at-risk window.

### Mechanics

- forward window: **14 calendar days** (10 trading days approx) on T6 connected to DXZ Live, **AutoTrading ON**, **minimum lot size** (per-EA contract minimum, typically 0.01 for FX, 0.10 for indices)
- live EA runs on T6 with its registered magic (no shadow-magic-offset — there is no shadow phase)
- live trade-by-trade outcomes captured to `D:\QM\reports\live_burn_in\<ea_id>\<datetime>\trades.csv`
- T6 monitoring per LiveOps Runbook continues; Observability-SRE alerts on any anomaly

### KS-test

- statistic: **two-sample Kolmogorov-Smirnov D**
- compared distributions: forward shadow per-trade returns (N_fwd) vs. backtest per-trade returns from the locked R002 calibration (N_bt)
- p-value threshold: **p < 0.01 → kill** (V5 default; deliberately stricter than 0.05 because the alternative — a real shift between BT and live — is the failure mode V5 is designed to detect)
- minimum sample size: kill check defers until N_fwd ≥ 30 trades; if 14-day window closes with N_fwd < 30, P10 returns `INSUFFICIENT_DATA` and the EA gets a 14-day extension with explicit OWNER acceptance
- lookback for the BT distribution: the most recent **6 months** of the backtest, not full history (matches typical regime persistence)

### Kill action

- if KS test returns `p < 0.01`:
  - all open shadow positions closed at market
  - EA removed from any pending P9 manifest
  - `KS_DAILY_LOSS` style log entry written (`event: P10_KILL`, with KS D, p-value, N_fwd, N_bt)
  - OWNER paged

### Verdicts

| Condition | Verdict |
|---|---|
| 14 days passed, N_fwd ≥ 30, KS p ≥ 0.01 | `LIVE_BURN_IN_PASS` → eligible for position-size expansion per OWNER manifest |
| KS p < 0.01 at any check | `LIVE_BURN_IN_KILL` → flatten + retire, full incident report |
| 14 days passed, N_fwd < 30 | `INSUFFICIENT_DATA` → OWNER decides extend or retire (extending = continued real-money exposure) |

### Runner

`framework/scripts/p10_live_burn_in_runner.py` (V5 new). Runs on a daily schedule via Task Scheduler, reads T6 live trade history, executes the KS test, writes verdict to receipt + immediately pages OWNER if KILL (money-at-risk path).

### Why no demo intermediary

OWNER decision 2026-04-26: DarwinexZero is live-only (monthly subscription fee, no demo account in between). Building a separate demo-broker pre-step would (a) duplicate infrastructure, (b) test against a different liquidity profile than DXZ uses, (c) delay learning real DXZ behavior. Trade-off: P10 is genuinely money-at-risk from day 1, mitigated by minimum-lot size + tight KS kill-switch. See `decisions/2026-04-26_dxz_live_only_and_p10_live_burn_in.md`.

## V5 vs V2.1 — Where defaults differ

| Item | V2.1 (V4 inherited) | V5 default | Reason |
|---|---|---|---|
| P5 trade-count guard | none | `≥ 50% of clean-run` | guards against stress-induced lot rejection masquerading as PASS |
| P5b YELLOW rule | per-sleeve narrative (SM_221) | one-YELLOW-per-basket cap | enforces V5 anti-waiver-creep stance |
| P6 verdict shape | binary PASS / FAIL | 4-state (PASS / MIXED / FAIL / WAIVER) with explicit waiver-counting | matches V5 evidence discipline |
| P7 consolidated runner | none (4 tests run separately) | single runner returns combined verdict | reduces orchestration drift |
| P10 KS p-threshold | not numerically specified anywhere | `p < 0.01` | conservative against the failure mode being detected |
| P10 lookback | not specified | trailing 6 months of BT | matches regime persistence |
| P10 architecture | "shadow on demo" (V4 implicit, never implemented) | "Live Burn-In with minimum lot + KS-test kill-switch" | DXZ is live-only per OWNER 2026-04-26; no demo intermediary |
| All sub-gate runners | Python scripts under `Company/scripts/` | Python scripts under `framework/scripts/` (V5 namespace) | V5 framework boundary |
| Calibration JSON | `Company/Results/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json` | `framework/calibrations/VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json`, V5 must re-measure from VPS | new VPS, new calibration |

## Impact — what V5 EAs need to clear

For any V5 EA to reach P10 PASS, it must clear:

1. P2 baseline (`PF > 1.30`, `T > 200`, `DD < 12%` on DEV 2017-2022, Model 4)
2. P3 sweep (`> 50%` configs profitable, plateau)
3. P3.5 CSR (`AUTO_PASS` or post-rerun `PASS`)
4. P4 walk-forward (≥ 6 folds, regime-labelled, clean OOS)
5. P5 stress (post-stress `PF > 1.0`, ≥ 50% trade-count retention)
6. P5b calibrated noise (strict-70 PASS, or YELLOW with basket budget)
7. P5c crisis slices (report-first, no auto-fail)
8. P6 multi-seed (`MULTI_SEED_PASS` or `MULTI_SEED_MIXED` with QT review)
9. P7 statistical validation (PBO < 5%, DSR > 0, MC p < 0.05, FDR q < 0.10)
10. P8 news impact (OFF / PAUSE / SKIP_DAY mode chosen, plus FTMO / 5ers compliance flags per `decisions/2026-04-25_news_compliance_variants_TBD.md` Hybrid A+C)
11. P9 portfolio construction (admitted to a basket without breaching family cap 3 / symbol cap 2 / portfolio risk budget)
12. P9b operational readiness checklist
13. P10 shadow deploy (KS p ≥ 0.01 over 14 days with N_fwd ≥ 30)

Then: live promotion via `processes/03-v-portfolio-deploy.md`.

## Recalibration Triggers

Defaults above must be re-evaluated by Quality-Tech when any of the following happens:

1. First V5 EA reaches P5b — re-evaluate `--paths 1000` adequacy
2. First V5 EA reaches P6 — re-evaluate seed count and acceptance rule
3. First V5 EA reaches P7 — re-evaluate PBO ≤ 5% in V5 distribution context
4. First V5 EA reaches P10 — re-evaluate KS p < 0.01 in V5 sample-size context
5. After any P5b YELLOW sleeve in a V5 basket — re-evaluate the one-YELLOW-per-basket cap
6. After any V5 incident that traces to a sub-gate weakness

Each recalibration produces a new ADR under `decisions/` and updates this file.

## Open Items (for Quality-Tech first pass)

1. Confirm `--reject-rate-floor 0.001` matches V5 calibration JSON (V4 reconstructed value).
2. Confirm `min-remaining-cushion-pct` and `recovery-fraction-limit` per-symbol values once V5 calibration JSON is built.
3. Confirm crisis-slice list — V5 may want to add 2025 events.
4. Confirm broad-asset-class taxonomy for P3.5 — V5 may want to split `FX_CROSS` further or merge `INDEX` with `INDEX_DERIVATIVE`.
5. Confirm P10 lookback (6 months) versus alternative (full backtest history with weighted recency).
6. Decide whether P7 FDR should run across the *EA's own parameter sweep* (intra-EA) or across *all V5 EAs in the same period* (inter-EA). V4 used intra-EA; inter-EA is more conservative.

## Sources

- `docs/ops/PIPELINE_PHASE_SPEC.md`
- `framework/V5_FRAMEWORK_DESIGN.md`
- `decisions/2026-04-26_v5_restart_clean_slate.md`
- `docs/ops/V5_RESTART_SCOPE_BOUNDARY.md`
- Laptop: `doc/pipeline-v2-1-detailed.md`
- Laptop: `Company/scripts/README_V2.1_RUNNERS.md`
- Laptop: `Company/Results/V5_PORTFOLIO_RISK_REVIEW_20260418.md`
- Laptop: `Company/Results/V5_COMPOSITION_LOCK_20260418.md`
- Laptop: `Company/Results/V5_P6_MULTISEED_WAIVERS_20260418.md`
- Laptop: `Company/Results/SM_221_P5B_YELLOW_DECISION_20260418.md`
- Laptop: `Company/Results/SM_221_P8_NEWS_IMPACT_20260418.md`
- Laptop: `Company/Results/P5_CALIBRATED_NOISE_RECAL_SM_124_UK100_20260418_R002.md`
- Codex: `Phase0_Migration_Pack_2026-04-25/pipeline_spec_second_pass_provenance.md` (CODEX_PIPELINE_V2.1_* confirmed missing)
