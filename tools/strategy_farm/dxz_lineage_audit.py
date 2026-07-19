from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from html.parser import HTMLParser
from pathlib import Path
from typing import Any, Iterable


SCHEMA_VERSION = 1
CLASSIFICATION_ORDER = (
    "EVIDENCE_MISSING",
    "PREDECLARED_VARIANT_UNPROVEN",
    "UNKNOWN_PRESET_KEYS",
    "SOURCE_DEFAULT",
)

# MQL5 ENUM_TIMEFRAMES values are deliberately non-linear above M30.
TIMEFRAME_ENUMS = {
    "PERIOD_CURRENT": 0,
    "PERIOD_M1": 1,
    "PERIOD_M2": 2,
    "PERIOD_M3": 3,
    "PERIOD_M4": 4,
    "PERIOD_M5": 5,
    "PERIOD_M6": 6,
    "PERIOD_M10": 10,
    "PERIOD_M12": 12,
    "PERIOD_M15": 15,
    "PERIOD_M20": 20,
    "PERIOD_M30": 30,
    "PERIOD_H1": 16385,
    "PERIOD_H2": 16386,
    "PERIOD_H3": 16387,
    "PERIOD_H4": 16388,
    "PERIOD_H6": 16390,
    "PERIOD_H8": 16392,
    "PERIOD_H12": 16396,
    "PERIOD_D1": 16408,
    "PERIOD_W1": 32769,
    "PERIOD_MN1": 49153,
}

INTEGER_TYPES = {
    "char",
    "uchar",
    "short",
    "ushort",
    "int",
    "uint",
    "long",
    "ulong",
}
FLOAT_TYPES = {"float", "double"}
POLICY_KEYS = {
    "friday": ("qm_friday_close_enabled", "qm_friday_close_hour_broker"),
    "news": (
        "qm_news_temporal",
        "qm_news_compliance",
        "qm_news_stale_max_hours",
        "qm_news_min_impact",
        "qm_news_mode_legacy",
    ),
}


class LineageAuditError(RuntimeError):
    """Raised when an audit input is structurally unsafe to evaluate."""


@dataclass(frozen=True)
class InputDeclaration:
    name: str
    type_name: str
    default_raw: str
    declared_in: str


class _TableParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.rows: list[list[str]] = []
        self._row: list[str] | None = None
        self._cell: list[str] | None = None

    def handle_starttag(
        self, tag: str, attrs: list[tuple[str, str | None]]
    ) -> None:
        del attrs
        tag = tag.lower()
        if tag == "tr":
            self._row = []
        elif tag in {"td", "th"} and self._row is not None:
            self._cell = []

    def handle_data(self, data: str) -> None:
        if self._cell is not None:
            self._cell.append(data)

    def handle_endtag(self, tag: str) -> None:
        tag = tag.lower()
        if tag in {"td", "th"} and self._row is not None and self._cell is not None:
            self._row.append(" ".join("".join(self._cell).split()))
            self._cell = None
        elif tag == "tr" and self._row is not None:
            self.rows.append(self._row)
            self._row = None


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_sha256(value: Any) -> str:
    payload = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def _read_text(path: Path) -> str:
    raw = path.read_bytes()
    for encoding in ("utf-8-sig", "utf-16", "utf-16-le", "cp1252"):
        try:
            return raw.decode(encoding)
        except UnicodeDecodeError:
            continue
    raise LineageAuditError(f"cannot decode text file: {path}")


def _absolute_path(raw: Any, label: str) -> Path:
    value = str(raw or "").strip()
    if not value:
        raise LineageAuditError(f"{label} path is empty")
    path = Path(value)
    if not path.is_absolute():
        raise LineageAuditError(f"{label} path must be absolute: {value}")
    return path


def _path_key(path: Path) -> str:
    return str(path).replace("/", "\\").rstrip("\\").casefold()


def _artifact_binding(path: Path) -> dict[str, Any]:
    exists = path.is_file()
    return {
        "path": str(path),
        "expected_exists": exists,
        "sha256": sha256_file(path) if exists else None,
    }


