"""Bind an MT5 requalification summary to the exact strategy build inputs."""

from __future__ import annotations

import argparse
import configparser
import datetime as dt
import hashlib
import json
import math
import os
import re
from html.parser import HTMLParser
from pathlib import Path
from typing import Any


PHASE_CONTRACTS: dict[str, dict[str, Any]] = {
    "Q02": {
        "minimum_runs": 2,
        "exact_runs": 2,
        "determinism": "required",
        "require_identical_metrics": True,
        "description": "current-binary deterministic replay",
        "from_date": "2017.01.01",
        "to_date": "2022.12.31",
        "model": 4,
        "profit_factor_gt": 1.30,
        "trades_gt": 200,
        "drawdown_pct_lt": 12.0,
    },
    "Q05": {
        "minimum_runs": 1,
        "determinism": "not_applicable",
        "require_identical_metrics": False,
        "description": "medium-stress scenario",
    },
    "Q06": {
        "minimum_runs": 1,
        "determinism": "not_applicable",
        "require_identical_metrics": False,
        "description": "harsh-stress scenario",
    },
    "Q07": {
        "minimum_runs": 5,
        "determinism": "not_applicable",
        "require_identical_metrics": False,
        "description": "canonical five-seed cohort",
    },
    "Q08": {
        "minimum_runs": 1,
        "determinism": "not_applicable",
        "require_identical_metrics": False,
        "description": "regime or seasonal stress scenario",
    },
}


_REPORT_LABELS = {
    "expert": ("Expert", "Expertenprogramm"),
    "symbol": ("Symbol",),
    "period": ("Period", "Periode"),
    "profit_factor": ("Profit Factor", "Profitfaktor"),
    "total_trades": ("Total Trades", "Gesamtanzahl Trades"),
    "equity_drawdown_maximal": (
        "Equity Drawdown Maximal",
        "Rückgang Equity maximal",
    ),
    "net_profit": ("Total Net Profit", "Nettogewinn gesamt"),
}
_SET_ASSIGNMENT_RE = re.compile(r"^\s*(?P<key>[A-Za-z_][A-Za-z0-9_]*)\s*=\s*(?P<value>.*?)\s*$")
_EA_DIR_RE = re.compile(r"^QM5_(?P<ea_id>\d+)(?:_|$)")
_MQ5_EA_ID_RE = re.compile(
    r"(?m)^\s*input\s+[A-Za-z_][A-Za-z0-9_<>]*\s+qm_ea_id\s*=\s*(?P<ea_id>\d+)\s*;"
)
_CARD_EA_ID_RE = re.compile(r"(?mi)^ea_id:\s*(?:QM5_)?(?P<ea_id>\d+)\s*$")
_CARD_APPROVED_RE = re.compile(r"(?mi)^g0_status:\s*APPROVED\s*$")
_DD_PCT_RE = re.compile(r"\((?P<pct>[-+]?[0-9][0-9\s\u00a0.,]*)\s*%\)")
_NUMERIC_ASSIGNMENT_RE = re.compile(r"^[-+]?(?:\d+(?:[.,]\d*)?|[.,]\d+)$")
_FRESHNESS_TOLERANCE_SECONDS = 2.0


