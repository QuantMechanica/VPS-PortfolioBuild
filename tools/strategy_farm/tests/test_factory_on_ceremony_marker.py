from __future__ import annotations

import datetime as dt
import json
from pathlib import Path
import subprocess

from tools.strategy_farm import health, render_cockpit


QUIET_ZONE_TASKS = [
    "QM_StrategyFarm_CodexOrchestration_15min",
    "QM_StrategyFarm_GeminiOrchestration_15min",
    "QM_StrategyFarm_ClaudeOrchestration_15min",
    "QM_StrategyFarm_CodexFleetPacer",
    "QM_StrategyFarm_AgyGovernor",
]


def _ps_function(source: str, name: str) -> str:
    start = source.index(f"function {name}")
    next_function = source.find("\nfunction ", start + len(name) + 9)
    return source[start:] if next_function < 0 else source[start:next_function]


def _write_valid_marker(path: Path) -> None:
    path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "kind": "qm.factory_on_ceremony_incomplete",
                "state": "CRITICAL",
                "ceremony_id": "a" * 32,
                "created_at_utc": "2026-08-16T10:35:00+00:00",
                "process_id": 1234,
                "mutation_point": "before_factory_off_release",
                "quiet_zone_release_certified": False,
                "quiet_zone_tasks": QUIET_ZONE_TASKS,
                "runtime_decision_id": "synthetic-decision",
                "runtime_decision_sha256": "b" * 64,
            },
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )


def test_health_marker_absent_is_ok(tmp_path: Path, monkeypatch) -> None:
    marker = tmp_path / "FACTORY_ON_CEREMONY_INCOMPLETE.json"
    monkeypatch.setattr(health, "FACTORY_ON_CEREMONY_INCOMPLETE_PATH", marker)

    result = health.chk_factory_on_ceremony_incomplete()

    assert result["status"] == "OK"
    assert result["value"] == "absent"


def test_health_valid_marker_is_unconditional_fail(
    tmp_path: Path, monkeypatch
) -> None:
    marker = tmp_path / "FACTORY_ON_CEREMONY_INCOMPLETE.json"
    _write_valid_marker(marker)
    monkeypatch.setattr(health, "FACTORY_ON_CEREMONY_INCOMPLETE_PATH", marker)

    result = health.chk_factory_on_ceremony_incomplete()

    assert result["status"] == "FAIL"
    assert result["name"] == "factory_on_ceremony_incomplete"
    assert "marker=valid" in result["detail"]
    assert "Do not enable lanes manually" in result["action_hint"]


def test_health_invalid_marker_still_fails_closed(
    tmp_path: Path, monkeypatch
) -> None:
    marker = tmp_path / "FACTORY_ON_CEREMONY_INCOMPLETE.json"
    marker.write_text("not-json\n", encoding="utf-8")
    monkeypatch.setattr(health, "FACTORY_ON_CEREMONY_INCOMPLETE_PATH", marker)

    result = health.chk_factory_on_ceremony_incomplete()

    assert result["status"] == "FAIL"
    assert result["value"] == "invalid"
    assert "invalid/unreadable" in result["detail"]


def test_cockpit_marker_probe_and_critical_precedence(
    tmp_path: Path, monkeypatch
) -> None:
    marker = tmp_path / "FACTORY_ON_CEREMONY_INCOMPLETE.json"
    monkeypatch.setattr(render_cockpit, "FACTORY_ON_CEREMONY_INCOMPLETE", marker)
    assert not render_cockpit.factory_on_ceremony_incomplete_marker_present()

    _write_valid_marker(marker)
    assert render_cockpit.factory_on_ceremony_incomplete_marker_present()

    source = Path(render_cockpit.__file__).read_text(encoding="utf-8")
    critical = source.index("if ceremony_incomplete:")
    maintenance = source.index("elif factory_off:", critical)
    assert critical < maintenance
    assert 'pill_label = "CRITICAL"' in source[critical:maintenance]
    assert '"factory_on_ceremony_incomplete"' in source
    assert "CRITICAL (FACTORY_ON CEREMONY INCOMPLETE)" in source