def verify_artifact(binding: dict[str, Any], label: str) -> tuple[Path, list[str]]:
    path = _absolute_path(binding.get("path"), label)
    expected_exists = binding.get("expected_exists")
    expected_sha = binding.get("sha256")
    reasons: list[str] = []
    if not isinstance(expected_exists, bool):
        reasons.append(f"{label}:EXPECTED_EXISTS_UNBOUND")
        return path, reasons
    actual_exists = path.is_file()
    if actual_exists != expected_exists:
        reasons.append(f"{label}:EXISTENCE_DRIFT")
        return path, reasons
    if not actual_exists:
        reasons.append(f"{label}:FILE_MISSING")
        return path, reasons
    if not isinstance(expected_sha, str) or not re.fullmatch(r"[0-9a-f]{64}", expected_sha):
        reasons.append(f"{label}:SHA256_UNBOUND")
        return path, reasons
    if sha256_file(path) != expected_sha:
        reasons.append(f"{label}:SHA256_MISMATCH")
    return path, reasons


def _strip_comments(text: str) -> str:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    return re.sub(r"//[^\r\n]*", "", text)


def _resolve_include(source: Path, token: str, repo_root: Path) -> Path | None:
    cleaned = token.strip().replace("\\", "/")
    candidates = [source.parent / cleaned]
    if cleaned.startswith("QM/"):
        candidates.append(repo_root / "framework" / "include" / cleaned)
    candidates.append(repo_root / "framework" / "include" / cleaned)
    for candidate in candidates:
        if candidate.is_file():
            return candidate.resolve()
    return None


def source_dependency_closure(source: Path, repo_root: Path) -> list[Path]:
    pending = [source.resolve()]
    seen: set[str] = set()
    result: list[Path] = []
    include_re = re.compile(r"^\s*#include\s*[<\"]([^>\"]+)[>\"]", re.MULTILINE)
    while pending:
        path = pending.pop()
        key = _path_key(path)
        if key in seen:
            continue
        seen.add(key)
        result.append(path)
        for match in include_re.finditer(_read_text(path)):
            resolved = _resolve_include(path, match.group(1), repo_root)
            if resolved is not None and _path_key(resolved) not in seen:
                pending.append(resolved)
    return sorted(result, key=lambda item: _path_key(item))


def parse_enum_values(texts: Iterable[str]) -> dict[str, int]:
    values = dict(TIMEFRAME_ENUMS)
    enum_re = re.compile(r"\benum\s+[A-Za-z_]\w*\s*\{(.*?)\}\s*;", re.DOTALL)
    for text in texts:
        clean = _strip_comments(text)
        for enum_match in enum_re.finditer(clean):
            current = -1
            for raw_member in enum_match.group(1).split(","):
                member = raw_member.strip()
                if not member:
                    continue
                name, separator, expression = member.partition("=")
                name = name.strip()
                if not re.fullmatch(r"[A-Za-z_]\w*", name):
                    continue
                if separator:
                    expression = expression.strip()
                    try:
                        current = int(expression, 0)
                    except ValueError:
                        if expression in values:
                            current = values[expression]
                        else:
                            continue
                else:
                    current += 1
                values[name] = current
    return values


def parse_input_declarations(paths: Iterable[Path]) -> dict[str, InputDeclaration]:
    declarations: dict[str, InputDeclaration] = {}
    input_re = re.compile(
        r"^\s*input\s+(?!group\b)([A-Za-z_]\w*)\s+([A-Za-z_]\w*)\s*=\s*([^;]+);",
        re.MULTILINE,
    )
    for path in paths:
        clean = _strip_comments(_read_text(path))
        for match in input_re.finditer(clean):
            declaration = InputDeclaration(
                name=match.group(2),
                type_name=match.group(1),
                default_raw=match.group(3).strip(),
                declared_in=str(path),
            )
            existing = declarations.get(declaration.name)
            if existing is not None and existing != declaration:
                raise LineageAuditError(
                    f"conflicting input declarations for {declaration.name}: "
                    f"{existing.declared_in} vs {declaration.declared_in}"
                )
            declarations[declaration.name] = declaration
    return declarations