class _ReportTableParser(HTMLParser):
    """Collect text from MT5 report table cells without depending on UI locale."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.rows: list[list[str]] = []
        self._row: list[str] | None = None
        self._cell: list[str] | None = None

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        del attrs
        lowered = tag.casefold()
        if lowered == "tr":
            self._row = []
        elif lowered in {"td", "th"} and self._row is not None:
            self._cell = []

    def handle_data(self, data: str) -> None:
        if self._cell is not None:
            self._cell.append(data)

    def handle_endtag(self, tag: str) -> None:
        lowered = tag.casefold()
        if lowered in {"td", "th"} and self._cell is not None:
            value = "".join(self._cell).replace("\u00a0", " ").strip()
            if self._row is not None:
                self._row.append(value)
            self._cell = None
        elif lowered == "tr" and self._row is not None:
            if self._row:
                self.rows.append(self._row)
            self._row = None
            self._cell = None


def file_record(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    modified = dt.datetime.fromtimestamp(path.stat().st_mtime, tz=dt.timezone.utc)
    return {
        "path": str(path.resolve()),
        "size_bytes": len(raw),
        "modified_utc": modified.isoformat(),
        "sha256": hashlib.sha256(raw).hexdigest(),
    }


def _timestamp(value: str) -> dt.datetime:
    parsed = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if parsed.tzinfo is None:
        raise ValueError("summary timestamp must include an offset")
    return parsed.astimezone(dt.timezone.utc)


def _read_text(path: Path) -> str:
    raw = Path(path).read_bytes()
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        return raw.decode("utf-16")
    return raw.decode("utf-8-sig")


def _same_path(left: Path, right: Path) -> bool:
    return os.path.normcase(str(left.resolve())) == os.path.normcase(str(right.resolve()))


def _is_within(path: Path, root: Path) -> bool:
    try:
        resolved_path = os.path.normcase(str(path.resolve()))
        resolved_root = os.path.normcase(str(root.resolve()))
        return os.path.commonpath((resolved_path, resolved_root)) == resolved_root
    except (OSError, ValueError):
        return False


def _normalized_label(value: str) -> str:
    return re.sub(r"\s+", " ", value.strip().rstrip(":")).casefold()


def _row_value(rows: list[list[str]], aliases: tuple[str, ...]) -> str | None:
    wanted = {_normalized_label(alias) for alias in aliases}
    for row in rows:
        for index, cell in enumerate(row):
            if _normalized_label(cell) not in wanted:
                continue
            for candidate in row[index + 1 :]:
                if candidate.strip():
                    return candidate.strip()
    return None


def _parse_mt5_float(raw: Any) -> float:
    text = str(raw or "").replace("\u00a0", " ").strip()
    match = re.search(r"[-+]?[0-9][0-9\s,\.]*", text)
    if not match:
        raise ValueError(f"no numeric value in {raw!r}")
    token = re.sub(r"\s+", "", match.group(0))
    if "," in token and "." in token:
        if token.rfind(",") > token.rfind("."):
            token = token.replace(".", "").replace(",", ".")
        else:
            token = token.replace(",", "")
    elif "," in token:
        token = token.replace(",", ".")
    value = float(token)
    if not math.isfinite(value):
        raise ValueError(f"non-finite numeric value in {raw!r}")
    return value


def _parse_mt5_int(raw: Any) -> int:
    text = str(raw or "").replace("\u00a0", " ").strip()
    if not re.fullmatch(r"[-+]?[0-9][0-9\s,\.]*", text):
        raise ValueError(f"invalid integer value {raw!r}")
    sign = -1 if text.startswith("-") else 1
    digits = re.sub(r"[^0-9]", "", text)
    if not digits:
        raise ValueError(f"invalid integer value {raw!r}")
    return sign * int(digits)


def _parse_drawdown_pct(raw: Any) -> float:
    match = _DD_PCT_RE.search(str(raw or ""))
    if not match:
        raise ValueError(f"drawdown percentage missing from {raw!r}")
    value = _parse_mt5_float(match.group("pct"))
    if value < 0:
        raise ValueError(f"negative drawdown percentage in {raw!r}")
    return value


def _report_payload(path: Path) -> dict[str, Any]:
    parser = _ReportTableParser()
    parser.feed(_read_text(path))
    parser.close()
    if not parser.rows:
        raise ValueError("native report has no table rows")

    inputs: dict[str, str] = {}
    duplicate_inputs: set[str] = set()
    for row in parser.rows:
        for cell in row:
            match = _SET_ASSIGNMENT_RE.fullmatch(cell)
            if not match:
                continue
            key = match.group("key")
            value = match.group("value").strip()
            if key in inputs:
                duplicate_inputs.add(key)
            else:
                inputs[key] = value

    values = {
        key: _row_value(parser.rows, aliases)
        for key, aliases in _REPORT_LABELS.items()
    }
    missing = [key for key, value in values.items() if value is None]
    if missing:
        raise ValueError("native report labels missing: " + ",".join(sorted(missing)))

    dd_raw = str(values["equity_drawdown_maximal"])
    return {
        "expert": str(values["expert"]),
        "symbol": str(values["symbol"]),
        "period": str(values["period"]),
        "profit_factor": _parse_mt5_float(values["profit_factor"]),
        "total_trades": _parse_mt5_int(values["total_trades"]),
        "drawdown_money": _parse_mt5_float(dd_raw),
        "drawdown_pct": _parse_drawdown_pct(dd_raw),
        "net_profit": _parse_mt5_float(values["net_profit"]),
        "inputs": inputs,
        "duplicate_inputs": sorted(duplicate_inputs),
    }


def _parse_setfile(path: Path) -> tuple[dict[str, str], list[str]]:
    assignments: dict[str, str] = {}
    duplicates: set[str] = set()
    for raw_line in _read_text(path).splitlines():
        if raw_line.lstrip().startswith((";", "#")) or not raw_line.strip():
            continue
        match = _SET_ASSIGNMENT_RE.fullmatch(raw_line)
        if not match:
            continue
        key = match.group("key")
        value = match.group("value").split("||", 1)[0].strip()
        if key in assignments:
            duplicates.add(key)
        else:
            assignments[key] = value
    return assignments, sorted(duplicates)


def _assignment_equal(left: str, right: str) -> bool:
    first = left.strip()
    second = right.strip()
    if len(first) >= 2 and first[0] == first[-1] == '"':
        first = first[1:-1]
    if len(second) >= 2 and second[0] == second[-1] == '"':
        second = second[1:-1]
    if first.casefold() in {"true", "false"} or second.casefold() in {"true", "false"}:
        return first.casefold() == second.casefold()
    if _NUMERIC_ASSIGNMENT_RE.fullmatch(first) and _NUMERIC_ASSIGNMENT_RE.fullmatch(second):
        try:
            return math.isclose(
                _parse_mt5_float(first),
                _parse_mt5_float(second),
                rel_tol=0.0,
                abs_tol=1e-12,
            )
        except ValueError:
            return False
    return first == second


def _load_tester_ini(path: Path) -> configparser.ConfigParser:
    parser = configparser.ConfigParser(interpolation=None, strict=True)
    parser.optionxform = str
    parser.read_string(_read_text(path))
    if not parser.has_section("Tester"):
        raise ValueError("tester.ini missing [Tester]")
    return parser


def _summary_float(value: Any, field: str) -> float:
    if isinstance(value, bool):
        raise ValueError(f"{field} must be numeric")
    parsed = float(value)
    if not math.isfinite(parsed):
        raise ValueError(f"{field} must be finite")
    return parsed


def _summary_int(value: Any, field: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f"{field} must be an integer")
    return value


def _append_mismatch(blockers: list[str], name: str, actual: Any, expected: Any) -> None:
    if str(actual).replace("/", "\\").casefold() != str(expected).replace("/", "\\").casefold():
        blockers.append(name)


def _q02_strict_evidence(
    *,
    summary_path: Path,
    summary: dict[str, Any],
    ea_dir: Path,
    setfile_path: Path,
    card_path: Path,
    mq5_files: list[Path],
    ex5_files: list[Path],
    required: dict[str, Path],
    blockers: list[str],
) -> dict[str, Any]:
    contract = PHASE_CONTRACTS["Q02"]
    result: dict[str, Any] = {
        "reports": [],
        "tester_inis": [],
        "tester_logs": [],
        "native_metrics": [],
        "set_input_parity": [],
    }

    directory_match = _EA_DIR_RE.match(ea_dir.name)
    expected_ea_id: int | None = None
    if directory_match is None:
        blockers.append("q02_ea_dir_name_invalid")
    else:
        expected_ea_id = int(directory_match.group("ea_id"))
        try:
            if _summary_int(summary.get("ea_id"), "ea_id") != expected_ea_id:
                blockers.append("q02_summary_ea_id_mismatch")
        except (TypeError, ValueError):
            blockers.append("q02_summary_ea_id_invalid")

    symbol = str(summary.get("symbol") or "")
    period = str(summary.get("period") or "")
    expected_expert = f"QM\\{ea_dir.name}"
    if not symbol:
        blockers.append("q02_summary_symbol_missing")
    if not period:
        blockers.append("q02_summary_period_missing")
    _append_mismatch(
        blockers,
        "q02_summary_expert_mismatch",
        summary.get("expert"),
        expected_expert,
    )
    if not str(summary.get("terminal") or ""):
        blockers.append("q02_summary_terminal_missing")
    if summary.get("requested_runs") != contract["exact_runs"]:
        blockers.append("q02_requested_runs_not_exact")
    if summary.get("model4_log_marker_detected") is not True:
        blockers.append("q02_model4_marker_missing")
    if summary.get("oninit_failure_detected") is True:
        blockers.append("q02_oninit_failure")
    if summary.get("log_bomb_detected") is True:
        blockers.append("q02_log_bomb_detected")

    mq5_path = mq5_files[0] if len(mq5_files) == 1 else None
    ex5_path = ex5_files[0] if len(ex5_files) == 1 else None
    if mq5_path is not None and mq5_path.stem != ea_dir.name:
        blockers.append("q02_mq5_stem_mismatch")
    if ex5_path is not None and ex5_path.stem != ea_dir.name:
        blockers.append("q02_ex5_stem_mismatch")
    if mq5_path is not None and ex5_path is not None:
        if ex5_path.stat().st_mtime + _FRESHNESS_TOLERANCE_SECONDS < mq5_path.stat().st_mtime:
            blockers.append("q02_ex5_older_than_mq5")
        try:
            mq5_text = _read_text(mq5_path)
            mq5_match = _MQ5_EA_ID_RE.search(mq5_text)
            if mq5_match is None:
                blockers.append("q02_mq5_ea_id_missing")
            elif expected_ea_id is not None and int(mq5_match.group("ea_id")) != expected_ea_id:
                blockers.append("q02_mq5_ea_id_mismatch")
        except (OSError, UnicodeError):
            blockers.append("q02_mq5_unreadable")

    if card_path.is_file():
        try:
            card_text = _read_text(card_path)
            if _CARD_APPROVED_RE.search(card_text) is None:
                blockers.append("q02_card_not_approved")
            card_id_match = _CARD_EA_ID_RE.search(card_text)
            if card_id_match is None:
                blockers.append("q02_card_ea_id_missing")
            elif expected_ea_id is not None and int(card_id_match.group("ea_id")) != expected_ea_id:
                blockers.append("q02_card_ea_id_mismatch")
        except (OSError, UnicodeError):
            blockers.append("q02_card_unreadable")

    set_assignments: dict[str, str] = {}
    if setfile_path.is_file():
        try:
            resolved_set = setfile_path.resolve(strict=True)
            expected_sets_dir = (ea_dir / "sets").resolve(strict=True)
            if not _is_within(resolved_set, expected_sets_dir) or resolved_set.parent != expected_sets_dir:
                blockers.append("q02_setfile_outside_ea_sets")
            expected_set_name = f"{ea_dir.name}_{symbol}_{period}_backtest.set"
            if resolved_set.name != expected_set_name:
                blockers.append("q02_setfile_name_mismatch")
            set_assignments, duplicate_set_keys = _parse_setfile(resolved_set)
            if duplicate_set_keys:
                blockers.append("q02_setfile_duplicate_assignments")
            if not set_assignments:
                blockers.append("q02_setfile_has_no_assignments")
            raw_set_ea_id = set_assignments.get("qm_ea_id")
            try:
                set_ea_id = int(str(raw_set_ea_id))
            except (TypeError, ValueError):
                blockers.append("q02_setfile_ea_id_invalid")
            else:
                if expected_ea_id is not None and set_ea_id != expected_ea_id:
                    blockers.append("q02_setfile_ea_id_mismatch")
        except (OSError, UnicodeError):
            blockers.append("q02_setfile_unreadable")

    input_paths = [
        path
        for label, path in required.items()
        if label in {"spec", "setfile", "card", "mq5", "ex5"} and path.is_file()
    ]
    input_mtime = max((path.stat().st_mtime for path in input_paths), default=0.0)

    report_dir: Path | None = None
    raw_report_dir = summary.get("report_dir")
    if not isinstance(raw_report_dir, str) or not raw_report_dir.strip():
        blockers.append("q02_report_dir_missing")
    else:
        candidate = Path(raw_report_dir)
        if not candidate.is_absolute():
            blockers.append("q02_report_dir_not_absolute")
        try:
            report_dir = candidate.resolve(strict=True)
            if not report_dir.is_dir():
                blockers.append("q02_report_dir_not_directory")
            if not _same_path(summary_path.parent, report_dir):
                blockers.append("q02_summary_outside_report_dir")
            if not _same_path(summary_path, report_dir / "summary.json"):
                blockers.append("q02_summary_path_not_canonical")
        except OSError:
            blockers.append("q02_report_dir_missing_on_disk")
            report_dir = None

    runs = summary.get("runs")
    if not isinstance(runs, list) or len(runs) != contract["exact_runs"]:
        blockers.append("q02_run_count_not_exact")
        runs = runs if isinstance(runs, list) else []

    seen_reports: set[str] = set()
    seen_logs: set[str] = set()
    evidence_mtimes: list[float] = []
    comparable_native: list[tuple[int, float, float, float, float]] = []
    for index, run in enumerate(runs, start=1):
        run_label = f"run_{index:02d}"
        prefix = f"q02_{run_label}"
        if not isinstance(run, dict):
            blockers.append(f"{prefix}_not_object")
            continue
        if run.get("run") != run_label:
            blockers.append(f"{prefix}_name_mismatch")
        if str(run.get("status") or "").upper() != "OK":
            blockers.append(f"{prefix}_not_ok")
        if run.get("exit_code") != 0:
            blockers.append(f"{prefix}_exit_code_not_zero")
        if run.get("real_ticks_marker") is not True:
            blockers.append(f"{prefix}_real_ticks_marker_missing")

        report_path: Path | None = None
        log_path: Path | None = None
        report_raw = run.get("report_canonical_path")
        log_raw = run.get("tester_log_path")
        if not isinstance(report_raw, str) or not report_raw or not Path(report_raw).is_absolute():
            blockers.append(f"{prefix}_report_path_invalid")
        else:
            try:
                report_path = Path(report_raw).resolve(strict=True)
            except OSError:
                blockers.append(f"{prefix}_report_missing")
        if not isinstance(log_raw, str) or not log_raw or not Path(log_raw).is_absolute():
            blockers.append(f"{prefix}_tester_log_path_invalid")
        else:
            try:
                log_path = Path(log_raw).resolve(strict=True)
            except OSError:
                blockers.append(f"{prefix}_tester_log_missing")

        expected_run_dir = report_dir / "raw" / run_label if report_dir is not None else None
        if report_path is not None:
            report_key = os.path.normcase(str(report_path))
            if report_key in seen_reports:
                blockers.append("q02_duplicate_report_path")
            seen_reports.add(report_key)
            if expected_run_dir is None or not _same_path(report_path, expected_run_dir / "report.htm"):
                blockers.append(f"{prefix}_report_not_canonical")
            if report_path.stat().st_size <= 0:
                blockers.append(f"{prefix}_report_empty")
        if log_path is not None:
            log_key = os.path.normcase(str(log_path))
            if log_key in seen_logs:
                blockers.append("q02_duplicate_tester_log_path")
            seen_logs.add(log_key)
            if (
                expected_run_dir is None
                or log_path.parent != expected_run_dir.resolve()
                or log_path.suffix.casefold() != ".log"
            ):
                blockers.append(f"{prefix}_tester_log_not_contained")
            if log_path.stat().st_size <= 0:
                blockers.append(f"{prefix}_tester_log_empty")
            else:
                try:
                    if "generating based on real ticks" not in _read_text(log_path).casefold():
                        blockers.append(f"{prefix}_real_ticks_log_proof_missing")
                except (OSError, UnicodeError):
                    blockers.append(f"{prefix}_tester_log_unreadable")

        ini_path = expected_run_dir / "tester.ini" if expected_run_dir is not None else None
        if ini_path is None or not ini_path.is_file():
            blockers.append(f"{prefix}_tester_ini_missing")
            ini_path = None

        if ini_path is not None:
            try:
                tester_ini = _load_tester_ini(ini_path)
                expected_ini = {
                    "Expert": expected_expert,
                    "Symbol": symbol,
                    "Period": period,
                    "Model": str(contract["model"]),
                    "FromDate": str(contract["from_date"]),
                    "ToDate": str(contract["to_date"]),
                    "Optimization": "0",
                    "ExpertParameters": setfile_path.name,
                }
                for key, expected_value in expected_ini.items():
                    actual_value = tester_ini.get("Tester", key, fallback=None)
                    if actual_value != expected_value:
                        blockers.append(f"{prefix}_tester_ini_{key.casefold()}_mismatch")
            except (OSError, UnicodeError, configparser.Error, ValueError):
                blockers.append(f"{prefix}_tester_ini_invalid")

        for evidence_name, evidence_path in (
            ("report", report_path),
            ("tester_log", log_path),
            ("tester_ini", ini_path),
        ):
            if evidence_path is None or not evidence_path.is_file():
                continue
            evidence_mtimes.append(evidence_path.stat().st_mtime)
            if evidence_path.stat().st_mtime + _FRESHNESS_TOLERANCE_SECONDS < input_mtime:
                blockers.append(f"{prefix}_{evidence_name}_predates_inputs")

        if ini_path is not None and report_path is not None:
            if report_path.stat().st_mtime + _FRESHNESS_TOLERANCE_SECONDS < ini_path.stat().st_mtime:
                blockers.append(f"{prefix}_report_predates_tester_ini")
        if ini_path is not None and log_path is not None:
            if log_path.stat().st_mtime + _FRESHNESS_TOLERANCE_SECONDS < ini_path.stat().st_mtime:
                blockers.append(f"{prefix}_tester_log_predates_tester_ini")

        native: dict[str, Any] | None = None
        if report_path is not None and report_path.is_file() and report_path.stat().st_size > 0:
            try:
                native = _report_payload(report_path)
            except (OSError, UnicodeError, ValueError):
                blockers.append(f"{prefix}_native_report_invalid")
        if native is not None:
            _append_mismatch(
                blockers,
                f"{prefix}_native_expert_mismatch",
                native["expert"],
                ea_dir.name,
            )
            _append_mismatch(
                blockers,
                f"{prefix}_native_symbol_mismatch",
                native["symbol"],
                symbol,
            )
            expected_period_pattern = re.compile(
                rf"^{re.escape(period)}\s*\(\s*{re.escape(str(contract['from_date']))}"
                rf"\s*-\s*{re.escape(str(contract['to_date']))}\s*\)$",
                re.IGNORECASE,
            )
            if expected_period_pattern.fullmatch(native["period"]) is None:
                blockers.append(f"{prefix}_native_period_mismatch")
            if native["duplicate_inputs"]:
                blockers.append(f"{prefix}_native_input_duplicates")

            missing_inputs = sorted(set(set_assignments) - set(native["inputs"]))
            mismatched_inputs = sorted(
                key
                for key, expected_value in set_assignments.items()
                if key in native["inputs"]
                and not _assignment_equal(expected_value, native["inputs"][key])
            )
            if missing_inputs:
                blockers.append(f"{prefix}_set_inputs_missing_from_report")
            if mismatched_inputs:
                blockers.append(f"{prefix}_set_inputs_mismatch")
            result["set_input_parity"].append(
                {
                    "run": run_label,
                    "set_assignment_count": len(set_assignments),
                    "matched_assignment_count": len(set_assignments)
                    - len(missing_inputs)
                    - len(mismatched_inputs),
                    "missing": missing_inputs,
                    "mismatched": mismatched_inputs,
                }
            )

            try:
                summary_trades = _summary_int(run.get("total_trades"), "total_trades")
                summary_pf = _summary_float(run.get("profit_factor"), "profit_factor")
                summary_dd_money = _summary_float(run.get("drawdown"), "drawdown")
                summary_net = _summary_float(run.get("net_profit"), "net_profit")
                summary_dd_pct = _parse_drawdown_pct(run.get("drawdown_raw"))
            except (TypeError, ValueError):
                blockers.append(f"{prefix}_summary_metrics_invalid")
            else:
                if summary_trades != native["total_trades"]:
                    blockers.append(f"{prefix}_summary_trades_mismatch")
                for metric_name, summary_value, native_value, tolerance in (
                    ("pf", summary_pf, native["profit_factor"], 1e-12),
                    ("drawdown_money", summary_dd_money, native["drawdown_money"], 0.01),
                    ("drawdown_pct", summary_dd_pct, native["drawdown_pct"], 1e-12),
                    ("net_profit", summary_net, native["net_profit"], 0.01),
                ):
                    if not math.isclose(summary_value, native_value, rel_tol=0.0, abs_tol=tolerance):
                        blockers.append(f"{prefix}_summary_{metric_name}_mismatch")

            if not native["profit_factor"] > float(contract["profit_factor_gt"]):
                blockers.append(f"{prefix}_pf_not_above_q02_floor")
            if not native["total_trades"] > int(contract["trades_gt"]):
                blockers.append(f"{prefix}_trades_not_above_q02_floor")
            if not native["drawdown_pct"] < float(contract["drawdown_pct_lt"]):
                blockers.append(f"{prefix}_drawdown_not_below_q02_ceiling")

            comparable_native.append(
                (
                    native["total_trades"],
                    native["profit_factor"],
                    native["drawdown_money"],
                    native["drawdown_pct"],
                    native["net_profit"],
                )
            )
            result["native_metrics"].append(
                {
                    "run": run_label,
                    "trades": native["total_trades"],
                    "profit_factor": native["profit_factor"],
                    "drawdown_money": native["drawdown_money"],
                    "drawdown_pct": native["drawdown_pct"],
                    "net_profit": native["net_profit"],
                }
            )

        if report_path is not None and report_path.is_file():
            result["reports"].append(file_record(report_path))
        if ini_path is not None and ini_path.is_file():
            result["tester_inis"].append(file_record(ini_path))
        if log_path is not None and log_path.is_file():
            result["tester_logs"].append(file_record(log_path))

    if len(comparable_native) != contract["exact_runs"]:
        blockers.append("q02_native_run_metrics_incomplete")
    elif any(metrics != comparable_native[0] for metrics in comparable_native[1:]):
        blockers.append("q02_native_run_metrics_not_identical")

    summary_mtime = summary_path.stat().st_mtime
    if summary_mtime + _FRESHNESS_TOLERANCE_SECONDS < input_mtime:
        blockers.append("q02_summary_predates_inputs")
    if evidence_mtimes:
        latest_evidence_mtime = max(evidence_mtimes)
        if summary_mtime + _FRESHNESS_TOLERANCE_SECONDS < latest_evidence_mtime:
            blockers.append("q02_summary_predates_run_evidence")
        try:
            embedded_timestamp = _timestamp(str(summary.get("timestamp_utc") or ""))
            embedded_epoch = embedded_timestamp.timestamp()
            if embedded_epoch + _FRESHNESS_TOLERANCE_SECONDS < latest_evidence_mtime:
                blockers.append("q02_embedded_timestamp_predates_run_evidence")
            if embedded_epoch > summary_mtime + _FRESHNESS_TOLERANCE_SECONDS:
                blockers.append("q02_embedded_timestamp_after_summary_file")
        except ValueError:
            blockers.append("q02_embedded_timestamp_invalid")

    result["contract"] = {
        "from_date": contract["from_date"],
        "to_date": contract["to_date"],
        "model": contract["model"],
        "exact_runs": contract["exact_runs"],
        "profit_factor_gt": contract["profit_factor_gt"],
        "trades_gt": contract["trades_gt"],
        "drawdown_pct_lt": contract["drawdown_pct_lt"],
    }
    return result


def _q07_aggregate_evidence(
    aggregate: dict[str, Any],
    ea_dir: Path,
    blockers: list[str],
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Convert the real Q07 aggregate plus five seed summaries into one cohort."""
    if str(aggregate.get("phase") or "").upper() != "Q07":
        blockers.append("q07_phase_mismatch")
    if str(aggregate.get("verdict") or "").upper() != "PASS":
        blockers.append("summary_not_pass")

    expected_seeds = [int(seed) for seed in (aggregate.get("seeds") or [])]
    details = aggregate.get("per_seed_detail") or []
    if len(expected_seeds) != len(set(expected_seeds)):
        blockers.append("q07_seed_list_not_unique")

    child_runs: list[dict[str, Any]] = []
    seed_evidence: list[dict[str, Any]] = []
    observed_seeds: list[int] = []
    identity: dict[str, Any] = {}
    for detail_index, detail in enumerate(details, start=1):
        try:
            seed = int(detail.get("seed"))
        except (TypeError, ValueError):
            blockers.append(f"q07_detail_{detail_index}_seed_invalid")
            continue
        observed_seeds.append(seed)
        child_path = Path(str(detail.get("summary_path") or ""))
        if not child_path.is_file():
            blockers.append(f"q07_seed_{seed}_summary_missing")
            continue
        try:
            child = json.loads(child_path.read_text(encoding="utf-8-sig"))
        except (OSError, json.JSONDecodeError):
            blockers.append(f"q07_seed_{seed}_summary_invalid")
            continue

        child_identity = {
            "ea_id": child.get("ea_id"),
            "symbol": child.get("symbol"),
            "period": child.get("period"),
            "terminal": child.get("terminal"),
            "model": child.get("model"),
            "expert": child.get("expert"),
        }
        if not identity:
            identity = child_identity
        elif child_identity != identity:
            blockers.append(f"q07_seed_{seed}_identity_mismatch")
        if child.get("ea_id") != aggregate.get("ea_id"):
            blockers.append(f"q07_seed_{seed}_ea_id_mismatch")
        expected_symbol = aggregate.get("runner_symbol") or aggregate.get("symbol")
        if str(child.get("symbol") or "").casefold() != str(expected_symbol or "").casefold():
            blockers.append(f"q07_seed_{seed}_symbol_mismatch")
        if str(child.get("result") or "").upper() != "PASS":
            blockers.append(f"q07_seed_{seed}_summary_not_pass")

        runs = child.get("runs") or []
        if len(runs) != 1:
            blockers.append(f"q07_seed_{seed}_run_count_not_one")
            continue
        run = runs[0]
        child_runs.append(run)
        if run.get("status") != "OK":
            blockers.append(f"q07_seed_{seed}_run_not_ok")
        if detail.get("pf") != run.get("profit_factor"):
            blockers.append(f"q07_seed_{seed}_pf_mismatch")
        if int(detail.get("trades") or 0) != int(run.get("total_trades") or 0):
            blockers.append(f"q07_seed_{seed}_trades_mismatch")

        report_path = Path(str(run.get("report_canonical_path") or ""))
        tester_ini = report_path.parent / "tester.ini"
        if not tester_ini.is_file():
            blockers.append(f"q07_seed_{seed}_tester_ini_missing")
            seed_set = None
        else:
            match = re.search(
                r"(?mi)^ExpertParameters=(?P<name>.+_q06_stress_harsh_seed"
                + re.escape(str(seed))
                + r"\.set)\s*$",
                tester_ini.read_text(encoding="utf-8", errors="replace"),
            )
            if not match:
                blockers.append(f"q07_seed_{seed}_setfile_not_proven")
                seed_set = None
            else:
                seed_set = ea_dir / "sets" / Path(match.group("name").strip()).name
                if not seed_set.is_file():
                    blockers.append(f"q07_seed_{seed}_setfile_missing")
                    seed_set = None

        evidence = {
            "seed": seed,
            "summary": file_record(child_path),
            "timestamp_utc": child.get("timestamp_utc"),
        }
        if tester_ini.is_file():
            evidence["tester_ini"] = file_record(tester_ini)
        if seed_set is not None:
            evidence["setfile"] = file_record(seed_set)
        seed_evidence.append(evidence)

    if observed_seeds != expected_seeds:
        blockers.append("q07_seed_order_or_membership_mismatch")
    if len(observed_seeds) != len(set(observed_seeds)):
        blockers.append("q07_observed_seeds_not_unique")

    synthetic = {
        "timestamp_utc": aggregate.get("generated_at_utc"),
        "result": aggregate.get("verdict"),
        "ea_id": identity.get("ea_id", aggregate.get("ea_id")),
        "symbol": identity.get("symbol", aggregate.get("runner_symbol") or aggregate.get("symbol")),
        "period": identity.get("period"),
        "terminal": identity.get("terminal"),
        "model": identity.get("model"),
        "expert": identity.get("expert"),
        "runs": child_runs,
    }
    return synthetic, seed_evidence


