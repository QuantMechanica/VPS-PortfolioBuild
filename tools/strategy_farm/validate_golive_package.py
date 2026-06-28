"""Validate a staged Go-Live package before any terminal action.

This is intentionally a package-level preflight, not a pipeline phase. It
fails closed when staged setfiles do not pass build guardrails or when the
framework, Go-Live package, and T_Live copies diverge.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from tools.strategy_farm.validate_build_guardrails import validate_path


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_TLIVE_ROOT = Path(r"C:\QM\mt5\T_Live\MT5_Base")
SET_KEY_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+?)\s*$")
COMMENT_FIELD_RE = re.compile(r"^\s*;\s*([^:]+):\s*(.*?)\s*$")
MANIFEST_NUMERIC_KEYS = {
    "PORTFOLIO_WEIGHT",
    "RISK_FIXED",
    "RISK_PERCENT",
    "qm_magic_slot_offset",
}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_hex(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest().upper()


def parse_setfile(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    comments: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        comment = COMMENT_FIELD_RE.match(raw)
        if comment:
            comments[comment.group(1).strip().lower().replace(" ", "_")] = comment.group(2).strip()
            continue
        key = SET_KEY_RE.match(raw)
        if key:
            values[key.group(1)] = key.group(2).strip()
    values["_comment_ea_id"] = comments.get("ea_id", "")
    values["_comment_symbol"] = comments.get("symbol", "")
    values["_comment_timeframe"] = comments.get("timeframe", "")
    values["_comment_environment"] = comments.get("environment", "")
    return values


def load_manifest_sleeves(package_root: Path) -> tuple[dict[int, dict[str, Any]], list[dict[str, Any]]]:
    findings: list[dict[str, Any]] = []
    manifest_paths = sorted(
        path
        for path in package_root.glob("manifest*.json")
        if path.is_file() and "preflight" not in path.name.lower()
    )
    if len(manifest_paths) != 1:
        findings.append(
            {
                "kind": "manifest_resolution_failed",
                "package_root": str(package_root),
                "matches": [str(path) for path in manifest_paths],
                "candidate_count": len(manifest_paths),
            }
        )
        return {}, findings

    try:
        manifest = json.loads(manifest_paths[0].read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        findings.append(
            {
                "kind": "manifest_read_failed",
                "path": str(manifest_paths[0]),
                "error": str(exc),
            }
        )
        return {}, findings

    sleeves: dict[int, dict[str, Any]] = {}
    for sleeve in manifest.get("sleeves", []):
        if not isinstance(sleeve, dict) or "slot" not in sleeve:
            findings.append({"kind": "manifest_sleeve_invalid", "sleeve": sleeve})
            continue
        slot = int(sleeve["slot"])
        if slot in sleeves:
            findings.append({"kind": "manifest_slot_duplicate", "slot": slot})
            continue
        sleeves[slot] = sleeve
    if not sleeves:
        findings.append({"kind": "manifest_no_sleeves", "path": str(manifest_paths[0])})
    return sleeves, findings


def _float_or_none(value: Any) -> float | None:
    try:
        return float(str(value).replace(",", "."))
    except (TypeError, ValueError):
        return None


def validate_manifest_expectation(
    values: dict[str, str],
    expected: dict[str, Any],
    *,
    source: str,
    path: Path,
) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    for key, expected_value in expected.items():
        actual_key = "_comment_environment" if key == "ENV" else key
        actual_value = values.get(actual_key)
        if actual_value is None:
            findings.append(
                {
                    "kind": "manifest_expected_key_missing",
                    "source": source,
                    "path": str(path),
                    "key": key,
                    "expected": expected_value,
                }
            )
            continue
        if key in MANIFEST_NUMERIC_KEYS:
            actual_number = _float_or_none(actual_value)
            expected_number = _float_or_none(expected_value)
            if actual_number is None or expected_number is None or not math.isclose(
                actual_number,
                expected_number,
                rel_tol=1e-9,
                abs_tol=1e-9,
            ):
                findings.append(
                    {
                        "kind": "manifest_expected_value_mismatch",
                        "source": source,
                        "path": str(path),
                        "key": key,
                        "expected": expected_value,
                        "actual": actual_value,
                    }
                )
            continue
        if str(actual_value).strip().lower() != str(expected_value).strip().lower():
            findings.append(
                {
                    "kind": "manifest_expected_value_mismatch",
                    "source": source,
                    "path": str(path),
                    "key": key,
                    "expected": expected_value,
                    "actual": actual_value,
                }
            )
    return findings


def find_one(paths: list[Path], *, label: str, findings: list[dict[str, Any]]) -> Path | None:
    existing = [path for path in paths if path.exists()]
    if len(existing) == 1:
        return existing[0]
    findings.append(
        {
            "kind": "path_resolution_failed",
            "label": label,
            "matches": [str(path) for path in existing],
            "candidate_count": len(existing),
        }
    )
    return None


def validate_setfile_copies(
    package_setfile: Path,
    *,
    repo_root: Path,
    tlive_root: Path,
    manifest_sleeves: dict[int, dict[str, Any]] | None = None,
) -> dict[str, Any]:
    findings: list[dict[str, Any]] = []
    values = parse_setfile(package_setfile)
    slot_match = re.match(r"slot([0-9]+)_", package_setfile.name, re.IGNORECASE)
    magic_match = re.search(r"_magic([0-9]+)\.set$", package_setfile.name, re.IGNORECASE)
    ea_id = values.get("_comment_ea_id", "").strip()
    symbol = values.get("_comment_symbol", "").strip()
    timeframe = values.get("_comment_timeframe", "").strip()

    if not ea_id or not symbol or not timeframe:
        findings.append(
            {
                "kind": "setfile_identity_missing",
                "path": str(package_setfile),
                "ea_id": ea_id,
                "symbol": symbol,
                "timeframe": timeframe,
            }
        )
        return {
            "package_setfile": str(package_setfile),
            "slot": None,
            "ea_id": ea_id,
            "symbol": symbol,
            "timeframe": timeframe,
            "verdict": "FAIL",
            "findings": findings,
        }

    slot = int(slot_match.group(1)) if slot_match else None
    sleeve = manifest_sleeves.get(slot) if manifest_sleeves is not None and slot is not None else None
    expected = sleeve.get("set_file_expectation") if isinstance(sleeve, dict) else None
    if manifest_sleeves is not None:
        if sleeve is None:
            findings.append(
                {
                    "kind": "manifest_sleeve_missing",
                    "slot": slot,
                    "package_setfile": str(package_setfile),
                }
            )
        elif not isinstance(expected, dict):
            findings.append(
                {
                    "kind": "manifest_set_file_expectation_missing",
                    "slot": slot,
                    "package_setfile": str(package_setfile),
                }
            )
        else:
            if int(sleeve.get("ea_id", -1)) != int(ea_id):
                findings.append(
                    {
                        "kind": "manifest_ea_id_mismatch",
                        "slot": slot,
                        "expected": sleeve.get("ea_id"),
                        "actual": int(ea_id),
                    }
                )
            if str(sleeve.get("symbol", "")) != symbol:
                findings.append(
                    {
                        "kind": "manifest_symbol_mismatch",
                        "slot": slot,
                        "expected": sleeve.get("symbol"),
                        "actual": symbol,
                    }
                )
            if magic_match and int(sleeve.get("magic_number", -1)) != int(magic_match.group(1)):
                findings.append(
                    {
                        "kind": "manifest_magic_mismatch",
                        "slot": slot,
                        "expected": sleeve.get("magic_number"),
                        "actual": int(magic_match.group(1)),
                    }
                )
            findings.extend(
                validate_manifest_expectation(
                    values,
                    expected,
                    source="package_setfile",
                    path=package_setfile,
                )
            )

    framework_matches = sorted(
        (repo_root / "framework" / "EAs").glob(
            f"QM5_{int(ea_id)}_*/sets/*_{symbol}_{timeframe}_live.set"
        )
    )
    framework_setfile = find_one(framework_matches, label="framework_setfile", findings=findings)
    tlive_setfile = (
        tlive_root / "MQL5" / "Presets" / "QM" / framework_setfile.name
        if framework_setfile is not None
        else None
    )
    if tlive_setfile is not None and not tlive_setfile.exists():
        findings.append(
            {
                "kind": "tlive_preset_missing",
                "path": str(tlive_setfile),
            }
        )
        tlive_setfile = None
    tlive_slot_setfiles = sorted((tlive_root / "MQL5" / "Presets").glob(f"slot{slot}_*.set")) if slot is not None else []
    tlive_slot_setfile = None
    if len(tlive_slot_setfiles) == 1:
        tlive_slot_setfile = tlive_slot_setfiles[0]
    elif len(tlive_slot_setfiles) > 1:
        findings.append(
            {
                "kind": "tlive_slot_preset_ambiguous",
                "slot": slot,
                "matches": [str(path) for path in tlive_slot_setfiles],
            }
        )

    if isinstance(expected, dict):
        if framework_setfile is not None:
            findings.extend(
                validate_manifest_expectation(
                    parse_setfile(framework_setfile),
                    expected,
                    source="framework_setfile",
                    path=framework_setfile,
                )
            )
        if tlive_setfile is not None:
            findings.extend(
                validate_manifest_expectation(
                    parse_setfile(tlive_setfile),
                    expected,
                    source="tlive_setfile",
                    path=tlive_setfile,
                )
            )
        if tlive_slot_setfile is not None:
            findings.extend(
                validate_manifest_expectation(
                    parse_setfile(tlive_slot_setfile),
                    expected,
                    source="tlive_slot_setfile",
                    path=tlive_slot_setfile,
                )
            )

    hashes: dict[str, str] = {"package": sha256_hex(package_setfile)}
    if framework_setfile is not None:
        hashes["framework"] = sha256_hex(framework_setfile)
    if tlive_setfile is not None:
        hashes["tlive"] = sha256_hex(tlive_setfile)
    if tlive_slot_setfile is not None:
        hashes["tlive_slot"] = sha256_hex(tlive_slot_setfile)
    if len(set(hashes.values())) != 1:
        findings.append({"kind": "setfile_hash_mismatch", "hashes": hashes})

    return {
        "package_setfile": str(package_setfile),
        "slot": slot,
        "ea_id": int(ea_id),
        "symbol": symbol,
        "timeframe": timeframe,
        "magic": int(magic_match.group(1)) if magic_match else None,
        "framework_setfile": str(framework_setfile) if framework_setfile else None,
        "tlive_setfile": str(tlive_setfile) if tlive_setfile else None,
        "tlive_slot_setfile": str(tlive_slot_setfile) if tlive_slot_setfile else None,
        "hashes": hashes,
        "verdict": "PASS" if not findings else "FAIL",
        "findings": findings,
    }


def validate_ex5_copies(
    package_root: Path,
    *,
    repo_root: Path,
    tlive_root: Path,
    strict_framework: bool = False,
) -> list[dict[str, Any]]:
    package_eas = sorted((package_root / "EAs").glob("slot*_QM5_*.ex5"))
    checks: list[dict[str, Any]] = []
    for package_ex5 in package_eas:
        findings: list[dict[str, Any]] = []
        match = re.search(r"_QM5_([0-9]+)_", package_ex5.name)
        if not match:
            checks.append(
                {
                    "package_ex5": str(package_ex5),
                    "verdict": "FAIL",
                    "findings": [{"kind": "ea_id_unresolved"}],
                }
            )
            continue
        ea_id = int(match.group(1))
        ea_dirs = sorted((repo_root / "framework" / "EAs").glob(f"QM5_{ea_id}_*"))
        framework_ex5 = None
        if len(ea_dirs) == 1:
            preferred = ea_dirs[0] / f"{ea_dirs[0].name}.ex5"
            matches = [preferred] if preferred.exists() else sorted(ea_dirs[0].glob("*.ex5"))
            framework_ex5 = matches[0] if len(matches) == 1 else None
        if framework_ex5 is None:
            findings.append(
                {
                    "kind": "framework_ex5_resolution_failed",
                    "ea_id": ea_id,
                    "matches": [str(path) for path in ea_dirs],
                }
            )
        tlive_ex5 = (
            tlive_root / "MQL5" / "Experts" / "QM" / framework_ex5.name
            if framework_ex5 is not None
            else None
        )
        if tlive_ex5 is not None and not tlive_ex5.exists():
            findings.append({"kind": "tlive_ex5_missing", "path": str(tlive_ex5)})
            tlive_ex5 = None

        hashes: dict[str, str] = {"package": sha256_hex(package_ex5)}
        if framework_ex5 is not None:
            hashes["framework"] = sha256_hex(framework_ex5)
        if tlive_ex5 is not None:
            hashes["tlive"] = sha256_hex(tlive_ex5)
        package_tlive_match = "tlive" in hashes and hashes["package"] == hashes["tlive"]
        framework_matches_package = "framework" in hashes and hashes["framework"] == hashes["package"]
        if not package_tlive_match:
            findings.append({"kind": "ex5_hash_mismatch", "hashes": hashes})
        if strict_framework and not framework_matches_package:
            findings.append({"kind": "framework_ex5_hash_mismatch", "hashes": hashes})
        checks.append(
            {
                "package_ex5": str(package_ex5),
                "ea_id": ea_id,
                "framework_ex5": str(framework_ex5) if framework_ex5 else None,
                "tlive_ex5": str(tlive_ex5) if tlive_ex5 else None,
                "hashes": hashes,
                "package_tlive_match": package_tlive_match,
                "framework_matches_package": framework_matches_package,
                "verdict": "PASS" if not findings else "FAIL",
                "findings": findings,
            }
        )
    return checks


def validate_package(
    package_root: Path,
    *,
    repo_root: Path = REPO_ROOT,
    tlive_root: Path = DEFAULT_TLIVE_ROOT,
    check_ex5: bool = True,
    strict_framework_ex5: bool = False,
) -> dict[str, Any]:
    package_root = package_root.resolve()
    setfiles_dir = package_root / "SetFiles"
    guardrail = validate_path(setfiles_dir)
    manifest_sleeves, manifest_findings = load_manifest_sleeves(package_root)
    setfile_checks = [
        validate_setfile_copies(
            path,
            repo_root=repo_root,
            tlive_root=tlive_root,
            manifest_sleeves=manifest_sleeves,
        )
        for path in sorted(setfiles_dir.glob("slot*.set"))
    ]
    ex5_checks = (
        validate_ex5_copies(
            package_root,
            repo_root=repo_root,
            tlive_root=tlive_root,
            strict_framework=strict_framework_ex5,
        )
        if check_ex5
        else []
    )
    findings = []
    findings.extend(manifest_findings)
    if guardrail["verdict"] != "PASS":
        findings.append({"kind": "guardrail_failed", "guardrail": guardrail})
    if not setfile_checks:
        findings.append({"kind": "no_package_setfiles", "path": str(setfiles_dir)})
    findings.extend(
        {
            "kind": "setfile_copy_check_failed",
            "package_setfile": check["package_setfile"],
            "findings": check["findings"],
        }
        for check in setfile_checks
        if check["verdict"] != "PASS"
    )
    findings.extend(
        {
            "kind": "ex5_copy_check_failed",
            "package_ex5": check["package_ex5"],
            "findings": check["findings"],
        }
        for check in ex5_checks
        if check["verdict"] != "PASS"
    )
    return {
        "checked_at": utc_now(),
        "package_root": str(package_root),
        "repo_root": str(repo_root),
        "tlive_root": str(tlive_root),
        "guardrail": guardrail,
        "manifest_sleeve_count": len(manifest_sleeves),
        "setfile_checks": setfile_checks,
        "ex5_checks": ex5_checks,
        "verdict": "PASS" if not findings else "FAIL",
        "findings": findings,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate a staged Go-Live package.")
    parser.add_argument("package_root", type=Path)
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument("--tlive-root", type=Path, default=DEFAULT_TLIVE_ROOT)
    parser.add_argument("--out", type=Path, help="Optional JSON evidence output path.")
    parser.add_argument("--skip-ex5", action="store_true")
    parser.add_argument(
        "--strict-framework-ex5",
        action="store_true",
        help="Also fail when framework .ex5 hashes differ from the staged package.",
    )
    args = parser.parse_args(argv)

    payload = validate_package(
        args.package_root,
        repo_root=args.repo_root,
        tlive_root=args.tlive_root,
        check_ex5=not args.skip_ex5,
        strict_framework_ex5=args.strict_framework_ex5,
    )
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0 if payload["verdict"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
