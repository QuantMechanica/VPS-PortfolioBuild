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
INPUT_RE = re.compile(
    r"^\s*input\s+(?:[A-Za-z_][\w:<>,\s\*&]*)\s+"
    r"(?P<name>[A-Za-z_]\w*)\s*=\s*(?P<default>[^;]+);",
    re.MULTILINE,
)
TIME_PARAM_TOKENS = (
    "hour",
    "hhmm",
    "minute",
    "session",
    "friday",
    "time",
)
TIME_PARAM_PHRASES = (
    "range_start",
    "range_end",
    "entry_start",
    "entry_end",
)
TACTICAL_KEYWORDS = (
    "asian",
    "balke",
    "big-ben",
    "break",
    "breakout",
    "eod",
    "london",
    "open",
    "overnight",
    "range",
    "session",
    "time",
)


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


def _is_live_setfile(path: Path, text: str, values: dict[str, str]) -> bool:
    lower_name = path.name.lower()
    if "_live.set" in lower_name:
        return True
    env = values.get("ENV") or values.get("Env") or values.get("env")
    if str(env).strip().lower() == "live":
        return True
    return re.search(r"^\s*;\s*environment:\s*live\b", text, re.IGNORECASE | re.MULTILINE) is not None


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


def _strategy_inputs(mq5_path: Path) -> set[str]:
    text = mq5_path.read_text(encoding="utf-8", errors="ignore")
    return {match.group("name") for match in INPUT_RE.finditer(text) if match.group("name").startswith("strategy_")}


def _time_strategy_inputs(strategy_inputs: set[str]) -> set[str]:
    result: set[str] = set()
    for name in strategy_inputs:
        lower = name.lower()
        words = set(re.findall(r"[a-z0-9]+", lower))
        if any(token in words for token in TIME_PARAM_TOKENS) or any(
            phrase in lower for phrase in TIME_PARAM_PHRASES
        ):
            result.add(name)
    return result


def _is_tactical_ea(ea_dir: Path, mq5_path: Path) -> bool:
    chunks = [ea_dir.name, mq5_path.read_text(encoding="utf-8", errors="ignore")[:12000]]
    for rel in ("SPEC.md", "strategy_card.md", "docs/strategy_card.md"):
        candidate = ea_dir / rel
        if candidate.exists():
            chunks.append(candidate.read_text(encoding="utf-8", errors="ignore"))
    haystack = "\n".join(chunks).lower()
    return any(re.search(rf"\b{re.escape(keyword)}\b", haystack) for keyword in TACTICAL_KEYWORDS)


def _scan_setfile(path: Path, max_news_stale_hours: int) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    text = path.read_text(encoding="utf-8", errors="ignore")
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
    if _is_live_setfile(path, text, values):
        strategy_keys = sorted(key for key in values if key.startswith("strategy_"))
        if not strategy_keys:
            findings.append(
                {
                    "path": str(path),
                    "kind": "live_strategy_params_missing",
                    "detail": "Live setfile must include explicit strategy_* params before deployment.",
                }
            )
        if "card_defaults_source=not_found" in text:
            findings.append(
                {
                    "path": str(path),
                    "kind": "live_card_defaults_source_not_found",
                    "detail": "Live setfile was generated without card/default extraction evidence.",
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


def _scan_strategy_conformance(path: Path) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    ea_dirs: list[tuple[Path, list[Path] | None]]
    if path.is_file():
        if path.suffix.lower() == ".set" and path.parent.name == "sets":
            ea_dirs = [(path.parent.parent, [path])]
        else:
            ea_dirs = [(path.parent, None)]
    elif (path / "sets").exists():
        ea_dirs = [(path, None)]
    else:
        ea_dirs = [(candidate, None) for candidate in path.rglob("*") if candidate.is_dir() and (candidate / "sets").exists()]

    for ea_dir, selected_setfiles in ea_dirs:
        mq5s = sorted(ea_dir.glob("*.mq5"))
        if not mq5s:
            continue
        mq5_path = mq5s[0]
        strategy_inputs = _strategy_inputs(mq5_path)
        time_inputs = _time_strategy_inputs(strategy_inputs)
        if not time_inputs or not _is_tactical_ea(ea_dir, mq5_path):
            continue
        setfiles = selected_setfiles if selected_setfiles is not None else sorted((ea_dir / "sets").glob("*.set"))
        for setfile in setfiles:
            values = _parse_setfile(setfile)
            if not _is_backtest_setfile(setfile, values):
                continue
            present_time_inputs = sorted(time_inputs & set(values))
            if present_time_inputs:
                continue
            findings.append(
                {
                    "path": str(setfile),
                    "kind": "time_sensitive_strategy_params_missing",
                    "required_any": sorted(time_inputs),
                    "detail": (
                        "Tactical/session/range EA has time-sensitive strategy inputs, "
                        "but this backtest setfile leaves all of them at EA defaults."
                    ),
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
    findings.extend(_scan_strategy_conformance(path))
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