def build_binding(
    summary_path: Path,
    ea_dir: Path,
    setfile_path: Path,
    card_path: Path,
    phase: str = "Q02",
) -> dict[str, Any]:
    phase = phase.upper()
    if phase not in PHASE_CONTRACTS:
        supported = ", ".join(sorted(PHASE_CONTRACTS))
        raise ValueError(f"unsupported phase {phase!r}; expected one of: {supported}")
    contract = PHASE_CONTRACTS[phase]

    source_payload = json.loads(summary_path.read_text(encoding="utf-8-sig"))
    mq5_files = sorted(ea_dir.glob("*.mq5"))
    ex5_files = sorted(ea_dir.glob("*.ex5"))
    required = {
        "summary": summary_path,
        "spec": ea_dir / "SPEC.md",
        "setfile": setfile_path,
        "card": card_path,
    }
    blockers: list[str] = []
    seed_evidence: list[dict[str, Any]] = []
    is_q07_aggregate = phase == "Q07" and "per_seed_detail" in source_payload
    if is_q07_aggregate:
        summary, seed_evidence = _q07_aggregate_evidence(
            source_payload,
            ea_dir,
            blockers,
        )
    else:
        summary = source_payload
    if len(mq5_files) != 1:
        blockers.append("mq5_not_unique")
    else:
        required["mq5"] = mq5_files[0]
    if len(ex5_files) != 1:
        blockers.append("ex5_not_unique")
    else:
        required["ex5"] = ex5_files[0]
    for label, path in required.items():
        if not path.is_file():
            blockers.append(f"{label}_missing")

    if summary.get("result") != "PASS":
        blockers.append("summary_not_pass")
    if contract["determinism"] == "required" and summary.get("deterministic") is not True:
        blockers.append("summary_not_deterministic")
    if int(summary.get("model") or 0) != 4:
        blockers.append("model_not_real_ticks")
    runs = summary.get("runs") or []
    minimum_runs = int(contract["minimum_runs"])
    if len(runs) < minimum_runs:
        blockers.append(f"fewer_than_{minimum_runs}_runs")
    metrics: list[tuple[Any, ...]] = []
    report_records: list[dict[str, Any]] = []
    for index, run in enumerate(runs):
        if not isinstance(run, dict):
            blockers.append(f"run_{index + 1}_invalid")
            continue
        if run.get("status") != "OK":
            blockers.append(f"run_{index + 1}_not_ok")
        metrics.append(
            (
                run.get("total_trades"),
                run.get("profit_factor"),
                run.get("drawdown"),
                run.get("net_profit"),
            )
        )
        report_path = Path(str(run.get("report_canonical_path") or ""))
        if not report_path.is_file():
            blockers.append(f"run_{index + 1}_report_missing")
        else:
            report_records.append(file_record(report_path))
    if (
        contract["require_identical_metrics"]
        and metrics
        and any(item != metrics[0] for item in metrics[1:])
    ):
        blockers.append("run_metrics_not_identical")

    records = {
        label: file_record(path)
        for label, path in required.items()
        if path.is_file()
    }
    q02_evidence: dict[str, Any] | None = None
    if phase == "Q02":
        q02_evidence = _q02_strict_evidence(
            summary_path=summary_path,
            summary=summary,
            ea_dir=ea_dir,
            setfile_path=setfile_path,
            card_path=card_path,
            mq5_files=mq5_files,
            ex5_files=ex5_files,
            required=required,
            blockers=blockers,
        )
        report_records = q02_evidence["reports"]
    if "ex5" in records:
        try:
            generated_at = _timestamp(str(summary.get("timestamp_utc") or ""))
            binary_time = _timestamp(records["ex5"]["modified_utc"])
            if generated_at < binary_time:
                blockers.append("summary_predates_binary")
        except ValueError:
            blockers.append("invalid_evidence_timestamp")
        if is_q07_aggregate:
            for evidence in seed_evidence:
                seed = evidence["seed"]
                try:
                    if _timestamp(str(evidence.get("timestamp_utc") or "")) < binary_time:
                        blockers.append(f"q07_seed_{seed}_summary_predates_binary")
                except ValueError:
                    blockers.append(f"q07_seed_{seed}_timestamp_invalid")

    return {
        "schema_version": 1,
        "status": "BOUND_PASS" if not blockers else "NO_GO",
        "phase": phase,
        "ea_id": summary.get("ea_id"),
        "symbol": summary.get("symbol"),
        "period": summary.get("period"),
        "terminal": summary.get("terminal"),
        "model": summary.get("model"),
        "deterministic": (
            summary.get("deterministic")
            if contract["determinism"] == "required"
            else "not_applicable"
        ),
        "source_summary_deterministic": summary.get("deterministic"),
        "run_contract": {
            "description": contract["description"],
            "minimum_runs": minimum_runs,
            "exact_runs": contract.get("exact_runs"),
            "observed_runs": len(runs),
            "require_identical_metrics": contract["require_identical_metrics"],
        },
        "metrics": {
            "trades": metrics[0][0] if metrics else None,
            "profit_factor": metrics[0][1] if metrics else None,
            "drawdown": metrics[0][2] if metrics else None,
            "drawdown_pct": (
                q02_evidence["native_metrics"][0]["drawdown_pct"]
                if q02_evidence and q02_evidence["native_metrics"]
                else None
            ),
            "net_profit": metrics[0][3] if metrics else None,
        },
        "cohort_metrics": source_payload.get("metrics") if is_q07_aggregate else None,
        "blockers": sorted(set(blockers)),
        "files": records,
        "reports": report_records,
        "tester_inis": q02_evidence["tester_inis"] if q02_evidence else [],
        "tester_logs": q02_evidence["tester_logs"] if q02_evidence else [],
        "native_metrics": q02_evidence["native_metrics"] if q02_evidence else [],
        "set_input_parity": q02_evidence["set_input_parity"] if q02_evidence else [],
        "q02_contract": q02_evidence["contract"] if q02_evidence else None,
        "seed_evidence": seed_evidence,
        "scope": f"native_current_binary_{phase.lower()}_only",
        "promotion_note": "BOUND_PASS does not waive FTMO cost reconciliation or Q04-Q10.",
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--ea-dir", type=Path, required=True)
    parser.add_argument("--setfile", type=Path, required=True)
    parser.add_argument("--card", type=Path, required=True)
    parser.add_argument(
        "--phase",
        choices=sorted(PHASE_CONTRACTS),
        default="Q02",
        help="Evidence phase contract (default: Q02, the conservative two-run contract).",
    )
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args(argv)
    artifact = build_binding(
        args.summary,
        args.ea_dir,
        args.setfile,
        args.card,
        phase=args.phase,
    )
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"wrote {args.out} status={artifact['status']}")
    return 0 if artifact["status"] == "BOUND_PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
