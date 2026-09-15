"""Tests for the Scheduled Automation vault-page generator (render contract).

Covers the pure ``render_markdown`` function: determinism (same inputs -> byte-identical
except the single ``generated_at_utc`` field), sorting, enabled/disabled partition, AI-spend
callout, purpose fallback, and markdown-cell escaping. The live scheduler query
(``fetch_tasks``) is an IO boundary and is not exercised here.

Slice: i3_old_rules_sweep_docs.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

_MOD_PATH = Path(__file__).resolve().parent.parent / "render_scheduled_automation.py"
_spec = importlib.util.spec_from_file_location("render_scheduled_automation", _MOD_PATH)
rsa = importlib.util.module_from_spec(_spec)
assert _spec and _spec.loader
_spec.loader.exec_module(rsa)


SAMPLE = [
    {"name": "QM_StrategyFarm_Pump_5min", "state": "Running", "exe": "C:/py/pythonw.exe",
     "cadence": "rep PT5M", "description": ""},
    {"name": "QM_StrategyFarm_ClaudeOrchestration_15min", "state": "Ready",
     "exe": "C:/py/pythonw.exe", "cadence": "rep PT15M",
     "description": "Headless single-pass claude orchestration cycle."},
    {"name": "QM_StrategyFarm_FactoryRecycle_Daily", "state": "Disabled",
     "exe": "powershell.exe", "cadence": "daily 04:30", "description": "Preventive recycle."},
    {"name": "QM_NightlyBackup_Vault", "state": "Ready", "exe": "powershell.exe",
     "cadence": "daily 02:00", "description": ""},
]


def test_render_is_deterministic_apart_from_timestamp() -> None:
    a = rsa.render_markdown(SAMPLE, "2026-09-15T00:00:00Z")
    b = rsa.render_markdown(list(reversed(SAMPLE)), "2026-09-15T00:00:00Z")
    # Same task set (any input order) -> byte-identical output.
    assert a == b


def test_timestamp_is_the_only_wallclock_field() -> None:
    a = rsa.render_markdown(SAMPLE, "2026-09-15T00:00:00Z")
    b = rsa.render_markdown(SAMPLE, "2027-01-01T12:34:56Z")
    diff = [(x, y) for x, y in zip(a.splitlines(), b.splitlines()) if x != y]
    assert diff == [("generated_at_utc: 2026-09-15T00:00:00Z",
                     "generated_at_utc: 2027-01-01T12:34:56Z")]


def test_frontmatter_counts_and_generated_marker() -> None:
    md = rsa.render_markdown(SAMPLE, "2026-09-15T00:00:00Z")
    assert "generated: true" in md
    assert "task_count: 4" in md
    assert "enabled_count: 3" in md
    assert "disabled_count: 1" in md
    # The disabled task is not in the enabled table but is in the disabled table.
    enabled_block, disabled_block = md.split("## Disabled tasks", 1)
    assert "QM_StrategyFarm_FactoryRecycle_Daily" not in enabled_block.split("## All enabled tasks", 1)[1]
    assert "QM_StrategyFarm_FactoryRecycle_Daily" in disabled_block


def test_ai_spend_callout_lists_orchestration_task() -> None:
    md = rsa.render_markdown(SAMPLE, "2026-09-15T00:00:00Z")
    callout = md.split("## Unattended AI-spend tasks", 1)[1].split("## All enabled tasks", 1)[0]
    assert "QM_StrategyFarm_ClaudeOrchestration_15min" in callout
    assert "QM_NightlyBackup_Vault" not in callout  # not an AI-spend task


def test_purpose_fallback_used_for_blank_description() -> None:
    md = rsa.render_markdown(SAMPLE, "2026-09-15T00:00:00Z")
    # QM_NightlyBackup_Vault has an empty description -> curated fallback appears.
    assert "Nightly backup of the Company Reference vault" in md


def test_markdown_pipes_are_escaped() -> None:
    tasks = [{"name": "QM_X", "state": "Ready", "exe": "x.exe", "cadence": "on-demand",
              "description": "does a | b | c"}]
    md = rsa.render_markdown(tasks, "2026-09-15T00:00:00Z")
    assert "does a \\| b \\| c" in md
