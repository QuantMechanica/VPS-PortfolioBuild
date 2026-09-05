"""Shared, hash-pinned research cost reader. It grants no governed adoption."""
from __future__ import annotations

import hashlib
import json
import math
import re
from pathlib import Path

SCHEMA = "qm.ftmo-cost-version/v1"
SYMBOLS = {"EURUSD", "GBPUSD", "USDCAD", "NZDUSD", "XAGUSD", "XTIUSD"}
FIELDS = {"commission", "swap_long", "swap_short", "triple_rollover_weekday",
          "contract_size", "tick_size", "tick_value", "swing_margin_percent",
          "lot_min", "lot_step", "fill_slippage", "session_spread"}
PROVENANCE = {"measured", "provider-provisional", "unknown"}


class CostVersionError(ValueError):
    pass


def _pairs(pairs):
    out = {}
    for k, v in pairs:
        if k in out:
            raise CostVersionError(f"duplicate key: {k}")
        out[k] = v
    return out


def _nonfinite(value):
    raise CostVersionError(f"non-finite JSON: {value}")


def load(path: Path, expected_sha256: str) -> dict:
    if not isinstance(expected_sha256, str) or not re.fullmatch("[a-f0-9]{64}", expected_sha256):
        raise CostVersionError("expected SHA-256 required")
    try:
        raw = Path(path).read_bytes()
        if hashlib.sha256(raw).hexdigest() != expected_sha256:
            raise CostVersionError("cost version hash mismatch")
        value = json.loads(raw.decode("utf-8-sig"), object_pairs_hook=_pairs, parse_constant=_nonfinite)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise CostVersionError(f"cost version unreadable: {exc}") from exc
    if not isinstance(value, dict) or value.get("schema") != SCHEMA:
        raise CostVersionError("unsupported cost version schema")
    if value.get("governed_adoption") is not False or value.get("status") != "REVIEW_RESEARCH_ONLY":
        raise CostVersionError("this reader accepts research-only versions; no adoption authority")
    rows = value.get("symbols")
    if not isinstance(rows, list) or len(rows) != 6 or {r.get("symbol") for r in rows if isinstance(r, dict)} != SYMBOLS:
        raise CostVersionError("six-symbol population incomplete or duplicated")
    for row in rows:
        fields = row.get("fields")
        if not isinstance(fields, dict) or set(fields) != FIELDS:
            raise CostVersionError("cost fields incomplete")
        for name, field in fields.items():
            if not isinstance(field, dict) or field.get("provenance") not in PROVENANCE or not field.get("unit") or not field.get("source"):
                raise CostVersionError(f"{name}: provenance, source and unit required")
            v = field.get("value")
            if field["provenance"] == "unknown" and v is not None:
                raise CostVersionError(f"{name}: unknown must stay null")
            if field["provenance"] != "unknown" and v is None:
                raise CostVersionError(f"{name}: observed/provisional value missing")
            if v is not None and name not in {"session_spread", "triple_rollover_weekday"} and (isinstance(v, bool) or not isinstance(v, (int, float))):
                raise CostVersionError(f"{name}: numeric value required")
            if isinstance(v, float) and not math.isfinite(v):
                raise CostVersionError(f"{name}: non-finite number")
    return value


def inspect(path: Path, expected_sha256: str, consumer: str) -> dict:
    value = load(path, expected_sha256)
    return {"schema": "qm.ftmo-cost-version-inspection/v1", "consumer": consumer,
            "cost_version_sha256": expected_sha256, "version_id": value["version_id"],
            "governed_adoption": False, "status": value["status"], "symbols": value["symbols"],
            "coverage": value["coverage"], "open_items": value["open_items"]}


def add_inspection_parser(subparsers):
    parser = subparsers.add_parser("inspect-cost-version", help="read a pinned research cost version; no execution or adoption")
    parser.add_argument("--cost-version", type=Path, required=True)
    parser.add_argument("--expected-sha256", required=True)


def emit_inspection(path, expected_sha256, consumer):
    try:
        print(json.dumps(inspect(path, expected_sha256, consumer), indent=2, sort_keys=True, allow_nan=False))
        return 0
    except CostVersionError as exc:
        print(json.dumps({"status": "REFUSED_COST_VERSION", "error": str(exc)}))
        return 2
