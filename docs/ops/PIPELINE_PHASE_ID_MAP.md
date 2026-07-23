> **⚠️ STALE — SUPERSEDED by the 2026-05-23 pipeline rewrite. NOT canonical.**
> This file describes the OLD 15-gate pipeline (Q00–Q14) with *different gate meanings*
> (here Q05 = Walk-Forward, Q10 = Statistical Validation). The LIVE pipeline is
> **14 gates Q00–Q13**. Canonical source: vault `03 Pipeline/` (Q00…Q13 files) +
> `tools/strategy_farm/phase_ids.py`. Do NOT use the numbering below — kept for history only.

# Pipeline Phase ID Map

Created: 2026-05-20
Owner: Board Advisor + CTO
Status: Canonical display/spec numbering. Runtime DB phase keys remain supported internally.

## Purpose

The canonical V5 display IDs are linear Q-series IDs. Runtime keys still exist for DB/report compatibility but are not operator-facing names.

| ID | Name | Evidence class |
|---|---|---|
| Q00 | Research Intake | artifact |
| Q01 | Build Validation | compile/smoke |
| Q02 | Baseline Screening | MT5 |
| Q03 | Parameter Sweep | MT5 |
| Q04 | Cross-Sectional Robustness | MT5/report |
| Q05 | Walk-Forward OOS | MT5 |
| Q06 | Calibrated Stress | MT5 |
| Q07 | Calibrated Noise | MT5 |
| Q08 | Crisis Slices | MT5 |
| Q09 | Multi-Seed | MT5 |
| Q10 | Statistical Validation | statistical evidence |
| Q11 | Real News Replay | MT5 + deal replay |
| Q12 | Portfolio Construction | manual OWNER |
| Q13 | Operational Readiness | manual OWNER |
| Q14 | Live Burn-In | live minimum-lot |

## Compatibility Rule

`work_items.phase`, historical paths, CLI flags, and existing reports keep runtime keys for now. Dashboards, prompts, specs, and new documentation show only Q-series IDs unless the topic is explicitly a runtime implementation detail.

## Gate Integrity Rule

Only rows backed by the evidence class above may produce a hard PASS. Proxy or report-only artifacts may be kept for diagnostics, but they must not promote the cascade.
