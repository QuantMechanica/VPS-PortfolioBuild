#!/usr/bin/env python3
"""Fail-closed verification for the prepared T_Live preset repair batch."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MANIFEST = REPO_ROOT / "docs/ops/evidence/2026-08-23_tlive_preset_repair_manifest.json"
HEADER_RE = re.compile(rb"^[ \t]*;[ \t]*(?P<key>[A-Za-z0-9_]+)[ \t]*:[ \t]*(?P<value>[^\r\n]*)$")
ASSIGNMENT_RE = re.compile(rb"^(?P<key>[A-Za-z_][A-Za-z0-9_]*)=(?P<value>[^\r\n]*)$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
FORBIDDEN_MARKERS = (b"draft_only", b"do_not_copy_to_t_live")


class VerificationError(ValueError):
    pass


@dataclass(frozen=True)
class SetFile:
    raw: bytes
    headers: dict[str, bytes]
    assignments: tuple[tuple[str, bytes], ...]

    @property
    def assignment_map(self) -> dict[str, bytes]:
        return dict(self.assignments)


def sha256_path(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def parse_setfile_bytes(raw: bytes, *, label: str = "setfile") -> SetFile:
    try:
        raw.decode("utf-8-sig", errors="strict")
    except UnicodeDecodeError as exc:
        raise VerificationError(f"{label}: not strict UTF-8") from exc

    headers: dict[str, bytes] = {}
    assignments: list[tuple[str, bytes]] = []
    assignment_keys: set[str] = set()
    for line in raw.splitlines():
        header = HEADER_RE.fullmatch(line)
        if header:
            key = header.group("key").decode("ascii").lower()
            if key in headers:
                raise VerificationError(f"{label}: duplicate header {key}")
            headers[key] = header.group("value").strip()
            continue
        assignment = ASSIGNMENT_RE.fullmatch(line)
        if assignment:
            key = assignment.group("key").decode("ascii")
            if key in assignment_keys:
                raise VerificationError(f"{label}: duplicate assignment {key}")
            assignment_keys.add(key)
            assignments.append((key, assignment.group("value")))
    return SetFile(raw=raw, headers=headers, assignments=tuple(assignments))


def parse_setfile(path: Path) -> SetFile:
    try:
        return parse_setfile_bytes(path.read_bytes(), label=str(path))
    except OSError as exc:
        raise VerificationError(f"{path}: unreadable: {exc}") from exc


def functional_key_diff(deployed: bytes, regenerated: bytes) -> dict[str, Any]:
    """Compare the ordered, raw-byte assignment maps without numeric coercion."""
    before = parse_setfile_bytes(deployed, label="deployed")
    after = parse_setfile_bytes(regenerated, label="regenerated")
    before_map = before.assignment_map
    after_map = after.assignment_map
    ordered_keys = list(before_map)
    ordered_keys.extend(key for key in after_map if key not in before_map)
    rows = []
    for key in ordered_keys:
        old = before_map.get(key)
        new = after_map.get(key)
        rows.append(
            {
                "key": key,
                "deployed_value": _decode(old),
                "regenerated_value": _decode(new),
                "deployed_value_hex": old.hex() if old is not None else None,
                "regenerated_value_hex": new.hex() if new is not None else None,
                "byte_equal": old == new,
            }
        )
    return {
        "ordered_keys_equal": before.assignments == after.assignments,
        "all_functional_keys_byte_equal": all(row["byte_equal"] for row in rows)
        and len(before.assignments) == len(after.assignments),
        "keys": rows,
    }


def build_functional_diff_report(manifest_path: Path, snapshot_dir: Path) -> dict[str, Any]:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    report_rows = []
    for entry in manifest["presets"]:
        source = _resolve_repo_path(entry["source_path"])
        deployed = snapshot_dir / Path(entry["target_tlive_path"]).name
        before = parse_setfile(deployed)
        after = parse_setfile(source)
        diff = functional_key_diff(before.raw, after.raw)
        comment_diff = {}
        for key in ("environment", "risk_mode", "build_hash"):
            old = before.headers.get(key)
            new = after.headers.get(key)
            comment_diff[key] = {
                "deployed_value": _decode(old),
                "regenerated_value": _decode(new),
                "byte_equal": old == new,
            }
        amap = after.assignment_map
        spotlight_keys = [
            key
            for key, _ in after.assignments
            if key in {"RISK_FIXED", "RISK_PERCENT", "PORTFOLIO_WEIGHT", "qm_magic_slot_offset", "qm_filter_news_enabled", "qm_filter_news_mode"}
            or "seed" in key.lower()
            or "friday" in key.lower()
        ]
        seed_keys = [key for key, _ in after.assignments if "seed" in key.lower()]
        friday_keys = [key for key, _ in after.assignments if "friday" in key.lower()]
        regenerable = diff["all_functional_keys_byte_equal"]
        report_rows.append(
            {
                "ea_label": entry["ea_label"],
                "deployed_path": entry["target_tlive_path"],
                "deployed_sha256": sha256_path(deployed),
                "regenerated_source": entry["source_path"],
                "regenerated_sha256": sha256_path(source),
                "status": "REGENERABLE" if regenerable else "NOT_REGENERABLE",
                "reason": None if regenerable else "one or more functional assignment bytes differ",
                "functional_key_diff": diff,
                "spotlight": {key: _decode(amap[key]) for key in spotlight_keys},
                "seed_keys": seed_keys,
                "friday_keys": friday_keys,
                "news_mode": _decode(amap.get("qm_filter_news_mode")) or "ABSENT",
                "comment_diff": comment_diff,
            }
        )
    return {
        "schema_version": "qm.tlive_preset_functional_diff.v1",
        "ticket": manifest["ticket"],
        "comparison": "raw UTF-8 bytes after '=' for every ordered non-comment assignment",
        "float_policy": "no numeric coercion; exponent and decimal spellings must be byte-identical",
        "status": "REGENERABLE"
        if all(row["status"] == "REGENERABLE" for row in report_rows)
        else "NOT_REGENERABLE",
        "presets": report_rows,
    }


def _decode(value: bytes | None) -> str | None:
    return value.decode("utf-8") if value is not None else None


def _load_registry(path: Path) -> dict[tuple[int, str], dict[str, str]]:
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))
    return {
        (int(row["ea_id"]), row["symbol"]): row
        for row in rows
        if row.get("status") == "active"
    }


def _resolve_repo_path(value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else REPO_ROOT / path


def _required(mapping: dict[str, bytes], keys: Iterable[str], label: str, findings: list[str]) -> None:
    for key in keys:
        if key not in mapping:
            findings.append(f"{label}: missing {key}")


def verify_manifest(manifest_path: Path, *, require_deployed: bool = False) -> dict[str, Any]:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    findings: list[str] = []
    results: list[dict[str, Any]] = []
    if manifest.get("schema_version") != "qm.tlive_preset_repair.v1":
        findings.append("manifest: unsupported schema_version")

    registry_path = _resolve_repo_path(manifest["magic_registry_path"])
    calendar_path = Path(manifest["news_calendar_path"])
    portfolio_path = Path(manifest["portfolio_manifest_path"])
    try:
        registry = _load_registry(registry_path)
    except (OSError, KeyError, ValueError) as exc:
        registry = {}
        findings.append(f"registry: {exc}")
    if not calendar_path.is_file():
        findings.append(f"news_calendar: missing {calendar_path}")
    if not portfolio_path.is_file():
        findings.append(f"portfolio_manifest: missing {portfolio_path}")
        portfolio = {}
    else:
        portfolio_sha = sha256_path(portfolio_path)
        if portfolio_sha != manifest.get("portfolio_manifest_sha256"):
            findings.append("portfolio_manifest: sha256 mismatch")
        portfolio = json.loads(portfolio_path.read_text(encoding="utf-8-sig"))
        if portfolio.get("n_sleeves") != 24 or float(portfolio.get("total_risk_pct", -1)) != 9.7499:
            findings.append("portfolio_manifest: expected 24 sleeves / 9.7499 total risk")
    sleeve_map = {
        (int(row["ea_id"]), row["symbol"]): row for row in portfolio.get("sleeves", [])
    }

    entries = manifest.get("presets", [])
    if len(entries) != 10:
        findings.append(f"manifest: expected 10 presets, got {len(entries)}")
    for entry in entries:
        label = entry.get("ea_label", "<unknown>")
        item_findings: list[str] = []
        source = _resolve_repo_path(entry["source_path"])
        target = Path(entry["target_tlive_path"])
        binary = Path(
            entry.get(
                "target_tlive_binary_path",
                str(target.parent.parent / "Experts" / "Live EAs" / f"{label}.ex5"),
            )
        )
        try:
            source_sha = sha256_path(source)
            parsed = parse_setfile(source)
        except (OSError, VerificationError) as exc:
            item_findings.append(str(exc))
            results.append({"ea_label": label, "status": "FAIL", "findings": item_findings})
            findings.extend(f"{label}: {item}" for item in item_findings)
            continue
        if source_sha != entry.get("source_sha256"):
            item_findings.append("source sha256 mismatch")
        if not binary.is_file() or sha256_path(binary) != entry.get("expected_build_hash"):
            item_findings.append("T_Live companion binary sha256 mismatch")
        if any(marker in parsed.raw.lower() for marker in FORBIDDEN_MARKERS):
            item_findings.append("forbidden draft/do-not-copy marker")

        _required(
            parsed.headers,
            ("ea_id", "ea_slug", "symbol", "timeframe", "environment", "risk_mode", "magic_slot", "build_hash"),
            "header",
            item_findings,
        )
        values = parsed.assignment_map
        _required(
            values,
            ("qm_magic_slot_offset", "RISK_FIXED", "RISK_PERCENT", "PORTFOLIO_WEIGHT"),
            "assignment",
            item_findings,
        )
        if parsed.headers.get("environment") != b"live":
            item_findings.append("environment comment is not live")
        if parsed.headers.get("risk_mode") != b"PERCENT":
            item_findings.append("risk_mode comment is not PERCENT")
        build_hash = _decode(parsed.headers.get("build_hash")) or ""
        if not SHA256_RE.fullmatch(build_hash) or build_hash != entry.get("expected_build_hash"):
            item_findings.append("build_hash comment mismatch")
        if values.get("RISK_FIXED") != b"0":
            item_findings.append("RISK_FIXED is not byte-exact 0")
        if _decode(values.get("RISK_PERCENT")) != entry.get("risk_percent"):
            item_findings.append("RISK_PERCENT mismatch")

        ea_id = int(entry["ea_id"])
        symbol = entry["symbol"]
        slot = int(entry["symbol_slot"])
        expected_magic = ea_id * 10000 + slot
        if int(entry["magic"]) != expected_magic:
            item_findings.append("manifest magic violates ea_id*10000+slot")
        if values.get("qm_magic_slot_offset") != str(slot).encode("ascii"):
            item_findings.append("setfile magic slot mismatch")
        registry_row = registry.get((ea_id, symbol))
        if not registry_row:
            item_findings.append("active magic registry row missing")
        elif int(registry_row["symbol_slot"]) != slot or int(registry_row["magic"]) != expected_magic:
            item_findings.append("magic registry inconsistency")
        sleeve = sleeve_map.get((ea_id, symbol))
        if not sleeve or f"{float(sleeve.get('risk_percent', -1)):.4f}" != entry["risk_percent"]:
            item_findings.append("live portfolio roster/risk mismatch")

        if values.get("qm_filter_news_enabled") == b"1" and "qm_filter_news_mode" not in values:
            item_findings.append("news enabled without qm_filter_news_mode")

        if not target.is_file():
            item_findings.append("target T_Live preset missing")
            target_state = "MISSING"
        else:
            target_sha = sha256_path(target)
            if target_sha == source_sha:
                target_state = "DEPLOYED_MATCH"
            elif target_sha == entry.get("expected_pre_deploy_sha256"):
                target_state = "EXPECTED_PREDEPLOY"
                if require_deployed:
                    item_findings.append("source->target sha256 mismatch")
            else:
                target_state = "UNEXPECTED_SHA"
                item_findings.append("target sha256 matches neither source nor expected pre-deploy hash")

        results.append(
            {
                "ea_label": label,
                "source_sha256": source_sha,
                "target_state": target_state,
                "status": "PASS" if not item_findings else "FAIL",
                "findings": item_findings,
            }
        )
        findings.extend(f"{label}: {item}" for item in item_findings)

    return {
        "status": "PASS" if not findings else "FAIL",
        "mode": "require_deployed" if require_deployed else "pre_or_post_deploy",
        "manifest": str(manifest_path),
        "presets": results,
        "findings": findings,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--require-deployed", action="store_true")
    parser.add_argument("--deployed-snapshot-dir", type=Path)
    parser.add_argument("--write-functional-diff", type=Path)
    args = parser.parse_args(argv)
    if bool(args.deployed_snapshot_dir) != bool(args.write_functional_diff):
        parser.error("--deployed-snapshot-dir and --write-functional-diff are required together")
    if args.deployed_snapshot_dir:
        try:
            diff_report = build_functional_diff_report(args.manifest, args.deployed_snapshot_dir)
            args.write_functional_diff.write_text(
                json.dumps(diff_report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
            )
        except (OSError, KeyError, ValueError, json.JSONDecodeError) as exc:
            print(json.dumps({"status": "FAIL", "findings": [str(exc)]}, indent=2))
            return 1
    try:
        result = verify_manifest(args.manifest, require_deployed=args.require_deployed)
    except (OSError, KeyError, ValueError, json.JSONDecodeError) as exc:
        result = {"status": "FAIL", "findings": [str(exc)]}
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
