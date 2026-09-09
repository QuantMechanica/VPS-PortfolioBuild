from __future__ import annotations

import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
GEN_SETFILE = REPO / "framework" / "scripts" / "gen_setfile.ps1"

REPAIRED_Q08_BASELINES = (
    ("QM5_10771_tv-trail-hunter", "XAUUSD.DWX_H1"),
    ("QM5_10771_tv-trail-hunter", "USDJPY.DWX_H1"),
    ("QM5_9573_brooks-ib-breakout-failure-h4", "NDX.DWX_H4"),
    ("QM5_9573_brooks-ib-breakout-failure-h4", "USDCHF.DWX_H4"),
    ("QM5_10148_tii-signal", "EURNZD.DWX_D1"),
    ("QM5_10848_tv-mtf-ambush", "GDAXI.DWX_H1"),
    ("QM5_10287_cinar-ichimoku", "XAUUSD.DWX_D1"),
    ("QM5_1230_carver-dynvol-mav", "XAUUSD.DWX_D1"),
)


@pytest.mark.parametrize("shell_name", ["powershell.exe", "pwsh"])
def test_card_defaults_mutate_ordered_target_and_override_source(tmp_path: Path, shell_name: str) -> None:
    shell = shutil.which(shell_name)
    if not shell:
        pytest.skip(f"{shell_name} unavailable")
    repo = tmp_path / "repo"
    label = "QM5_99996_card-defaults-fixture"
    script = repo / "framework/scripts/gen_setfile.ps1"
    ea_dir = repo / "framework/EAs" / label
    registry = repo / "framework/registry/magic_numbers.csv"
    card = repo / "artifacts/cards_approved" / (label + ".md")
    for directory in (script.parent, ea_dir, registry.parent, card.parent):
        directory.mkdir(parents=True, exist_ok=True)
    shutil.copy2(GEN_SETFILE, script)
    (ea_dir / (label + ".mq5")).write_text(
        'input group "News"\ninput int qm_news_temporal = 3;\n'
        'input uint qm_rng_seed = 42;\ninput string qm_news_min_impact = "high";\n'
        'input group "Strategy"\ninput int strategy_period = 17;\n', encoding="utf-8")
    registry.write_text("ea_id,symbol,status,symbol_slot\n99996,EURUSD.DWX,active,0\n", encoding="utf-8")
    card.write_text(
        "# Fixture\n\n| param | default |\n| --- | --- |\n"
        "| qm_news_temporal | 3 |\n| qm_rng_seed | 42 |\n"
        "| qm_news_min_impact | high |\n| strategy_period | 23 |\n"
        "| nonexistent_input | 99 |\n", encoding="utf-8")
    result = subprocess.run([shell, "-NoProfile", "-NonInteractive", "-File", str(script),
        "-EaSlug", label, "-Symbol", "EURUSD.DWX", "-TF", "H1", "-Env", "backtest"],
        cwd=repo, capture_output=True, text=True, timeout=30, check=False,
        creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    assert result.returncode == 0, result.stderr or result.stdout
    content = (ea_dir / "sets" / (label + "_EURUSD.DWX_H1_backtest.set")).read_text(encoding="utf-8")
    for assignment in ("qm_news_temporal=3", "qm_rng_seed=42", "qm_news_min_impact=high", "strategy_period=23"):
        assert content.splitlines().count(assignment) == 1
    assert "strategy_period=17" not in content
    assert "nonexistent_input=" not in content


@pytest.mark.parametrize(("ea_slug", "symbol_tf"), REPAIRED_Q08_BASELINES)
def test_repaired_q08_baseline_materializes_every_strategy_input(
    ea_slug: str, symbol_tf: str
) -> None:
    ea_dir = REPO / "framework" / "EAs" / ea_slug
    source = (ea_dir / f"{ea_slug}.mq5").read_text(encoding="utf-8-sig")
    set_text = (
        ea_dir / "sets" / f"{ea_slug}_{symbol_tf}_backtest.set"
    ).read_text(encoding="utf-8-sig")

    input_names = set(
        re.findall(
            r"(?m)^input\s+\w+\s+(strategy_[A-Za-z0-9_]+)\s*=",
            source,
        )
    )
    assignment_names = set(
        re.findall(r"(?m)^(strategy_[A-Za-z0-9_]+)=", set_text)
    )

    assert input_names
    assert assignment_names == input_names


def test_missing_card_falls_back_to_strategy_input_defaults(tmp_path: Path) -> None:
    pwsh = shutil.which("pwsh")
    if not pwsh:
        pytest.skip("PowerShell 7 is required for gen_setfile.ps1")

    repo = tmp_path / "repo"
    script_dir = repo / "framework" / "scripts"
    ea_slug = "QM5_99998_no-card-fixture"
    ea_dir = repo / "framework" / "EAs" / ea_slug
    registry_dir = repo / "framework" / "registry"
    script_dir.mkdir(parents=True)
    ea_dir.mkdir(parents=True)
    registry_dir.mkdir(parents=True)
    shutil.copy2(GEN_SETFILE, script_dir / GEN_SETFILE.name)

    (ea_dir / f"{ea_slug}.mq5").write_text(
        '\n'.join(
            (
                'input group "Signal"',
                'input int strategy_period = 17;',
                'input group "Strategy"',
                'input bool AllowShorts = false;',
                'input ENUM_TIMEFRAMES strategy_signal_tf = PERIOD_M30;',
                'input string strategy_variant_id = "TPO_VA80_ROT_BASELINE";',
            )
        )
        + '\n',
        encoding="utf-8",
    )
    (registry_dir / "magic_numbers.csv").write_text(
        "ea_id,symbol,status,symbol_slot\n"
        "99998,EURUSD.DWX,active,7\n",
        encoding="utf-8",
    )

    env = os.environ.copy()
    env["QM_STRATEGY_FARM_ROOT"] = str(tmp_path / "empty-farm")
    result = subprocess.run(
        (
            pwsh,
            "-NoProfile",
            "-NonInteractive",
            "-File",
            str(script_dir / GEN_SETFILE.name),
            "-EaSlug",
            ea_slug,
            "-Symbol",
            "EURUSD.DWX",
            "-TF",
            "H1",
            "-Env",
            "backtest",
        ),
        cwd=repo,
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )

    assert result.returncode == 0, result.stderr or result.stdout
    setfile = ea_dir / "sets" / f"{ea_slug}_EURUSD.DWX_H1_backtest.set"
    content = setfile.read_text(encoding="utf-8")
    assert "; card_defaults_source=ea_input_defaults" in content
    assert "; card_defaults_source=not_found" not in content
    assert content.count("strategy_period=17") == 1
    assert content.count("AllowShorts=false") == 1
    assert content.count("strategy_signal_tf=30") == 1
    assert "strategy_signal_tf=PERIOD_M30" not in content
    assert content.count("strategy_variant_id=TPO_VA80_ROT_BASELINE") == 1
    assert 'strategy_variant_id="TPO_VA80_ROT_BASELINE"' not in content


def test_versioned_output_is_create_only_and_records_version(tmp_path: Path) -> None:
    pwsh = shutil.which("pwsh")
    if not pwsh:
        pytest.skip("PowerShell 7 is required for gen_setfile.ps1")

    repo = tmp_path / "repo"
    script_dir = repo / "framework" / "scripts"
    ea_slug = "QM5_99997_versioned-fixture"
    ea_dir = repo / "framework" / "EAs" / ea_slug
    registry_dir = repo / "framework" / "registry"
    script_dir.mkdir(parents=True)
    ea_dir.mkdir(parents=True)
    registry_dir.mkdir(parents=True)
    shutil.copy2(GEN_SETFILE, script_dir / GEN_SETFILE.name)

    (ea_dir / f"{ea_slug}.mq5").write_text(
        'input int strategy_period = 21;\n', encoding="utf-8"
    )
    (registry_dir / "magic_numbers.csv").write_text(
        "ea_id,symbol,status,symbol_slot\n"
        "99997,XAUUSD.DWX,active,4\n",
        encoding="utf-8",
    )
    version = "s20260907-001"
    command = (
        pwsh,
        "-NoProfile",
        "-NonInteractive",
        "-File",
        str(script_dir / GEN_SETFILE.name),
        "-EaSlug",
        ea_slug,
        "-Symbol",
        "XAUUSD.DWX",
        "-TF",
        "H1",
        "-Env",
        "backtest",
        "-VersionTag",
        version,
    )
    env = os.environ.copy()
    env["QM_STRATEGY_FARM_ROOT"] = str(tmp_path / "empty-farm")

    first = subprocess.run(
        command,
        cwd=repo,
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert first.returncode == 0, first.stderr or first.stdout
    target = ea_dir / "sets" / f"{ea_slug}_XAUUSD.DWX_H1_backtest_{version}.set"
    content = target.read_text(encoding="utf-8")
    assert "; set_version:  s20260907-001" in content
    assert "strategy_period=21" in content

    second = subprocess.run(
        command,
        cwd=repo,
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert second.returncode != 0
    assert "VERSIONED_SETFILE_ALREADY_EXISTS" in (second.stderr + second.stdout)


def test_declared_strategy_guard_applies_to_every_environment() -> None:
    source = GEN_SETFILE.read_text(encoding="utf-8-sig")
    guard = re.search(
        r"if \(\$eaInputDefaults\.strategy\.Count -gt 0 "
        r"-and \$strategyAssignmentLines\.Count -eq 0\) \{"
        r"(?P<body>.*?)\n\}",
        source,
        re.DOTALL,
    )
    assert guard is not None
    assert "SETFILE_DECLARED_STRATEGY_PARAMS_MISSING" in guard.group("body")
    assert "$Env -eq" not in guard.group(0)
