"""D2: book-path entrypoints refuse fail-closed with ONE structured JSON refusal.

Each CLI (DXZ builder, FTMO builder, deploy) is invoked as a subprocess against a
throwaway tmp root whose qualified-pool census is below the 25-pair floor (a
missing DB stands in) and whose order-dir holds no OWNER order, so book_build_guard
refuses. The refusal must exit 2 and print a parseable JSON refusal on stdout,
never leak a Python traceback on stderr.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
_SF = REPO_ROOT / "tools" / "strategy_farm"
DXZ = _SF / "portfolio" / "build_book_dxz.py"
FTMO = _SF / "portfolio" / "build_book_ftmo.py"
DEPLOY = _SF / "deploy_tlive_book.py"


def _run(argv: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, *argv],
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
    )


def _assert_structured_refusal(proc: subprocess.CompletedProcess[str]) -> dict:
    # Fail-closed exit code, exactly like `book_build_guard.py --status`.
    assert proc.returncode == 2, (proc.returncode, proc.stdout, proc.stderr)
    # No uncaught traceback leaked to stderr.
    assert "Traceback (most recent call last)" not in proc.stderr, proc.stderr
    # The structured JSON refusal is printed and parseable.
    payload = json.loads(proc.stdout)
    assert payload["status"] in {"BOOK_BUILD_REFUSED", "LIVE_RISK_FREEZE_BLOCKED"}
    assert payload.get("reason"), payload
    return payload


def test_dxz_builder_refuses_below_floor_with_json_not_traceback(tmp_path: Path) -> None:
    proc = _run([
        str(DXZ),
        "--book-db", str(tmp_path / "absent.sqlite"),
        "--order-dir", str(tmp_path / "orders"),
        "--out-dir", str(tmp_path / "never"),
    ])
    payload = _assert_structured_refusal(proc)
    assert payload["status"] == "BOOK_BUILD_REFUSED"
    assert payload["qualified_pairs"] < 25
    assert not (tmp_path / "never").exists()


def test_ftmo_builder_refuses_below_floor_with_json_not_traceback(tmp_path: Path) -> None:
    proc = _run([
        str(FTMO),
        "--book-db", str(tmp_path / "absent.sqlite"),
        "--order-dir", str(tmp_path / "orders"),
        "--out-dir", str(tmp_path / "never"),
    ])
    payload = _assert_structured_refusal(proc)
    assert payload["status"] == "BOOK_BUILD_REFUSED"
    assert payload["qualified_pairs"] < 25
    assert not (tmp_path / "never").exists()


def test_deploy_cli_refuses_below_floor_with_json_not_traceback(tmp_path: Path) -> None:
    proc = _run([
        str(DEPLOY),
        "--plan", str(tmp_path / "copy-plan.json"),
        "--live-root", str(tmp_path / "fixture_live"),
        "--book-db", str(tmp_path / "absent.sqlite"),
        "--order-dir", str(tmp_path / "orders"),
    ])
    payload = _assert_structured_refusal(proc)
    assert payload["status"] == "BOOK_BUILD_REFUSED"
    assert payload["qualified_pairs"] < 25
    # The guard fires before the plan is read, so a missing plan never surfaces.
    assert not (tmp_path / "fixture_live").exists()
