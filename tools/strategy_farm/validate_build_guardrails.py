"""Deterministic EA build guardrails.

These checks catch policy violations that are easy for generated/reworked EAs
to introduce before the artifact reaches Q-only pipeline execution.
"""

from __future__ import annotations

import argparse
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_MAX_NEWS_STALE_HOURS = 336
NEWS_STALE_RE = re.compile(
    r"\b(?:input\s+)?int\s+qm_news_stale_max_hours\s*=\s*([0-9]+)\b",
    re.IGNORECASE,
)
SET_KEY_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*([^;\r\n#]+)")


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _parse_number(raw: str) -> float | None:
    try:
        return float(str(raw).strip())
    except ValueError:
        return None


def _parse_setfile(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
        match = SET_KEY_RE.match(line)
        if match:
            values[match.group(1)] = match.group(2).strip()
    return values


def _is_backtest_setfile(path: Path, values: dict[str, str]) -> bool:
    lower_name = path.name.lower()
    if "_backtest.set" in lower_name:
        return True
    env = values.get("ENV") or values.get("Env") or values.get("env")
    return str(env).strip().lower() == "backtest"


def _scan_mq5(path: Path, max_news_stale_hours: int) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    text = path.read_text(encoding="utf-8", errors="ignore")
    for match in NEWS_STALE_RE.finditer(text):
        hours = int(match.group(1))
        if hours > max_news_stale_hours:
            findings.append(
                {
                    "path": str(path),
                    "kind": "news_stale_max_hours_too_high",
                    "value": hours,
                    "max_allowed": max_news_stale_hours,
                }
            )
    return findings


def _scan_setfile(path: Path, max_news_stale_hours: int) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    values = _parse_setfile(path)
    if _is_backtest_setfile(path, values):
        risk_fixed = _parse_number(values.get("RISK_FIXED", ""))
        risk_percent = _parse_number(values.get("RISK_PERCENT", ""))
        if risk_fixed is None or risk_fixed <= 0:
            findings.append(
                {
                    "path": str(path),
                    "kind": "backtest_risk_fixed_invalid",
                    "value": values.get("RISK_FIXED"),
                    "required": "> 0",
                }
            )
        if risk_percent is None or risk_percent != 0:
            findings.append(
                {
                    "path": str(path),
                    "kind": "backtest_risk_percent_invalid",
                    "value": values.get("RISK_PERCENT"),
                    "required": "0",
                }
            )
    stale_raw = values.get("qm_news_stale_max_hours")
    stale_hours = _parse_number(stale_raw) if stale_raw is not None else None
    if stale_hours is not None and stale_hours > max_news_stale_hours:
        findings.append(
            {
                "path": str(path),
                "kind": "setfile_news_stale_max_hours_too_high",
                "value": stale_hours,
                "max_allowed": max_news_stale_hours,
            }
        )
    return findings


def iter_candidate_files(path: Path) -> list[Path]:
    if path.is_file():
        return [path]
    if not path.exists():
        return []
    return sorted(
        candidate
        for candidate in path.rglob("*")
        if candidate.is_file() and candidate.suffix.lower() in {".mq5", ".set"}
    )


def validate_path(path: Path, max_news_stale_hours: int = DEFAULT_MAX_NEWS_STALE_HOURS) -> dict[str, Any]:
    findings: list[dict[str, Any]] = []
    files = iter_candidate_files(path)
    for candidate in files:
        suffix = candidate.suffix.lower()
        if suffix == ".mq5":
            findings.extend(_scan_mq5(candidate, max_news_stale_hours))
        elif suffix == ".set":
            findings.extend(_scan_setfile(candidate, max_news_stale_hours))
    return {
        "checked_at": utc_now(),
        "path": str(path),
        "files_checked": len(files),
        "max_news_stale_hours": max_news_stale_hours,
        "verdict": "PASS" if not findings else "FAIL",
        "findings": findings,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Validate EA build guardrails.")
    parser.add_argument("paths", nargs="+")
    parser.add_argument("--max-news-stale-hours", type=int, default=DEFAULT_MAX_NEWS_STALE_HOURS)
    args = parser.parse_args(argv)
    results = [validate_path(Path(p), args.max_news_stale_hours) for p in args.paths]
    payload = {
        "checked_at": utc_now(),
        "verdict": "PASS" if all(item["verdict"] == "PASS" for item in results) else "FAIL",
        "results": results,
    }
    print(json.dumps(payload, indent=2, sort_keys=True))
    return 0 if payload["verdict"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
