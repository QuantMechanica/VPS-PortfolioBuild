# V4 Reference Material

V4 source material kept as reference for V5 Wave 0+ to read, learn from, and reuse selectively. **Not V5 input** — none of these files run as-is in V5. Wave 0 (CTO, DevOps, Documentation-KM) reviews and decides what to port, what to redesign, what to discard.

## Folders

| Folder | Source on Drive | Purpose |
|---|---|---|
| `v4_scripts/` | `Company/scripts/*.{py,ps1}` | V4 Python + PowerShell automation: dashboard refresh, aggregator loop, processes builder, scheduler |
| `v4_infra/` | `Company/scripts/infra/` | V4 Windows infra: MT5 watchdog, load shaping, WinRM bootstrap, GitHub issues sync |
| `v4_controlling/` | `Company/Controlling/` | V4 KPI builder, dashboard evidence map, refresh JS |
| `v4_doc/` | `doc/` | V4 decision history + star EA reference (excludes pipeline-v2-1-detailed.md which is mirrored as `docs/ops/PIPELINE_PHASE_SPEC.md`) |

## Read Rule

V5 inherits patterns and learnings from these scripts but **not their code verbatim**. Reasons:

1. V4 scripts were written for V4-era paths (`Company/Results/`, `Company/scripts/`, `MT5_*` data folders, etc.). V5 paths are different (`framework/`, `D:\QM\reports\`, `C:\QM\mt5\T1..T5\`).
2. V4 had no shared framework library (`Company/Include` was absent — Codex inventory 2026-04-26). V5 builds shared library first; scripts must consume it.
3. V4 doc/code drift: V2.1 runner guide referenced scripts that did not exist (`p35_csr_runner.py`, `p5_calibrated_noise_runner.py`, `run_news_impact_tests.py`). V5 must not reintroduce that pattern — every script reference in V5 specs gets a status badge until built.
4. V4 mass-delete-incident root cause was Drive-sync conflict on `.git/` triggered by concurrent multi-agent git writes from these scripts. PC1-00 (Drive `.git/` exclusion + git mutex) must close before V5 reuses any concurrent-write pattern from these scripts.

## What's Useful Here

- **Magic-number arithmetic patterns** (V4-tested formula `SM_ID * 10000 + symbol_slot`, V5 keeps formula but rebuilds wrapper as `QM_MagicResolver.mqh`)
- **Aggregator loop shape** (`standalone_aggregator_loop.py`): how V4 collected per-tick state from MT5 → JSON. V5 may reuse the architecture but reimplement against new framework.
- **Dashboard refresh cadence patterns** (`full_dashboard_refresh_15min.py`, `refresh_dashboard_data.js`, `build_kpi_sections.py`): how V4 went from raw artifacts to public KPIs. Useful when V5 builds `export_public_snapshot.ps1`.
- **MT5 watchdog patterns** (`mt5_tester_bar_tmp_watchdog.ps1`): how V4 prevented bar*.tmp disk explosions. Same problem class on VPS.
- **MT5 load shaping** (`mt5_load_shaping_gate.ps1`): how V4 paused factory work when T6 needed CPU. Directly applicable to V5 same-VPS factory/live coupling per `LIVE_T6_AUTOMATION_RUNBOOK.md`.
- **WinRM client bootstrap** (`winrm_client_bootstrap.ps1`): how V4 set up remote PowerShell to the VPS from a workstation.
- **Paperclip ↔ GitHub issues sync** (`paperclip_github_issues_sync.sh`): pattern for keeping public issue board mirrored to internal Paperclip.

## What's Confusing Or V4-Specific

- `pipeline_feed_guard.py` — V4 TODO.md heartbeat-feed plumbing. V5 doesn't have the same heartbeat shape; useful only as concept reference.
- `_rewrite_dashboard_template.py` — V4 single-purpose rewrite tool; not portable.
- `setup_processes_scheduler.ps1` + `setup_strategy_panel_refresh_scheduler.ps1` — V4 Task-Scheduler set-up scripts; V5 needs its own per `WEBSITE_DASHBOARD_PAPERCLIP_STYLE.md`.
- `dashboard_evidence_map.md` — V4 layout of what evidence feeds which dashboard tile. Pattern is good, files are V4.

## What's NOT Migrated (intentionally)

- `Company/scripts/.cto_lock*` — V4 operational state files (~120 lock files), not source code
- `Company/scripts/state.json`, `Company/scripts/.cto_last_message.txt` — V4 runtime state
- `Company/scripts/forum_research_toolkit/` — large, V4-specific; check on demand
- `Company/scripts/__pycache__/` — Python build artifacts
- `Company/HANDOFF.md`, `Company/TODO.md` — V4 operational logs (very large, V4-only)
- `Company/Status/CTO/current.md` — 80k tokens, V4 operational state

These are on Drive if needed; not in repo to keep V5 lean.

## Sync Rule

These reference files do not auto-sync. If Drive originals change, repo copies stay frozen. To pick up changes, re-copy explicitly with a Migration Log entry.
