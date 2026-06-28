from __future__ import annotations

import json
import shutil
from pathlib import Path

from tools.strategy_farm.validate_golive_package import validate_package


def _write_setfile(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "\n".join(
            [
                "; ea_id:        11132",
                "; symbol:       SP500.DWX",
                "; timeframe:    D1",
                "; environment:  live",
                "qm_magic_slot_offset=0",
                "RISK_FIXED=0",
                "RISK_PERCENT=0.25",
                "PORTFOLIO_WEIGHT=0.125",
                "; card_defaults_source=unit_test",
                "strategy_entry=38.0",
            ]
        )
        + "\n",
        encoding="utf-8",
    )


def _build_package(tmp_path: Path) -> tuple[Path, Path, Path]:
    repo_root = tmp_path / "repo"
    package_root = tmp_path / "package"
    tlive_root = tmp_path / "T_Live"

    framework_set = (
        repo_root
        / "framework"
        / "EAs"
        / "QM5_11132_tm-cum-rsi2"
        / "sets"
        / "QM5_11132_tm-cum-rsi2_SP500.DWX_D1_live.set"
    )
    _write_setfile(framework_set)
    package_set = package_root / "SetFiles" / "slot6_SP500_D1_QM5_11132_tm-cum-rsi2_magic111320000.set"
    package_set.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(framework_set, package_set)
    tlive_set = tlive_root / "MQL5" / "Presets" / "QM" / framework_set.name
    tlive_set.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(framework_set, tlive_set)
    manifest = {
        "sleeves": [
            {
                "slot": 6,
                "ea_id": 11132,
                "symbol": "SP500.DWX",
                "magic_number": 111320000,
                "set_file_expectation": {
                    "ENV": "live",
                    "RISK_FIXED": 0.0,
                    "RISK_PERCENT": 0.25,
                    "PORTFOLIO_WEIGHT": 0.125,
                    "qm_magic_slot_offset": 0,
                },
            }
        ]
    }
    (package_root / "manifest_unit.json").write_text(
        json.dumps(manifest, indent=2) + "\n",
        encoding="utf-8",
    )

    framework_ex5 = repo_root / "framework" / "EAs" / "QM5_11132_tm-cum-rsi2" / "QM5_11132_tm-cum-rsi2.ex5"
    framework_ex5.write_bytes(b"unit-test-ex5")
    package_ex5 = package_root / "EAs" / "slot6_SP500_D1_QM5_11132_tm-cum-rsi2_magic111320000.ex5"
    package_ex5.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(framework_ex5, package_ex5)
    tlive_ex5 = tlive_root / "MQL5" / "Experts" / "QM" / framework_ex5.name
    tlive_ex5.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(framework_ex5, tlive_ex5)
    return package_root, repo_root, tlive_root


def test_golive_package_preflight_accepts_matching_setfiles_and_ex5(tmp_path: Path) -> None:
    package_root, repo_root, tlive_root = _build_package(tmp_path)

    result = validate_package(package_root, repo_root=repo_root, tlive_root=tlive_root)

    assert result["verdict"] == "PASS"
    assert result["guardrail"]["verdict"] == "PASS"
    assert result["setfile_checks"][0]["verdict"] == "PASS"
    assert result["ex5_checks"][0]["verdict"] == "PASS"


def test_golive_package_preflight_rejects_setfile_hash_mismatch(tmp_path: Path) -> None:
    package_root, repo_root, tlive_root = _build_package(tmp_path)
    package_set = package_root / "SetFiles" / "slot6_SP500_D1_QM5_11132_tm-cum-rsi2_magic111320000.set"
    package_set.write_text(package_set.read_text(encoding="utf-8") + "strategy_extra=1\n", encoding="utf-8")

    result = validate_package(package_root, repo_root=repo_root, tlive_root=tlive_root)

    assert result["verdict"] == "FAIL"
    assert result["setfile_checks"][0]["verdict"] == "FAIL"
    assert result["setfile_checks"][0]["findings"][0]["kind"] == "setfile_hash_mismatch"


def test_golive_package_preflight_rejects_manifest_setfile_mismatch(tmp_path: Path) -> None:
    package_root, repo_root, tlive_root = _build_package(tmp_path)
    package_set = package_root / "SetFiles" / "slot6_SP500_D1_QM5_11132_tm-cum-rsi2_magic111320000.set"
    package_set.write_text(
        package_set.read_text(encoding="utf-8").replace("RISK_PERCENT=0.25", "RISK_PERCENT=0.75"),
        encoding="utf-8",
    )

    result = validate_package(package_root, repo_root=repo_root, tlive_root=tlive_root)

    assert result["verdict"] == "FAIL"
    assert result["setfile_checks"][0]["verdict"] == "FAIL"
    assert any(
        finding["kind"] == "manifest_expected_value_mismatch"
        and finding["source"] == "package_setfile"
        and finding["key"] == "RISK_PERCENT"
        for finding in result["setfile_checks"][0]["findings"]
    )


def test_golive_package_preflight_allows_framework_ex5_drift_by_default(tmp_path: Path) -> None:
    package_root, repo_root, tlive_root = _build_package(tmp_path)
    framework_ex5 = repo_root / "framework" / "EAs" / "QM5_11132_tm-cum-rsi2" / "QM5_11132_tm-cum-rsi2.ex5"
    framework_ex5.write_bytes(b"different-framework-build")

    result = validate_package(package_root, repo_root=repo_root, tlive_root=tlive_root)
    strict_result = validate_package(
        package_root,
        repo_root=repo_root,
        tlive_root=tlive_root,
        strict_framework_ex5=True,
    )

    assert result["verdict"] == "PASS"
    assert result["ex5_checks"][0]["package_tlive_match"] is True
    assert result["ex5_checks"][0]["framework_matches_package"] is False
    assert strict_result["verdict"] == "FAIL"
    assert strict_result["ex5_checks"][0]["findings"][0]["kind"] == "framework_ex5_hash_mismatch"
