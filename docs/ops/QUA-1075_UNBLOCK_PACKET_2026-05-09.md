# QUA-1075 Unblock Packet — SRC04_S08 (`lien-channels`) P0→P3

Timestamp: 2026-05-09T12:00:33+02:00
Owner lane for unblock: Development/CTO

## Why this packet

Pipeline-Operator cannot execute P3 yet because deterministic guards show:
- `build_ea_first` (no EA dir / no `.ex5` / no setfiles)
- `stop_no_p2_pass_symbols` (no P2 outputs)

## Required child tasks (create directly)

1. `QUA-1075-P0` — Build + compile EA package for `ea_id=1014`
- Target path: `framework/EAs/QM5_1014_lien_channels/`
- Target file: `framework/EAs/QM5_1014_lien_channels/QM5_1014_lien_channels.mq5`
- Compile artifact required: `framework/EAs/QM5_1014_lien_channels/QM5_1014_lien_channels.ex5`
- Source card: `strategy-seeds/cards/lien-channels_card.md`

2. `QUA-1075-P1` — Smoke validation (Lien worked examples)
- Symbols/timeframe: `USDCAD.DWX M15`, `EURGBP.DWX M15`
- Evidence required: smoke summaries + logs under `D:/QM/reports/smoke/QM5_1014/...`

3. `QUA-1075-P2` — Baseline screening cohort for queue candidate
- Symbols: `USDCAD.DWX,EURGBP.DWX,EURUSD.DWX,GBPUSD.DWX,USDJPY.DWX,USDCHF.DWX,AUDUSD.DWX,NZDUSD.DWX`
- Timeframes: `M15,M30,H1,H4,D1`
- Infra mode: 5-terminal saturation profile per CTO/harness controls
- Evidence required:
  - `D:/QM/reports/pipeline/QM5_1014/P2/report.csv`
  - `D:/QM/reports/pipeline/QM5_1014/P2/p2_QM5_1014_result.json`

## Deterministic preflight commands for Development

```powershell
python C:/QM/repo/framework/scripts/skill_p2_baseline_guard.py --ea-label QM5_1014
python C:/QM/repo/framework/scripts/skill_p3_sweep_guard.py --ea-id QM5_1014
```

Expected transition before Pipeline-Operator resumes P3:
- P2 guard no longer returns `build_ea_first`
- P3 guard returns `status=ok` with nonzero `p2_pass_symbol_count`

## Pipeline-Operator immediate resume command (once unblocked)

```powershell
python C:/QM/repo/framework/scripts/p3_param_sweep.py --ea QM5_1014
```

If P3 command surface changes, fallback is canonical orchestrator:

```powershell
python C:/QM/repo/framework/scripts/phase_orchestrator.py --ea QM5_1014
```

## One-shot resume script (added this heartbeat)

```powershell
pwsh -NoProfile -File C:/QM/repo/framework/scripts/run_qua1075_p3_resume.ps1
```

Behavior:
- Runs P2 guard first, then P3 guard.
- Launches `p3_param_sweep.py` only when both guards pass.
- Fails fast with nonzero exit while still blocked.
