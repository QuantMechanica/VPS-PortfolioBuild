# Pipeline Phase Spec (V5 / V2.1)

Created: 2026-04-25
Owner: CTO + Quality-Tech
Reviewer: CEO + Codex
Source of truth: `G:\My Drive\QuantMechanica\doc\pipeline-v2-1-detailed.md` (laptop), mirrored here as the canonical VPS reference.
Supersedes: the simplified 10-phase pipeline in the older Notion `V5 Pipeline Design` page (see `decisions/2026-04-25_pipeline_15_phase_override.md`).

## Purpose

Authoritative phase-by-phase reference for the V5 strategy/EA pipeline. `PIPELINE_AUTONOMY_MODEL.md` governs *who may change this spec and how*. This file holds *what the spec actually is*.

## Phase Map

```text
G0  Research Intake
P1  Build Validation
P2  Baseline Screening              (DEV only, 2017-2022)
P3  Parameter Sweep
P3.5 Cross-Sectional Robustness     (V2.1 additive)
P4  Walk-Forward                    (OOS begins here)
P5  Stress Test                     (full history begins here)
P5b Calibrated Noise Add-on         (V2.1 additive)
P5c Crisis Event Slices             (optional, report-first)
P6  Multi-Seed
P7  Statistical Validation
P8  News Impact (7 modes: OFF/PAUSE/SKIP_DAY/FTMO_PAUSE/5ers_PAUSE/no_news/news_only)
P9  Portfolio Construction          (manual)
P9b Operational Readiness           (manual)
P10 Live Burn-In Window             (manual; minimum-lot live + KS-test kill-switch — no demo intermediary)
→ Full Live (post-P10 promotion: position-size expansion per OWNER approval)
```

## Phase Detail

| Phase | Name | Description | Type |
|---|---|---|---|
| G0 | Research Intake | Every EA needs economic thesis + failure hypothesis + MT5-native data confirmation. | Autonomous |
| P1 | Build Validation | Compile proof, parameter schema, deterministic smoke test, no missing files. | Autonomous |
| P2 | Baseline Screening | DEV only (2017-2022), `PF > 1.30`, `T > 200`, `DD < 12%`, Model 4, fixed-risk baseline. | Autonomous |
| P3 | Parameter Sweep | 30-50 configs around baseline, `>50%` profitable, plateau check required. | Autonomous |
| P3.5 | Cross-Sectional Robustness | Orthogonal asset-class robustness check (V2.1 additive gate). | Autonomous |
| P4 | Walk-Forward | Min 6 anchored folds with DEV→HO embargo and regime labels. | Autonomous |
| P5 | Stress Test | Single calibrated stress scenario, `PF > 1.0` after stress, full history. | Autonomous |
| P5b | Calibrated Noise Add-on | MC noise/latency/jitter robustness gate with proxy compliance logic (`>= 70%` proxy). | Autonomous |
| P5c | Crisis Event Slices | Optional report-first slices for named events. | Optional |
| P6 | Multi-Seed | 5-seed stability gate (`42, 17, 99, 7, 2026`). | Autonomous |
| P7 | Statistical Validation | DSR + MC + FDR hard gates, **PBO < 5% hard gate**. | Autonomous |
| P8 | News Impact | OFF / PAUSE / SKIP_DAY mode selection for deploy behavior. | Autonomous |
| P9 | Portfolio Construction | Family cap 3, symbol cap 2, ENB + marginal Sharpe. | Manual (OWNER) |
| P9b | Operational Readiness | Compile / deploy / risk / restart / news / filter / commission checks. | Manual (OWNER) |
| P10 | Live Burn-In Window | 2-week LIVE forward test on T6/DXZ with minimum lot + KS-test kill-switch (no demo intermediary, per OWNER 2026-04-26). | Manual (OWNER) |

## V2.1 Policy Notes

- V2.1 is additive and non-invalidating for existing V2.0 PASS results.
- Retroactive reruns are required only for EAs actively moving toward deploy.
- P3.5 and P5b are the two explicit additive gates introduced in V2.1.
- P5b uses proxy compliance (`>= 70%`) instead of strict binary any-breach fail.
- P10 is *not* a permanent demo holding pen. It is a 2-week forward window with a KS-test kill-switch; on PASS the sleeve promotes to live via the V-Portfolio deploy process.

## Methodology Notes