def parse_preset(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line_number, raw_line in enumerate(_read_text(path).splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith(";") or line.startswith("#"):
            continue
        if "=" not in line:
            raise LineageAuditError(f"malformed preset line {path}:{line_number}")
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.split("||", 1)[0].strip()
        if not re.fullmatch(r"[A-Za-z_]\w*", key):
            raise LineageAuditError(f"invalid preset key {path}:{line_number}: {key}")
        if key in values:
            raise LineageAuditError(f"duplicate preset key {path}:{line_number}: {key}")
        values[key] = value
    return values


def parse_report_inputs(path: Path) -> dict[str, str]:
    parser = _TableParser()
    parser.feed(_read_text(path))
    in_inputs = False
    values: dict[str, str] = {}
    for row in parser.rows:
        if any(cell.rstrip(":").strip().casefold() == "inputs" for cell in row):
            in_inputs = True
        if in_inputs and any(cell.rstrip(":").strip().casefold() == "company" for cell in row):
            break
        if not in_inputs:
            continue
        for cell in row:
            key, separator, value = cell.partition("=")
            key = key.strip()
            if separator and re.fullmatch(r"[A-Za-z_]\w*", key):
                values[key] = value.strip()
    if not in_inputs:
        raise LineageAuditError(f"MT5 report has no Inputs section: {path}")
    return values


def _decimal_canonical(value: str) -> str | None:
    try:
        number = Decimal(value.strip())
    except InvalidOperation:
        return None
    if not number.is_finite():
        return None
    if number == 0:
        return "0"
    rendered = format(number.normalize(), "f")
    return rendered.rstrip("0").rstrip(".") if "." in rendered else rendered


def normalize_value(
    raw: str,
    type_name: str,
    enum_values: dict[str, int] | None = None,
) -> dict[str, Any]:
    value = str(raw).strip()
    enums = enum_values or TIMEFRAME_ENUMS
    if type_name == "bool":
        lowered = value.casefold()
        if lowered in {"true", "1"}:
            return {"raw": value, "kind": "bool", "canonical": True, "resolved": True}
        if lowered in {"false", "0"}:
            return {"raw": value, "kind": "bool", "canonical": False, "resolved": True}
        return {"raw": value, "kind": "bool", "canonical": value, "resolved": False}
    if type_name in INTEGER_TYPES:
        try:
            integer = int(value, 0)
        except ValueError:
            integer = enums.get(value)  # type: ignore[assignment]
        if integer is not None:
            return {"raw": value, "kind": "integer", "canonical": integer, "resolved": True}
        return {"raw": value, "kind": "integer", "canonical": value, "resolved": False}
    if type_name in FLOAT_TYPES:
        canonical = _decimal_canonical(value)
        if canonical is not None:
            return {"raw": value, "kind": "number", "canonical": canonical, "resolved": True}
        return {"raw": value, "kind": "number", "canonical": value, "resolved": False}
    if type_name == "string":
        if len(value) >= 2 and value[0] == value[-1] == '"':
            value = value[1:-1]
        return {"raw": raw.strip(), "kind": "string", "canonical": value, "resolved": True}
    if value in enums:
        return {"raw": value, "kind": "enum", "canonical": enums[value], "resolved": True}
    try:
        integer = int(value, 0)
    except ValueError:
        return {"raw": value, "kind": "enum", "canonical": value, "resolved": False}
    return {"raw": value, "kind": "enum", "canonical": integer, "resolved": True}


def normalized_equal(left: dict[str, Any], right: dict[str, Any]) -> bool:
    return (
        bool(left.get("resolved"))
        and bool(right.get("resolved"))
        and left.get("canonical") == right.get("canonical")
    )


def _card_status(path: Path) -> str | None:
    text = _read_text(path)
    frontmatter = text.split("---", 2)
    if len(frontmatter) < 3:
        return None
    for key in ("g0_status", "status"):
        match = re.search(rf"^\s*{key}\s*:\s*([^#\r\n]+)", frontmatter[1], re.MULTILINE)
        if match:
            return match.group(1).strip().strip('"\'')
    return None


def _effective_entry(
    name: str,
    declaration: InputDeclaration,
    preset: dict[str, str],
    report: dict[str, str],
    enum_values: dict[str, int],
) -> dict[str, Any]:
    default = normalize_value(declaration.default_raw, declaration.type_name, enum_values)
    preset_value = (
        normalize_value(preset[name], declaration.type_name, enum_values)
        if name in preset
        else None
    )
    expected = preset_value or default
    report_value = (
        normalize_value(report[name], declaration.type_name, enum_values)
        if name in report
        else None
    )
    effective = report_value or expected
    return {
        "type": declaration.type_name,
        "declared_in": declaration.declared_in,
        "source_default": default,
        "preset_value": preset_value,
        "preset_declared": name in preset,
        "report_value": report_value,
        "effective_value": effective,
        "preset_overrides_source": bool(preset_value and not normalized_equal(default, preset_value)),
        "report_matches_expected": (
            normalized_equal(report_value, expected) if report_value is not None else None
        ),
    }


def _policy_view(entries: dict[str, dict[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for group, names in POLICY_KEYS.items():
        group_entries = {name: entries[name] for name in names if name in entries}
        result[group] = {
            "inputs": group_entries,
            "changed_from_source": any(
                bool(item.get("preset_overrides_source")) for item in group_entries.values()
            ),
        }
    return result


def _select_classification(flags: list[str]) -> str:
    for classification in CLASSIFICATION_ORDER:
        if classification in flags:
            return classification
    raise AssertionError("classification flags cannot be empty")


def bind_explicit_spec(spec: dict[str, Any], spec_path: Path) -> dict[str, Any]:
    if spec.get("schema_version") != SCHEMA_VERSION:
        raise LineageAuditError("unsupported explicit spec schema_version")
    repo_root = _absolute_path(spec.get("repo_root"), "repo_root")
    source_manifest_path = _absolute_path(spec.get("source_manifest_path"), "source_manifest")
    sleeves = spec.get("sleeves")
    if not isinstance(sleeves, list) or not sleeves:
        raise LineageAuditError("explicit spec sleeves must be a non-empty list")
    bound_sleeves: list[dict[str, Any]] = []
    seen: set[str] = set()
    for index, sleeve in enumerate(sleeves):
        if not isinstance(sleeve, dict):
            raise LineageAuditError(f"sleeves[{index}] must be an object")
        ea_id = int(sleeve.get("ea_id"))
        symbol = str(sleeve.get("symbol") or "").strip()
        key = f"{ea_id}|{symbol}"
        if not symbol or key in seen:
            raise LineageAuditError(f"invalid or duplicate sleeve identity: {key}")
        seen.add(key)
        artifacts: dict[str, Any] = {}
        for label in ("card", "source", "receipt", "preset", "report"):
            path = _absolute_path(sleeve.get(f"{label}_path"), f"{key}:{label}")
            artifacts[label] = _artifact_binding(path)
        source_path = Path(artifacts["source"]["path"])
        dependencies = (
            source_dependency_closure(source_path, repo_root)
            if source_path.is_file()
            else []
        )
        artifacts["source_dependencies"] = [
            _artifact_binding(path) for path in dependencies if path != source_path.resolve()
        ]
        bound_sleeves.append(
            {
                "ea_id": ea_id,
                "symbol": symbol,
                "artifacts": artifacts,
                "variant_authorization": sleeve.get("variant_authorization"),
            }
        )
    result = {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "DXZ23_LINEAGE_AUDIT_BOUND_INPUT",
        "qualification_scope": "NON_QUALIFICATION_LINEAGE_AUDIT",
        "deployment_eligible": False,
        "binding_mode": "EXPLICIT_PATH_HASHES",
        "bound_as_of_utc": str(spec.get("bound_as_of_utc") or "").strip(),
        "repo_root": str(repo_root),
        "source_spec": _artifact_binding(spec_path),
        "source_manifest": _artifact_binding(source_manifest_path),
        "sleeves": bound_sleeves,
    }
    if not result["bound_as_of_utc"]:
        raise LineageAuditError("bound_as_of_utc is required for deterministic evidence")
    result["binding_sha256"] = canonical_sha256(result)
    return result


def _verify_receipt(
    path: Path,
    ea_id: int,
    symbol: str,
    preset_path: Path,
    report_path: Path,
    preset_sha: str | None,
    report_sha: str | None,
) -> list[str]:
    reasons: list[str] = []
    try:
        receipt = json.loads(_read_text(path))
    except (json.JSONDecodeError, OSError) as exc:
        return [f"receipt:PARSE_ERROR:{type(exc).__name__}"]
    job = receipt.get("job") or {}
    if int(job.get("ea_id") or -1) != ea_id or str(job.get("symbol") or "") != symbol:
        reasons.append("receipt:SLEEVE_IDENTITY_MISMATCH")
    identity = receipt.get("identity") or {}
    receipt_preset = identity.get("live_preset_path")
    if receipt_preset and _path_key(Path(str(receipt_preset))) != _path_key(preset_path):
        reasons.append("receipt:PRESET_PATH_MISMATCH")
    if preset_sha and identity.get("live_preset_sha256") not in {None, preset_sha}:
        reasons.append("receipt:PRESET_SHA256_MISMATCH")
    receipt_report = (receipt.get("native_metrics") or {}).get("report_path")
    if receipt_report and _path_key(Path(str(receipt_report))) != _path_key(report_path):
        reasons.append("receipt:REPORT_PATH_MISMATCH")
    if report_sha and identity.get("native_report_sha256") not in {None, report_sha}:
        reasons.append("receipt:REPORT_SHA256_MISMATCH")
    return reasons


def audit_bound_input(bound: dict[str, Any], input_path: Path, as_of_utc: str) -> dict[str, Any]:
    if bound.get("schema_version") != SCHEMA_VERSION:
        raise LineageAuditError("unsupported bound input schema_version")
    if bound.get("binding_mode") != "EXPLICIT_PATH_HASHES":
        raise LineageAuditError("audit requires EXPLICIT_PATH_HASHES binding_mode")
    if bound.get("deployment_eligible") is not False:
        raise LineageAuditError("bound input must be deployment_eligible=false")
    expected_binding_sha = bound.get("binding_sha256")
    unhashed_bound = dict(bound)
    unhashed_bound.pop("binding_sha256", None)
    if expected_binding_sha != canonical_sha256(unhashed_bound):
        raise LineageAuditError("bound input binding_sha256 mismatch")

    repo_root = _absolute_path(bound.get("repo_root"), "repo_root")
    source_manifest_path, global_reasons = verify_artifact(
        bound.get("source_manifest") or {}, "source_manifest"
    )
    try:
        source_manifest = json.loads(_read_text(source_manifest_path)) if not global_reasons else {}
    except json.JSONDecodeError:
        source_manifest = {}
        global_reasons.append("source_manifest:PARSE_ERROR")
    manifest_rows = {
        f"{int(row.get('ea_id'))}|{str(row.get('symbol') or '')}": row
        for row in (source_manifest.get("sleeves") or [])
        if isinstance(row, dict) and row.get("ea_id") is not None
    }
    bound_rows = bound.get("sleeves")
    if not isinstance(bound_rows, list):
        raise LineageAuditError("bound sleeves must be a list")
    bound_keys = [f"{int(row.get('ea_id'))}|{str(row.get('symbol') or '')}" for row in bound_rows]
    if len(bound_keys) != len(set(bound_keys)):
        raise LineageAuditError("duplicate bound sleeve identities")
    if set(bound_keys) != set(manifest_rows):
        global_reasons.append("BOUND_SLEEVES_DO_NOT_EQUAL_SOURCE_MANIFEST")

    results: list[dict[str, Any]] = []
    for row in bound_rows:
        ea_id = int(row.get("ea_id"))
        symbol = str(row.get("symbol") or "")
        key = f"{ea_id}|{symbol}"
        artifacts = row.get("artifacts") or {}
        reasons = list(global_reasons)
        verified_paths: dict[str, Path] = {}
        evidence_hashes: dict[str, Any] = {}
        for label in ("card", "source", "receipt", "preset", "report"):
            binding = artifacts.get(label) or {}
            path, artifact_reasons = verify_artifact(binding, label)
            verified_paths[label] = path
            reasons.extend(artifact_reasons)
            evidence_hashes[label] = {
                "path": str(path),
                "sha256": binding.get("sha256"),
                "verified": not artifact_reasons,
            }
        dependency_paths: list[Path] = []
        dependency_hashes: list[dict[str, Any]] = []
        for dep_index, dep_binding in enumerate(artifacts.get("source_dependencies") or []):
            dep_path, dep_reasons = verify_artifact(dep_binding, f"source_dependency[{dep_index}]")
            reasons.extend(dep_reasons)
            if not dep_reasons:
                dependency_paths.append(dep_path)
            dependency_hashes.append(
                {
                    "path": str(dep_path),
                    "sha256": dep_binding.get("sha256"),
                    "verified": not dep_reasons,
                }
            )
        evidence_hashes["source_dependencies"] = dependency_hashes

        source_ok = evidence_hashes["source"]["verified"]
        preset_ok = evidence_hashes["preset"]["verified"]
        report_ok = evidence_hashes["report"]["verified"]
        card_ok = evidence_hashes["card"]["verified"]
        receipt_ok = evidence_hashes["receipt"]["verified"]
        declarations: dict[str, InputDeclaration] = {}
        enum_values = dict(TIMEFRAME_ENUMS)
        preset: dict[str, str] = {}
        report: dict[str, str] = {}
        if source_ok:
            closure = [verified_paths["source"], *dependency_paths]
            try:
                enum_values = parse_enum_values(_read_text(path) for path in closure)
                declarations = parse_input_declarations(closure)
            except LineageAuditError as exc:
                reasons.append(f"source:PARSE_ERROR:{exc}")
        if preset_ok:
            try:
                preset = parse_preset(verified_paths["preset"])
            except LineageAuditError as exc:
                reasons.append(f"preset:PARSE_ERROR:{exc}")
        if report_ok:
            try:
                report = parse_report_inputs(verified_paths["report"])
            except LineageAuditError as exc:
                reasons.append(f"report:PARSE_ERROR:{exc}")

        if receipt_ok:
            reasons.extend(
                _verify_receipt(
                    verified_paths["receipt"],
                    ea_id,
                    symbol,
                    verified_paths["preset"],
                    verified_paths["report"],
                    artifacts.get("preset", {}).get("sha256"),
                    artifacts.get("report", {}).get("sha256"),
                )
            )
        manifest_row = manifest_rows.get(key)
        if manifest_row is None:
            reasons.append("source_manifest:SLEEVE_MISSING")
        elif source_ok and verified_paths["source"].stem != str(manifest_row.get("ea_label") or ""):
            reasons.append("source_manifest:EA_LABEL_SOURCE_MISMATCH")

        entries = {
            name: _effective_entry(name, declaration, preset, report, enum_values)
            for name, declaration in sorted(declarations.items())
        }
        report_mismatches = sorted(
            name
            for name, entry in entries.items()
            if entry["report_matches_expected"] is False
        )
        if report_mismatches:
            reasons.append("report:EFFECTIVE_INPUT_MISMATCH")
        unknown_preset_keys = sorted(set(preset) - set(declarations))
        strategy_overrides = {
            name: entry
            for name, entry in entries.items()
            if name.startswith("strategy_") and entry["preset_overrides_source"]
        }
        missing_strategy_keys = {
            name: entry
            for name, entry in entries.items()
            if name.startswith("strategy_") and not entry["preset_declared"]
        }
        policy = _policy_view(entries)
        policy_changed = any(group["changed_from_source"] for group in policy.values())
        flags: list[str] = []
        if reasons:
            flags.append("EVIDENCE_MISSING")
        if unknown_preset_keys:
            flags.append("UNKNOWN_PRESET_KEYS")
        if strategy_overrides or policy_changed:
            flags.append("PREDECLARED_VARIANT_UNPROVEN")
        if not flags:
            flags.append("SOURCE_DEFAULT")

        card_status = _card_status(verified_paths["card"]) if card_ok else None
        results.append(
            {
                "ea_id": ea_id,
                "symbol": symbol,
                "key": key,
                "classification": _select_classification(flags),
                "classification_flags": flags,
                "evidence_missing_reasons": sorted(set(reasons)),
                "evidence_hashes": evidence_hashes,
                "card_status": card_status,
                "mql5_input_defaults": entries,
                "preset_values_raw": dict(sorted(preset.items())),
                "report_effective_values_raw": dict(sorted(report.items())),
                "preset_overrides": {
                    name: entry for name, entry in entries.items() if entry["preset_overrides_source"]
                },
                "strategy_overrides": strategy_overrides,
                "missing_strategy_keys_using_defaults": missing_strategy_keys,
                "unknown_preset_keys": unknown_preset_keys,
                "report_effective_mismatches": report_mismatches,
                "effective_policy": policy,
                "variant_authorization": row.get("variant_authorization"),
            }
        )

    counts = {name: sum(item["classification"] == name for item in results) for name in CLASSIFICATION_ORDER}
    flag_counts = {name: sum(name in item["classification_flags"] for item in results) for name in CLASSIFICATION_ORDER}
    result = {
        "schema_version": SCHEMA_VERSION,
        "artifact_type": "DXZ23_CARD_EA_PRESET_REPORT_LINEAGE_AUDIT",
        "qualification_scope": "NON_QUALIFICATION_LINEAGE_AUDIT",
        "deployment_eligible": False,
        "autotrading_action": "NONE_READ_ONLY",
        "generated_as_of_utc": as_of_utc,
        "input_manifest": {"path": str(input_path), "sha256": sha256_file(input_path)},
        "source_manifest": {
            "path": str(source_manifest_path),
            "sha256": (bound.get("source_manifest") or {}).get("sha256"),
        },
        "selection_policy": "EXPLICIT_BOUND_PATHS_ONLY_NO_LATEST_DISCOVERY",
        "classification_precedence": list(CLASSIFICATION_ORDER),
        "counts": counts,
        "classification_flag_counts": flag_counts,
        "sleeve_count": len(results),
        "global_evidence_reasons": sorted(set(global_reasons)),
        "sleeves": results,
    }
    result["report_content_sha256"] = canonical_sha256(result)
    return result


def write_immutable_json(path: Path, payload: dict[str, Any]) -> None:
    rendered = json.dumps(payload, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    if path.exists():
        if path.read_text(encoding="utf-8") == rendered:
            return
        raise LineageAuditError(f"refusing to overwrite immutable artifact: {path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(rendered, encoding="utf-8")
    temporary.replace(path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Read-only, hash-bound DXZ Card/EA/Preset/Report lineage audit."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)
    bind_parser = subparsers.add_parser("bind", help="Bind an explicit path spec to SHA-256 values")
    bind_parser.add_argument("--spec", type=Path, required=True)
    bind_parser.add_argument("--output", type=Path, required=True)
    audit_parser = subparsers.add_parser("audit", help="Audit a previously hash-bound input manifest")
    audit_parser.add_argument("--input-manifest", type=Path, required=True)
    audit_parser.add_argument("--output", type=Path, required=True)
    audit_parser.add_argument("--as-of-utc", required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "bind":
            spec_path = args.spec.resolve()
            spec = json.loads(_read_text(spec_path))
            payload = bind_explicit_spec(spec, spec_path)
            write_immutable_json(args.output.resolve(), payload)
        else:
            input_path = args.input_manifest.resolve()
            bound = json.loads(_read_text(input_path))
            payload = audit_bound_input(bound, input_path, str(args.as_of_utc).strip())
            if not payload["generated_as_of_utc"]:
                raise LineageAuditError("--as-of-utc must not be empty")
            write_immutable_json(args.output.resolve(), payload)
        print(json.dumps(payload.get("counts", {"binding_sha256": payload.get("binding_sha256")}), sort_keys=True))
        return 0
    except (LineageAuditError, json.JSONDecodeError, OSError, ValueError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
