"""Pre-registration — freeze the hypothesis before validation (design doc sec 6).

Before a candidate is tested, PRE-REGISTER freezes the hypothesis so a later
holdout result cannot be retrofitted. :func:`build_preregistration` produces an
immutable freeze record (directive sec 16 fields), :func:`write_preregistration`
writes ``preregistration.json`` (self-hashed) into the research artifact dir,
appends a ``lineage.json`` version, and appends a ``status: preregistered`` row to
the research-source ledger.

Lineage / immutability rule (directive sec 16, R-B): once holdout results are
observed the hypothesis may not be modified and passed off as the original. Any
modification mints a NEW lineage version with a parent link — never a silent
rewrite. :func:`check_unchanged` is the deterministic guard: it recomputes the
mechanical-spec sha256 and confirms it still matches the frozen record.
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
from typing import Any, Mapping

PREREGISTRATION_SCHEMA = "qm.research-preregistration/v1"
LINEAGE_SCHEMA = "qm.research-lineage/v1"

# Directive sec 16 required freeze fields.
_REQUIRED = (
    "hypothesis",
    "parameter_ranges",
    "discovery_sample",
    "validation_sample",
    "holdout_logic",
    "expected_behaviour",
    "success_criteria",
    "failure_criteria",
    "known_risks",
)


def _utc_now_iso() -> str:
    return dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha256_text(text: str) -> str:
    return _sha256_bytes(text.encode("utf-8"))


def _spec_sha256(spec: Path | str) -> str:
    """sha256 of a mechanical-spec file (path) or its literal text."""

    candidate = Path(spec) if not isinstance(spec, Path) else spec
    try:
        if candidate.exists():
            return _sha256_bytes(candidate.read_bytes())
    except (OSError, ValueError):
        pass
    # Treat the argument as literal spec text.
    return _sha256_text(str(spec))


def _canonical_record_sha(record: Mapping[str, Any]) -> str:
    """Content hash over the record with its own sha field excluded."""

    payload = {k: v for k, v in record.items() if k != "record_sha256"}
    return _sha256_text(json.dumps(payload, sort_keys=True, separators=(",", ":")))


def build_preregistration(
    *,
    research_id: str,
    hypothesis: str,
    mechanical_spec: Path | str,
    parameter_ranges: Mapping[str, Any],
    discovery_sample: Any,
    validation_sample: Any,
    holdout_logic: Any,
    expected_behaviour: Any,
    success_criteria: Any,
    failure_criteria: Any,
    known_risks: Any,
    parent_version: int | None = None,
    now: dt.datetime | None = None,
) -> dict[str, Any]:
    """Build the immutable freeze record (directive sec 16)."""

    if not str(research_id or "").strip():
        raise ValueError("research_id is required")
    if not isinstance(parameter_ranges, Mapping) or not parameter_ranges:
        raise ValueError("parameter_ranges must be a non-empty mapping name->range")

    record: dict[str, Any] = {
        "schema": PREREGISTRATION_SCHEMA,
        "research_id": str(research_id).strip(),
        "created_at": (now.isoformat() if now else _utc_now_iso()),
        "version": (int(parent_version) + 1) if parent_version is not None else 1,
        "parent_version": int(parent_version) if parent_version is not None else None,
        "hypothesis": hypothesis,
        "mechanical_spec_sha256": _spec_sha256(mechanical_spec),
        "parameter_ranges": dict(parameter_ranges),
        "parameter_count": len(parameter_ranges),
        "discovery_sample": discovery_sample,
        "validation_sample": validation_sample,
        "holdout_logic": holdout_logic,
        "expected_behaviour": expected_behaviour,
        "success_criteria": success_criteria,
        "failure_criteria": failure_criteria,
        "known_risks": known_risks,
    }
    missing = [f for f in _REQUIRED if record.get(f) in (None, "", [], {})]
    if missing:
        raise ValueError(f"preregistration missing fields: {sorted(missing)}")
    record["record_sha256"] = _canonical_record_sha(record)
    return record


def check_unchanged(record: Mapping[str, Any], current_spec: Path | str) -> bool:
    """True iff the mechanical spec still matches the frozen record's sha256.

    A False result means the spec changed after freeze: the caller MUST mint a new
    lineage version (parent = the frozen record's version), never edit in place.
    """

    frozen = str(record.get("mechanical_spec_sha256") or "")
    return bool(frozen) and _spec_sha256(current_spec) == frozen


def _append_ledger(ledger_path: Path, row: dict[str, Any]) -> None:
    ledger_path.parent.mkdir(parents=True, exist_ok=True)
    line = (json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    flags = os.O_WRONLY | os.O_CREAT | os.O_APPEND | getattr(os, "O_BINARY", 0)
    fd = os.open(ledger_path, flags, 0o600)
    try:
        os.write(fd, line)
    finally:
        os.close(fd)


def _update_lineage(artifact_dir: Path, record: Mapping[str, Any]) -> dict[str, Any]:
    """Append a preregistration version to lineage.json.

    Tolerates a lineage.json minted by research_source.mint (contract F6, 2026-09-15):
    that skeleton carries schema/research_id/version/parent_version_id/... but NO
    ``versions`` list. We initialise ``versions`` when absent and PRESERVE every
    existing key, so both tools share one schema id (qm.research-lineage/v1) with a
    ``versions[]`` array rather than colliding on incompatible shapes.
    """
    lineage_path = artifact_dir / "lineage.json"
    if lineage_path.exists():
        loaded = json.loads(lineage_path.read_text(encoding="utf-8"))
        lineage = loaded if isinstance(loaded, dict) else {}
    else:
        lineage = {}
    lineage.setdefault("schema", LINEAGE_SCHEMA)
    lineage.setdefault("research_id", record.get("research_id"))
    lineage.setdefault("versions", [])
    if not isinstance(lineage.get("versions"), list):
        lineage["versions"] = []
    lineage["versions"].append(
        {
            "version": record["version"],
            "parent_version": record.get("parent_version"),
            "record_sha256": record["record_sha256"],
            "mechanical_spec_sha256": record["mechanical_spec_sha256"],
            "created_at": record["created_at"],
        }
    )
    lineage_path.write_text(
        json.dumps(lineage, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n"
    )
    return lineage


def write_preregistration(
    artifact_dir: Path | str,
    record: Mapping[str, Any],
    *,
    ledger_path: Path | str | None = None,
) -> dict[str, Any]:
    """Write preregistration.json + update lineage.json + append the ledger row.

    Returns {"preregistration_path", "lineage_path", "lineage"}. The
    preregistration.json for version N is written once; a later change must call
    :func:`build_preregistration` with ``parent_version=N`` producing a distinct
    ``preregistration.v<N+1>.json`` — this function refuses to overwrite an
    existing same-version file (immutability).
    """

    artifact_dir = Path(artifact_dir)
    artifact_dir.mkdir(parents=True, exist_ok=True)
    version = int(record["version"])
    name = "preregistration.json" if version == 1 else f"preregistration.v{version}.json"
    prereg_path = artifact_dir / name
    if prereg_path.exists():
        existing = json.loads(prereg_path.read_text(encoding="utf-8"))
        if existing.get("record_sha256") != record.get("record_sha256"):
            raise FileExistsError(
                f"preregistration {name} already exists with a different hash "
                "(immutability): mint a new version with parent_version instead"
            )
        return {
            "preregistration_path": str(prereg_path),
            "lineage_path": str(artifact_dir / "lineage.json"),
            "lineage": json.loads((artifact_dir / "lineage.json").read_text(encoding="utf-8"))
            if (artifact_dir / "lineage.json").exists()
            else None,
            "already_present": True,
        }

    prereg_path.write_text(
        json.dumps(dict(record), indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n"
    )
    lineage = _update_lineage(artifact_dir, record)

    if ledger_path is not None:
        _append_ledger(
            Path(ledger_path),
            {
                "schema": "qm.research-source-ledger/v1",
                "ts": _utc_now_iso(),
                "id": record.get("research_id"),
                "status": "preregistered",
                "version": version,
                "parent_version": record.get("parent_version"),
                "record_sha256": record["record_sha256"],
                "mechanical_spec_sha256": record["mechanical_spec_sha256"],
                "preregistration_path": str(prereg_path),
            },
        )

    return {
        "preregistration_path": str(prereg_path),
        "lineage_path": str(artifact_dir / "lineage.json"),
        "lineage": lineage,
        "already_present": False,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", nargs=2, metavar=("PREREG_JSON", "SPEC"),
                        help="check that SPEC still matches the frozen record")
    args = parser.parse_args(argv)
    if args.check:
        record = json.loads(Path(args.check[0]).read_text(encoding="utf-8"))
        unchanged = check_unchanged(record, args.check[1])
        print(json.dumps({"unchanged": unchanged}, indent=2))
        return 0 if unchanged else 5
    parser.print_help()
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
