#!/usr/bin/env python3
"""Build cross-EA scheduler queue from approved and transition-ready sources."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

DEFAULT_SOURCE = Path(r"D:\QM\Reports\pipeline\multi_ea_queue_source.json")
DEFAULT_QUEUE = Path(r"D:\QM\Reports\pipeline\multi_ea_job_queue.json")

REQUIRED_FIELDS = ("ea_id", "phase", "symbol", "config_hash")


def _require_non_empty_string(value: Any, field_name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{field_name} must be non-empty string")
    return value.strip()


def normalize_job(raw: dict[str, Any], *, source_name: str) -> dict[str, str]:
    if not isinstance(raw, dict):
        raise ValueError(f"{source_name} item must be object")
    job: dict[str, str] = {}
    for field in REQUIRED_FIELDS:
        job[field] = _require_non_empty_string(raw.get(field), f"{source_name}.{field}")
    if not job["symbol"].endswith(".DWX"):
        raise ValueError(f"{source_name}.symbol must end with .DWX")
    return job


def load_source(path: Path) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    with path.open("r", encoding="utf-8-sig") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise ValueError("source payload must be object")
    approved = payload.get("approved_waiting_p0", [])
    transitions = payload.get("transition_ready", [])
    if not isinstance(approved, list) or not isinstance(transitions, list):
        raise ValueError("approved_waiting_p0 and transition_ready must be arrays")
    p0_jobs = [normalize_job(item, source_name="approved_waiting_p0") for item in approved]
    transition_jobs = [normalize_job(item, source_name="transition_ready") for item in transitions]
    return p0_jobs, transition_jobs


def build_queue(approved: list[dict[str, str]], transition_ready: list[dict[str, str]]) -> list[dict[str, str]]:
    # Priority policy: transition-ready work first, then new P0 work.
    combined = transition_ready + approved
    dedup: set[tuple[str, str, str, str]] = set()
    queue: list[dict[str, str]] = []
    for job in combined:
        key = (job["ea_id"], job["phase"], job["symbol"], job["config_hash"])
        if key in dedup:
            continue
        dedup.add(key)
        queue.append(job)
    return queue


def save_queue(path: Path, queue: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(queue, handle, indent=2, sort_keys=True)
        handle.write("\n")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Build multi-EA queue from source payload")
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--out", type=Path, default=DEFAULT_QUEUE)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    approved, transition_ready = load_source(args.source)
    queue = build_queue(approved, transition_ready)
    save_queue(args.out, queue)
    print(json.dumps({"queue_size": len(queue), "out": str(args.out)}, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
