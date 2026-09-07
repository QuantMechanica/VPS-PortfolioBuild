#!/usr/bin/env python3
"""Governed, create-only monthly refresh for the QM5_1537 sleeve calendar.

The normal path is intentionally narrow: it may use only the dedicated
Darwinex-Live ``T_Export`` wrapper, stages new versioned repository artifacts,
emits an install *candidate*, and stops in REVIEW.  It never writes an MT5
terminal data directory, attaches a chart, or changes AutoTrading.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import hashlib
import importlib.util
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import uuid
from zoneinfo import ZoneInfo


SCHEMA = "qm.qm1537-monthly-sleeve-refresh/v1"
INSTALL_SCHEMA = "qm.qm1537-refresh-install-candidate/v1"
TIMEZONE = ZoneInfo("Europe/Berlin")
HOST_SYMBOL = "XAGUSD.DWX"
UNIVERSE = (
    "XAUUSD.DWX", "XAGUSD.DWX", "XNGUSD.DWX", "XTIUSD.DWX",
    "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX", "SP500.DWX",
    "AUDCAD.DWX", "AUDCHF.DWX", "AUDJPY.DWX", "AUDNZD.DWX", "AUDUSD.DWX",
    "CADCHF.DWX", "CADJPY.DWX", "CHFJPY.DWX", "EURAUD.DWX", "EURCAD.DWX",
    "EURCHF.DWX", "EURGBP.DWX", "EURJPY.DWX", "EURNZD.DWX", "EURUSD.DWX",
    "GBPAUD.DWX", "GBPCAD.DWX", "GBPCHF.DWX", "GBPJPY.DWX", "GBPNZD.DWX",
    "GBPUSD.DWX", "NZDCAD.DWX", "NZDCHF.DWX", "NZDJPY.DWX", "NZDUSD.DWX",
    "USDCAD.DWX", "USDCHF.DWX", "USDJPY.DWX",
)
NATIVE_HEADER = ["time", "open", "high", "low", "close", "tickvol", "spread"]
CALENDAR_HEADER = [
    "schema_version", "contract_sha256", "input_bundle_sha256", "month_key",
    "host_symbol", "host_rank", "valid_count", "selected", "selected_1",
    "selected_2", "selected_3", "host_vol_pct", "asof_epoch",
]
SOURCE_HEADER = [
    "calendar_row", "month_key", "host_symbol", "source",
    "source_bundle_sha256", "row_sha256",
]

REPO_ROOT = Path(__file__).resolve().parents[2]
EA_DIR = REPO_ROOT / "framework/EAs/QM5_1537_aa-vol-sma10"
CALENDAR_DIR = EA_DIR / "calendar"
SET_DIR = EA_DIR / "sets"
BUILDER = EA_DIR / "tools/build_monthly_sleeve_calendar.py"
EXPORTER = REPO_ROOT / "framework/scripts/mt5_diagnostics/qm1537_native_d1_export.py"
EVIDENCE_ROOT = REPO_ROOT / "docs/ops/evidence"
NATIVE_EXPORT_ROOT = Path("D:/QM/reports/qm1537_native_d1")
COMMON_FILES = Path(os.environ.get("APPDATA", r"C:/Users/Administrator/AppData/Roaming")) / "MetaQuotes/Terminal/Common/Files"
FTMO_DEMO_DATA = Path(
    os.environ.get(
        "QM_FTMO_DEMO_DATA_DIR",
        r"C:/Users/Administrator/AppData/Roaming/MetaQuotes/Terminal/81A933A9AFC5DE3C23B15CAB19C63850",
    )
)


class RefreshError(RuntimeError):
    """A fail-closed refresh defect."""


class RefreshDeferred(RefreshError):
    """A safe condition that should be retried by a later scheduled launch."""


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest().upper()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def utc_iso(value: dt.datetime | None = None) -> str:
    value = value or dt.datetime.now(dt.timezone.utc)
    return value.astimezone(dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def month_key_for_date(value: dt.date) -> int:
    return value.year * 100 + value.month


def split_month_key(value: int) -> tuple[int, int]:
    year, month = divmod(int(value), 100)
    if year < 2000 or month < 1 or month > 12:
        raise RefreshError(f"invalid month key: {value}")
    return year, month


def month_start_epoch(value: int) -> int:
    year, month = split_month_key(value)
    return int(dt.datetime(year, month, 1, tzinfo=dt.timezone.utc).timestamp())


def month_key_for_epoch(value: int) -> int:
    observed = dt.datetime.fromtimestamp(value, dt.timezone.utc)
    return observed.year * 100 + observed.month


def schedule_window_candidate(value: dt.date) -> bool:
    """Return whether the local date can be the first tradable day.

    The task is intentionally registered only for days 1-3.  Weekends are
    skipped before any process inspection.  The authoritative trading-day
    decision is made later from the first native XAG D1 bar of the month.
    """

    return 1 <= value.day <= 3 and value.weekday() < 5


def is_first_native_trading_day(value: dt.date, first_bar_epoch: int) -> bool:
    first_bar_date = dt.datetime.fromtimestamp(first_bar_epoch, dt.timezone.utc).date()
    return month_key_for_date(value) == month_key_for_epoch(first_bar_epoch) and first_bar_date == value


def _is_relative_to(path: Path, root: Path) -> bool:
    try:
        path.relative_to(root)
        return True
    except ValueError:
        return False


def _read_json(path: Path) -> dict:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, json.JSONDecodeError) as exc:
        raise RefreshError(f"cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise RefreshError(f"JSON object required: {path}")
    return value


def _write_bytes_create_only(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with path.open("xb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
    except FileExistsError as exc:
        raise RefreshError(f"create-only target already exists: {path}") from exc


def _write_json_create_only(path: Path, payload: dict) -> None:
    _write_bytes_create_only(
        path,
        (json.dumps(payload, indent=2, sort_keys=True) + "\n").encode("utf-8"),
    )


def _read_csv(path: Path, expected_header: list[str], *, encoding: str = "ascii") -> list[dict[str, str]]:
    try:
        with path.open(encoding=encoding, newline="") as handle:
            reader = csv.DictReader(handle)
            if reader.fieldnames != expected_header:
                raise RefreshError(f"CSV header mismatch: {path}")
            return list(reader)
    except (OSError, UnicodeError, csv.Error) as exc:
        raise RefreshError(f"cannot read CSV {path}: {exc}") from exc


def ensure_lf_only(path: Path) -> None:
    raw = path.read_bytes()
    if b"\r" in raw or (raw and not raw.endswith(b"\n")):
        raise RefreshError(f"LF/final-newline contract failed: {path}")


def verify_exact_prefix(prior: Path, candidate: Path) -> dict[str, object]:
    prior_bytes = prior.read_bytes()
    candidate_bytes = candidate.read_bytes()
    if not candidate_bytes.startswith(prior_bytes):
        raise RefreshError("candidate calendar does not preserve the prior calendar byte prefix")
    if len(candidate_bytes) <= len(prior_bytes):
        raise RefreshError("candidate calendar did not append any bytes")
    return {
        "preserved": True,
        "prior_bytes": len(prior_bytes),
        "prior_sha256": sha256_bytes(prior_bytes),
        "appended_bytes": len(candidate_bytes) - len(prior_bytes),
    }


def _validated_native_csv(item: dict, canonical: str) -> tuple[dict, list[int]]:
    try:
        path = Path(str(item["path"])).resolve()
        slot = int(item["slot"])
        expected_rows = int(item["rows"])
        expected_first = int(item["first_epoch"])
        expected_last = int(item["last_epoch"])
    except (KeyError, TypeError, ValueError) as exc:
        raise RefreshError(f"native receipt binding malformed for {canonical}") from exc
    if slot != UNIVERSE.index(canonical):
        raise RefreshError(f"native receipt slot mismatch for {canonical}")
    if item.get("canonical_symbol") != canonical or item.get("native_symbol") != canonical.removesuffix(".DWX"):
        raise RefreshError(f"native symbol mapping mismatch for {canonical}")
    if not path.is_file() or sha256_file(path) != str(item.get("sha256", "")).upper():
        raise RefreshError(f"native file/hash mismatch for {canonical}")

    rows = _read_csv(path, NATIVE_HEADER, encoding="utf-8-sig")
    if len(rows) != expected_rows or len(rows) < 270:
        raise RefreshError(f"native row count invalid for {canonical}")
    epochs: list[int] = []
    for row in rows:
        try:
            epoch = int(row["time"])
            open_price, high, low, close = (
                float(row[name]) for name in ("open", "high", "low", "close")
            )
            tick_volume = int(row["tickvol"])
            spread = int(row["spread"])
        except (KeyError, TypeError, ValueError) as exc:
            raise RefreshError(f"native numeric field invalid for {canonical}") from exc
        if epochs and epoch <= epochs[-1]:
            raise RefreshError(f"native timestamps not strictly increasing for {canonical}")
        if (
            not all(math.isfinite(value) and value > 0.0 for value in (open_price, high, low, close))
            or max(open_price, close) > high
            or min(open_price, close) < low
            or tick_volume < 0
            or spread < 0
        ):
            raise RefreshError(f"native OHLC integrity failed for {canonical}")
        epochs.append(epoch)
    if epochs[0] != expected_first or epochs[-1] != expected_last:
        raise RefreshError(f"native boundary mismatch for {canonical}")
    return item, epochs


def validate_native_export(receipt_path: Path, target_month: int) -> dict[str, object]:
    receipt_path = receipt_path.resolve()
    receipt = _read_json(receipt_path)
    if receipt.get("schema") != "qm.qm1537-native-dwx-d1-export/v1":
        raise RefreshError("native export receipt schema mismatch")
    if receipt.get("status") != "PASS" or receipt.get("account_class") != "Darwinex-Live":
        raise RefreshError("native export receipt is not a Darwinex-Live PASS")
    exports = receipt.get("exports")
    if not isinstance(exports, list) or len(exports) != len(UNIVERSE):
        raise RefreshError("native export receipt must bind exactly 37 exports")
    if [item.get("canonical_symbol") for item in exports] != list(UNIVERSE):
        raise RefreshError("native export universe/order mismatch")

    host_epochs: list[int] = []
    for item, canonical in zip(exports, UNIVERSE):
        _, epochs = _validated_native_csv(item, canonical)
        if canonical == HOST_SYMBOL:
            host_epochs = epochs
    bundle_payload = json.dumps(exports, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    computed_bundle = sha256_bytes(bundle_payload.encode("ascii"))
    declared_bundle = str(receipt.get("input_bundle_sha256", "")).upper()
    if computed_bundle != declared_bundle:
        raise RefreshError("native receipt bundle SHA mismatch")
    target_epochs = [value for value in host_epochs if month_key_for_epoch(value) == target_month]
    if not target_epochs:
        raise RefreshDeferred(f"native XAG D1 has no first bar for {target_month}")
    return {
        "path": str(receipt_path),
        "sha256": sha256_file(receipt_path),
        "input_bundle_sha256": declared_bundle,
        "valid_exports": len(exports),
        "first_host_bar_epoch": target_epochs[0],
        "first_host_bar_utc": utc_iso(dt.datetime.fromtimestamp(target_epochs[0], dt.timezone.utc)),
    }


def _load_exporter_module():
    spec = importlib.util.spec_from_file_location("qm1537_monthly_refresh_exporter", EXPORTER)
    if spec is None or spec.loader is None:
        raise RefreshError(f"cannot import exporter: {EXPORTER}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def assert_t_export_idle_and_bound() -> None:
    exporter = _load_exporter_module()
    terminal = exporter.ROOT / "terminal64.exe"
    if exporter.boot._exact_process_for_path(exporter.boot.scan_terminal_processes(), terminal):
        raise RefreshDeferred("T_Export is active; deferred without interruption")
    _login, server = exporter.boot.load_dxz_factory_login()
    if str(server).lower() != "darwinex-live":
        raise RefreshError(f"T_Export account binding is not Darwinex-Live: {server}")


def run_native_export(
    output_dir: Path,
    target_month: int,
    observed_utc: dt.datetime,
    timeout_seconds: int,
) -> Path:
    to_epoch = int(observed_utc.timestamp()) + 3600
    command = [
        sys.executable,
        str(EXPORTER),
        "--out", str(output_dir),
        "--timeout", str(timeout_seconds),
        "--minimum-last-epoch", str(month_start_epoch(target_month)),
        "--to-epoch", str(to_epoch),
    ]
    creationflags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
    completed = subprocess.run(
        command,
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        timeout=timeout_seconds + 300,
        creationflags=creationflags,
    )
    receipt = output_dir / "export_receipt.json"
    if completed.returncode != 0 or not receipt.is_file():
        tail = (completed.stderr or completed.stdout or "")[-1000:].replace("\n", " ")
        raise RefreshError(f"native export failed exit={completed.returncode}: {tail}")
    return receipt


def _calendar_version(path: Path) -> int:
    match = re.fullmatch(r"QM5_1537_monthly_sleeves_v(\d+)\.csv", path.name)
    if not match:
        raise RefreshError(f"invalid calendar version name: {path}")
    return int(match.group(1))


def discover_latest_calendar() -> tuple[Path, Path, dict]:
    candidates = [
        path for path in CALENDAR_DIR.glob("QM5_1537_monthly_sleeves_v*.csv")
        if re.fullmatch(r"QM5_1537_monthly_sleeves_v\d+\.csv", path.name)
    ]
    if not candidates:
        raise RefreshError("no versioned QM5_1537 calendar found")
    calendar = max(candidates, key=_calendar_version)
    manifest_path = calendar.with_suffix(".manifest.json")
    manifest = _read_json(manifest_path)
    if sha256_file(calendar) != str(manifest.get("calendar_sha256", "")).upper():
        raise RefreshError("latest calendar/manifest SHA mismatch")
    if str(manifest.get("ranking_contract_sha256", "")).upper() == "":
        raise RefreshError("latest manifest lacks ranking contract SHA")
    return calendar, manifest_path, manifest


def calendar_target_rows(calendar: Path, target_month: int) -> list[dict[str, str]]:
    rows = _read_csv(calendar, CALENDAR_HEADER)
    return [
        row for row in rows
        if int(row["month_key"]) == target_month and row["host_symbol"] == HOST_SYMBOL
    ]


def _run_builder(
    prior: Path,
    native_receipt: Path,
    from_month: int,
    to_month: int,
    output: Path,
    manifest: Path,
    sources: Path,
) -> dict:
    command = [
        sys.executable,
        str(BUILDER),
        "--output", str(output),
        "--manifest-output", str(manifest),
        "--from-month", str(from_month),
        "--to-month", str(to_month),
        "--host-symbol", HOST_SYMBOL,
        "--append-v1", str(prior),
        "--native-export-receipt", str(native_receipt),
        "--source-declaration-output", str(sources),
    ]
    completed = subprocess.run(
        command,
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        timeout=300,
    )
    if completed.returncode != 0:
        tail = (completed.stderr or completed.stdout or "")[-2000:].replace("\n", " ")
        raise RefreshError(f"calendar builder failed exit={completed.returncode}: {tail}")
    return _read_json(manifest)


def verify_calendar_candidate(
    prior: Path,
    candidate: Path,
    manifest_path: Path,
    sources_path: Path,
    native: dict[str, object],
    target_month: int,
    *,
    expected_calendar: Path | None = None,
) -> dict[str, object]:
    for path in (candidate, manifest_path, sources_path):
        ensure_lf_only(path)
    prefix = verify_exact_prefix(prior, candidate)
    prior_rows = _read_csv(prior, CALENDAR_HEADER)
    rows = _read_csv(candidate, CALENDAR_HEADER)
    appended = rows[len(prior_rows):]
    if not appended or any(row["host_symbol"] != HOST_SYMBOL for row in appended):
        raise RefreshError("candidate must append only XAG host rows")
    keys = [(int(row["month_key"]), row["host_symbol"]) for row in rows]
    if len(keys) != len(set(keys)):
        raise RefreshError("candidate calendar contains duplicate host/month keys")
    target_rows = [row for row in appended if int(row["month_key"]) == target_month]
    if len(target_rows) != 1:
        raise RefreshError("candidate does not append exactly one target-month XAG row")
    target = target_rows[0]
    manifest = _read_json(manifest_path)
    contract = str(manifest.get("ranking_contract_sha256", "")).upper()
    bundle = str(native["input_bundle_sha256"]).upper()
    if (
        int(target["valid_count"]) != len(UNIVERSE)
        or target["contract_sha256"] != contract
        or target["input_bundle_sha256"] != bundle
        or int(target["asof_epoch"]) != int(native["first_host_bar_epoch"])
    ):
        raise RefreshError("target row lineage/completeness mismatch")
    if sha256_file(candidate) != str(manifest.get("calendar_sha256", "")).upper():
        raise RefreshError("candidate manifest calendar SHA mismatch")
    if contract != str(rows[0]["contract_sha256"]).upper():
        raise RefreshError("ranking contract changed")
    append_manifest = manifest.get("append_only")
    if not isinstance(append_manifest, dict):
        raise RefreshError("candidate manifest lacks append-only evidence")
    if (
        int(append_manifest.get("legacy_prefix_bytes", -1)) != int(prefix["prior_bytes"])
        or str(append_manifest.get("legacy_prefix_sha256", "")).upper() != prefix["prior_sha256"]
    ):
        raise RefreshError("append-only manifest binding mismatch")

    declarations = _read_csv(sources_path, SOURCE_HEADER)
    if len(declarations) != len(rows):
        raise RefreshError("source declaration row count mismatch")
    physical_rows = candidate.read_bytes().splitlines(keepends=True)
    for index, (row, declaration) in enumerate(zip(rows, declarations), start=1):
        if (
            int(declaration["calendar_row"]) != index
            or int(declaration["month_key"]) != int(row["month_key"])
            or declaration["host_symbol"] != row["host_symbol"]
            or declaration["source_bundle_sha256"] != row["input_bundle_sha256"]
            or declaration["row_sha256"] != sha256_bytes(physical_rows[index])
        ):
            raise RefreshError(f"source declaration mismatch at row {index}")
    target_index = rows.index(target)
    if declarations[target_index]["source"] != "native_dwx_d1":
        raise RefreshError("target row is not declared native_dwx_d1")
    declared_source_sha = str(manifest.get("row_source_declaration", {}).get("sha256", "")).upper()
    if sha256_file(sources_path) != declared_source_sha:
        raise RefreshError("source declaration manifest SHA mismatch")

    reproduction = None
    if expected_calendar is not None:
        reproduction = {
            "path": str(expected_calendar.resolve()),
            "expected_sha256": sha256_file(expected_calendar),
            "actual_sha256": sha256_file(candidate),
            "byte_exact": candidate.read_bytes() == expected_calendar.read_bytes(),
        }
        if not reproduction["byte_exact"]:
            raise RefreshError("dry-run candidate is not byte-exact with expected calendar")
        expected_sources = expected_calendar.with_suffix(".sources.csv")
        if expected_sources.is_file() and sources_path.read_bytes() != expected_sources.read_bytes():
            raise RefreshError("dry-run source declaration is not byte-exact")

    return {
        "calendar_sha256": sha256_file(candidate),
        "source_declaration_sha256": sha256_file(sources_path),
        "ranking_contract_sha256": contract,
        "input_bundle_sha256": bundle,
        "row_count": len(rows),
        "appended_row_count": len(appended),
        "target_row": target,
        "prefix": prefix,
        "reproduction": reproduction,
    }


def _replace_unique_line(lines: list[str], prefix: str, replacement: str) -> None:
    matches = [index for index, line in enumerate(lines) if line.startswith(prefix)]
    if len(matches) != 1:
        raise RefreshError(f"preset requires exactly one {prefix!r} line")
    lines[matches[0]] = replacement


def render_versioned_preset(
    source: Path,
    set_version: str,
    calendar_name: str,
    calendar_sha: str,
    contract_sha: str,
    bundle_sha: str,
    observed_date: dt.date,
) -> bytes:
    original = source.read_text(encoding="utf-8-sig").replace("\r\n", "\n").replace("\r", "\n")
    lines = original.splitlines()
    replacements = {
        "; set_version:": f"; set_version:  {set_version}",
        "; date:": f"; date:         {observed_date.isoformat()}",
        "strategy_sleeve_calendar_file=": f"strategy_sleeve_calendar_file={calendar_name}",
        "strategy_sleeve_calendar_sha256=": f"strategy_sleeve_calendar_sha256={calendar_sha}",
        "strategy_sleeve_contract_sha256=": f"strategy_sleeve_contract_sha256={contract_sha}",
        "strategy_sleeve_input_bundle_sha256=": f"strategy_sleeve_input_bundle_sha256={bundle_sha}",
        "; trial_status:": "; trial_status: REVIEW_REATTACH_REQUIRED",
    }
    before = list(lines)
    for prefix, replacement in replacements.items():
        _replace_unique_line(lines, prefix, replacement)
    changed = {index for index, (left, right) in enumerate(zip(before, lines)) if left != right}
    allowed = {
        index for index, line in enumerate(before)
        if any(line.startswith(prefix) for prefix in replacements)
    }
    if changed - allowed:
        raise RefreshError("preset mutation escaped the approved pin/header lines")
    news = [line for line in lines if line.startswith("qm_news_stale_max_hours=")]
    if len(news) != 1 or int(news[0].split("=", 1)[1]) > 336:
        raise RefreshError("preset news-staleness ceiling is absent or above 336")
    if not any(line == "RISK_PERCENT=0.3125" for line in lines):
        raise RefreshError("review preset risk binding changed")
    return ("\n".join(lines) + "\n").encode("utf-8")


def next_preset_target(observed_date: dt.date) -> tuple[Path, str]:
    stamp = observed_date.strftime("%Y%m%d")
    pattern = re.compile(rf"QM5_1537_XAGUSD_D1_live_trial_s{stamp}-(\d{{3}})\.set")
    sequences = [
        int(match.group(1))
        for path in SET_DIR.glob(f"QM5_1537_XAGUSD_D1_live_trial_s{stamp}-*.set")
        if (match := pattern.fullmatch(path.name))
    ]
    sequence = max(sequences, default=0) + 1
    set_version = f"s{stamp}-{sequence:03d}"
    return SET_DIR / f"QM5_1537_XAGUSD_D1_live_trial_{set_version}.set", set_version


def latest_review_preset() -> Path:
    candidates = sorted(SET_DIR.glob("QM5_1537_XAGUSD_D1_live_trial_s*.set"))
    if not candidates:
        raise RefreshError("no prior QM5_1537 XAG review preset exists")
    return candidates[-1]


def owner_reattach_lines(preset_name: str, target_month: int) -> list[str]:
    return [
        "On the FTMO demo XAGUSD D1 chart, remove the existing QM5_1537 instance.",
        f"Attach QM5_1537_aa-vol-sma10.ex5 and load {preset_name}.",
        f"Keep AutoTrading under OWNER control and confirm MONTHLY_SLEEVE_STATE reports month {target_month}, ready=true, valid_count=37.",
    ]


def build_install_candidate(
    calendar: Path,
    manifest: Path,
    sources: Path,
    preset: Path,
    target_month: int,
) -> dict:
    source_files = [
        {"role": "calendar", "path": str(calendar), "sha256": sha256_file(calendar)},
        {"role": "manifest", "path": str(manifest), "sha256": sha256_file(manifest)},
        {"role": "sources", "path": str(sources), "sha256": sha256_file(sources)},
        {"role": "preset", "path": str(preset), "sha256": sha256_file(preset)},
    ]
    return {
        "schema": INSTALL_SCHEMA,
        "status": "REVIEW_REQUIRED",
        "month_key": target_month,
        "created_at_utc": utc_iso(),
        "writes_performed": False,
        "terminal_scope": "FTMO-Demo install candidate only; excludes T_Live and T1-T10",
        "source_files": source_files,
        "copy_plan": [
            {"source": str(calendar), "target": str(COMMON_FILES / calendar.name)},
            {"source": str(calendar), "target": str(COMMON_FILES / "QM/calendars" / calendar.name)},
            {"source": str(manifest), "target": str(COMMON_FILES / "QM/calendars" / manifest.name)},
            {"source": str(sources), "target": str(COMMON_FILES / "QM/calendars" / sources.name)},
            {"source": str(preset), "target": str(FTMO_DEMO_DATA / "MQL5/Presets" / preset.name)},
            {"source": str(preset), "target": str(FTMO_DEMO_DATA / "MQL5/Profiles/Presets/QM_FTMO_M13" / preset.name)},
        ],
        "authority": {
            "install_authorized": False,
            "attachment_authorized": False,
            "autotrading_authorized": False,
            "owner_review_required": True,
        },
        "owner_reattach": owner_reattach_lines(preset.name, target_month),
    }


def base_receipt(run_id: str, mode: str, target_month: int, observed_local: dt.datetime) -> dict:
    return {
        "schema": SCHEMA,
        "run_id": run_id,
        "created_at_utc": utc_iso(),
        "mode": mode,
        "status": "STARTED",
        "month_key": target_month,
        "schedule": {
            "timezone": "Europe/Berlin",
            "observed_local": observed_local.isoformat(timespec="seconds"),
            "days_of_month": [1, 2, 3],
            "local_time": "05:30",
            "window_candidate": schedule_window_candidate(observed_local.date()),
        },
        "safety": {
            "t_export_only": True,
            "t_live_accessed": False,
            "t1_t10_accessed": False,
            "terminal_data_written": False,
            "chart_changed": False,
            "autotrading_changed": False,
            "existing_calendar_overwritten": False,
            "existing_preset_overwritten": False,
        },
        "inputs": {},
        "outputs": {},
        "verification": {},
        "owner_review": {
            "required": mode == "APPLY",
            "state": "REVIEW" if mode == "APPLY" else "NOT_APPLICABLE_DRY_RUN",
            "reattach_instructions": [],
        },
    }


def validate_receipt_schema(receipt: dict) -> None:
    required = {
        "schema", "run_id", "created_at_utc", "mode", "status", "month_key",
        "schedule", "safety", "inputs", "outputs", "verification", "owner_review",
    }
    if not required.issubset(receipt) or receipt.get("schema") != SCHEMA:
        raise RefreshError("refresh receipt schema/required fields invalid")
    if receipt.get("mode") not in {"APPLY", "DRY_RUN"}:
        raise RefreshError("refresh receipt mode invalid")
    safety = receipt.get("safety")
    if not isinstance(safety, dict) or any(
        safety.get(name) is not False
        for name in (
            "t_live_accessed", "t1_t10_accessed", "terminal_data_written",
            "chart_changed", "autotrading_changed", "existing_calendar_overwritten",
            "existing_preset_overwritten",
        )
    ):
        raise RefreshError("refresh receipt safety attestation invalid")
    owner = receipt.get("owner_review")
    if not isinstance(owner, dict) or "required" not in owner or "state" not in owner:
        raise RefreshError("refresh receipt owner-review block invalid")


def receipt_path(evidence_dir: Path, args: argparse.Namespace, run_id: str) -> Path:
    if args.receipt_name:
        if Path(args.receipt_name).name != args.receipt_name:
            raise RefreshError("--receipt-name must be a plain filename")
        return evidence_dir / args.receipt_name
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    return evidence_dir / f"refresh_receipt_{stamp}_{run_id[-8:]}.json"


def write_receipt(path: Path, receipt: dict) -> None:
    validate_receipt_schema(receipt)
    _write_json_create_only(path, receipt)


def _rewrite_staged_manifest(
    staged: Path,
    final_calendar: Path,
    final_sources: Path,
) -> None:
    manifest = _read_json(staged)
    manifest["calendar_path"] = str(final_calendar.resolve())
    declaration = manifest.get("row_source_declaration")
    if not isinstance(declaration, dict):
        raise RefreshError("staged manifest lacks source declaration")
    declaration["path"] = str(final_sources.resolve())
    staged.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8", newline="\n")


def _stage_create_only(staged: Path, final: Path) -> None:
    if final.exists():
        raise RefreshError(f"version target already exists: {final}")
    _write_bytes_create_only(final, staged.read_bytes())


def execute_dry_run(
    args: argparse.Namespace,
    receipt: dict,
    evidence_dir: Path,
    target_month: int,
) -> tuple[dict, Path]:
    if args.native_export_receipt is None or args.reproduce_calendar is None:
        raise RefreshError("dry-run requires --native-export-receipt and --reproduce-calendar")
    expected = args.reproduce_calendar.resolve()
    expected_manifest = _read_json(expected.with_suffix(".manifest.json"))
    append = expected_manifest.get("append_only")
    if not isinstance(append, dict):
        raise RefreshError("reproduction calendar manifest lacks append-only block")
    prior = Path(str(append["legacy_calendar_path"])).resolve()
    from_month = int(append["appended_from_month"])
    native = validate_native_export(args.native_export_receipt, target_month)
    receipt["inputs"] = {
        "prior_calendar": {"path": str(prior), "sha256": sha256_file(prior)},
        "native_export": native,
        "expected_calendar": {"path": str(expected), "sha256": sha256_file(expected)},
    }
    with tempfile.TemporaryDirectory(prefix="qm1537-refresh-dry-") as temporary:
        root = Path(temporary)
        candidate = root / expected.name
        manifest = candidate.with_suffix(".manifest.json")
        sources = candidate.with_suffix(".sources.csv")
        _run_builder(
            prior,
            args.native_export_receipt.resolve(),
            from_month,
            target_month,
            candidate,
            manifest,
            sources,
        )
        verification = verify_calendar_candidate(
            prior,
            candidate,
            manifest,
            sources,
            native,
            target_month,
            expected_calendar=expected,
        )
    receipt["status"] = "PASS"
    receipt["verification"] = verification
    receipt["outputs"] = {
        "production_artifacts_written": False,
        "expected_calendar_verified": str(expected),
    }
    path = receipt_path(evidence_dir, args, receipt["run_id"])
    write_receipt(path, receipt)
    return receipt, path


def execute_apply(
    args: argparse.Namespace,
    receipt: dict,
    evidence_dir: Path,
    target_month: int,
    observed_local: dt.datetime,
) -> tuple[dict, Path]:
    if args.native_export_receipt is not None or args.reproduce_calendar is not None:
        raise RefreshError("normal runs may not inject a fixture receipt or reproduction calendar")
    if not schedule_window_candidate(observed_local.date()):
        receipt["status"] = "NOOP_NOT_SCHEDULE_WINDOW"
        receipt["verification"] = {"no_process_inspection": True, "no_artifacts_written": True}
        path = receipt_path(evidence_dir, args, receipt["run_id"])
        write_receipt(path, receipt)
        return receipt, path

    prior, prior_manifest_path, prior_manifest = discover_latest_calendar()
    existing = calendar_target_rows(prior, target_month)
    receipt["inputs"]["prior_calendar"] = {
        "path": str(prior),
        "sha256": sha256_file(prior),
        "manifest": str(prior_manifest_path),
    }
    if len(existing) > 1:
        raise RefreshError("latest calendar contains duplicate target-month XAG rows")
    if existing:
        receipt["status"] = "NOOP_ALREADY_PRESENT"
        receipt["verification"] = {
            "idempotent": True,
            "existing_target_row": existing[0],
            "no_process_inspection": True,
            "no_artifacts_written": True,
        }
        path = receipt_path(evidence_dir, args, receipt["run_id"])
        write_receipt(path, receipt)
        return receipt, path

    assert_t_export_idle_and_bound()
    export_stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    native_dir = NATIVE_EXPORT_ROOT / f"{export_stamp}_qm1537_refresh_{target_month}_{receipt['run_id'][-8:]}"
    native_receipt_path = run_native_export(
        native_dir,
        target_month,
        observed_local.astimezone(dt.timezone.utc),
        args.export_timeout,
    )
    native = validate_native_export(native_receipt_path, target_month)
    if not is_first_native_trading_day(observed_local.date(), int(native["first_host_bar_epoch"])):
        raise RefreshDeferred(
            "observed local date is not the first native XAG D1 trading date of the month"
        )
    receipt["schedule"]["first_native_host_bar_utc"] = native["first_host_bar_utc"]
    receipt["schedule"]["first_native_trading_day"] = True
    receipt["inputs"]["native_export"] = native

    prior_version = _calendar_version(prior)
    calendar = CALENDAR_DIR / f"QM5_1537_monthly_sleeves_v{prior_version + 1}.csv"
    manifest = calendar.with_suffix(".manifest.json")
    sources = calendar.with_suffix(".sources.csv")
    preset, set_version = next_preset_target(observed_local.date())
    targets = (calendar, manifest, sources, preset)
    if any(path.exists() for path in targets):
        raise RefreshError("one or more create-only version targets already exist")

    with tempfile.TemporaryDirectory(prefix="qm1537-refresh-stage-") as temporary:
        root = Path(temporary)
        staged_calendar = root / calendar.name
        staged_manifest = root / manifest.name
        staged_sources = root / sources.name
        staged_preset = root / preset.name
        _run_builder(
            prior,
            native_receipt_path,
            target_month,
            target_month,
            staged_calendar,
            staged_manifest,
            staged_sources,
        )
        verification = verify_calendar_candidate(
            prior,
            staged_calendar,
            staged_manifest,
            staged_sources,
            native,
            target_month,
        )
        prior_contract = str(prior_manifest.get("ranking_contract_sha256", "")).upper()
        if verification["ranking_contract_sha256"] != prior_contract:
            raise RefreshError("ranking contract changed from the prior manifest")
        staged_preset.write_bytes(
            render_versioned_preset(
                latest_review_preset(),
                set_version,
                calendar.name,
                str(verification["calendar_sha256"]),
                str(verification["ranking_contract_sha256"]),
                str(verification["input_bundle_sha256"]),
                observed_local.date(),
            )
        )
        ensure_lf_only(staged_preset)
        _rewrite_staged_manifest(staged_manifest, calendar, sources)
        ensure_lf_only(staged_manifest)
        for staged, final in zip(
            (staged_calendar, staged_manifest, staged_sources, staged_preset),
            targets,
        ):
            _stage_create_only(staged, final)

    install_candidate = build_install_candidate(
        calendar, manifest, sources, preset, target_month
    )
    install_path = evidence_dir / f"install_candidate_{receipt['run_id'][-8:]}.json"
    _write_json_create_only(install_path, install_candidate)
    receipt["status"] = "REVIEW_REQUIRED"
    receipt["verification"] = verification
    receipt["outputs"] = {
        "calendar": {"path": str(calendar), "sha256": sha256_file(calendar)},
        "manifest": {"path": str(manifest), "sha256": sha256_file(manifest)},
        "sources": {"path": str(sources), "sha256": sha256_file(sources)},
        "preset": {"path": str(preset), "sha256": sha256_file(preset)},
        "install_candidate": {"path": str(install_path), "sha256": sha256_file(install_path)},
        "terminal_files_written": False,
    }
    receipt["owner_review"] = {
        "required": True,
        "state": "REVIEW",
        "reattach_instructions": owner_reattach_lines(preset.name, target_month),
    }
    path = receipt_path(evidence_dir, args, receipt["run_id"])
    write_receipt(path, receipt)
    return receipt, path


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    result.add_argument("--dry-run", action="store_true", help="verify a historical fixture without T_Export or production writes")
    result.add_argument("--month-key", type=int, help="defaults to the current Europe/Berlin month")
    result.add_argument("--native-export-receipt", type=Path, help="dry-run fixture only")
    result.add_argument("--reproduce-calendar", type=Path, help="dry-run expected calendar only")
    result.add_argument("--evidence-dir", type=Path, help="must remain below canonical docs/ops/evidence")
    result.add_argument("--receipt-name", help="optional create-only receipt filename")
    result.add_argument("--export-timeout", type=int, default=1200)
    return result


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    observed_local = dt.datetime.now(TIMEZONE)
    target_month = args.month_key or month_key_for_date(observed_local.date())
    split_month_key(target_month)
    if not args.dry_run and target_month != month_key_for_date(observed_local.date()):
        raise SystemExit("normal run month must equal the current Europe/Berlin month")
    evidence_dir = (
        args.evidence_dir.resolve()
        if args.evidence_dir
        else EVIDENCE_ROOT / f"{observed_local.date().isoformat()}_qm1537_refresh_{target_month}"
    )
    if not _is_relative_to(evidence_dir, EVIDENCE_ROOT.resolve()):
        raise SystemExit("evidence directory must be below canonical docs/ops/evidence")
    evidence_dir.mkdir(parents=True, exist_ok=True)
    run_id = f"{dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S')}-{uuid.uuid4().hex[:12]}"
    mode = "DRY_RUN" if args.dry_run else "APPLY"
    receipt = base_receipt(run_id, mode, target_month, observed_local)
    try:
        if args.dry_run:
            receipt, path = execute_dry_run(args, receipt, evidence_dir, target_month)
        else:
            receipt, path = execute_apply(
                args, receipt, evidence_dir, target_month, observed_local
            )
    except Exception as exc:
        receipt["status"] = "DEFERRED" if isinstance(exc, RefreshDeferred) else "FAIL"
        receipt["error"] = {"type": type(exc).__name__, "message": str(exc)}
        fallback_args = argparse.Namespace(receipt_name=None)
        path = receipt_path(evidence_dir, fallback_args, run_id)
        try:
            write_receipt(path, receipt)
        except Exception as receipt_exc:
            print(json.dumps({
                "status": "FAIL",
                "error": str(exc),
                "receipt_error": str(receipt_exc),
            }))
            return 2
        print(json.dumps({"status": receipt["status"], "error": str(exc), "receipt": str(path)}))
        return 3 if isinstance(exc, RefreshDeferred) else 2
    print(json.dumps({
        "status": receipt["status"],
        "month_key": target_month,
        "receipt": str(path),
    }))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
