"""Resolve the latest summary-linked, schema-v1 smoke logger sample."""

from __future__ import annotations

import argparse
import datetime as dt
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence


@dataclass(frozen=True)
class LoggerSample:
    timestamp_utc: dt.datetime
    summary_path: Path
    sample_path: Path


QM_REQUIRED_FIELDS = frozenset(
    {
        "sv",
        "ts_utc",
        "ts_broker",
        "level",
        "ea_id",
        "slug",
        "symbol",
        "tf",
        "magic",
        "event",
        "payload",
    }
)


def _parse_timestamp(value: object) -> dt.datetime | None:
    try:
        parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    except (TypeError, ValueError):
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=dt.UTC)
    return parsed.astimezone(dt.UTC)


def is_valid_logger_sample(path: Path) -> bool:
    if not path.is_file() or path.stat().st_size <= 0:
        return False
    rows = 0
    try:
        with path.open(encoding="utf-8") as handle:
            for line in handle:
                if not line.strip():
                    continue
                row = json.loads(line)
                if not isinstance(row, dict) or not QM_REQUIRED_FIELDS.issubset(row):
                    return False
                if row.get("sv") != 1 or not isinstance(row.get("event"), str):
                    return False
                rows += 1
    except (OSError, UnicodeError, json.JSONDecodeError):
        return False
    return rows > 0


def _linked_sample(summary_path: Path) -> LoggerSample | None:
    try:
        summary = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return None
    timestamp = _parse_timestamp(summary.get("timestamp_utc"))
    raw_path = summary.get("logger_sample_path")
    if timestamp is None or not isinstance(raw_path, str) or not raw_path.strip():
        return None
    sample = Path(raw_path)
    if not sample.is_absolute():
        sample = summary_path.parent / sample
    try:
        sample = sample.resolve(strict=True)
        report_dir = summary_path.parent.resolve(strict=True)
        sample.relative_to(report_dir)
    except (OSError, ValueError):
        return None
    if sample.name != "logger_sample.jsonl" or not is_valid_logger_sample(sample):
        return None
    return LoggerSample(timestamp, summary_path.resolve(), sample)


def resolve_latest_logger_sample(report_root: Path) -> LoggerSample | None:
    if not report_root.is_dir():
        return None
    candidates = [
        candidate
        for summary in sorted(report_root.rglob("summary.json"), key=lambda path: path.as_posix())
        if (candidate := _linked_sample(summary)) is not None
    ]
    if not candidates:
        return None
    return max(
        candidates,
        key=lambda item: (item.timestamp_utc, item.summary_path.as_posix().casefold()),
    )


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report-root", type=Path, default=Path("D:/QM/reports/smoke"))
    parser.add_argument("--json", action="store_true", dest="as_json")
    parser.add_argument("--require", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    candidate = resolve_latest_logger_sample(args.report_root)
    if candidate is None:
        if args.as_json:
            print(json.dumps({"status": "NOT_FOUND", "logger_sample_path": None}, sort_keys=True))
        return 1 if args.require else 0
    if args.as_json:
        print(
            json.dumps(
                {
                    "status": "FOUND",
                    "timestamp_utc": candidate.timestamp_utc.isoformat(),
                    "summary_path": str(candidate.summary_path),
                    "logger_sample_path": str(candidate.sample_path),
                },
                sort_keys=True,
            )
        )
    else:
        print(candidate.sample_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
