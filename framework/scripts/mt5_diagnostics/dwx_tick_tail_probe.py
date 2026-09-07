"""Governed T1 wrapper for the read-only 37-symbol .DWX tick-tail probe."""

from __future__ import annotations

import argparse
import base64
import calendar
import csv
import datetime as dt
import hashlib
import io
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
from typing import Any, Mapping


REPO_ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO_ROOT))
sys.path.insert(0, str(REPO_ROOT / "tools" / "strategy_farm"))

from tools.dukascopy import common as dukascopy_common
from tools.strategy_farm import custom_history_contract
from tools.strategy_farm import custom_history_gate
from tools.strategy_farm import dwx_tick_tail_probe_work_item
from tools.strategy_farm import farmctl
from tools.strategy_farm import ftmo_m1_bootstrap as boot
from tools.strategy_farm import mt5_history_isolation


ROOT = Path("D:/QM/mt5/T1")
SPLICE_ROOT = Path("D:/QM/reports/dukascopy/splice")
SOURCE = Path(__file__).with_name("QM_DWX_Tick_Tail_Probe.mq5")
HISTORY_RANGES = REPO_ROOT / "docs/ops/evidence/2026-09-02_dukascopy_p0_history_ranges.csv"
RAW_HEADER = [
    "symbol",
    "last_tick_time_msc",
    "last_tick_bid",
    "last_tick_ask",
    "tick_count_last_day",
    "first_tick_time_msc",
    "source_terminal",
]
FINAL_HEADER = [
    "symbol",
    "last_tick_time_msc",
    "last_tick_utc",
    "last_tick_bid",
    "last_tick_ask",
    "tick_count_last_day",
    "first_tick_time_msc",
    "source_terminal",
    "probe_sha256",
]
ROW_HASH_CONTRACT = "qm.dwx-tick-tail-row/v1"
SUMMARY_SCHEMA = "qm.dwx-tick-tail-probe-summary/v1"
RECEIPT_SCHEMA = "qm.dwx-tick-tail-probe-receipt/v1"
FORBIDDEN_CUSTOM_WRITE_TOKENS = (
    r"\bCustomTicks(?:Add|Replace|Delete)\s*\(",
    r"\bCustomRates(?:Update|Replace|Delete)\s*\(",
    r"\bCustomSymbol(?:Create|Delete|SetDouble|SetInteger|SetString)\s*\(",
)


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _canonical_bytes(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=True,
        allow_nan=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("ascii")


def _atomic_write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    with temporary.open("w", encoding="utf-8", newline="") as handle:
        handle.write(text)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)


def _atomic_write_json(path: Path, value: object) -> None:
    _atomic_write_text(path, json.dumps(value, indent=2, sort_keys=True) + "\n")


def broker_msc_to_utc(value: int) -> dt.datetime:
    """Decode the Darwinex broker-wall millisecond epoch using qm.dst_rule.us.v1.

    The November repeated hour has two valid UTC candidates. QuantMechanica's
    established MQL/Python policy is deterministic: prefer standard time (+2).
    A spring-forward wall time with no valid candidate is refused.
    """

    raw = int(value)
    if raw <= 0:
        raise ValueError("broker millisecond timestamp must be positive")
    seconds, milliseconds = divmod(raw, 1000)
    wall = dt.datetime.fromtimestamp(seconds, tz=dt.timezone.utc).replace(
        microsecond=milliseconds * 1000
    )
    candidates: list[dt.datetime] = []
    for offset in (2, 3):
        candidate = wall - dt.timedelta(hours=offset)
        if dukascopy_common.darwinex_broker_offset_hours(candidate) == offset:
            candidates.append(candidate)
    if not candidates:
        raise ValueError(f"non-existent Darwinex broker wall time: {raw}")
    return candidates[0]


def _format_utc_milliseconds(value: dt.datetime) -> str:
    return value.astimezone(dt.timezone.utc).isoformat(timespec="milliseconds").replace(
        "+00:00", "Z"
    )


