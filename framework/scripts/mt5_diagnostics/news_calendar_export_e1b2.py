"""Task-scoped T_Export StartUp wrapper; never launches a research/live lane."""
from __future__ import annotations
import argparse
import base64
import csv
import datetime as dt
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

# All reused operational helpers come from the canonical checkout.
sys.path.insert(0, "C:/QM/repo/tools/strategy_farm")
import ftmo_m1_bootstrap as boot

ROOT = Path("D:/QM/mt5/T_Export")
STAGING = Path("D:/QM/reports/news_calendar/repair_e1a")
SOURCE = Path(__file__).with_name("QM_NewsCalendar_E1B2_Export.mq5")
CCYS = ("USD", "EUR", "GBP", "JPY", "AUD", "CAD")
TAGS = ("CORE_PPI", "EMPIRE_STATE", "BUILDING_PERMITS", "TRADE_BALANCE")


def expected_names():
    return [*(f"T_EXPORT_{c}_HIGH_2026H1_NATIVE.csv" for c in CCYS),
            *(f"T_EXPORT_USD_ALL_{t}_2018_2025_NATIVE.csv" for t in TAGS)]


def validate_output(path):
    with path.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    if not rows:
        raise ValueError("empty export")
    times = [int(r["broker_time"]) for r in rows]
    ids = [r["value_id"] for r in rows]
    if times != sorted(times) or len(set(ids)) != len(ids):
        raise ValueError("unsorted or duplicate native release")
    if "_HIGH_" in path.name and any(r["importance"] != "high" for r in rows):
        raise ValueError("non-high row in HIGH export")
    return {**boot.file_binding(path), "rows": len(rows), "first_raw": min(times),
            "last_raw": max(times), "event_names": sorted({r["event_name"] for r in rows}),
            "timestamp_encoding": "UNVERIFIED_MT5_SERVER_CIVIL"}


def owned_match(row, ini, started):
    if boot._windows_path_key(row.get("ExecutablePath",""))!=boot._windows_path_key(ROOT/"terminal64.exe"):
        return None
    if str(ini).lower() not in str(row.get("CommandLine","")).lower():
        return None
    identity=boot.process_identity(row,"owned T_Export")
    creation=dt.datetime.fromisoformat(identity["creation_date_utc"].replace("Z","+00:00"))
    return identity if creation>=started-dt.timedelta(seconds=2) else None


def terminate_owned(identity, ini):
    encoded=base64.b64encode(str(ini).encode()).decode()
    pid=int(identity["pid"])
    creation=identity["creation_date_utc"]
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


