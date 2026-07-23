# Pipeline Phase Spec (V5 / Q-Series)

Created: 2026-04-25
Owner: OWNER
Reviewer: artifact-bound deterministic gates; optional worker audit
Source of truth: `G:\My Drive\QuantMechanica\doc\pipeline-v2-1-detailed.md` (laptop), mirrored here as the canonical VPS reference.
Supersedes: the simplified 10-phase pipeline in the older Notion `V5 Pipeline Design` page (see `decisions/2026-04-25_pipeline_15_phase_override.md`).
Canonical numbering: `docs/ops/PIPELINE_PHASE_ID_MAP.md`. Operator-facing naming uses only Q-series IDs. Legacy runtime keys remain DB/report compatibility only.

## Purpose

Authoritative phase-by-phase reference for the V5 strategy/EA pipeline. `PIPELINE_AUTONOMY_MODEL.md` governs *who may change this spec and how*. This file holds *what the spec actually is*.

## Phase Map

```text
Q00   Research Intake
Q01   Build Validation
Q02   Baseline Screening              (DEV only, 2017-2022)
Q03   Parameter Sweep
Q04   Cross-Sectional Robustness
Q05   Walk-Forward                    (OOS begins here)
Q06   Calibrated Stress               (full history begins here)
Q07   Calibrated Noise                (real MT5 runs required)
Q08   Crisis Event Slices             (real MT5 slice runs required)
Q09   Multi-Seed
Q10   Statistical Validation          (no proxy pass-row counts)
Q11   Real News Replay                (MT5 news-mode reruns + deal replay)
Q12   Portfolio Construction          (manual)
Q13   Operational Readiness           (manual)
Q14   Live Burn-In Window             (manual; minimum-lot live + KS-test kill-switch — no demo intermediary)
→ Full Live (post-Q14 promotion: position-size expansion per OWNER approval)
```

## Phase Detail

| ID | Name | Description | Type |
|---|---|---|---|
| Q00 | Research Intake | Every EA needs economic thesis + failure hypothesis + MT5-native data confirmation. | Autonomous |
| Q01 | Build Validation | Compile proof, parameter schema, deterministic trade-generation smoke test, no missing files. | Autonomous |
| Q02 | Baseline Screening | DEV only (2017-2022), `PF > 1.30`, `T > 200`, `DD < 12%`, Model 4, fixed-risk baseline. | Autonomous |
| Q03 | Parameter Sweep | Balke-style Edge Hunting: 30-100 configs scanning time-ranges (start/duration) and structural technicals (ATR mults, thresholds). | Autonomous |
| Q04 | Cross-Sectional Robustness | Orthogonal asset-class robustness check. | Autonomous |
| Q05 | Walk-Forward | Min 6 anchored folds with DEV→HO embargo and regime labels. | Autonomous |
| Q06 | Calibrated Stress | Calibrated clean/stress MT5 runs, `PF > 1.0` after stress. | Autonomous |
| Q07 | Calibrated Noise | Real MT5 reruns with calibrated noise/stress setfiles. Synthetic MC rows are diagnostics only. | Autonomous |
| Q08 | Crisis Event Slices | Named crisis windows run in MT5. Report-only/proxy rows do not promote. | Autonomous |
| Q09 | Multi-Seed | 5-seed stability gate (`42, 17, 99, 7, 2026`); mixed seeds are FAIL for promotion. | Autonomous |
| Q10 | Statistical Validation | DSR + MC + FDR hard gates, **PBO < 5% hard gate**; proxy pass-row counts are rejected. | Autonomous |
| Q11 | Real News Replay | MT5 news-mode reruns plus deal replay against real UTC news calendar. | Autonomous |
| Q12 | Portfolio Construction | Family cap 3, symbol cap 2, ENB + marginal Sharpe. | Manual (OWNER) |
| Q13 | Operational Readiness | Compile / deploy / risk / restart / news / filter / commission checks. | Manual (OWNER) |
| Q14 | Live Burn-In Window | 2-week LIVE forward test on T6/DXZ with minimum lot + KS-test kill-switch (no demo intermediary, per OWNER 2026-04-26). | Manual (OWNER) |

## V2.1 Policy Notes