def load_m1_history_ranges(path: Path = HISTORY_RANGES) -> dict[str, dict[str, Any]]:
    with Path(path).open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != [
            "symbol", "period", "first_year", "last_year", "source_terminals"
        ]:
            raise ValueError("P0 history-range schema mismatch")
        rows = [row for row in reader if str(row.get("period") or "").upper() == "M1"]
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        symbol = str(row["symbol"]).strip().upper()
        if symbol in result:
            raise ValueError(f"duplicate M1 history-range row: {symbol}")
        terminals = {
            value.strip().upper()
            for value in str(row["source_terminals"]).split(",")
            if value.strip()
        }
        if "T1" not in terminals:
            raise ValueError(f"P0 history range does not authorize T1: {symbol}")
        result[symbol] = {
            "first_year": int(row["first_year"]),
            "last_year": int(row["last_year"]),
            "source_terminals": sorted(terminals),
        }
    expected = set(dukascopy_common.CANONICAL_SYMBOLS)
    if set(result) != expected or len(result) != 37:
        raise ValueError("P0 M1 history ranges must cover the exact 37-symbol universe")
    return result


def validate_mql_source(path: Path = SOURCE) -> dict[str, Any]:
    source = Path(path).read_text(encoding="utf-8-sig")
    forbidden = [
        pattern
        for pattern in (*boot.FORBIDDEN_MQL_TOKENS, *FORBIDDEN_CUSTOM_WRITE_TOKENS)
        if re.search(pattern, source)
    ]
    if forbidden:
        raise ValueError("MQL probe contains a trading/custom-write API: " + ",".join(forbidden))
    compact = re.sub(r"\s+", "", source).lower()
    if 'root!="d:\\\\qm\\\\mt5\\\\t1"' not in compact:
        raise ValueError("exact T1 MQL path guard absent")
    declared = set(re.findall(r'"([A-Z0-9]+\.DWX)"', source))
    if declared != set(dukascopy_common.CANONICAL_SYMBOLS) or len(declared) != 37:
        raise ValueError("MQL probe universe is not the exact canonical 37")
    if "CopyTicks(" not in source or "CopyTicksRange(" not in source:
        raise ValueError("MQL probe must use read-only CopyTicks and CopyTicksRange")
    return {
        "path": str(Path(path).resolve()),
        "sha256": sha256_file(Path(path)),
        "symbol_count": len(declared),
        "read_only_api": True,
    }


def _probe_row_hash(row: Mapping[str, str]) -> str:
    payload = {"contract": ROW_HASH_CONTRACT, **{key: row[key] for key in FINAL_HEADER[:-1]}}
    return hashlib.sha256(_canonical_bytes(payload)).hexdigest()