def test_programme_panel_marker_wins_over_intentional_off(
    tmp_path: Path, monkeypatch
) -> None:
    marker = tmp_path / "FACTORY_ON_CEREMONY_INCOMPLETE.json"
    factory_off = tmp_path / "FACTORY_OFF.flag"
    _write_valid_marker(marker)
    factory_off.write_text("intentional\n", encoding="utf-8")
    monkeypatch.setattr(render_cockpit, "FACTORY_ON_CEREMONY_INCOMPLETE", marker)
    monkeypatch.setattr(render_cockpit, "FACTORY_OFF_FLAG", factory_off)

    snapshot = render_cockpit.pipeline_books_program_snapshot(
        now_utc=dt.datetime(2026, 7, 30, 10, 0, tzinfo=dt.UTC)
    )
    page = render_cockpit.render_pipeline_books_program(snapshot)

    assert "FACTORY</b> CRITICAL (FACTORY_ON CEREMONY INCOMPLETE)" in page
    assert "FACTORY</b> OFF (INTENTIONAL)" not in page


def test_powershell_marker_round_trip_is_exact_and_removable(tmp_path: Path) -> None:
    factory_on = Path(render_cockpit.__file__).with_name("Factory_ON.ps1")
    source = factory_on.read_text(encoding="utf-8-sig")
    helpers = "\n".join(
        (
            _ps_function(source, "Write-FactoryOnCeremonyIncompleteMarker"),
            _ps_function(source, "Complete-FactoryOnCeremonyMarker"),
        )
    )
    marker = str(tmp_path / "FACTORY_ON_CEREMONY_INCOMPLETE.json").replace(
        "'", "''"
    )
    quiet_tasks = ",".join(f"'{name}'" for name in QUIET_ZONE_TASKS)
    harness = f"""
$ErrorActionPreference = 'Stop'
$factoryOnCeremonyIncompletePath = '{marker}'
$QM_AI_ORCHESTRATION_QUIET_ZONE_TASKS = @({quiet_tasks})
$script:factoryMutationLockNonce = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
$script:runtimeAuthorization = [pscustomobject]@{{
    decision_id = 'synthetic-decision'
    decision_sha256 = ('b' * 64)
}}
function Remove-QmFileIfContentMatches {{
    param([string]$Path,[string]$ExpectedRawBytesBase64)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {{ return $false }}
    $actual = [Convert]::ToBase64String([IO.File]::ReadAllBytes($Path))
    if ($actual -cne $ExpectedRawBytesBase64) {{ return $false }}
    Remove-Item -LiteralPath $Path -Force
    return $true
}}
{helpers}
$record = Write-FactoryOnCeremonyIncompleteMarker
if (-not (Test-Path -LiteralPath $factoryOnCeremonyIncompletePath -PathType Leaf)) {{ exit 40 }}
$parsed = Get-Content -Raw -LiteralPath $factoryOnCeremonyIncompletePath | ConvertFrom-Json
if ($parsed.kind -cne 'qm.factory_on_ceremony_incomplete' -or
    $parsed.state -cne 'CRITICAL' -or
    [bool]$parsed.quiet_zone_release_certified -or
    @($parsed.quiet_zone_tasks).Count -ne 5) {{ exit 41 }}
if ([string]::IsNullOrWhiteSpace($script:factoryOnCeremonyMarkerRawBytesBase64)) {{ exit 42 }}
Complete-FactoryOnCeremonyMarker
if (Test-Path -LiteralPath $factoryOnCeremonyIncompletePath) {{ exit 43 }}
if ($null -ne $script:factoryOnCeremonyMarkerRawBytesBase64) {{ exit 44 }}
Write-Output 'PASS ceremony-marker-round-trip'
"""
    result = subprocess.run(
        ("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", harness),
        cwd=factory_on.parents[2],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS ceremony-marker-round-trip" in result.stdout


def test_health_check_is_registered() -> None:
    registered = {name for name, _function, _needs_connection in health.ALL_CHECKS}
    assert "factory_on_ceremony_incomplete" in registered
