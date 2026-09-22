"""Validate dated, source-bound futures prop-firm research profiles.

The profile format is deliberately research-only.  It refuses a deployable
profile while any operational requirement is unresolved and verifies the
immutable hashes of the source comparison used to construct the profile.
It does not connect to a provider, submit orders, or decide payout eligibility.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import date
from pathlib import Path
from urllib.parse import urlparse


SCHEMA = "qm.futures-prop-research-profile.v1"
REQUIRED_PHASES = ("evaluation", "sim_funded", "payout", "live_transition")
REQUIRED_COVERAGE = (
    "news",
    "inactivity",
    "consistency",
    "reset",
    "day_count",
    "scalping",
    "ownership",
    "hosting",
)
CONSTRAINT_STATUSES = {
    "KNOWN",
    "UNKNOWN",
    "CONDITIONAL",
    "NOT_APPLICABLE",
    "NONE_PUBLISHED",
    "DERIVED",
}
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_json(path: Path) -> dict:
    def no_duplicates(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError(f"Duplicate JSON key: {key}")
            result[key] = value
        return result

    value = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=no_duplicates)
    if not isinstance(value, dict):
        raise ValueError("Profile root must be an object")
    return value


def _check_constraint(node, path: str, sources: dict, errors: list[str]) -> None:
    if not isinstance(node, dict):
        errors.append(f"{path}: constraint must be an object")
        return
    missing = {"status", "value", "source_ids"} - set(node)
    if missing:
        errors.append(f"{path}: missing constraint fields {sorted(missing)}")
        return
    status = node["status"]
    if status not in CONSTRAINT_STATUSES:
        errors.append(f"{path}: unsupported status {status!r}")
    if status == "UNKNOWN" and node["value"] != "UNKNOWN":
        errors.append(f"{path}: UNKNOWN must be preserved as the literal string UNKNOWN")
    if status != "UNKNOWN" and node["value"] == "UNKNOWN":
        errors.append(f"{path}: literal UNKNOWN requires status UNKNOWN")
    if status != "UNKNOWN" and node["value"] is None:
        errors.append(f"{path}: non-UNKNOWN constraint cannot have a null value")
    source_ids = node["source_ids"]
    if not isinstance(source_ids, list) or not source_ids:
        errors.append(f"{path}: source_ids must be a non-empty list")
    else:
        if any(not isinstance(source_id, str) for source_id in source_ids):
            errors.append(f"{path}: every source id must be a string")
            return
        missing_sources = sorted({source_id for source_id in source_ids if source_id not in sources})
        if missing_sources:
            errors.append(f"{path}: unknown source ids {missing_sources}")


def validate_profile(profile: dict, expected_task_id: str | None = None) -> list[str]:
    errors: list[str] = []
    if profile.get("schema") != SCHEMA:
        errors.append(f"schema must equal {SCHEMA}")
    if expected_task_id and profile.get("created_for_task") != expected_task_id:
        errors.append("created_for_task does not match the requested task")
    try:
        as_of = date.fromisoformat(profile.get("as_of", ""))
    except (TypeError, ValueError):
        errors.append("as_of must be an ISO date")
        as_of = None

    snapshot = profile.get("source_snapshot")
    if not isinstance(snapshot, dict):
        errors.append("source_snapshot must be an object")
    else:
        for key in ("json", "markdown"):
            item = snapshot.get(key)
            if not isinstance(item, dict):
                errors.append(f"source_snapshot.{key} must be an object")
                continue
            digest = str(item.get("sha256", "")).lower()
            if not SHA256_RE.fullmatch(digest):
                errors.append(f"source_snapshot.{key}.sha256 is not a SHA-256")
            if not item.get("path"):
                errors.append(f"source_snapshot.{key}.path is required")

    sources = profile.get("sources")
    if not isinstance(sources, dict) or not sources:
        errors.append("sources must be a non-empty object")
        sources = {}
    else:
        for source_id, source in sources.items():
            path = f"sources.{source_id}"
            if not isinstance(source, dict):
                errors.append(f"{path}: source must be an object")
                continue
            if source.get("official") is not True:
                errors.append(f"{path}: only official sources are admissible")
            parsed = urlparse(str(source.get("url", "")))
            if parsed.scheme != "https" or not parsed.netloc:
                errors.append(f"{path}: source URL must be HTTPS")
            try:
                observed = date.fromisoformat(source.get("observed_date", ""))
                if as_of and observed > as_of:
                    errors.append(f"{path}: observed_date is later than profile as_of")
            except (TypeError, ValueError):
                errors.append(f"{path}: observed_date must be an ISO date")

    coverage = profile.get("coverage")
    if not isinstance(coverage, dict):
        errors.append("coverage must be an object")
    else:
        missing = sorted(set(REQUIRED_COVERAGE) - set(coverage))
        if missing:
            errors.append(f"coverage is missing {missing}")
        for name, node in coverage.items():
            _check_constraint(node, f"coverage.{name}", sources, errors)

    if tuple(profile.get("phase_order", ())) != REQUIRED_PHASES:
        errors.append(f"phase_order must be {list(REQUIRED_PHASES)}")
    phases = profile.get("phases")
    if not isinstance(phases, dict):
        errors.append("phases must be an object")
    else:
        if set(phases) != set(REQUIRED_PHASES):
            errors.append(f"phases must contain exactly {list(REQUIRED_PHASES)}")
        for phase_name, phase in phases.items():
            if not isinstance(phase, dict):
                errors.append(f"phases.{phase_name}: phase must be an object")
                continue
            for section_name in ("rules", "costs"):
                section = phase.get(section_name)
                if not isinstance(section, dict) or not section:
                    errors.append(f"phases.{phase_name}.{section_name}: non-empty object required")
                    continue
                for name, node in section.items():
                    _check_constraint(
                        node,
                        f"phases.{phase_name}.{section_name}.{name}",
                        sources,
                        errors,
                    )

    unresolved = profile.get("unresolved_operational_requirements")
    unresolved_ids: list[str] = []
    if not isinstance(unresolved, list) or not unresolved:
        errors.append("unresolved_operational_requirements must be a non-empty list")
    else:
        for index, item in enumerate(unresolved):
            path = f"unresolved_operational_requirements[{index}]"
            if not isinstance(item, dict):
                errors.append(f"{path}: requirement must be an object")
                continue
            requirement_id = item.get("id")
            if not isinstance(requirement_id, str) or not requirement_id:
                errors.append(f"{path}: id is required")
            else:
                unresolved_ids.append(requirement_id)
            if item.get("blocks_deployment") is not True:
                errors.append(f"{path}: unresolved requirement must block deployment")
            if not item.get("detail"):
                errors.append(f"{path}: detail is required")
            source_ids = item.get("source_ids")
            if not isinstance(source_ids, list) or not source_ids:
                errors.append(f"{path}: source_ids must be non-empty")
            elif any(source_id not in sources for source_id in source_ids):
                errors.append(f"{path}: source_ids contain an unknown source")
        if len(unresolved_ids) != len(set(unresolved_ids)):
            errors.append("unresolved requirement ids must be unique")

    deployment = profile.get("deployment")
    if not isinstance(deployment, dict):
        errors.append("deployment must be an object")
    else:
        if deployment.get("deployable") is not False:
            errors.append("research profile must remain deployable=false")
        if deployment.get("status") != "NONDEPLOYABLE_RESEARCH_ONLY":
            errors.append("deployment.status must be NONDEPLOYABLE_RESEARCH_ONLY")
        if sorted(deployment.get("blocked_by", [])) != sorted(unresolved_ids):
            errors.append("deployment.blocked_by must enumerate every unresolved requirement")
    return errors


def validate_source_hashes(profile: dict, source_json: Path, source_markdown: Path) -> list[str]:
    errors = []
    supplied = {
        "json": sha256_file(source_json),
        "markdown": sha256_file(source_markdown),
    }
    for key, actual in supplied.items():
        expected = str(profile["source_snapshot"][key]["sha256"]).lower()
        if actual != expected:
            errors.append(f"source_snapshot.{key}: expected {expected}, found {actual}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", type=Path, action="append", required=True)
    parser.add_argument("--source-json", type=Path, required=True)
    parser.add_argument("--source-markdown", type=Path, required=True)
    parser.add_argument("--task-id")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    source_hashes = {
        "json": sha256_file(args.source_json),
        "markdown": sha256_file(args.source_markdown),
    }
    results = []
    all_valid = True
    for profile_path in args.profile:
        try:
            profile = load_json(profile_path)
            errors = validate_profile(profile, args.task_id)
            if not errors:
                errors.extend(validate_source_hashes(profile, args.source_json, args.source_markdown))
            profile_id = profile.get("profile_id", "UNKNOWN")
            deployable = profile.get("deployment", {}).get("deployable")
        except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
            profile_id = "UNREADABLE"
            deployable = None
            errors = [str(exc)]
        all_valid = all_valid and not errors
        results.append(
            {
                "path": str(profile_path.resolve()),
                "sha256": sha256_file(profile_path) if profile_path.is_file() else None,
                "profile_id": profile_id,
                "deployable": deployable,
                "validation": "PASS" if not errors else "FAIL",
                "errors": errors,
            }
        )

    receipt = {
        "schema": "qm.futures-prop-profile-validation.v1",
        "status": "PASS" if all_valid else "FAIL",
        "source_files": {
            "json": {"path": str(args.source_json.resolve()), "sha256": source_hashes["json"]},
            "markdown": {"path": str(args.source_markdown.resolve()), "sha256": source_hashes["markdown"]},
        },
        "profiles": results,
        "safety": "Research validation only; no provider login, purchase, live connection or order action.",
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"{receipt['status']} {len(results)} profile(s)")
    return 0 if all_valid else 1


if __name__ == "__main__":
    raise SystemExit(main())