def canonicalize_raw_probe(
    raw_path: Path,
    output_path: Path,
    *,
    history_ranges_path: Path = HISTORY_RANGES,
    now_utc: dt.datetime | None = None,
) -> dict[str, Any]:
    ranges = load_m1_history_ranges(history_ranges_path)
    now = (now_utc or dt.datetime.now(dt.timezone.utc)).astimezone(dt.timezone.utc)
    future_limit = dukascopy_common.utc_msc_to_broker_msc(
        int((now + dt.timedelta(days=2)).timestamp() * 1000)
    )
    rows: list[dict[str, str]] = []
    with Path(raw_path).open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != RAW_HEADER:
            raise ValueError("raw tick-tail schema mismatch")
        for raw in reader:
            symbol = str(raw.get("symbol") or "").strip().upper()
            if symbol not in ranges:
                raise ValueError(f"raw tick-tail symbol outside universe: {symbol!r}")
            last_msc = int(raw["last_tick_time_msc"])
            first_msc = int(raw["first_tick_time_msc"])
            day_count = int(raw["tick_count_last_day"])
            bid = float(raw["last_tick_bid"])
            ask = float(raw["last_tick_ask"])
            if (
                first_msc <= 0
                or last_msc < first_msc
                or last_msc > future_limit
                or day_count <= 0
                or not math.isfinite(bid)
                or not math.isfinite(ask)
                or bid <= 0.0
                or ask < bid
                or str(raw.get("source_terminal") or "").strip().upper() != "T1"
            ):
                raise ValueError(f"invalid tick-tail values: {symbol}")
            first_year = broker_msc_to_utc(first_msc).year
            last_year = broker_msc_to_utc(last_msc).year
            if first_year != ranges[symbol]["first_year"]:
                raise ValueError(
                    f"tick head contradicts P0 history range: {symbol} "
                    f"tick={first_year} range={ranges[symbol]['first_year']}"
                )
            if last_year < ranges[symbol]["last_year"]:
                raise ValueError(
                    f"tick tail predates P0 history range: {symbol} "
                    f"tick={last_year} range={ranges[symbol]['last_year']}"
                )
            row = {
                "symbol": symbol,
                "last_tick_time_msc": str(last_msc),
                "last_tick_utc": _format_utc_milliseconds(broker_msc_to_utc(last_msc)),
                "last_tick_bid": format(bid, ".12g"),
                "last_tick_ask": format(ask, ".12g"),
                "tick_count_last_day": str(day_count),
                "first_tick_time_msc": str(first_msc),
                "source_terminal": "T1",
            }
            row["probe_sha256"] = _probe_row_hash(row)
            rows.append(row)
    rows.sort(key=lambda row: row["symbol"])
    if len(rows) != 37 or {row["symbol"] for row in rows} != set(ranges):
        raise ValueError("tick-tail output must contain exactly one row for every canonical symbol")
    stream = io.StringIO(newline="")
    writer = csv.DictWriter(stream, fieldnames=FINAL_HEADER, lineterminator="\n")
    writer.writeheader()
    writer.writerows(rows)
    _atomic_write_text(Path(output_path), stream.getvalue())
    return {
        "path": str(Path(output_path).resolve()),
        "sha256": sha256_file(Path(output_path)),
        "rows": len(rows),
        "schema": FINAL_HEADER,
        "p0_history_ranges_path": str(Path(history_ranges_path).resolve()),
        "p0_history_ranges_sha256": sha256_file(Path(history_ranges_path)),
    }


def _compact_isolation_audit(root: Path) -> dict[str, Any]:
    activation = custom_history_gate.load_activation(root)
    if not activation or activation.get("enabled") is not True:
        raise ValueError("custom-history isolation activation is absent or disabled")
    terminals = tuple(str(value).upper() for value in activation["runner_terminals"])
    if "T1" not in terminals:
        raise ValueError("custom-history isolation activation does not authorize T1")
    audit = mt5_history_isolation.audit_history_isolation(
        mt5_root=ROOT.parent,
        terminals=terminals,
        protected_roots=tuple(activation["protected_roots"]),
        manifest_path=Path(activation["manifest_path"]),
        require_owner_approval=True,
        verify_archive_hashes=False,
        hash_private_terminals=("T1",),
        hash_cache_dir=root / "state" / "custom_history_verify_cache",
        authorized_runner_terminals=terminals,
    )
    file_audit = audit.get("variant_a_file_audit") or {}
    t1 = next(
        (
            row
            for row in file_audit.get("terminal_summaries") or []
            if str(row.get("terminal") or "").upper() == "T1"
        ),
        None,
    )
    if audit.get("status") != "PASS_ISOLATED" or not isinstance(t1, dict):
        raise ValueError("read-only custom-history isolation audit failed closed")
    return {
        "status": audit["status"],
        "activation_sha256": activation["activation_sha256"],
        "manifest_path": activation["manifest_path"],
        "manifest_sha256": activation["manifest_sha256"],
        "audit_sha256": audit["audit_sha256"],
        "file_audit_sha256": file_audit.get("file_audit_sha256"),
        "archive_hash_verification": file_audit.get("archive_hash_verification"),
        "terminal_private_hash_verification": file_audit.get(
            "terminal_private_hash_verification"
        ),
        "t1_inventory": t1,
    }