- V2.1 is additive and non-invalidating for existing V2.0 PASS results.
- Retroactive reruns are required only for EAs actively moving toward deploy.
- Q04 and Q07 were introduced as V2.1 additive gates.
- Q07 no longer uses proxy compliance as a hard PASS condition. Hard PASS requires real MT5 calibrated-noise reruns.
- Q08 is no longer report-first for promotion. Hard PASS requires real MT5 crisis-slice reruns.
- Q10 must not synthesize PBO/DSR from pass-row counts. Missing real statistical evidence is `WAITING_INPUT`, not PASS.
- Q11 synthetic news matrices are deprecated. Hard PASS requires real news replay evidence.
- Q14 is *not* a permanent demo holding pen. It is a 2-week forward window with a KS-test kill-switch; on PASS the sleeve promotes to live via the V-Portfolio deploy process.

## Methodology Notes

- Q02 and Q03 remain DEV-only (2017-2022).
- **Q03 Hunting Protocol**: For any time-sensitive or breakout strategy, Q03 MUST include a "Edge Hunt" sweep. This includes scanning session start hours (0-23) and structural multipliers (ATR, RSI, Vol). The goal is to discover the symbol-specific "Sweet Spot" before moving to Walk-Forward.
- OOS begins with Q05 and must remain holdout-clean.
- Full-history windows begin at Q06.
- Q01 smoke is **not** baseline-equivalent. Third-pass audits must use the actual trigger symbol + full BL window, not a portable smoke.
- Q01 includes a pre-Q02 trade-generation gate: after build and before Q02 fanout, the latest build smoke must show at least one trade on an in-universe reference run. A zero-trade Q01 smoke routes to Codex fix or card rework and must not create Q02 work items. This is separate from downstream per-symbol zero-trade recovery.
- Q02 fanout must respect the approved card's declared symbol universe and timeframe. Broad DWX fanout is only valid when the approved card is genuinely symbol-agnostic or lacks a parseable declared universe; basket EAs use their logical basket work item.
- `NO_REPORT` (size-0 `.htm`) must be disambiguated via file-size check before any "dead EA" verdict.
- `SETUP_DATA_MISSING` (e.g. missing news/calendar seed) and `SETUP_DATA_MISMATCH` (e.g. timezone/DST) are setup-quality failures, never strategy PASS/FAIL signals.

## Locked V5 Composition (snapshot 2026-04-19)

The current locked 5-sleeve basket sits at the Q12 / Q13 boundary with documented open waivers. See `strategy-seeds/v5_locked_basket_2026-04-18.md` and `Company/Results/V5_COMPOSITION_LOCK_20260418.md` (laptop). Excluded outliers: `SM_890 AUDUSD`, `SM_890 EURUSD`, `SM_882 WS30` (`kill` lane + `sleeve-drop`, see V5 Portfolio Risk Review).

## Deploy Promotion Path (post-Q14)

V5 architecture: **DarwinexZero is live-only (no demo account, monthly fee).** There is no demo-broker phase between Backtest and Live — P10 is the first live exposure with minimum lot and KS-test kill-switch.

1. P9b Operational Readiness sign-off
2. Q14 Live Burn-In Window — 14 days at minimum lot on T6/DXZ; only OWNER may authorize enabling trading
3. KS-test kill-switch active throughout — kills at p < 0.01 vs backtest distribution (per `PIPELINE_V5_SUB_GATE_SPEC.md` § P10)
4. P10 PASS = OWNER explicit approval to proceed to position-size expansion
5. Position-size expansion = additional manifest signed by OWNER per increment
6. Continuous live monitoring through the approved read-only monitoring contract

T6 is the only terminal that trades live. T1-T5 never trade live.

## Open Questions / TBD

- News-rule-set compliance variants (FTMO / The5ers / no-trading-on-news / news-only) are now part of Q11 real news replay. See `framework/conventions/P8_NEWS_DRIVER_AND_CALENDAR_SPEC.md`.
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
- Pipeline spec changes require an explicit OWNER decision, a recorded rationale,
  deterministic-rule review, and an update to the affected runbooks and tests.
- No promotion of V1-V4 PASS into V5 PASS without re-test against this spec.
- Magic numbers must be unique and deterministic per sleeve / symbol slot.
- `.DWX` symbols stay in research/backtest workflows; stripped only at VPS deploy packaging.
- Git is the canonical store for spec docs.