def run(out: Path, timeout: int, catalog_only=False, empire_only=False):
    out = out.resolve()
    boot._safe_tag(out.name)
    if not 60<=timeout<=900:
        raise ValueError("export timeout must be 60..900 seconds")
    if STAGING.resolve() not in out.parents or out.exists():
        raise ValueError("run must use a new E1-A staging child")
    terminal = ROOT / "terminal64.exe"
    rows = boot.scan_terminal_processes()
    if boot._exact_process_for_path(rows, terminal):
        raise ValueError("T_Export already active; defer without interruption")
    requested=[expected_names()[7]] if empire_only else expected_names()[6 if catalog_only else 0:]
    for name in requested:
        if (ROOT / "MQL5/Files" / name).exists():
            raise ValueError("existing export refused: " + name)
    source = SOURCE.read_text()
    if any(re.search(p, source) for p in boot.FORBIDDEN_MQL_TOKENS):
        raise ValueError("trading API in exporter")
    if 'root!="d:\\\\qm\\\\mt5\\\\t_export"' not in source:
        raise ValueError("exact T_Export MQL path guard absent")
    out.mkdir(parents=True)
    result = {"schema": "qm.news-native-export-e1b2/v1", "production_write": False,
              "mechanism": "ftmo_m1_bootstrap StartUp; exact T_Export extension",
              "bootstrap": boot.file_binding(Path(boot.__file__)), "source": boot.file_binding(SOURCE)}
    with boot.exclusive_bootstrap_lock(STAGING / "t_export_e1b2.lock"):
        editor = ROOT / "MetaEditor64.exe"
        if any(boot._windows_path_key(r.get("ExecutablePath", "")) == boot._windows_path_key(editor)
               for r in boot.scan_metaeditor_processes()):
            raise ValueError("T_Export MetaEditor busy")
        staged = ROOT / "MQL5/Scripts/QM/news_e1b2" / out.name / SOURCE.name
        if staged.exists():
            raise ValueError("staged script already exists; preserve previous run")
        staged.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(SOURCE, staged)
        log = out / "compile.log"
        p = subprocess.run([str(editor), f"/compile:{staged}", f"/log:{log}"],
                           cwd=ROOT, capture_output=True, timeout=180,
                           creationflags=subprocess.CREATE_NO_WINDOW)
        counts = re.findall(r"(\d+) errors?, (\d+) warnings?", boot._read_text_auto(log))
        if p.returncode not in (0, 1) or not counts or counts[-1] != ("0", "0"):
            raise ValueError("compile did not pass 0E/0W: " + str(counts))
        result["compile"] = {"exit_code": p.returncode, "errors": 0, "warnings": 0,
                             "log": boot.file_binding(log), "ex5": boot.file_binding(staged.with_suffix(".ex5"))}
        tag = out.name
        complete = f"E1B2_EXPORT_COMPLETE_{tag}.txt"
        preset = ROOT / "MQL5/Presets" / f"E1B2_{tag}.set"
        settings=f"InpBatch=true\nInpCatalogOnly={'true' if catalog_only else 'false'}\nInpCompletion={complete}\n"
        if empire_only:
            settings=f"InpBatch=false\nInpCompletion={complete}\nInpCurrency=USD\nInpFrom=1514764800\nInpTo=1767225600\nInpImpact=1\nInpEventName=NY Empire State Manufacturing Index\nInpOutput={requested[0]}\n"
        boot.atomic_write_text(preset, settings)
        login, server = boot.load_dxz_factory_login()
        ini = out / "startup.ini"
        boot.atomic_write_text(ini, "\n".join([
            "[Common]", f"Login={login}", f"Server={server}", "[Experts]", "Enabled=0",
            "AllowLiveTrading=0", "AllowDllImport=0", "[StartUp]",
            f"Script=QM\\news_e1b2\\{out.name}\\QM_NewsCalendar_E1B2_Export", f"ScriptParameters={preset.name}",
            "Symbol=EURUSD", "Period=M1", "ShutdownTerminal=0", ""]))
        if boot._exact_process_for_path(boot.scan_terminal_processes(), terminal):
            raise ValueError("T_Export ceased being idle before launch")
        started=dt.datetime.now(dt.timezone.utc)
        process = subprocess.Popen([str(terminal), "/portable", f"/config:{ini}"], cwd=ROOT,
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                   creationflags=subprocess.CREATE_NO_WINDOW)
        result["launched_pid"]=process.pid
        result["startup_ini"]=boot.file_binding(ini)
        identity = None
        marker = ROOT / "MQL5/Files" / complete
        deadline = time.monotonic() + timeout
        try:
            while time.monotonic() < deadline:
                matches = [v for row in boot.scan_terminal_processes() if (v:=owned_match(row,ini,started))]
                if matches:
                    if len(matches) != 1:
                        raise ValueError("owned T_Export config/path is not unique")
                    if identity and identity != matches[0]:
                        result.setdefault("update_handoffs",[]).append({"before":identity,"after":matches[0]})
                    identity = matches[0]
                if process.poll() is not None and not identity and dt.datetime.now(dt.timezone.utc)-started>dt.timedelta(seconds=20):
                    raise ValueError("owned exporter process exited early")
                if marker.is_file() and identity:
                    result["completion"] = marker.read_text(encoding="utf-8-sig").strip()
                    break
                time.sleep(1)
            else:
                result["error"] = "native export timed out"
        finally:
            if identity:
                try:
                    result["termination"]=terminate_owned(identity,ini)
                    result["terminated_owned_pid"] = identity["pid"]
                except Exception as exc:
                    result["cleanup_error"]=str(exc)
            result["process_identity"] = identity
            result["exports"] = []
            for name in expected_names():
                path = ROOT / "MQL5/Files" / name
                try:
                    result["exports"].append(validate_output(path))
                except (OSError, ValueError, KeyError) as exc:
                    result["exports"].append({"path": str(path), "error": str(exc)})
            result["status"] = "PASS" if "cleanup_error" not in result and result.get("completion") == f"successes={len(requested)} failures=0" and all(
                "error" not in r for r in result["exports"]) else "FAIL"
            boot.atomic_write_json(out / "export_receipt.json", result)
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--timeout", type=int, default=420)
    parser.add_argument("--catalog-only", action="store_true")
    parser.add_argument("--empire-only", action="store_true")
    args = parser.parse_args()
    result = run(args.out, args.timeout, args.catalog_only, args.empire_only)
    print(json.dumps({"status": result["status"], "exports": len(result["exports"]), "receipt": str(args.out / "export_receipt.json")}))
    raise SystemExit(0 if result["status"] == "PASS" else 2)