def _signed_archive_snapshot(manifest_path: Path) -> dict[str, Any]:
    manifest = custom_history_contract.load_manifest(
        Path(manifest_path), require_owner_approval=True
    )
    if manifest.get("archive_years") != list(range(2017, 2026)):
        raise ValueError("signed archive years are not the exact 2017-2025 range")
    source = Path(str(manifest["source_custom"]))
    if source.resolve() != (ROOT / "Bases/Custom").resolve():
        raise ValueError("signed archive source is not T1 Bases/Custom")
    identities: list[dict[str, Any]] = []
    for row in manifest["files"]:
        relative = str(row["relative_path"])
        path = source / Path(relative)
        identity = custom_history_contract.file_identity(path)
        if int(identity["size"]) != int(row["size"]):
            raise ValueError(f"signed archive size mismatch: {relative}")
        identities.append(
            {
                "relative_path": relative,
                "size": int(identity["size"]),
                "mtime_ns": int(identity["mtime_ns"]),
                "file_id": str(identity["file_id"]),
                "manifest_sha256": str(row["sha256"]),
            }
        )
    snapshot_sha256 = hashlib.sha256(_canonical_bytes(identities)).hexdigest()
    return {
        "manifest_sha256": manifest["manifest_sha256"],
        "archive_years": manifest["archive_years"],
        "file_count": len(identities),
        "total_bytes": sum(row["size"] for row in identities),
        "t1_archive_inventory_sha256": snapshot_sha256,
    }


def _validate_claim(root: Path, work_item_id: str, out: Path) -> dict[str, Any]:
    if os.environ.get("QM_DWX_TICK_TAIL_WORK_ITEM_ID") != work_item_id:
        raise ValueError("tick-tail wrapper lacks the exact work-item environment binding")
    if os.environ.get("QM_DWX_TICK_TAIL_CLAIMED_TERMINAL", "").upper() != "T1":
        raise ValueError("tick-tail wrapper lacks the exact T1 claim environment binding")
    with farmctl.connect(root) as connection:
        row = connection.execute(
            "SELECT * FROM work_items WHERE id=?", (work_item_id,)
        ).fetchone()
    if row is None:
        raise ValueError("tick-tail work item is absent")
    payload = json.loads(row["payload_json"] or "{}")
    dwx_tick_tail_probe_work_item.validate_payload(
        payload, terminal="T1", verify_files=True
    )
    if (
        str(row["status"]) != "active"
        or str(row["claimed_by"]).upper() != "T1"
        or str(row["kind"]) != farmctl.DIAGNOSTIC_WORK_ITEM_KIND
        or str(row["phase"]) != farmctl.DWX_TICK_TAIL_PROBE_PHASE
        or payload.get("diagnostic_contract") != farmctl.DWX_TICK_TAIL_PROBE_CONTRACT
        or payload.get("diagnostic_non_admission") is not True
        or payload.get("diagnostic_allowed_terminals") != ["T1"]
        or payload.get("probe_stamp") != out.name
        or Path(str(payload.get("output_dir") or "")).resolve() != out
    ):
        raise ValueError("tick-tail work-item claim contract mismatch")
    return {"row": dict(row), "payload": payload}


def _owned_match(row: dict[str, Any], ini: Path, started: dt.datetime) -> dict[str, Any] | None:
    terminal = ROOT / "terminal64.exe"
    if boot._windows_path_key(row.get("ExecutablePath", "")) != boot._windows_path_key(terminal):
        return None
    if str(ini).lower() not in str(row.get("CommandLine", "")).lower():
        return None
    identity = boot.process_identity(row, "owned T1 DWX tick-tail probe")
    creation = dt.datetime.fromisoformat(identity["creation_date_utc"].replace("Z", "+00:00"))
    return identity if creation >= started - dt.timedelta(seconds=2) else None


def _terminate_owned(identity: Mapping[str, Any], ini: Path) -> dict[str, Any]:
    encoded = base64.b64encode(str(ini).encode()).decode()
    pid = int(identity["pid"])
    creation = str(identity["creation_date_utc"])
    return boot._powershell_json(f"""
$expectedConfig=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{encoded}'))
$row=Get-CimInstance Win32_Process -Filter 'ProcessId={pid}' -ErrorAction Stop
if ($null -eq $row -or $row.ExecutablePath -ine 'D:\\QM\\mt5\\T1\\terminal64.exe') {{ throw 'Owned probe path drift' }}
if ($row.CreationDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') -ne '{creation}') {{ throw 'Owned probe creation drift' }}
if (-not ([string]$row.CommandLine).ToLowerInvariant().Contains($expectedConfig.ToLowerInvariant())) {{ throw 'Owned probe config drift' }}
$r=Invoke-CimMethod -InputObject $row -MethodName Terminate -Arguments @{{Reason=0}}
if ($r.ReturnValue -ne 0) {{ throw 'Owned probe termination failed' }}
@{{terminated=$true;pid={pid}}} | ConvertTo-Json -Compress
""")


