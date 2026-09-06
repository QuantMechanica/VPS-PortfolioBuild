"""EA_FRAMEWORK_INPUT_PINNED scope and corpus regression tests."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest


REPO_ROOT = Path(__file__).resolve().parents[3]
BUILD_CHECK = REPO_ROOT / "framework" / "scripts" / "build_check.ps1"
PWSH = shutil.which("pwsh") or shutil.which("powershell")


def _extract(marker: str) -> str:
    text = BUILD_CHECK.read_text(encoding="utf-8")
    match = re.search(
        rf"^\s*#\s*QM-MARK:\s*BEGIN\s+{marker}\s*$(?P<body>.*?)"
        rf"^\s*#\s*QM-MARK:\s*END\s+{marker}\s*$",
        text,
        re.MULTILINE | re.DOTALL,
    )
    assert match, f"QM-MARK block {marker} missing"
    return match.group("body")


def run_predicate(tmp_path: Path, paths: list[Path]) -> list[str]:
    harness = tmp_path / "framework_input_pin_harness.ps1"
    file_list = ",".join("'" + str(path).replace("'", "''") + "'" for path in paths)
    harness.write_text(
        "$ErrorActionPreference = 'Stop'\n"
        "$script:found = New-Object 'System.Collections.Generic.List[string]'\n"
        "function Add-Failure { param([string]$Message) $script:found.Add($Message) }\n"
        f"$mqlFiles = @({file_list})\n"
        + _extract("FRAMEWORK_INPUT_PIN_PATTERNS")
        + "\n"
        + _extract("FRAMEWORK_INPUT_PIN_SCAN")
        + "\nConvertTo-Json -InputObject @($script:found) -Compress\n",
        encoding="utf-8",
    )
    result = subprocess.run(
        [PWSH, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", str(harness)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    assert result.returncode == 0, result.stdout + result.stderr
    return list(json.loads(result.stdout or "[]"))


def _ea_source(root: Path, ea_id: int) -> Path:
    directory = next((root / "framework" / "EAs").glob(f"QM5_{ea_id}_*"))
    return directory / f"{directory.name}.mq5"


def test_41171_pre_fix_guard_is_positive(tmp_path: Path) -> None:
    source = tmp_path / "QM5_41171_pre_fix.mq5"
    source.write_text(
        """bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsHostChart() || qm_ea_id != 41171 ||
      qm_magic_slot_offset != 0 || qm_rng_seed != 42)
      return true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_stale_max_hours != 336)
      return true;
   if(qm_friday_close_enabled ||
      qm_stress_reject_probability != 0.0)
      return true;
   return false;
  }
""",
        encoding="utf-8",
    )
    hits = run_predicate(tmp_path, [source])
    assert hits
    assert all(hit.startswith("EA_FRAMEWORK_INPUT_PINNED:") for hit in hits)
    assert any("qm_rng_seed !=" in hit for hit in hits)


@pytest.mark.parametrize("ea_id", [41171, 41319, 41358, 41359, 41360, 41361, 41362])
def test_repaired_pacer_guard_is_negative(tmp_path: Path, ea_id: int) -> None:
    assert run_predicate(tmp_path, [_ea_source(REPO_ROOT, ea_id)]) == []


def test_q07_passing_10268_guard_is_negative(tmp_path: Path) -> None:
    assert run_predicate(tmp_path, [_ea_source(REPO_ROOT, 10268)]) == []


def test_canonical_4000_source_census_flags_exact_200_only(tmp_path: Path) -> None:
    canonical = Path(r"C:\QM\repo")
    sources = sorted((canonical / "framework" / "EAs").rglob("*.mq5"))
    if len(sources) < 4000:  # pragma: no cover - production corpus assertion
        pytest.skip(f"canonical 4,000-source corpus unavailable ({len(sources)} sources)")
    hits = run_predicate(tmp_path, sources)
    flagged = {
        Path(match.group("path")).resolve()
        for hit in hits
        if (match := re.match(r"EA_FRAMEWORK_INPUT_PINNED:\s*(?P<path>.*\.mq5):\d+", hit))
    }
    expected_seed_neq = {
        path.resolve()
        for path in sources
        if re.search(r"\bqm_rng_seed\s*!=", path.read_text(encoding="utf-8", errors="replace"))
    }
    # Census 2026-09-06 (evidence docs/ops/evidence/2026-09-06_framework_input_pin_census.md):
    # 200 sources carried the ``qm_rng_seed !=`` form before the seven pacer
    # repairs (193 after); the broader fail-closed predicate exposes 378 sources
    # because pre-existing ==/!= pins on the other named framework inputs are
    # real findings too. The corpus grows daily, so assert structure, not counts.
    repaired = {
        path.resolve()
        for path in sources
        if re.search(r"QM5_(41171|41319|41358|41359|41360|41361|41362)_", path.name)
    }
    assert len(repaired) == 7
    assert not (repaired & expected_seed_neq)  # the seven repaired guards no longer pin the seed
    assert not (repaired & flagged)  # ...and the broad predicate is clean on them
    assert len(expected_seed_neq) >= 150  # the QM5_20xxx cohort is still pinned until its batch ticket
    assert expected_seed_neq <= flagged
    assert flagged - expected_seed_neq  # broader named-input pins are real findings


def test_build_check_still_parses() -> None:
    escaped = str(BUILD_CHECK).replace("'", "''")
    result = subprocess.run(
        [PWSH, "-NoProfile", "-NonInteractive", "-Command",
         f"[void][scriptblock]::Create([IO.File]::ReadAllText('{escaped}'))"],
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr
