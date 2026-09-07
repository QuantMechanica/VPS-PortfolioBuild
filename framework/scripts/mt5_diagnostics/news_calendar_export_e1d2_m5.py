"""Controlled T_Export StartUp wrapper for the E1-D2 M5 footprint exports."""
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
STAGING = Path("D:/QM/reports/news_calendar/repair_e1a")
SOURCE = Path(__file__).with_name("QM_NewsCalendar_E1D2_M5_Export.mq5")
OUTPUTS = ("AUDUSD.DWX_M5.csv", "USDCAD.DWX_M5.csv")
HEADER = ["time", "open", "high", "low", "close", "tickvol"]


def validate_output(path: Path) -> dict:
    digest = hashlib.sha256()
    rows = 0
    first = last = prior = None
    with path.open("rb") as raw:
        for block in iter(lambda: raw.read(1024 * 1024), b""):
            digest.update(block)
    with path.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != HEADER:
            raise ValueError(f"M5 schema invalid: {path}")
        for row in reader:
            epoch = int(row["time"])
            prices = [float(row[name]) for name in ("open", "high", "low", "close")]
            ticks = int(row["tickvol"])
            if prior is not None and epoch <= prior:
                raise ValueError(f"M5 time order/duplicate invalid: {path}")
            if not all(math.isfinite(value) for value in prices) or ticks < 0:
                raise ValueError(f"M5 numeric value invalid: {path}")
            if max(prices[0], prices[3]) > prices[1] or min(prices[0], prices[3]) < prices[2] or prices[2] > prices[1]:
                raise ValueError(f"M5 OHLC relation invalid: {path}")
            first = epoch if first is None else first
            last = prior = epoch
            rows += 1
    if rows < 100_000:
        raise ValueError(f"M5 export unexpectedly short: {path} rows={rows}")
    return {
        "path": str(path.resolve()),
        "sha256": digest.hexdigest(),
        "bytes": path.stat().st_size,
        "rows": rows,
        "first_broker_epoch": first,
        "last_broker_epoch": last,
        "schema": HEADER,
    }


def owned_match(row: dict, ini: Path, started: dt.datetime):
    if boot._windows_path_key(row.get("ExecutablePath", "")) != boot._windows_path_key(ROOT / "terminal64.exe"):
        return None
    if str(ini).lower() not in str(row.get("CommandLine", "")).lower():
        return None
    identity = boot.process_identity(row, "owned T_Export E1-D2")
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


def run(out: Path, timeout: int = 900) -> dict:
    out = out.resolve()
    boot._safe_tag(out.name)
    if not 60 <= timeout <= 1200:
        raise ValueError("export timeout must be 60..1200 seconds")
    if STAGING.resolve() not in out.parents or out.exists():
        raise ValueError("run must use a new E1-A staging child")
    terminal = ROOT / "terminal64.exe"
    if boot._exact_process_for_path(boot.scan_terminal_processes(), terminal):
        raise ValueError("T_Export already active; defer without interruption")
    for name in OUTPUTS:
        if (ROOT / "MQL5/Files" / name).exists():
            raise ValueError("existing export refused: " + name)
    source = SOURCE.read_text(encoding="utf-8-sig")
    if any(re.search(pattern, source) for pattern in boot.FORBIDDEN_MQL_TOKENS):
        raise ValueError("trading API in M5 exporter")
    if 'root!="d:\\\\qm\\\\mt5\\\\t_export"' not in source:
        raise ValueError("exact T_Export MQL path guard absent")

    out.mkdir(parents=True)
    result = {
        "schema": "qm.news-calendar-e1d2-m5-export/v1",
        "production_write": False,
        "mechanism": "ftmo_m1_bootstrap StartUp; exact dedicated T_Export lane",
        "bootstrap": boot.file_binding(Path(boot.__file__)),
        "source": boot.file_binding(SOURCE),
    }
    with boot.exclusive_bootstrap_lock(STAGING / "t_export_e1d2_m5.lock"):
        editor = ROOT / "MetaEditor64.exe"
        if any(boot._windows_path_key(row.get("ExecutablePath", "")) == boot._windows_path_key(editor)
               for row in boot.scan_metaeditor_processes()):
            raise ValueError("T_Export MetaEditor busy")
        staged = ROOT / "MQL5/Scripts/QM/news_e1d2_m5" / out.name / SOURCE.name
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

        marker_name = f"E1D2_M5_EXPORT_COMPLETE_{out.name}.txt"
        preset = ROOT / "MQL5/Presets" / f"E1D2_M5_{out.name}.set"
        boot.atomic_write_text(preset, f"InpFrom=1514764800\nInpTo=1782864000\nInpCompletion={marker_name}\n")
        login, server = boot.load_dxz_factory_login()
        ini = out / "startup.ini"
        boot.atomic_write_text(ini, "\n".join([
            "[Common]", f"Login={login}", f"Server={server}", "[Experts]", "Enabled=0",
            "AllowLiveTrading=0", "AllowDllImport=0", "[StartUp]",
            f"Script=QM\\news_e1d2_m5\\{out.name}\\QM_NewsCalendar_E1D2_M5_Export",
            f"ScriptParameters={preset.name}", "Symbol=EURUSD", "Period=M1", "ShutdownTerminal=0", "",
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
                    if identity and identity != matches[0]:
                        result.setdefault("update_handoffs", []).append({"before": identity, "after": matches[0]})
                    identity = matches[0]
                if process.poll() is not None and not identity and dt.datetime.now(dt.timezone.utc) - started > dt.timedelta(seconds=20):
                    raise ValueError("owned exporter process exited early")
                if marker.is_file() and identity:
                    result["completion"] = marker.read_text(encoding="utf-8-sig").strip()
                    break
                time.sleep(1)
            else:
                result["error"] = "M5 export timed out"
        finally:
            if identity:
                try:
                    result["termination"] = terminate_owned(identity, ini)
                    result["terminated_owned_pid"] = identity["pid"]
                except Exception as exc:
                    result["cleanup_error"] = str(exc)
            result["process_identity"] = identity
            result["exports"] = []
            for name in OUTPUTS:
                path = ROOT / "MQL5/Files" / name
                try:
                    result["exports"].append(validate_output(path))
                except (OSError, ValueError, KeyError) as exc:
                    result["exports"].append({"path": str(path), "error": str(exc)})
            result["status"] = "PASS" if (
                "cleanup_error" not in result
                and result.get("completion") == "successes=2 failures=0"
                and all("error" not in item for item in result["exports"])
            ) else "FAIL"
            boot.atomic_write_json(out / "export_receipt.json", result)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--timeout", type=int, default=900)
    args = parser.parse_args()
    result = run(args.out, args.timeout)
    print(json.dumps({"status": result["status"], "exports": result["exports"],
                      "receipt": str(args.out / "export_receipt.json")}))
    raise SystemExit(0 if result["status"] == "PASS" else 2)
