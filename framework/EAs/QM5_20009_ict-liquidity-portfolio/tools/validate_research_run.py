"""Fail-closed phase and evidence fence for QM5_20009 research runs.

Invoke immediately before a tester launch.  If ``--receipt`` is supplied, invoke
the same command after the run with ``--postflight-receipt`` to prove that mutable
news and Model-4 data files did not change while the EA was running.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import date, datetime
from pathlib import Path
from typing import Any, Mapping

import generate_research_sets as freeze


class FenceError(RuntimeError):
    pass


def _market(protocol: Mapping[str, Any], symbol: str) -> Mapping[str, Any]:
    matches = [row for row in protocol["markets"] if row["symbol"] == symbol]
    if len(matches) != 1:
        raise FenceError(f"symbol is not uniquely registered: {symbol}")
    return matches[0]


def _phase(protocol: Mapping[str, Any], phase_id: str) -> Mapping[str, Any]:
    matches = [row for row in protocol["phases"] if row["id"] == phase_id]
    if len(matches) != 1:
        raise FenceError(f"unknown or duplicate phase: {phase_id}")
    return matches[0]


def phase_window(
    protocol: Mapping[str, Any], phase_id: str, symbol: str
) -> tuple[str, str]:
    phase = _phase(protocol, phase_id)
    if phase.get("window") == "PER_MARKET_DEV":
        market = _market(protocol, symbol)
        return str(market["dev_from"]), str(market["dev_to"])
    return str(phase["from"]), str(phase["to"])


def validate_request(
    protocol: Mapping[str, Any],
    *,
    phase_id: str,
    symbol: str,
    timeframe: str,
    variant: str,
    from_date: str,
    to_date: str,
) -> None:
    market = _market(protocol, symbol)
    phase = _phase(protocol, phase_id)
    if "allowed_symbols" in phase and symbol not in phase["allowed_symbols"]:
        raise FenceError(f"symbol {symbol} is not allowed in phase {phase_id}")
    if timeframe != market["timeframe"]:
        raise FenceError(f"timeframe mismatch: {timeframe} != {market['timeframe']}")
    expected_from, expected_to = phase_window(protocol, phase_id, symbol)
    if (from_date, to_date) != (expected_from, expected_to):
        raise FenceError(
            f"partition mismatch: {from_date}..{to_date} != {expected_from}..{expected_to}"
        )
    try:
        start = date.fromisoformat(from_date)
        end = date.fromisoformat(to_date)
    except ValueError as exc:
        raise FenceError("run dates must be ISO YYYY-MM-DD") from exc
    if start > end:
        raise FenceError("run start is after run end")
    if phase.get("execution_kind") == "FORWARD_ONLY_NOT_RETROSPECTIVE_BACKTEST":
        raise FenceError("FORWARD_ONLY_PHASE_NOT_VALID_FOR_TESTER_RUN")
    known_variants = {name for name, _parameter, _value in freeze.variants(market["kind"])}
    if variant not in known_variants:
        raise FenceError(f"variant not in preregistered star: {variant}")
    if start >= date(2023, 1, 1) and variant != "center":
        raise FenceError("OAAT_NEIGHBOUR_FORBIDDEN_AT_OR_AFTER_2023")
    if phase["allowed_variants"] == "CENTER_ONLY" and variant != "center":
        raise FenceError(f"phase {phase_id} is center-only")
    if phase["allowed_variants"] == "ALL_13" and phase_id != "DEV":
        raise FenceError("only DEV may allow the OAAT star")
    if phase.get("requires_resolved_cost_axes"):
        unresolved = [
            axis
            for axis in protocol["qualification_blocking_cost_axes"]
            if protocol["costs"][axis]["status"] != "RESOLVED"
        ]
        if unresolved:
            raise FenceError(f"phase blocked by unresolved cost axes: {','.join(unresolved)}")


def validate_phase_unlock(
    protocol: Mapping[str, Any],
    *,
    phase_id: str,
    freeze_inputs_sha256: str,
    manifest_sha256: str,
    verdict_root: Path | None = None,
) -> list[dict[str, str]]:
    """Verify every prior binding verdict required to unlock ``phase_id``.

    Verdicts are intentionally outside the immutable freeze because they are
    produced later.  Each one is nevertheless identity-bound to this protocol,
    freeze root and manifest, and protected by a detached SHA-256 file.  Missing,
    malformed, non-binding or cross-freeze records fail closed.
    """

    unlock = protocol.get("phase_unlock")
    if not isinstance(unlock, Mapping) or unlock.get("enforcement") != (
        "FAIL_CLOSED_DETACHED_VERDICT_RECORDS"
    ):
        raise FenceError("phase unlock enforcement is absent or disabled")
    prerequisites = unlock.get("required_prior_verdicts")
    if not isinstance(prerequisites, Mapping) or phase_id not in prerequisites:
        raise FenceError(f"phase unlock mapping missing for {phase_id}")
    prior_phases = prerequisites[phase_id]
    if not isinstance(prior_phases, list):
        raise FenceError(f"phase unlock prerequisites are invalid for {phase_id}")
    root = verdict_root or freeze._artifact_path(str(unlock["verdict_root"]))
    template = str(unlock["record_name_template"])
    suffix = str(unlock["detached_sha256_suffix"])
    required_fields = set(unlock["required_record_fields"])
    sha_re = re.compile(r"^[0-9a-f]{64}$")
    verified: list[dict[str, str]] = []
    for prior_phase in prior_phases:
        if prior_phase in set(unlock.get("nonbinding_phases", [])):
            raise FenceError(f"non-binding phase cannot unlock research: {prior_phase}")
        record_path = root / template.format(phase_id=prior_phase)
        detached_path = Path(f"{record_path}{suffix}")
        if not record_path.is_file() or not detached_path.is_file():
            raise FenceError(f"required prior verdict is missing: {prior_phase}")
        raw = record_path.read_bytes()
        actual_record_sha = hashlib.sha256(raw).hexdigest()
        detached_sha = detached_path.read_text(encoding="ascii").strip().lower()
        if not sha_re.fullmatch(detached_sha) or detached_sha != actual_record_sha:
            raise FenceError(f"prior verdict detached hash mismatch: {prior_phase}")
        try:
            record = json.loads(raw)
        except (UnicodeDecodeError, json.JSONDecodeError) as exc:
            raise FenceError(f"prior verdict JSON invalid: {prior_phase}") from exc
        missing = required_fields - set(record)
        if missing:
            raise FenceError(f"prior verdict fields missing for {prior_phase}: {sorted(missing)}")
        if (
            record.get("schema_version") != unlock["record_schema_version"]
            or record.get("protocol_id") != protocol["protocol_id"]
            or record.get("phase_id") != prior_phase
            or record.get("binding") is not True
            or record.get("verdict") != unlock["accepted_verdict"]
            or record.get("freeze_inputs_sha256") != freeze_inputs_sha256
            or record.get("manifest_sha256") != manifest_sha256
            or not sha_re.fullmatch(str(record.get("evidence_sha256", "")).lower())
        ):
            raise FenceError(f"prior verdict identity/status mismatch: {prior_phase}")
        try:
            completed = datetime.fromisoformat(str(record["completed_utc"]).replace("Z", "+00:00"))
        except ValueError as exc:
            raise FenceError(f"prior verdict completion timestamp invalid: {prior_phase}") from exc
        if completed.tzinfo is None:
            raise FenceError(f"prior verdict completion timestamp lacks timezone: {prior_phase}")
        verified.append({"phase_id": prior_phase, "record_sha256": actual_record_sha})
    return verified


def parse_set_metadata(path: Path) -> dict[str, str]:
    metadata: dict[str, str] = {}
    input_names: set[str] = set()
    for raw in path.read_text(encoding="ascii").splitlines():
        if raw.startswith("; ") and ": " in raw:
            key, value = raw[2:].split(": ", 1)
            metadata[key] = value
        elif raw and not raw.startswith(";") and "=" in raw:
            key = raw.split("=", 1)[0]
            if key in input_names:
                raise FenceError(f"duplicate input assignment in set: {key}")
            input_names.add(key)
    if input_names != set(freeze.visible_input_names()):
        raise FenceError("set does not contain the exact visible input closure")
    required = {"symbol", "timeframe", "variant", "freeze_inputs_sha256", "protocol_id"}
    if not required.issubset(metadata):
        raise FenceError(f"set header missing: {sorted(required - set(metadata))}")
    return metadata


def _selected_data_rows(
    protocol: Mapping[str, Any],
    manifest: Mapping[str, Any],
    symbol: str,
    from_date: str,
    to_date: str,
) -> list[Mapping[str, Any]]:
    start = date.fromisoformat(from_date)
    end = date.fromisoformat(to_date)
    required = {str(protocol["model4_data"]["symbol_definition_relative_path"])}
    for month in freeze._month_range(from_date, end.strftime("%Y%m")):
        required.add(f"Custom/ticks/{symbol}/{month}.tkc")
    for year in range(start.year, end.year + 1):
        required.add(f"Custom/history/{symbol}/{year}.hcc")
    rows = {
        str(row["relative_path"]): row
        for row in manifest["freeze_inputs"]["model4_data_files"]
    }
    missing = sorted(required - set(rows))
    if missing:
        raise FenceError(f"freeze manifest lacks selected data files: {','.join(missing[:8])}")
    return [rows[name] for name in sorted(required)]


def rehash_selected_data(
    protocol: Mapping[str, Any], rows: list[Mapping[str, Any]]
) -> list[dict[str, Any]]:
    root = freeze._artifact_path(str(protocol["model4_data"]["destination_root"]))
    actual_rows: list[dict[str, Any]] = []
    for expected in rows:
        relative = str(expected["relative_path"])
        path = root / Path(relative)
        if not path.is_file() or path.stat().st_size != int(expected["size"]):
            raise FenceError(f"selected Model-4 file missing/size drift: {path}")
        digest = freeze.sha256_file(path)
        if digest != expected["sha256"]:
            raise FenceError(f"selected Model-4 file hash drift: {path}")
        actual_rows.append({"relative_path": relative, "size": path.stat().st_size, "sha256": digest})
    return actual_rows


def preflight(
    *,
    phase_id: str,
    symbol: str,
    timeframe: str,
    set_file: Path,
    from_date: str,
    to_date: str,
) -> dict[str, Any]:
    try:
        issues = freeze.check()
    except freeze.FreezeError as exc:
        raise FenceError(str(exc)) from exc
    if issues:
        raise FenceError(f"freeze bundle drift: {issues[0]}")
    if set_file.resolve().parent != freeze.SETS_ROOT.resolve():
        raise FenceError("set file must come from the frozen sets directory")
    metadata = parse_set_metadata(set_file)
    protocol = freeze.load_protocol()
    if metadata["symbol"] != symbol or metadata["timeframe"] != timeframe:
        raise FenceError("CLI symbol/timeframe does not match frozen set header")
    manifest_path = freeze.SETS_ROOT / "manifest.json"
    manifest_bytes = manifest_path.read_bytes()
    manifest = json.loads(manifest_bytes)
    manifest_sha256 = hashlib.sha256(manifest_bytes).hexdigest()
    validate_request(
        protocol,
        phase_id=phase_id,
        symbol=symbol,
        timeframe=timeframe,
        variant=metadata["variant"],
        from_date=from_date,
        to_date=to_date,
    )
    if metadata["freeze_inputs_sha256"] != manifest["freeze_inputs_sha256"]:
        raise FenceError("set freeze root differs from manifest")
    unlock_records = validate_phase_unlock(
        protocol,
        phase_id=phase_id,
        freeze_inputs_sha256=str(manifest["freeze_inputs_sha256"]),
        manifest_sha256=manifest_sha256,
    )
    set_digest = freeze.sha256_file(set_file)
    matching = [row for row in manifest["sets"] if row["file"] == set_file.name]
    if len(matching) != 1 or matching[0]["set_sha256"] != set_digest:
        raise FenceError("selected set is not uniquely hash-bound in manifest")
    selected = _selected_data_rows(protocol, manifest, symbol, from_date, to_date)
    actual_data = rehash_selected_data(protocol, selected)
    return {
        "schema_version": 1,
        "request": {
            "phase": phase_id,
            "symbol": symbol,
            "timeframe": timeframe,
            "variant": metadata["variant"],
            "from": from_date,
            "to": to_date,
        },
        "freeze_inputs_sha256": manifest["freeze_inputs_sha256"],
        "manifest_sha256": manifest_sha256,
        "set_sha256": set_digest,
        "selected_data_sha256": freeze.sha256_bytes(freeze.canonical_json_bytes(actual_data)),
        "phase_unlock_records": unlock_records,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", required=True)
    parser.add_argument("--symbol", required=True)
    parser.add_argument("--timeframe", required=True)
    parser.add_argument("--set-file", required=True, type=Path)
    parser.add_argument("--from", dest="from_date", required=True)
    parser.add_argument("--to", dest="to_date", required=True)
    receipts = parser.add_mutually_exclusive_group()
    receipts.add_argument("--receipt", type=Path)
    receipts.add_argument("--postflight-receipt", type=Path)
    args = parser.parse_args(argv)
    try:
        result = preflight(
            phase_id=args.phase,
            symbol=args.symbol,
            timeframe=args.timeframe,
            set_file=args.set_file,
            from_date=args.from_date,
            to_date=args.to_date,
        )
        if args.postflight_receipt:
            previous = json.loads(args.postflight_receipt.read_text(encoding="utf-8"))
            if previous != result:
                raise FenceError("postflight evidence differs from preflight receipt")
        elif args.receipt:
            args.receipt.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    except (FenceError, OSError, json.JSONDecodeError) as exc:
        print(f"REJECT: {exc}")
        return 2
    print(json.dumps({"status": "PASS", **result}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
