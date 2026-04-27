<!--
AUTO-GENERATED MIRROR — DO NOT EDIT.
Source: Notion page 34947da58f4a8192bbebc65eaacb0949
Title: V5 Pipeline Design
Mirrored: 2026-04-27T11:24:00Z by Documentation-KM (QUA-151)
Editing surface: Notion. Direct edits will be overwritten by the next sync.
Manifest: infra/notion-sync/manifest.yaml
NOTE: This Notion page is SUPERSEDED 2026-04-26. The Git-canonical V2.1
implementation spec is docs/ops/PIPELINE_PHASE_SPEC.md. This mirror is kept
because the Notion page is still the public/planning copy.
-->

# V5 Pipeline Design

> **⚠️ SUPERSEDED 2026-04-26.** This 10-phase outline does not match the canonical V5 / V2.1 pipeline on the laptop and VPS repo. Use [`docs/ops/PIPELINE_PHASE_SPEC.md`](https://github.com/QuantMechanica/VPS-PortfolioBuild/blob/main/docs/ops/PIPELINE_PHASE_SPEC.md) (15 phases: G0, P1, P2, P3, P3.5, P4, P5, P5b, P5c, P6, P7, P8 News Impact, P9 Portfolio Construction, P9b Operational Readiness, P10 Shadow Deploy → Live). Override rationale: [`decisions/2026-04-25_pipeline_15_phase_override.md`](https://github.com/QuantMechanica/VPS-PortfolioBuild/blob/main/decisions/2026-04-25_pipeline_15_phase_override.md). Content below kept for historical context only.

**Inherits from:** V4 pipeline (the 10-phase structure with baseline → optimization → WF → ...)

**V5 decision:** keep the 10-phase spine as the operating map for now. Paperclip executes and instruments it; Paperclip may propose changes, but cannot silently rewrite the pipeline.

**Key changes from V4:** fewer phases, clearer gates, baked-in scale-invariance checks.

## Phase Map (V5)

```
[Strategy Card] → [P1 Smoke] → [P2 Baseline] → [P3 Optimization Sweep]
                                                                     |
    [P7 Live Candidate] ← [P6 Robustness] ← [P5 Walk-Forward] ← [P4 Selection]
                |
        [P8 Demo Deploy] → [P9 Live Deploy] → [P10 Portfolio Monitor]
```

## Phase Gates (Who Decides, What Evidence)

| Phase | Decision | Evidence required | Approver |
|---|---|---|---|
| P1 Smoke | PASS/FAIL | 1 symbol, 1 year, Model 4, ≥20 trades, PF ≥1.0 | Pipeline-Operator (auto) |
| P2 Baseline | PASS/FAIL/REJECT | Full BL sweep, all symbols, PF ≥1.2, DD ≤20%, ≥50 trades | CEO (with QT cross-check) |
| P3 Optimization | Parameter selection | OOS-separated grid or genetic, DSR >0.5 | CEO |
| P4 Selection | Top-K per source | Cross-strategy ranking | Quality-Business |
| P5 Walk-Forward | PASS/FAIL | Rolling WF with 3+ windows, no window-pick hacking | Quality-Tech |
| P6 Robustness | PASS/FAIL | Monte Carlo + parameter sensitivity | Quality-Tech |
| P7 Live Candidate | Deploy approval | Magic-number assigned, set file ready | CEO + Fabian |
| P8 Demo Deploy | 30-day DarwinexZero/demo observation | T6/DarwinexZero live-test metrics match BT within tolerance | LiveOps |
| P9 Live Deploy | DarwinexZero live-test / money-at-risk activation | Fabian direct manifest approval only | Fabian |
| P10 Monitor | Keep/pause/retire | Rolling 90-day PF, DD, trade count | CEO + Fabian |

## Key Rules Carried Over From V4

- Model 4 (Every Real Tick) on all backtests — no Model 1/2
- Fixed Risk $1K for backtest baseline, Percent Risk for live
- `RISK_PERCENT` + `RISK_FIXED` both supported as EA inputs
- `.DWX` symbols in research / backtests, stripped only at deploy packaging
- Magic number schema: `SM_ID * 10000 + symbol_slot` — collision = hard abort
- Enhancement Doctrine: exit-only changes OK, entry-filter changes kill trades

## How Paperclip Uses This Pipeline

Paperclip is given the source queue, Strategy Cards, gate criteria, runbooks, and evidence requirements. It does not invent a new process every time. Agents operate inside this map:

- Research extracts Strategy Cards from one approved source at a time.
- CTO turns approved cards into technical specs and review checklists.
- Development implements one EA at a time.
- Pipeline-Operator runs P1-P3/P5-P6 jobs on T1-T5 only.
- Quality-Tech and Quality-Business cross-challenge PASS decisions.
- CEO decides gates.
- LiveOps handles P8-P10 on T6/DarwinexZero only after manifest approval.
- R-and-D may propose pipeline changes, but changes require prior-art check, CTO review, CEO approval, and Codex phase-boundary audit.

## Key Rules NEW in V5

- **Scale-invariance check before any re-run** after a systemic bug (lot size, commission). Document which metrics are scale-invariant (P2/P3 gates) and which are not (P7/P9).
- **Smoke ≠ BL-equivalent.** Third-pass audits must use the actual trigger symbol + full BL window, not a portable smoke. (The SM_261 XTIUSD/EURGBP 320x divergence lesson.)
- **Filesystem is truth, trackers are lies.** Before claiming "stall" or "dead EA", always verify with actual file counts vs state.json.
- **NO_REPORT (size-0 .htm) ≠ EA-weakness.** Disambiguate via file-size check BEFORE rendering a "dead EA" verdict.
- **Deep research call before any pipeline spec change.** External frameworks overlap 30% with our methods; research separates signal from duplication.
- **CEO uses 2-phase close:** claim done → verify with real output → archive. No single-step closes.
- **Cross-challenge:** every PASS decision needs 2 agents agreeing at 90%+ confidence. Single-agent PASS is provisional.

## Data Scope

- Darwinex MT5 native data only (no external market APIs — same as V4)
- Darwinex tick data via Tick Data Suite
- DarwinexZero MT5 server time is New-York-Close based: GMT+2 outside US DST, GMT+3 during US DST. Tick Data Manager exports must reproduce this server-time convention before any gate run.
- Custom symbols with `.DWX` suffix — never delete `bases/` (MT5 cannot re-download custom tick data)
- DST/timezone mismatch is a setup/data-quality failure (`SETUP_DATA_MISMATCH`), not a strategy PASS/FAIL signal.

## Unique EA Counting

We count **unique EAs**, not EA+symbol combos. An EA that runs on 5 symbols is 1 EA.

## Deliverable Definition: "PASS for Live"

An EA reaches P7 Live-Candidate only if it has:

- [ ] Source citation (from Strategy Card)
- [ ] P2 Baseline PASS with ≥50 trades on ≥1 symbol
- [ ] P3 Optimization: OOS PF within 20% of IS PF
- [ ] P5 Walk-Forward: ≥3 windows, majority PASS
- [ ] P6 Robustness: Monte Carlo 95% CI does not include PF < 1.0
- [ ] Magic number assigned (no collision in registry)
- [ ] Deploy set file reviewed by Quality-Tech
- [ ] YouTube episode covering this EA drafted (for build-in-public commitment)