- Baseline (P2) and sweep (P3) remain DEV-only (2017-2022).
- OOS begins with P4 and must remain holdout-clean.
- Full-history windows begin at P5.
- Smoke (P1) is **not** baseline-equivalent. Third-pass audits must use the actual trigger symbol + full BL window, not a portable smoke.
- `NO_REPORT` (size-0 `.htm`) must be disambiguated via file-size check before any "dead EA" verdict.
- `SETUP_DATA_MISSING` (e.g. missing news/calendar seed) and `SETUP_DATA_MISMATCH` (e.g. timezone/DST) are setup-quality failures, never strategy PASS/FAIL signals.

## Locked V5 Composition (snapshot 2026-04-19)

The current locked 5-sleeve basket sits at the P9 / P9b boundary with documented open waivers. See `strategy-seeds/v5_locked_basket_2026-04-18.md` and `Company/Results/V5_COMPOSITION_LOCK_20260418.md` (laptop). Excluded outliers: `SM_890 AUDUSD`, `SM_890 EURUSD`, `SM_882 WS30` (`kill` lane + `sleeve-drop`, see V5 Portfolio Risk Review).

## Deploy Promotion Path (post-P10)

V5 architecture: **DarwinexZero is live-only (no demo account, monthly fee).** There is no demo-broker phase between Backtest and Live — P10 is the first live exposure with minimum lot and KS-test kill-switch.

1. P9b Operational Readiness sign-off
2. P10 Live Burn-In Window — 14 days at minimum lot on T6/DXZ, AutoTrading ON
3. KS-test kill-switch active throughout — kills at p < 0.01 vs backtest distribution (per `PIPELINE_V5_SUB_GATE_SPEC.md` § P10)
4. P10 PASS = OWNER explicit approval to proceed to position-size expansion
5. Position-size expansion = additional manifest signed by OWNER per increment
6. Live monitoring continuous (Observability-SRE)

T6 is the only terminal that trades live. T1-T5 never trade live.

## Open Questions / TBD

- News-rule-set compliance variants (FTMO / The5ers / no-trading-on-news / news-only) are **not** part of the canonical P8 News Impact spec. Decision pending: see `decisions/2026-04-25_news_compliance_variants_TBD.md`.
- **Sub-gate detail authored 2026-04-26 in `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md`** — V5-local reconstruction replacing the missing V4 `CODEX_PIPELINE_V2.1_SPEC/IMPACT/DIFF.md` files (Codex 2026-04-26 second-pass confirmed they do not exist anywhere on Drive). Defaults are provisional pending Quality-Tech recalibration after first V5 EA distributions exist.

## Evidence Index

### V5 (this repo)

- `framework/V5_FRAMEWORK_DESIGN.md` — V5 EA framework spec
- `decisions/2026-04-25_pipeline_15_phase_override.md`
- `decisions/2026-04-26_v5_restart_clean_slate.md`
- `decisions/2026-04-26_v5_framework_design.md`

### V4 / laptop (legacy reference, NOT V5 inputs)

- `Company/Results/V5_COMPOSITION_LOCK_20260418.md`
- `Company/Results/V5_PORTFOLIO_RISK_REVIEW_20260418.md`
- `Company/Results/V5_P6_MULTISEED_WAIVERS_20260418.md`
- `Company/Results/SM_221_P5B_YELLOW_DECISION_20260418.md`
- `Company/Results/SM_221_P8_NEWS_IMPACT_20260418.md`
- `Company/Results/P5_CALIBRATED_NOISE_RECAL_SM_124_UK100_20260418_R002.md`

### Confirmed missing on laptop (per Codex 2026-04-26)

- `Company/Results/CODEX_PIPELINE_V2.1_SPEC.md` — does not exist
- `Company/Results/CODEX_PIPELINE_V2.1_IMPACT.md` — does not exist
- `Company/Results/CODEX_PIPELINE_V2.1_DIFF.md` — does not exist
- `Company/scripts/run_news_impact_tests.py` — does not exist (V4 P8 was hand-orchestrated)

## Hard Rules

- Filesystem is truth.
- Pipeline spec changes only via R-and-D → CTO → Quality-Tech → CEO → Codex audit → Documentation-KM update (see `PIPELINE_AUTONOMY_MODEL.md`).
- No promotion of V1-V4 PASS into V5 PASS without re-test against this spec.
- Magic numbers must be unique and deterministic per sleeve / symbol slot.
- `.DWX` symbols stay in research/backtest workflows; stripped only at VPS deploy packaging.
- Git is the canonical store for spec docs.
