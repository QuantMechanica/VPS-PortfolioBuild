"""Deterministic EA build guardrails.

These checks catch policy violations that are easy for generated/reworked EAs
to introduce before the artifact reaches Q-only pipeline execution.
"""

from __future__ import annotations

import argparse
import csv
import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


DEFAULT_MAX_NEWS_STALE_HOURS = 336
DEFAULT_ENTRY_GRACE_MARGIN_MINUTES = 5.0
SESSION_OFFSET_REGISTRY_PATH = (
    Path(__file__).resolve().parents[2]
    / "framework"
    / "registry"
    / "session_offset_minutes.csv"
)
AUTHORITATIVE_SESSION_OFFSET_SOURCES = frozenset({"measured"})
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

CODE_COMMENT_OR_LITERAL_RE = re.compile(
    r'//[^\r\n]*|/\*.*?\*/|"(?:\\.|[^"\\])*"',
    re.DOTALL,
)
PERIOD_TOKEN_RE = re.compile(r"\bPERIOD_([A-Z0-9]+)\b")
ENTRY_GRACE_CARD_RES = (
    re.compile(
        r"\bstrategy_entry_grace_minutes\b`?\s*(?:[:=]|\|)\s*`?([0-9]+(?:\.[0-9]+)?)",
        re.IGNORECASE,
    ),
    re.compile(
        r"\b(?:entry|opening)[-_ ]grace\b[^0-9\r\n]{0,40}([0-9]+(?:\.[0-9]+)?)\s*(?:minutes?|mins?)\b",
        re.IGNORECASE,
    ),
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


def _strip_code_comments_and_literals(text: str) -> str:
    """Remove lexical decoys while preserving line/character positions."""

    return CODE_COMMENT_OR_LITERAL_RE.sub(
        lambda match: "".join("\n" if char == "\n" else " " for char in match.group(0)),
        text,
    )


def _is_entry_grace_name(name: str) -> bool:
    lower = str(name).strip().lower()
    return "entry" in lower and "grace" in lower and (
        "minute" in lower or lower.endswith("_min")
    )


def _entry_grace_input_defaults(mq5_text: str) -> dict[str, float | None]:
    defaults: dict[str, float | None] = {}
    for match in INPUT_RE.finditer(mq5_text):
        name = match.group("name")
        if not _is_entry_grace_name(name):
            continue
        defaults[name] = _parse_number(match.group("default"))
    return defaults


def _entry_grace_card_values(ea_dir: Path) -> list[tuple[str, float]]:
    values: list[tuple[str, float]] = []
    for rel in ("SPEC.md", "strategy_card.md", "docs/strategy_card.md"):
        candidate = ea_dir / rel
        if not candidate.is_file():
            continue
        text = candidate.read_text(encoding="utf-8", errors="ignore")
        for pattern in ENTRY_GRACE_CARD_RES:
            for match in pattern.finditer(text):
                value = _parse_number(match.group(1))
                if value is not None:
                    values.append((str(candidate), value))
    return values


def _operational_grace_windows(code: str, grace_names: set[str]) -> list[str]:
    """Return code windows where an entry-grace value drives a time test.

    Input declarations and locked-default validation (``==``/``!=``) are not
    entry-clock idioms. A real use must share a local code window with a clock,
    bar source, or an elapsed/delay variable.
    """

    windows: list[str] = []
    for name in grace_names:
        for match in re.finditer(rf"\b{re.escape(name)}\b", code):
            line_start = code.rfind("\n", 0, match.start()) + 1
            line_end = code.find("\n", match.end())
            if line_end < 0:
                line_end = len(code)
            line = code[line_start:line_end]
            if re.search(r"\binput\b", line):
                continue
            if ("!=" in line or "==" in line) and not any(op in line for op in ("<", ">")):
                continue
            start = max(0, match.start() - 700)
            end = min(len(code), match.end() + 700)
            window = code[start:end]
            if not re.search(r"\b(?:TimeCurrent|iTime|QM_ReadBar|elapsed|delay|bar_time)\b", window):
                continue
            if not re.search(r"(?:\*\s*60\b|60\s*\*|grace_seconds|grace_minutes)", window):
                continue
            windows.append(window)
    return windows


def _entry_grace_anchor_periods(mq5_text: str) -> set[str]:
    """Infer bar periods that feed an operational entry-grace clock.

    This is deliberately narrow data-flow, not a keyword census. It maps bar
    variables produced by ``iTime``/``QM_ReadBar``, follows simple assignments,
    and considers only variables reachable from a window where an entry-grace
    input is used as elapsed time. Clear intraday anchors therefore remain out
    of the D1-label gate even when the EA also reads D1 bars for indicators.
    """

    defaults = _entry_grace_input_defaults(mq5_text)
    if not defaults:
        return set()
    code = _strip_code_comments_and_literals(mq5_text)
    windows = _operational_grace_windows(code, set(defaults))
    if not windows:
        return set()

    variable_periods: dict[str, set[str]] = {}

    def bind(name: str, period: str) -> None:
        if name:
            variable_periods.setdefault(name, set()).add(period.upper())

    for match in re.finditer(
        r"\b([A-Za-z_]\w*)\s*=\s*iTime\s*\([^;]*?\bPERIOD_([A-Z0-9]+)\b[^;]*?\)\s*;",
        code,
        re.DOTALL,
    ):
        bind(match.group(1), match.group(2))
    for match in re.finditer(
        r"\bQM_ReadBar\s*\([^;]*?\bPERIOD_([A-Z0-9]+)\b[^;]*?,\s*([A-Za-z_]\w*)\s*\)\s*;",
        code,
        re.DOTALL,
    ):
        bind(match.group(2), match.group(1))

    # Names that explicitly carry a timeframe are useful for framework helpers
    # whose assignment happens behind QM_IsNewBar rather than at the call site.
    for name in set(re.findall(r"\b[A-Za-z_]\w*\b", code)):
        lower = name.lower()
        for period in ("d1", "h1", "m30", "m15", "m5", "m1"):
            if re.search(rf"(?:^|_){period}(?:_|$)", lower):
                bind(name, period.upper())

    dependencies: dict[str, set[str]] = {}
    assignment_re = re.compile(
        r"(?:^|[;{}])\s*(?:const\s+)?(?:datetime|long|int|double|MqlRates\s*)?"
        r"\b([A-Za-z_]\w*)\s*(?<![=!<>])=(?!=)\s*([^;]+);",
        re.MULTILINE,
    )
    for match in assignment_re.finditer(code):
        lhs = match.group(1)
        rhs_tokens = set(re.findall(r"\b[A-Za-z_]\w*\b", match.group(2)))
        rhs_tokens.discard(lhs)
        dependencies.setdefault(lhs, set()).update(rhs_tokens)

    # Propagate period provenance through ordinary aliases and elapsed/delay
    # temporaries until reaching a fixed point.
    changed = True
    while changed:
        changed = False
        for lhs, rhs_names in dependencies.items():
            inherited: set[str] = set()
            for rhs in rhs_names:
                inherited.update(variable_periods.get(rhs, set()))
            before = len(variable_periods.get(lhs, set()))
            if inherited:
                variable_periods.setdefault(lhs, set()).update(inherited)
            changed = changed or len(variable_periods.get(lhs, set())) != before

    periods: set[str] = set()
    for window in windows:
        periods.update(PERIOD_TOKEN_RE.findall(window))
        for token in set(re.findall(r"\b[A-Za-z_]\w*\b", window)):
            periods.update(variable_periods.get(token, set()))
    return {period.upper() for period in periods}


def _setfile_timeframe(path: Path, text: str, ea_dir: Path) -> str | None:
    comment = re.search(r"^\s*;\s*timeframe\s*:\s*([A-Za-z0-9]+)\b", text, re.IGNORECASE | re.MULTILINE)
    if comment:
        return comment.group(1).upper()
    filename = re.search(r"_(M1|M5|M15|M30|H1|H4|H6|H8|D1|W1|MN1)(?:_|\.)", path.name, re.IGNORECASE)
    if filename:
        return filename.group(1).upper()
    manifest = ea_dir / "basket_manifest.json"
    if manifest.is_file():
        try:
            value = json.loads(manifest.read_text(encoding="utf-8-sig")).get("host_timeframe")
            if value:
                return str(value).strip().upper()
        except (OSError, json.JSONDecodeError, AttributeError):
            pass
    return None


def _load_session_offsets(path: Path | None = None) -> tuple[dict[str, dict[str, str]], str | None]:
    registry_path = Path(path or SESSION_OFFSET_REGISTRY_PATH)
    if not registry_path.is_file():
        return {}, "session_offset_registry_missing"
    try:
        lines = [
            line
            for line in registry_path.read_text(encoding="utf-8-sig").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
        reader = csv.DictReader(lines)
        required = {"symbol", "offset_minutes", "offset_source"}
        if not reader.fieldnames or not required.issubset(set(reader.fieldnames)):
            return {}, "session_offset_registry_schema_invalid"
        rows: dict[str, dict[str, str]] = {}
        for raw in reader:
            symbol = str(raw.get("symbol") or "").strip().upper()
            if not symbol:
                continue
            if symbol in rows:
                return {}, f"session_offset_registry_duplicate_symbol:{symbol}"
            rows[symbol] = {key: str(value or "").strip() for key, value in raw.items()}
        return rows, None
    except (OSError, csv.Error):
        return {}, "session_offset_registry_unreadable"


def _symbols_for_setfile(
    ea_dir: Path,
    setfile: Path,
    text: str,
    registry_symbols: set[str],
) -> list[str]:
    symbols: list[str] = []

    def add(value: Any) -> None:
        symbol = str(value or "").strip().upper()
        if symbol and symbol not in symbols:
            symbols.append(symbol)

    for match in re.finditer(
        r"(?<![A-Z0-9])[A-Z][A-Z0-9]{2,15}\.DWX(?![A-Z0-9.])",
        setfile.name.upper(),
    ):
        add(match.group(0))
    comment = re.search(r"^\s*;\s*symbol\s*:\s*([^\s;]+)", text, re.IGNORECASE | re.MULTILINE)
    if comment and comment.group(1).upper().endswith(".DWX"):
        add(comment.group(1))

    manifest = ea_dir / "basket_manifest.json"
    if manifest.is_file():
        try:
            payload = json.loads(manifest.read_text(encoding="utf-8-sig"))
            add(payload.get("host_symbol"))
            for key in ("traded_symbols", "basket_symbols"):
                for value in payload.get(key) or []:
                    add(value)
        except (OSError, json.JSONDecodeError, AttributeError, TypeError):
            pass

    # If the filename has an exact registered symbol embedded in a longer
    # logical name, retain it without guessing from arbitrary uppercase words.
    upper_name = setfile.name.upper()
    for symbol in sorted(registry_symbols):
        if symbol in upper_name:
            add(symbol)
    return symbols


def _ea_dirs_for_path(path: Path) -> list[tuple[Path, list[Path] | None]]:
    if path.is_file():
        if path.suffix.lower() == ".set" and path.parent.name == "sets":
            return [(path.parent.parent, [path])]
        return [(path.parent, None)]
    if (path / "sets").exists():
        return [(path, None)]
    return [
        (candidate, None)
        for candidate in path.rglob("*")
        if candidate.is_dir() and (candidate / "sets").exists()
    ]


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


def _scan_entry_grace_vs_session_offset(path: Path) -> list[dict[str, Any]]:
    """Fail closed when a D1-label grace cannot reach the first tradable tick.

    Only operational bar-open entry clocks are in scope. EAs that merely carry
    an entry-grace input, or that anchor it to a current H1/M30/etc. bar, are
    deliberately unaffected. Registry rows are authoritative only when their
    ``offset_source`` is ``measured``; inferred offsets require measurement
    rather than a silent zero or an implicit policy override.
    """

    findings: list[dict[str, Any]] = []
    for ea_dir, selected_setfiles in _ea_dirs_for_path(path):
        mq5s = sorted(ea_dir.glob("*.mq5"))
        if not mq5s:
            continue
        mq5_path = mq5s[0]
        mq5_text = mq5_path.read_text(encoding="utf-8", errors="ignore")
        defaults = _entry_grace_input_defaults(mq5_text)
        if not defaults:
            continue
        code = _strip_code_comments_and_literals(mq5_text)
        if not _operational_grace_windows(code, set(defaults)):
            continue

        anchor_periods = _entry_grace_anchor_periods(mq5_text)
        registry, registry_error = _load_session_offsets()
        setfiles = (
            selected_setfiles
            if selected_setfiles is not None
            else sorted((ea_dir / "sets").glob("*.set"))
        )
        card_values = _entry_grace_card_values(ea_dir)

        for setfile in setfiles:
            text = setfile.read_text(encoding="utf-8", errors="ignore")
            values = _parse_setfile(setfile)
            if not _is_backtest_setfile(setfile, values):
                continue

            timeframe = _setfile_timeframe(setfile, text, ea_dir)
            if anchor_periods and "D1" not in anchor_periods:
                continue
            if not anchor_periods and timeframe != "D1":
                continue

            declarations: list[tuple[str, float | None]] = [
                (f"{mq5_path}:input:{name}", value)
                for name, value in defaults.items()
            ]
            for key, raw in values.items():
                if _is_entry_grace_name(key):
                    declarations.append((f"{setfile}:set:{key}", _parse_number(raw)))
            declarations.extend(card_values)
            invalid = [source for source, value in declarations if value is None or value < 0]
            if invalid:
                findings.append(
                    {
                        "path": str(setfile),
                        "kind": "entry_grace_value_invalid",
                        "sources": invalid,
                        "required": ">= 0 numeric minutes",
                    }
                )
                continue
            numeric = [(source, float(value)) for source, value in declarations if value is not None]
            if not numeric:
                continue
            # The narrowest card/source/set declaration is the binding contract;
            # a wider setfile cannot silently weaken an approved tight boundary.
            grace_minutes = min(value for _, value in numeric)
            grace_sources = sorted(source for source, value in numeric if value == grace_minutes)

            if registry_error:
                findings.append(
                    {
                        "path": str(setfile),
                        "kind": registry_error.split(":", 1)[0],
                        "detail": registry_error,
                        "registry_path": str(SESSION_OFFSET_REGISTRY_PATH),
                        "declared_grace_minutes": grace_minutes,
                    }
                )
                continue

            symbols = _symbols_for_setfile(ea_dir, setfile, text, set(registry))
            if not symbols:
                findings.append(
                    {
                        "path": str(setfile),
                        "kind": "session_offset_symbol_missing",
                        "symbol": "UNRESOLVED_FROM_SETFILE_OR_BASKET_MANIFEST",
                        "registry_path": str(SESSION_OFFSET_REGISTRY_PATH),
                        "declared_grace_minutes": grace_minutes,
                        "declared_grace_sources": grace_sources,
                    }
                )
                continue

            for symbol in symbols:
                row = registry.get(symbol)
                if row is None:
                    findings.append(
                        {
                            "path": str(setfile),
                            "kind": "session_offset_symbol_missing",
                            "symbol": symbol,
                            "registry_path": str(SESSION_OFFSET_REGISTRY_PATH),
                            "declared_grace_minutes": grace_minutes,
                            "declared_grace_sources": grace_sources,
                        }
                    )
                    continue
                offset_source = str(row.get("offset_source") or "").strip().lower()
                if offset_source not in AUTHORITATIVE_SESSION_OFFSET_SOURCES:
                    findings.append(
                        {
                            "path": str(setfile),
                            "kind": "session_offset_non_authoritative",
                            "symbol": symbol,
                            "offset_source": offset_source or None,
                            "offset_minutes": row.get("offset_minutes") or None,
                            "required_source": sorted(AUTHORITATIVE_SESSION_OFFSET_SOURCES),
                            "detail": (
                                "D1-label entry-grace builds require a measured offset; "
                                "inferred/unmeasured rows fail closed pending measurement."
                            ),
                        }
                    )
                    continue
                offset_minutes = _parse_number(row.get("offset_minutes", ""))
                if offset_minutes is None or offset_minutes < 0:
                    findings.append(
                        {
                            "path": str(setfile),
                            "kind": "session_offset_value_invalid",
                            "symbol": symbol,
                            "value": row.get("offset_minutes") or None,
                            "offset_source": offset_source,
                        }
                    )
                    continue
                required_grace = offset_minutes + DEFAULT_ENTRY_GRACE_MARGIN_MINUTES
                if grace_minutes + 1.0e-9 < required_grace:
                    findings.append(
                        {
                            "path": str(setfile),
                            "kind": "entry_grace_below_session_offset",
                            "symbol": symbol,
                            "declared_grace_minutes": grace_minutes,
                            "declared_grace_sources": grace_sources,
                            "offset_minutes": offset_minutes,
                            "offset_source": offset_source,
                            "margin_minutes": DEFAULT_ENTRY_GRACE_MARGIN_MINUTES,
                            "minimum_grace_minutes": required_grace,
                            "required": "declared_grace_minutes >= offset_minutes + margin_minutes",
                        }
                    )
    return findings


def _scan_strategy_conformance(path: Path) -> list[dict[str, Any]]:
    findings: list[dict[str, Any]] = []
    for ea_dir, selected_setfiles in _ea_dirs_for_path(path):
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
    findings.extend(_scan_entry_grace_vs_session_offset(path))
    return {
        "checked_at": utc_now(),
        "path": str(path),
        "files_checked": len(files),
        "max_news_stale_hours": max_news_stale_hours,
        "entry_grace_margin_minutes": DEFAULT_ENTRY_GRACE_MARGIN_MINUTES,
        "session_offset_registry_path": str(SESSION_OFFSET_REGISTRY_PATH),
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
