# Decision: DarwinexZero is live-only — P10 redesigned as Live Burn-In Window

- Date: 2026-04-26
- Status: accepted
- Owner: OWNER
- Affected docs: `docs/ops/PIPELINE_PHASE_SPEC.md` § P10, `docs/ops/PIPELINE_V5_SUB_GATE_SPEC.md` § P10, `docs/ops/LIVE_T6_AUTOMATION_RUNBOOK.md`, `docs/ops/PROJECT_CHARTER.md` (risk register), `docs/ops/EPISODE_GUIDE.md` § EP04, `paperclip-prompts/liveops.md`, `processes/03-v-portfolio-deploy.md`

## Context

V5 docs across multiple files assumed DarwinexZero (DXZ) operates with both demo and live tiers, mirroring the V1-V4 pattern. P10 was specced as "Shadow Deploy on T6 demo with AutoTrading OFF for live, ON for shadow capture only".

OWNER 2026-04-26: **DarwinexZero is live-only.** There is no demo account; DXZ is a paid (monthly fee) live trading service. Verified: live account already exists.

This invalidates every doc that references "DXZ demo", "T6 demo", "demo before live", or any pre-live demo intermediary built on DXZ.

## Decision

**Two binding rules:**

1. V5 has **no demo phase** between Backtest and Live. P10 is the first money-at-risk window.
2. P10 redesigned: **Live Burn-In Window** (was: Shadow Deploy on demo). 14 days, T6 + DXZ Live, **minimum lot size**, **AutoTrading ON**, KS-test kill-switch with `p < 0.01` threshold (per `PIPELINE_V5_SUB_GATE_SPEC.md` § P10).

## Pipeline Flow Changes

### Before (assumed)

```
P9b Operational Readiness
  → P10 Shadow Deploy (T6, AutoTrading OFF for live, ON for shadow capture)
    → 14d shadow window, KS test, magic offset +9000
      → SHADOW_PASS → Live promotion via 03-v-portfolio-deploy
```

### After (binding)

```
P9b Operational Readiness
  → P10 Live Burn-In Window (T6, DXZ Live, AutoTrading ON, MINIMUM LOT)
    → 14d live exposure, KS test, registered magic (no shadow offset)
      → LIVE_BURN_IN_PASS → position-size expansion per OWNER manifest
```

## Doc Updates

| Doc | Change |
|---|---|
| `PIPELINE_PHASE_SPEC.md` § P10 row + § Deploy Promotion Path | "Shadow Deploy" → "Live Burn-In Window"; deploy path collapsed (no demo step) |
| `PIPELINE_V5_SUB_GATE_SPEC.md` § P10 | Mechanics rewritten; verdict labels `LIVE_BURN_IN_PASS / KILL / INSUFFICIENT_DATA`; runner renamed `p10_live_burn_in_runner.py`; new sub-section "Why no demo intermediary" |
| `LIVE_T6_AUTOMATION_RUNBOOK.md` | Operating Model rewritten ("DXZ live-only"); manifest schema example uses `environment: live_burn_in` and `account_type: live` (was `demo`) |
| `PROJECT_CHARTER.md` § Risk Register | Add explicit risk: "P10 is real money from day 1; mitigation = minimum lot + KS kill-switch + OWNER position-size approvals" |
| `EPISODE_GUIDE.md` § EP04 | "MT5 Demo login" reference revised to "DXZ Live login" |
| `paperclip-prompts/liveops.md` | LiveOps system prompt: remove "demo observation" language, emphasize "Live Burn-In = first money at risk, minimum lot mandatory, OWNER paged on KS kill" |
| `processes/03-v-portfolio-deploy.md` | V4 process doc references demo phase; flag for Wave-0 Documentation-KM rewrite (interim: ADR overrides process doc) |

## Risks

| Risk | Mitigation |
|---|---|
| P10 is real-money from day 1 | Minimum lot size mandatory (0.01 FX, 0.10 indices); position-size expansion only via separate OWNER-signed manifest |
| KS-test fires false positive in first 14 days | `p < 0.01` threshold is deliberately conservative; minimum sample N_fwd ≥ 30 prevents kill on noise |
| Backtest assumes liquidity that DXZ live doesn't provide | Per-EA P5 stress + P5b calibrated noise must use DXZ-realistic slippage / latency calibration (`VPS_SLIPPAGE_LATENCY_CALIBRATION_V2.json`) — open item, see `PROJECT_BACKLOG.md` |
| OWNER unavailable when KS kill fires | Auto-flatten + Observability-SRE page; Pipeline-Operator + DevOps escalation channels also wired |

## Alternatives Considered

- **Build a separate demo broker (e.g. Darwinex Demo, ICMarkets Demo) before DXZ Live.** Rejected — duplicates infrastructure for tests that don't reflect DXZ's actual liquidity.
- **Skip P10 entirely; go from P9b straight to full-size live.** Rejected — KS-test against backtest distribution is the V4-learning-driven sanity check; minimum-lot live for 14d is cheap insurance.
- **Paper-trade P10 (track trades but don't execute).** Rejected — needs separate paper-trading infrastructure that V5 doesn't have; minimum-lot live captures real fills without that complexity.
- **Reduce P10 from 14 days to 7 days to limit exposure.** Rejected per `PIPELINE_V5_SUB_GATE_SPEC.md` minimum sample N_fwd ≥ 30 — 14 days is the minimum window that produces enough trades for a meaningful KS test for typical V5 EAs.

## Consequences

- The "T6 demo" mental model goes away across all V5 docs. T6 is "live execution terminal", period.
- Wave 4 (LiveOps) hire trigger changes from "T6 demo + manifest dry run passes" to "T6 Live + first dry-run-style harmless EA placement passes (with AutoTrading OFF as the proof, not Demo)".
- LiveOps prompt's "First dry run" section (use harmless logging EA on EURUSD M15 with AutoTrading OFF) still applies — it's a placement-mechanism dry run, not a demo-trading dry run.
- Process registry: `processes/03-v-portfolio-deploy.md` is V4-era and references demo. Documentation-KM (Wave 0) rewrites it to align. Until then, this ADR overrides.
- Project Charter risk #1 ("Same-VPS factory/live contention") gets a sibling risk: "P10 = real money from day 1".

## Sources

- OWNER conversation 2026-04-26 ("zu 6: es gibt einfach kein Demo Konto in between, 6c: C")
- `decisions/2026-04-26_v5_restart_clean_slate.md`
- `decisions/2026-04-26_v5_sub_gate_reconstruction.md`
- `framework/V5_FRAMEWORK_DESIGN.md` (no change needed — framework already supports any AutoTrading state per manifest)
