"""Controlled T_Export StartUp wrapper for the QM5_1537 native D1 snapshot."""
from __future__ import annotations

import argparse
import base64
import csv
import datetime as dt
import hashlib
import json
import math
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

sys.path.insert(0, "C:/QM/repo/tools/strategy_farm")
import ftmo_m1_bootstrap as boot

ROOT = Path("D:/QM/mt5/T_Export")
STAGING = Path("D:/QM/reports/qm1537_native_d1")
SOURCE = Path(__file__).with_name("QM_1537_Native_D1_Export.mq5")
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
NATIVE_BY_CANONICAL = {symbol: symbol.removesuffix(".DWX") for symbol in UNIVERSE}
HEADER = ["time", "open", "high", "low", "close", "tickvol", "spread"]
DEFAULT_FROM_EPOCH = 1672531200  # 2023-01-01 00:00:00 UTC
DEFAULT_TO_EPOCH = 1788825600  # 2026-09-08 00:00:00 UTC (fixture-compatible default)
MIN_LAST_EPOCH = 1788220800  # 2026-09-01 00:00:00 UTC (fixture-compatible default)
MAX_FUTURE_SKEW_SECONDS = 2 * 86400


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def validate_output(path: Path, canonical: str, minimum_last_epoch: int = MIN_LAST_EPOCH) -> dict:
    rows = 0
    first = last = prior = None
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != HEADER:
            raise ValueError(f"D1 schema invalid: {path}")
        for row in reader:
            epoch = int(row["time"])
            prices = [float(row[name]) for name in ("open", "high", "low", "close")]
            ticks = int(row["tickvol"])
            spread = int(row["spread"])
            if prior is not None and epoch <= prior:
                raise ValueError(f"D1 time order/duplicate invalid: {path}")
            if (not all(math.isfinite(value) and value > 0 for value in prices)
                    or ticks < 0 or spread < 0):
                raise ValueError(f"D1 numeric value invalid: {path}")
            if max(prices[0], prices[3]) > prices[1] or min(prices[0], prices[3]) < prices[2]:
                raise ValueError(f"D1 OHLC relation invalid: {path}")
            first = epoch if first is None else first
            last = prior = epoch
            rows += 1
    if rows < 270 or last is None or last < minimum_last_epoch:
        raise ValueError(f"D1 export incomplete: {path} rows={rows} last={last}")
    return {
        "slot": UNIVERSE.index(canonical),
        "canonical_symbol": canonical,
        "native_symbol": NATIVE_BY_CANONICAL[canonical],
        "path": str(path.resolve()),
        "sha256": sha256_file(path),
        "bytes": path.stat().st_size,
        "rows": rows,
        "first_epoch": first,
        "last_epoch": last,
        "schema": HEADER,
    }


