#!/usr/bin/env python3
"""Fail-closed Q10 input binding for Q09_NEWS v2.

This module validates that a Q10 work item has *both* authenticated upstream
dependencies (Q09_NEWS and Q09_PORTFOLIO), verifies their evidence bytes, and
materializes a generated setfile below the isolated Q10 report root.  The
source setfile is never modified.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sqlite3
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any, Mapping, Sequence

try:
    from q09_news_contract import (
        ADJUDICATION_SCHEMA_VERSION,
        TEMPORAL_MODE_IDS,
        canonical_json_bytes,
        sha256_file,
    )
    from q09_news_calendar import CalendarBundleError, verify_bundle
    from q09_news_schema import Q10DependencyGate, SchemaError, assert_q10_dependency_gate
except ModuleNotFoundError:
    from tools.strategy_farm.q09_news_contract import (
        ADJUDICATION_SCHEMA_VERSION,
        TEMPORAL_MODE_IDS,
        canonical_json_bytes,
        sha256_file,
    )
    from tools.strategy_farm.q09_news_calendar import CalendarBundleError, verify_bundle
    from tools.strategy_farm.q09_news_schema import (
        Q10DependencyGate,
        SchemaError,
        assert_q10_dependency_gate,
    )


SCHEMA_VERSION = "q10-q09-news-binding/v2"
COMPLIANCE_MODE_IDS = {"NONE": 0, "DXZ": 1, "FTMO": 2, "5ERS": 3}


class Q10BindingError(RuntimeError):
    """Raised when Q10 cannot prove its complete immutable input lineage."""


@dataclass(frozen=True)
class VerifiedBinding:
    q10_work_item_id: str
    q09_news_work_item_id: str
    q09_portfolio_work_item_id: str
    q09_news_evidence_path: str
    q09_news_evidence_sha256: str
    q09_portfolio_evidence_path: str
    q09_portfolio_evidence_sha256: str
    calendar_bundle_id: str
    calendar_manifest_path: str
    calendar_manifest_sha256: str
    calendar_content_sha256: str
    chosen_temporal: str
    chosen_temporal_id: int
    chosen_compliance: str
    chosen_compliance_id: int
    baseline_setfile_sha256: str
    ex5_sha256: str
    include_closure_sha256: str


def _resolve_evidence_path(raw: str, evidence_root: Path | None) -> Path:
    path = Path(raw)
    if not path.is_absolute():
        if evidence_root is None:
            raise Q10BindingError(f"relative evidence path has no evidence root: {raw}")
        path = evidence_root / path
    return path.resolve()


def _verify_file(path: Path, expected_sha256: str, role: str) -> None:
    if not path.is_file():
        raise Q10BindingError(f"{role} is missing: {path}")
    actual = sha256_file(path)
    if actual != expected_sha256:
        raise Q10BindingError(f"{role} SHA-256 mismatch: expected {expected_sha256}, got {actual}")


def verify_q10_binding(
    conn: sqlite3.Connection,
    q10_work_item_id: str,
    *,
    evidence_root: Path | None = None,
) -> VerifiedBinding:
    """Authenticate both dependencies and every file hash needed by Q10."""

    try:
        gate: Q10DependencyGate = assert_q10_dependency_gate(conn, q10_work_item_id)
    except SchemaError as exc:
        raise Q10BindingError(str(exc)) from exc

    news_row = conn.execute(
        """
        SELECT w.evidence_path,t.aggregate_path,b.manifest_path,b.manifest_sha256,b.content_sha256
        FROM work_items w
        JOIN q09_news_tests t ON t.work_item_id=w.id
        JOIN news_calendar_bundles b ON b.bundle_id=t.calendar_bundle_id
        WHERE w.id=? AND w.phase='Q09_NEWS' AND w.verdict='CONFIG_LOCKED'
        """,
        (gate.q09_news_work_item_id,),
    ).fetchone()
    if news_row is None:
        raise Q10BindingError("Q09_NEWS result/header/calendar binding is incomplete")
    if news_row[0] and str(news_row[0]) != str(news_row[1]):
        raise Q10BindingError("Q09_NEWS work-item evidence_path contradicts aggregate_path")
    news_path = _resolve_evidence_path(str(news_row[1]), evidence_root)
    _verify_file(news_path, gate.q09_news_evidence_sha256, "Q09_NEWS aggregate")
    try:
        news_aggregate = json.loads(news_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise Q10BindingError(f"Q09_NEWS aggregate is unreadable: {exc}") from exc
    embedded_adjudication_hash = news_aggregate.get("adjudication_sha256")
    unsigned_aggregate = dict(news_aggregate)
    unsigned_aggregate.pop("adjudication_sha256", None)
    actual_adjudication_hash = hashlib.sha256(canonical_json_bytes(unsigned_aggregate)).hexdigest()
    if (
        news_aggregate.get("schema_version") != ADJUDICATION_SCHEMA_VERSION
        or news_aggregate.get("verdict") != "CONFIG_LOCKED"
        or embedded_adjudication_hash != actual_adjudication_hash
    ):
        raise Q10BindingError("Q09_NEWS aggregate contract/hash is invalid")
    chosen = news_aggregate.get("chosen_config") or {}
    if (
        chosen.get("temporal_mode") != gate.chosen_temporal
        or chosen.get("compliance_mode") != gate.chosen_compliance
    ):
        raise Q10BindingError("Q09_NEWS aggregate chosen policy contradicts database lock")
    aggregate_identities = news_aggregate.get("identities") or {}
    if (
        aggregate_identities.get("baseline_setfile_sha256") != gate.baseline_setfile_sha256
        or aggregate_identities.get("ex5_sha256") != gate.ex5_sha256
        or aggregate_identities.get("include_closure_sha256") != gate.include_closure_sha256
    ):
        raise Q10BindingError("Q09_NEWS aggregate binary/input identity contradicts database lock")

    portfolio_row = conn.execute(
        """
        SELECT evidence_path FROM work_items
        WHERE id=? AND phase='Q09_PORTFOLIO' AND verdict='PASS_PORTFOLIO'
        """,
        (gate.q09_portfolio_work_item_id,),
    ).fetchone()
    if portfolio_row is None or not portfolio_row[0]:
        raise Q10BindingError("Q09_PORTFOLIO PASS evidence path is missing")
    portfolio_path = _resolve_evidence_path(str(portfolio_row[0]), evidence_root)
    _verify_file(portfolio_path, gate.q09_portfolio_evidence_sha256, "Q09_PORTFOLIO aggregate")

    calendar_path = _resolve_evidence_path(str(news_row[2]), evidence_root)
    _verify_file(calendar_path, str(news_row[3]), "calendar manifest")
    try:
        calendar_manifest = json.loads(calendar_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise Q10BindingError(f"calendar manifest is unreadable: {exc}") from exc
    if calendar_manifest.get("bundle_id") != gate.calendar_bundle_id:
        raise Q10BindingError("calendar manifest bundle_id mismatch")
    if calendar_manifest.get("content_sha256") != news_row[4]:
        raise Q10BindingError("calendar manifest content hash contradicts database")
    aggregate_calendar = news_aggregate.get("calendar_bundle") or {}
    if (
        aggregate_calendar.get("bundle_id") != gate.calendar_bundle_id
        or aggregate_calendar.get("manifest_sha256") != str(news_row[3])
        or aggregate_calendar.get("content_sha256") != str(news_row[4])
    ):
        raise Q10BindingError("Q09_NEWS aggregate calendar identity contradicts database lock")
    try:
        verified_calendar = verify_bundle(calendar_path.parent)
    except CalendarBundleError as exc:
        raise Q10BindingError(f"calendar bundle verification failed: {exc}") from exc
    if Path(verified_calendar["manifest_path"]).resolve() != calendar_path:
        raise Q10BindingError("calendar manifest is not the canonical bundle manifest")

    if gate.chosen_temporal not in TEMPORAL_MODE_IDS:
        raise Q10BindingError("Q09_NEWS chose a non-canonical temporal mode")
    if gate.chosen_compliance not in COMPLIANCE_MODE_IDS:
        raise Q10BindingError("Q09_NEWS chose a non-canonical compliance mode")
    return VerifiedBinding(
        q10_work_item_id=q10_work_item_id,
        q09_news_work_item_id=gate.q09_news_work_item_id,
        q09_portfolio_work_item_id=gate.q09_portfolio_work_item_id,
        q09_news_evidence_path=str(news_path),
        q09_news_evidence_sha256=gate.q09_news_evidence_sha256,
        q09_portfolio_evidence_path=str(portfolio_path),
        q09_portfolio_evidence_sha256=gate.q09_portfolio_evidence_sha256,
        calendar_bundle_id=gate.calendar_bundle_id,
        calendar_manifest_path=str(calendar_path),
        calendar_manifest_sha256=str(news_row[3]),
        calendar_content_sha256=str(news_row[4]),
        chosen_temporal=gate.chosen_temporal,
        chosen_temporal_id=TEMPORAL_MODE_IDS[gate.chosen_temporal],
        chosen_compliance=gate.chosen_compliance,
        chosen_compliance_id=COMPLIANCE_MODE_IDS[gate.chosen_compliance],
        baseline_setfile_sha256=gate.baseline_setfile_sha256,
        ex5_sha256=gate.ex5_sha256,
        include_closure_sha256=gate.include_closure_sha256,
    )


def _safe_relative_common_path(value: str) -> str:
    normalized = value.replace("\\", "/").strip("/")
    path = PurePosixPath(normalized)
    if not normalized or path.is_absolute() or ".." in path.parts or ":" in normalized:
        raise Q10BindingError("calendar Common path must be a safe relative path")
    return str(path)


def _decode_setfile(data: bytes) -> tuple[str, str, bytes]:
    if data.startswith(b"\xff\xfe"):
        return data[2:].decode("utf-16-le"), "utf-16-le", b"\xff\xfe"
    if data.startswith(b"\xfe\xff"):
        return data[2:].decode("utf-16-be"), "utf-16-be", b"\xfe\xff"
    if data.startswith(b"\xef\xbb\xbf"):
        return data[3:].decode("utf-8"), "utf-8", b"\xef\xbb\xbf"
    try:
        return data.decode("utf-8"), "utf-8", b""
    except UnicodeDecodeError:
        return data.decode("cp1252"), "cp1252", b""


def _replace_set_values(text: str, updates: Mapping[str, str]) -> str:
    newline = "\r\n" if "\r\n" in text else "\n"
    lines = text.splitlines()
    remaining = {key.lower(): (key, value) for key, value in updates.items()}
    output: list[str] = []
    for line in lines:
        if not line or line.lstrip().startswith(";") or "=" not in line:
            output.append(line)
            continue
        key, current = line.split("=", 1)
        lookup = key.strip().lower()
        update = remaining.pop(lookup, None)
        if update is None:
            output.append(line)
            continue
        _, value = update
        optimization_suffix = ""
        if "||" in current:
            optimization_suffix = "||" + current.split("||", 1)[1]
        output.append(f"{key}={value}{optimization_suffix}")
    if remaining:
        if output and output[-1] != "":
            output.append("")
        output.append("; Q09_NEWS v2 immutable Q10 binding")
        for _, (key, value) in sorted(remaining.items()):
            output.append(f"{key}={value}")
    return newline.join(output) + newline


def materialize_q10_inputs(
    binding: VerifiedBinding,
    *,
    source_setfile: Path,
    ex5_path: Path,
    include_closure_path: Path,
    report_root: Path,
    calendar_relative_common_path: str,
) -> dict[str, Any]:
    """Create the bound Q10 setfile and input manifest below ``report_root``."""

    source_setfile = source_setfile.resolve()
    ex5_path = ex5_path.resolve()
    include_closure_path = include_closure_path.resolve()
    report_root = report_root.resolve()
    relative_calendar = _safe_relative_common_path(calendar_relative_common_path)
    _verify_file(source_setfile, binding.baseline_setfile_sha256, "baseline source setfile")
    _verify_file(ex5_path, binding.ex5_sha256, "compiled EX5")
    _verify_file(include_closure_path, binding.include_closure_sha256, "include-closure manifest")
    source_before = source_setfile.read_bytes()
    decoded, encoding, bom = _decode_setfile(source_before)
    updates = {
        "qm_news_temporal": str(binding.chosen_temporal_id),
        "qm_news_compliance": str(binding.chosen_compliance_id),
        "qm_news_calendar_bundle_id": binding.calendar_bundle_id,
        "qm_news_calendar_expected_sha256": binding.calendar_content_sha256,
        "qm_news_calendar_common_relative_path": relative_calendar,
    }
    generated_text = _replace_set_values(decoded, updates)
    destination_dir = (report_root / "q10_bound" / binding.q10_work_item_id).resolve()
    try:
        destination_dir.relative_to(report_root)
    except ValueError as exc:
        raise Q10BindingError("generated Q10 directory escaped report root") from exc
    destination_dir.mkdir(parents=True, exist_ok=True)
    setfile_path = destination_dir / "q10_confirmation_bound.set"
    if setfile_path.resolve() == source_setfile:
        raise Q10BindingError("generated setfile would overwrite source setfile")
    encoded = bom + generated_text.encode(encoding)
    temporary_set = setfile_path.with_suffix(".set.tmp")
    temporary_set.write_bytes(encoded)
    temporary_set.replace(setfile_path)
    if source_setfile.read_bytes() != source_before:
        raise Q10BindingError("source setfile changed while materializing Q10 inputs")
    generated_sha = sha256_file(setfile_path)
    manifest: dict[str, Any] = {
        "schema_version": SCHEMA_VERSION,
        "q10_work_item_id": binding.q10_work_item_id,
        "dependencies": {
            "Q09_NEWS": {
                "work_item_id": binding.q09_news_work_item_id,
                "evidence_path": binding.q09_news_evidence_path,
                "evidence_sha256": binding.q09_news_evidence_sha256,
            },
            "Q09_PORTFOLIO": {
                "work_item_id": binding.q09_portfolio_work_item_id,
                "evidence_path": binding.q09_portfolio_evidence_path,
                "evidence_sha256": binding.q09_portfolio_evidence_sha256,
            },
        },
        "chosen_policy": {
            "temporal_mode": binding.chosen_temporal,
            "temporal_mode_id": binding.chosen_temporal_id,
            "compliance_mode": binding.chosen_compliance,
            "compliance_mode_id": binding.chosen_compliance_id,
        },
        "calendar_bundle": {
            "bundle_id": binding.calendar_bundle_id,
            "manifest_path": binding.calendar_manifest_path,
            "manifest_sha256": binding.calendar_manifest_sha256,
            "content_sha256": binding.calendar_content_sha256,
            "common_relative_path": relative_calendar,
        },
        "inputs": {
            "baseline_source_setfile": str(source_setfile),
            "baseline_source_setfile_sha256": binding.baseline_setfile_sha256,
            "generated_setfile": str(setfile_path),
            "generated_setfile_sha256": generated_sha,
            "ex5_path": str(ex5_path),
            "ex5_sha256": binding.ex5_sha256,
            "include_closure_path": str(include_closure_path),
            "include_closure_sha256": binding.include_closure_sha256,
        },
    }
    manifest["binding_sha256"] = hashlib.sha256(canonical_json_bytes(manifest)).hexdigest()
    manifest_path = destination_dir / "q10_input_manifest.json"
    temporary_manifest = manifest_path.with_suffix(".json.tmp")
    temporary_manifest.write_bytes(canonical_json_bytes(manifest))
    temporary_manifest.replace(manifest_path)
    return {
        "manifest": manifest,
        "manifest_path": str(manifest_path),
        "manifest_sha256": sha256_file(manifest_path),
        "generated_setfile": str(setfile_path),
        "generated_setfile_sha256": generated_sha,
    }


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", required=True, type=Path)
    parser.add_argument("--q10-work-item-id", required=True)
    parser.add_argument("--evidence-root", type=Path)
    parser.add_argument("--source-setfile", required=True, type=Path)
    parser.add_argument("--ex5", required=True, type=Path)
    parser.add_argument("--include-closure", required=True, type=Path)
    parser.add_argument("--report-root", required=True, type=Path)
    parser.add_argument("--calendar-common-relative-path", required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    conn = sqlite3.connect(str(args.database))
    try:
        binding = verify_q10_binding(
            conn,
            args.q10_work_item_id,
            evidence_root=args.evidence_root,
        )
    finally:
        conn.close()
    result = materialize_q10_inputs(
        binding,
        source_setfile=args.source_setfile,
        ex5_path=args.ex5,
        include_closure_path=args.include_closure,
        report_root=args.report_root,
        calendar_relative_common_path=args.calendar_common_relative_path,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
