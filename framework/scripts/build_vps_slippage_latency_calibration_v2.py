#!/usr/bin/env python3
"""Build VPS slippage/latency calibration V2 JSON from measured evidence."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


PHASE = "P5"
CRITERION = "vps_calibration_json_v2"


def _require(payload: dict[str, Any], key: str) -> Any:
    if key not in payload:
        raise ValueError(f"missing required key: {key}")
    return payload[key]


def build_calibration(measured: dict[str, Any], evidence_rel_path: str) -> dict[str, Any]:
    sampling = _require(measured, "sampling")
    metrics = _require(measured, "metrics")
    symbol_key = _require(measured, "symbol_key")

    return {
        "measurement_status": _require(measured, "measurement_status"),
        "notes": (
            "Measured on T1 Darwinex-Live. Slippage reflects quote-drift proxy "
            "until live-fill sample policy is approved."
        ),
        "measurement": {
            "terminal": _require(measured, "source_terminal"),
            "broker_server": _require(measured, "broker_server"),
            "symbol_source": _require(measured, "symbol_source"),
            "measured_at_server_time": _require(measured, "measured_at_server_time"),
            "method": _require(measured, "measurement_method"),
            "samples": _require(sampling, "samples"),
            "ping_samples_used": _require(sampling, "ping_samples_used"),
            "spread_samples_used": _require(sampling, "spread_samples_used"),
            "slippage_proxy_samples_used": _require(sampling, "slippage_proxy_samples_used"),
            "raw_evidence_file": evidence_rel_path,
        },
        "symbols": {
            symbol_key: {
                "commission_cents_per_lot": _require(metrics, "commission_cents_per_lot"),
                "latency_ms": _require(metrics, "latency_ms"),
                "slippage_points": _require(metrics, "slippage_points"),
                "spread_points": _require(metrics, "spread_points"),
            }
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ea", default="CALIBRATION", help="ea id for structured log")
    parser.add_argument("--input-json", required=True, help="measured evidence json path")
    parser.add_argument("--output-json", required=True, help="calibration output json path")
    parser.add_argument(
        "--log-jsonl",
        help="optional jsonl log path; defaults to <output dir>/phase_runner_log.jsonl",
    )
    args = parser.parse_args()

    input_path = Path(args.input_json)
    output_path = Path(args.output_json)
    log_path = Path(args.log_jsonl) if args.log_jsonl else output_path.parent / "phase_runner_log.jsonl"

    measured = json.loads(input_path.read_text(encoding="utf-8"))
    evidence_rel = input_path.as_posix()
    calibration = build_calibration(measured, evidence_rel)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json.dumps(calibration, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    log_record = {
        "phase": PHASE,
        "ea_id": args.ea,
        "verdict": "PASS",
        "criterion": CRITERION,
        "evidence_path": output_path.as_posix(),
        "input_evidence_path": input_path.as_posix(),
    }
    log_path.parent.mkdir(parents=True, exist_ok=True)
    with log_path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(log_record, sort_keys=True) + "\n")

    print(json.dumps(log_record, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