def input_bundle_sha256(exports: list[dict]) -> str:
    payload = json.dumps(exports, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(payload.encode("ascii")).hexdigest().upper()


def owned_match(row: dict, ini: Path, started: dt.datetime):
    if boot._windows_path_key(row.get("ExecutablePath", "")) != boot._windows_path_key(ROOT / "terminal64.exe"):
        return None
    if str(ini).lower() not in str(row.get("CommandLine", "")).lower():
        return None
    identity = boot.process_identity(row, "owned T_Export QM5_1537 D1")
    creation = dt.datetime.fromisoformat(identity["creation_date_utc"].replace("Z", "+00:00"))
    return identity if creation >= started - dt.timedelta(seconds=2) else None


def terminate_owned(identity: dict, ini: Path):
    encoded = base64.b64encode(str(ini).encode()).decode()
    pid = int(identity["pid"])
    creation = identity["creation_date_utc"]
    return boot._powershell_json(f"""
$expectedConfig=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('{encoded}'))
$row=Get-CimInstance Win32_Process -Filter 'ProcessId={pid}' -ErrorAction Stop
if ($null -eq $row -or $row.ExecutablePath -ine 'D:\\QM\\mt5\\T_Export\\terminal64.exe') {{ throw 'Owned export path drift' }}
if ($row.CreationDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') -ne '{creation}') {{ throw 'Owned export creation drift' }}
if (-not ([string]$row.CommandLine).ToLowerInvariant().Contains($expectedConfig.ToLowerInvariant())) {{ throw 'Owned export config drift' }}
$r=Invoke-CimMethod -InputObject $row -MethodName Terminate -Arguments @{{Reason=0}}
if ($r.ReturnValue -ne 0) {{ throw 'Owned export termination failed' }}
@{{terminated=$true;pid={pid}}} | ConvertTo-Json -Compress
""")


def run(
    out: Path,
    timeout: int = 1200,
    *,
    minimum_last_epoch: int = MIN_LAST_EPOCH,
    to_epoch: int = DEFAULT_TO_EPOCH,
) -> dict:
    out = out.resolve()
    boot._safe_tag(out.name)
    if not 300 <= timeout <= 1800:
        raise ValueError("export timeout must be 300..1800 seconds")
    now_epoch = int(dt.datetime.now(dt.timezone.utc).timestamp())
    if not DEFAULT_FROM_EPOCH <= minimum_last_epoch < to_epoch:
        raise ValueError("export range must satisfy from <= minimum_last < to")
    if to_epoch > now_epoch + MAX_FUTURE_SKEW_SECONDS:
        raise ValueError("export end is more than two days in the future")
    if STAGING.resolve() not in out.parents or out.exists():
        raise ValueError("run must use a new QM5_1537 staging child")
    terminal = ROOT / "terminal64.exe"
    if boot._exact_process_for_path(boot.scan_terminal_processes(), terminal):
        raise ValueError("T_Export already active; defer without interruption")
    source = SOURCE.read_text(encoding="utf-8-sig")
    if any(re.search(pattern, source) for pattern in boot.FORBIDDEN_MQL_TOKENS):
        raise ValueError("trading API in D1 exporter")
    if 'root!="d:\\\\qm\\\\mt5\\\\t_export"' not in source:
        raise ValueError("exact T_Export MQL path guard absent")

    out.mkdir(parents=True)
    run_tag = out.name
    output_rel = f"QM\\1537_native_d1\\{run_tag}"
    output_dir = ROOT / "MQL5/Files/QM/1537_native_d1" / run_tag
    if output_dir.exists():
        raise ValueError("immutable output directory already exists")
    output_dir.mkdir(parents=True)
    result = {
        "schema": "qm.qm1537-native-dwx-d1-export/v1",
        "production_write": False,
        "mechanism": "ftmo_m1_bootstrap StartUp; exact dedicated T_Export lane",
        "requested_range": {"from_epoch": DEFAULT_FROM_EPOCH, "to_epoch": to_epoch},
        "minimum_last_epoch": minimum_last_epoch,
        "account_class": "Darwinex-Live",
        "symbol_mapping": NATIVE_BY_CANONICAL,
        "bootstrap": boot.file_binding(Path(boot.__file__)),
        "source": boot.file_binding(SOURCE),
    }
    with boot.exclusive_bootstrap_lock(STAGING / "t_export_qm1537_native_d1.lock"):
        editor = ROOT / "MetaEditor64.exe"
        if any(boot._windows_path_key(row.get("ExecutablePath", "")) == boot._windows_path_key(editor)
               for row in boot.scan_metaeditor_processes()):
            raise ValueError("T_Export MetaEditor busy")
        staged = ROOT / "MQL5/Scripts/QM/qm1537_native_d1" / run_tag / SOURCE.name
        if staged.exists():
            raise ValueError("staged script already exists; preserve previous run")
        staged.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(SOURCE, staged)
        log = out / "compile.log"
        compiled = subprocess.run([str(editor), f"/compile:{staged}", f"/log:{log}"], cwd=ROOT,
                                  capture_output=True, timeout=180, creationflags=subprocess.CREATE_NO_WINDOW)
        counts = re.findall(r"(\d+) errors?, (\d+) warnings?", boot._read_text_auto(log))
        if compiled.returncode not in (0, 1) or not counts or counts[-1] != ("0", "0"):
            raise ValueError("compile did not pass 0E/0W: " + str(counts))
        result["compile"] = {"exit_code": compiled.returncode, "errors": 0, "warnings": 0,
                             "log": boot.file_binding(log), "ex5": boot.file_binding(staged.with_suffix(".ex5"))}

        marker_name = f"QM1537_NATIVE_D1_COMPLETE_{run_tag}.txt"
        preset = ROOT / "MQL5/Presets" / f"QM1537_NATIVE_D1_{run_tag}.set"
        boot.atomic_write_text(preset, "\n".join([
            f"InpFrom={DEFAULT_FROM_EPOCH}", f"InpTo={to_epoch}",
            f"InpMinimumLast={minimum_last_epoch}",
            f"InpOutputDir={output_rel}", f"InpCompletion={marker_name}", "",
        ]))
        login, server = boot.load_dxz_factory_login()
        if server.lower() != "darwinex-live":
            raise ValueError(f"refused non-Darwinex-Live server: {server}")
        ini = out / "startup.ini"
        boot.atomic_write_text(ini, "\n".join([
            "[Common]", f"Login={login}", f"Server={server}", "[Experts]", "Enabled=0",
            "AllowLiveTrading=0", "AllowDllImport=0", "[StartUp]",
            f"Script=QM\\qm1537_native_d1\\{run_tag}\\QM_1537_Native_D1_Export",
            f"ScriptParameters={preset.name}", "Symbol=EURUSD", "Period=D1", "ShutdownTerminal=0", "",
        ]))
        if boot._exact_process_for_path(boot.scan_terminal_processes(), terminal):
            raise ValueError("T_Export ceased being idle before launch")
        started = dt.datetime.now(dt.timezone.utc)
        process = subprocess.Popen([str(terminal), "/portable", f"/config:{ini}"], cwd=ROOT,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        result["launched_pid"] = process.pid
        result["startup_ini"] = boot.file_binding(ini)
        marker = ROOT / "MQL5/Files" / marker_name
        identity = None
        deadline = time.monotonic() + timeout
        try:
            while time.monotonic() < deadline:
                matches = [value for row in boot.scan_terminal_processes() if (value := owned_match(row, ini, started))]
                if matches:
                    if len(matches) != 1:
                        raise ValueError("owned T_Export config/path is not unique")
                    identity = matches[0]
                if process.poll() is not None and not identity and dt.datetime.now(dt.timezone.utc) - started > dt.timedelta(seconds=20):
                    raise ValueError("owned exporter process exited early")
                if marker.is_file() and identity:
                    result["completion"] = marker.read_text(encoding="utf-8-sig").strip()
                    break
                time.sleep(1)
            else:
                result["error"] = "D1 export timed out"
        finally:
            if identity:
                try:
                    result["termination"] = terminate_owned(identity, ini)
                    result["terminated_owned_pid"] = identity["pid"]
                except Exception as exc:
                    result["cleanup_error"] = str(exc)
            result["process_identity"] = identity
            result["exports"] = []
            for canonical in UNIVERSE:
                path = output_dir / f"{canonical}_D1.csv"
                try:
                    result["exports"].append(
                        validate_output(path, canonical, minimum_last_epoch)
                    )
                except (OSError, ValueError, KeyError) as exc:
                    result["exports"].append({"canonical_symbol": canonical, "path": str(path), "error": str(exc)})
            valid = [item for item in result["exports"] if "error" not in item]
            if len(valid) == len(UNIVERSE):
                result["input_bundle_sha256"] = input_bundle_sha256(valid)
            result["status"] = "PASS" if (
                "cleanup_error" not in result
                and result.get("completion", "").startswith("successes=37 failures=0 server=Darwinex-Live ")
                and len(valid) == len(UNIVERSE)
            ) else "FAIL"
            boot.atomic_write_json(out / "export_receipt.json", result)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--timeout", type=int, default=1200)
    parser.add_argument("--minimum-last-epoch", type=int, default=MIN_LAST_EPOCH)
    parser.add_argument("--to-epoch", type=int, default=DEFAULT_TO_EPOCH)
    args = parser.parse_args()
    result = run(
        args.out,
        args.timeout,
        minimum_last_epoch=args.minimum_last_epoch,
        to_epoch=args.to_epoch,
    )
    print(json.dumps({"status": result["status"], "valid_exports": sum("error" not in x for x in result["exports"]),
                      "receipt": str(args.out / "export_receipt.json")}))
    raise SystemExit(0 if result["status"] == "PASS" else 2)