def _summary_path_guard(summary_path: Path, work_item_id: str) -> Path:
    resolved = Path(summary_path).resolve()
    expected = (
        Path("D:/QM/reports/work_items")
        / work_item_id
        / farmctl.DWX_TICK_TAIL_PROBE_EA_ID
        / farmctl.DWX_TICK_TAIL_PROBE_PHASE
        / "summary.json"
    ).resolve()
    if resolved != expected:
        raise ValueError("summary path must be the exact diagnostic work-item summary")
    return resolved


def run(
    out: Path,
    summary_path: Path,
    work_item_id: str,
    farm_root: Path,
    *,
    timeout: int = 1800,
) -> dict[str, Any]:
    out = Path(out).resolve()
    summary_path = _summary_path_guard(summary_path, work_item_id)
    farm_root = Path(farm_root).resolve()
    boot._safe_tag(out.name)
    if not 300 <= int(timeout) <= 3600:
        raise ValueError("probe timeout must be 300..3600 seconds")
    if out.parent != SPLICE_ROOT.resolve() or out.exists():
        raise ValueError("probe output must be a new direct child of the splice root")
    if (farm_root / "state/FACTORY_OFF.flag").exists():
        raise ValueError("factory is administratively OFF; production probe refused")
    claim = _validate_claim(farm_root, work_item_id, out)
    source_binding = validate_mql_source(SOURCE)
    terminal = ROOT / "terminal64.exe"
    if boot._exact_process_for_path(boot.scan_terminal_processes(), terminal):
        raise ValueError("T1 is already active; defer without interruption")

    out.mkdir(parents=True)
    result: dict[str, Any] = {
        "schema_version": RECEIPT_SCHEMA,
        "status": "FAIL",
        "no_gate_verdict": True,
        "work_item_id": work_item_id,
        "phase": farmctl.DWX_TICK_TAIL_PROBE_PHASE,
        "terminal_claim": "T1",
        "probe_stamp": out.name,
        "started_at_utc": boot.utc_now(),
        "source": source_binding,
        "history_ranges": boot.file_binding(HISTORY_RANGES),
        "work_item_payload_sha256": hashlib.sha256(
            str(claim["row"]["payload_json"]).encode("utf-8")
        ).hexdigest(),
        "config_safety": {
            "Enabled": 0,
            "AllowLiveTrading": 0,
            "AllowDllImport": 0,
            "terminal_path": str(terminal),
            "manual_terminal_start": False,
        },
    }
    process: subprocess.Popen[bytes] | None = None
    identity: dict[str, Any] | None = None
    ini: Path | None = None
    raw_terminal_path: Path | None = None
    pre_snapshot: dict[str, Any] | None = None
    try:
        pre_audit = _compact_isolation_audit(farm_root)
        if (
            pre_audit.get("manifest_sha256") != claim["payload"].get("manifest_sha256")
            or Path(str(pre_audit.get("manifest_path") or "")).resolve()
            != Path(str(claim["payload"].get("manifest_path") or "")).resolve()
        ):
            raise ValueError("active signed archive differs from the claimed manifest")
        pre_snapshot = _signed_archive_snapshot(Path(pre_audit["manifest_path"]))
        result["custom_history_pre_audit"] = pre_audit
        result["signed_archive_before"] = pre_snapshot

        with boot.exclusive_bootstrap_lock(
            farm_root / "state" / "locks" / "t1_dwx_tick_tail_probe.lock"
        ):
            editor = ROOT / "MetaEditor64.exe"
            if any(
                boot._windows_path_key(row.get("ExecutablePath", ""))
                == boot._windows_path_key(editor)
                for row in boot.scan_metaeditor_processes()
            ):
                raise ValueError("T1 MetaEditor is already active")
            staged = ROOT / "MQL5/Scripts/QM/dwx_tick_tail" / out.name / SOURCE.name
            if staged.exists() or staged.with_suffix(".ex5").exists():
                raise ValueError("probe script staging path already exists")
            staged.parent.mkdir(parents=True, exist_ok=False)
            shutil.copyfile(SOURCE, staged)
            compile_log = out / "compile.log"
            compiled = subprocess.run(
                [str(editor), f"/compile:{staged}", f"/log:{compile_log}"],
                cwd=ROOT,
                capture_output=True,
                timeout=180,
                creationflags=subprocess.CREATE_NO_WINDOW,
                check=False,
            )
            counts = re.findall(r"(\d+) errors?, (\d+) warnings?", boot._read_text_auto(compile_log))
            ex5 = staged.with_suffix(".ex5")
            if (
                compiled.returncode not in (0, 1)
                or not counts
                or counts[-1] != ("0", "0")
                or not ex5.is_file()
            ):
                raise ValueError("probe compile did not pass 0 errors / 0 warnings")
            compiled_dir = out / "compiled"
            compiled_dir.mkdir()
            shutil.copyfile(staged, compiled_dir / staged.name)
            shutil.copyfile(ex5, compiled_dir / ex5.name)
            result["compile"] = {
                "exit_code": compiled.returncode,
                "errors": 0,
                "warnings": 0,
                "log": boot.file_binding(compile_log),
                "source": boot.file_binding(compiled_dir / staged.name),
                "ex5": boot.file_binding(compiled_dir / ex5.name),
            }

            output_rel = f"QM\\dwx_tick_tail\\{out.name}\\tick_tail_raw.csv"
            marker_name = f"QM_DWX_TICK_TAIL_COMPLETE_{out.name}.txt"
            raw_terminal_path = ROOT / "MQL5/Files/QM/dwx_tick_tail" / out.name / "tick_tail_raw.csv"
            marker = ROOT / "MQL5/Files" / marker_name
            if raw_terminal_path.exists() or marker.exists():
                raise ValueError("probe terminal output path already exists")
            preset = ROOT / "MQL5/Presets" / f"QM_DWX_TICK_TAIL_{out.name}.set"
            boot.atomic_write_text(
                preset,
                "\n".join(
                    [
                        f"InpOutputFile={output_rel}",
                        f"InpCompletion={marker_name}",
                        "InpSyncAttempts=90",
                        "",
                    ]
                ),
            )
            login, server = boot.load_dxz_factory_login()
            if server.lower() != "darwinex-live":
                raise ValueError(f"refused non-Darwinex-Live server: {server}")
            ini = out / "startup.ini"
            boot.atomic_write_text(
                ini,
                "\n".join(
                    [
                        "[Common]",
                        f"Login={login}",
                        f"Server={server}",
                        "[Experts]",
                        "Enabled=0",
                        "AllowLiveTrading=0",
                        "AllowDllImport=0",
                        "[StartUp]",
                        f"Script=QM\\dwx_tick_tail\\{out.name}\\QM_DWX_Tick_Tail_Probe",
                        f"ScriptParameters={preset.name}",
                        "Symbol=EURUSD.DWX",
                        "Period=M1",
                        "ShutdownTerminal=0",
                        "",
                    ]
                ),
            )
            _validate_claim(farm_root, work_item_id, out)
            if (farm_root / "state/FACTORY_OFF.flag").exists():
                raise ValueError("factory became administratively OFF before launch")
            if boot._exact_process_for_path(boot.scan_terminal_processes(), terminal):
                raise ValueError("T1 ceased being idle before launch")
            started = dt.datetime.now(dt.timezone.utc)
            process = subprocess.Popen(
                [str(terminal), "/portable", f"/config:{ini}"],
                cwd=ROOT,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                creationflags=subprocess.CREATE_NO_WINDOW,
            )
            result["launched_pid"] = process.pid
            result["startup_ini"] = boot.file_binding(ini)
            deadline = time.monotonic() + int(timeout)
            while time.monotonic() < deadline:
                matches = [
                    value
                    for row in boot.scan_terminal_processes()
                    if (value := _owned_match(row, ini, started))
                ]
                if matches:
                    if len(matches) != 1:
                        raise ValueError("owned T1 probe config/path is not unique")
                    identity = matches[0]
                if (
                    process.poll() is not None
                    and identity is None
                    and dt.datetime.now(dt.timezone.utc) - started > dt.timedelta(seconds=20)
                ):
                    raise ValueError("owned probe terminal exited before identity binding")
                if marker.is_file() and identity is not None:
                    result["completion"] = marker.read_text(encoding="utf-8-sig").strip()
                    break
                time.sleep(1)
            else:
                raise TimeoutError("DWX tick-tail probe timed out")
    except Exception as exc:
        result["error"] = f"{type(exc).__name__}: {exc}"
    finally:
        if identity is not None and ini is not None:
            try:
                result["termination"] = _terminate_owned(identity, ini)
                result["terminated_owned_pid"] = identity["pid"]
            except Exception as exc:
                result["cleanup_error"] = f"{type(exc).__name__}: {exc}"
        result["process_identity"] = identity
        try:
            post_audit = _compact_isolation_audit(farm_root)
            post_snapshot = _signed_archive_snapshot(Path(post_audit["manifest_path"]))
            result["custom_history_post_audit"] = post_audit
            result["signed_archive_after"] = post_snapshot
            result["signed_archive_unchanged"] = bool(
                pre_snapshot is not None and pre_snapshot == post_snapshot
            )
        except Exception as exc:
            result["post_audit_error"] = f"{type(exc).__name__}: {exc}"
            result["signed_archive_unchanged"] = False

        if raw_terminal_path is not None and raw_terminal_path.is_file():
            try:
                raw_copy = out / "tick_tail_raw.csv"
                shutil.copyfile(raw_terminal_path, raw_copy)
                result["raw_csv"] = boot.file_binding(raw_copy)
                result["tick_tail_csv"] = canonicalize_raw_probe(
                    raw_copy, out / "tick_tail.csv"
                )
            except Exception as exc:
                result["output_error"] = f"{type(exc).__name__}: {exc}"

        result["completed_at_utc"] = boot.utc_now()
        result["status"] = "PASS" if (
            "error" not in result
            and "cleanup_error" not in result
            and "post_audit_error" not in result
            and "output_error" not in result
            and result.get("completion", "").startswith(
                "successes=37 failures=0 terminal=T1 "
            )
            and result.get("signed_archive_unchanged") is True
            and (result.get("tick_tail_csv") or {}).get("rows") == 37
        ) else "FAIL"
        receipt_path = out / "probe_receipt.json"
        _atomic_write_json(receipt_path, result)
        summary = {
            "schema_version": SUMMARY_SCHEMA,
            # Claim freshness uses run_tag. The output stamp can predate the
            # eventual T1 claim while a pending row waits in the queue, so keep
            # the two identities explicit instead of making fresh evidence look
            # stale merely because it was enqueued earlier.
            "run_tag": dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d_%H%M%S"),
            "probe_stamp": out.name,
            "status": result["status"],
            "verdict": "REVIEW_REQUIRED" if result["status"] == "PASS" else "INFRA_FAIL",
            "no_gate_verdict": True,
            "work_item_id": work_item_id,
            "terminal": "T1",
            "probe_receipt_path": str(receipt_path),
            "probe_receipt_sha256": sha256_file(receipt_path),
            "tick_tail_csv": result.get("tick_tail_csv"),
            "signed_archive_unchanged": result.get("signed_archive_unchanged", False),
            "completed_at_utc": result["completed_at_utc"],
            "error": result.get("error") or result.get("output_error") or result.get("post_audit_error"),
        }
        _atomic_write_json(summary_path, summary)
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--summary", required=True, type=Path)
    parser.add_argument("--work-item-id", required=True)
    parser.add_argument("--farm-root", required=True, type=Path)
    parser.add_argument("--timeout", type=int, default=1800)
    args = parser.parse_args(argv)
    result = run(
        args.out,
        args.summary,
        args.work_item_id,
        args.farm_root,
        timeout=args.timeout,
    )
    print(
        json.dumps(
            {
                "status": result["status"],
                "receipt": str(Path(args.out) / "probe_receipt.json"),
                "tick_tail_csv": (result.get("tick_tail_csv") or {}).get("path"),
            },
            sort_keys=True,
        )
    )
    return 0 if result["status"] == "PASS" else 2


if __name__ == "__main__":
    raise SystemExit(main())
