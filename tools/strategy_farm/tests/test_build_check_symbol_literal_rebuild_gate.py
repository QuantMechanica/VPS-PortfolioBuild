"""Harness test for the EA_SYMBOL_LITERAL_REBUILD_GATE block in build_check.ps1.

OWNER 2026-09-13: the symbol-literal debt ("symbols are inputs, never code
literals" -- OWNER 2026-09-06) is repaired at the natural rebuild. Whenever an
EA is compiled through build_check.ps1, its source must be free of the
fail-closed symbol-literal lint (framework/scripts/lint_ea_symbol_literals.py,
classes symbol_literal_comparison / symbol_literal_global) or the build is
refused with reason class EA_SYMBOL_LITERAL_REBUILD_REQUIRES_FIX. The rollback
env QM_SYMBOL_LITERAL_REBUILD_GATE=0 downgrades the refusal to a warning; a
missing/erroring lint tool fails closed as EA_SYMBOL_LITERAL_REBUILD_SCANNER_FAILED.

Style mirrors test_buildcheck_predicate_fix.py::
test_power_shell_ml_scoping_with_real_frozen_and_negative_inputs: the gate block
is sliced out of build_check.ps1 into a temporary harness with stub Add-Failure/
Add-Warning collecting into lists, with $EALabel and $ResolvedRepoRoot set and the
lint pointed at a temp EA directory.
"""
from pathlib import Path
import json
import shutil
import subprocess
import os

ROOT = Path(__file__).resolve().parents[3]
LINT_TOOL = ROOT / "framework" / "scripts" / "lint_ea_symbol_literals.py"

VIOLATING_MQL = (
    "#property strict\n"
    "bool Strategy_IsTarget()\n"
    "  {\n"
    '   return (_Symbol == "EURUSD.DWX");\n'
    "  }\n"
)
CLEAN_MQL = (
    "#property strict\n"
    'input string strategy_host_symbol = "EURUSD.DWX";\n'
    "bool Strategy_IsTarget()\n"
    "  {\n"
    "   return (QM_MagicSymbolCanonical(_Symbol) =="
    " QM_MagicSymbolCanonical(strategy_host_symbol));\n"
    "  }\n"
)


def _gate_block() -> str:
    source = (ROOT / "framework/scripts/build_check.ps1").read_text(encoding="utf-8-sig")
    start = source.index("# ---- EA_SYMBOL_LITERAL_REBUILD_GATE")
    end = source.index("$externalHits = Select-String", start)
    return source[start:end]


def _run(tmp_path, ea_label, mql_text, *, install_tool=True, env_disable=False):
    repo_root = tmp_path / "repo"
    ea_dir = repo_root / "framework" / "EAs" / ea_label
    ea_dir.mkdir(parents=True)
    if mql_text is not None:
        (ea_dir / (ea_label + ".mq5")).write_text(mql_text, encoding="utf-8")
    scripts_dir = repo_root / "framework" / "scripts"
    scripts_dir.mkdir(parents=True)
    if install_tool:
        shutil.copyfile(LINT_TOOL, scripts_dir / "lint_ea_symbol_literals.py")

    harness = tmp_path / "gate.ps1"
    ps_root = str(repo_root).replace("'", "''")
    harness.write_text(
        "$ErrorActionPreference='Stop'\n"
        f"$EALabel='{ea_label}'\n"
        f"$ResolvedRepoRoot='{ps_root}'\n"
        "$script:fails=New-Object 'System.Collections.Generic.List[string]'\n"
        "$script:warns=New-Object 'System.Collections.Generic.List[string]'\n"
        "function Add-Failure {param([string]$Message) $script:fails.Add($Message)}\n"
        "function Add-Warning {param([string]$Message) $script:warns.Add($Message)}\n"
        + _gate_block()
        + "\nConvertTo-Json -InputObject @{failures=@($script:fails);"
        "warnings=@($script:warns)} -Compress -Depth 4\n",
        encoding="utf-8",
    )

    env = dict(os.environ)
    if env_disable:
        env["QM_SYMBOL_LITERAL_REBUILD_GATE"] = "0"
    else:
        env.pop("QM_SYMBOL_LITERAL_REBUILD_GATE", None)

    run = subprocess.run(
        ["powershell", "-NoProfile", "-NonInteractive", "-File", str(harness)],
        capture_output=True,
        text=True,
        env=env,
    )
    assert run.returncode == 0, run.stderr
    parsed = json.loads(run.stdout.splitlines()[-1])

    def _as_list(value):
        if value is None:
            return []
        if isinstance(value, str):
            return [value]
        return list(value)

    return _as_list(parsed.get("failures")), _as_list(parsed.get("warnings"))


def test_violating_ea_fails_with_reason_class(tmp_path):
    fails, warns = _run(tmp_path, "QM5_99001_violating", VIOLATING_MQL)
    assert len(fails) == 1, fails
    assert fails[0].startswith("EA_SYMBOL_LITERAL_REBUILD_REQUIRES_FIX:"), fails
    assert "1 violation(s) in QM5_99001_violating" in fails[0], fails
    assert "OWNER 2026-09-06" in fails[0] and "OWNER 2026-09-13" in fails[0]
    assert warns == []


def test_clean_ea_reports_nothing(tmp_path):
    fails, warns = _run(tmp_path, "QM5_99002_clean", CLEAN_MQL)
    assert fails == [], fails
    assert warns == [], warns


def test_env_disabled_downgrades_to_warning(tmp_path):
    fails, warns = _run(
        tmp_path, "QM5_99003_violating", VIOLATING_MQL, env_disable=True
    )
    assert fails == [], fails
    assert len(warns) == 1, warns
    assert warns[0].startswith("EA_SYMBOL_LITERAL_REBUILD_REQUIRES_FIX:"), warns
    assert warns[0].endswith("gate disabled by env"), warns


def test_missing_lint_tool_fails_closed(tmp_path):
    fails, warns = _run(
        tmp_path, "QM5_99004_notool", CLEAN_MQL, install_tool=False
    )
    assert len(fails) == 1, fails
    assert fails[0].startswith("EA_SYMBOL_LITERAL_REBUILD_SCANNER_FAILED:"), fails
    assert warns == []
