"""One-shot post-reboot verification (OWNER window 2026-09-11, weekend): pagefile / commit limit,
workers, T_Live + FTMO terminal presence, launcher events, active cells. Writes
D:/QM/reports/state/post_reboot_check_20260911.md (+ .json). Registered as scheduled task
QM_TMP_PostRebootCheck_0911 (AtStartup + 10 min delay) because the orchestrator session dies with the reboot."""
import json, sqlite3, subprocess, time, datetime, pathlib
OUT = pathlib.Path("D:/QM/reports/state/post_reboot_check_20260911")
def ps(cmd):
    r = subprocess.run(["powershell", "-NoProfile", "-Command", cmd], capture_output=True, text=True, timeout=120)
    return (r.stdout or "").strip()
rep = {"generated_at_utc": datetime.datetime.utcnow().isoformat(timespec="seconds") + "Z"}
rep["boot"] = ps("(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString('u')")
rep["pagefile"] = ps("Get-CimInstance Win32_PageFileUsage | ForEach-Object { $_.Name+' alloc='+$_.AllocatedBaseSize+' use='+$_.CurrentUsage }")
rep["virtual_gb"] = ps("$o=Get-CimInstance Win32_OperatingSystem; ([int]($o.TotalVirtualMemorySize/1MB)).ToString() + ' total / ' + ([int]($o.FreeVirtualMemory/1MB)).ToString() + ' free'")
rep["processes"] = ps("Get-Process terminal64,pythonw -ErrorAction SilentlyContinue | ForEach-Object { $_.Name+' '+$_.Id+' '+$_.Path } | Out-String -Width 200")
rep["tlive_running"] = "T_Live" in rep["processes"]
rep["ftmo_running"] = "FTMO" in rep["processes"]
rep["worker_count"] = rep["processes"].count("pythonw")
try:
    c = sqlite3.connect("file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro", uri=True, timeout=10)
    rep["active"] = c.execute("select phase, claimed_by from work_items where status='active'").fetchall()
    rep["done_last_60m"] = c.execute("select count(*) from work_items where status='done' and replace(substr(updated_at,1,19),'T',' ')>=strftime('%Y-%m-%d %H:%M:%S','now','-60 minutes')").fetchone()[0]
except Exception as exc:
    rep["db_error"] = repr(exc)
try:
    ev = pathlib.Path("D:/QM/reports/state/live_launcher_events.jsonl").read_text(encoding="utf-8", errors="ignore").splitlines()[-6:]
    rep["launcher_events_tail"] = ev
except Exception as exc:
    rep["launcher_events_tail"] = repr(exc)
OUT.with_suffix(".json").write_text(json.dumps(rep, indent=2, default=str), encoding="utf-8")
md = ["# Post-reboot check 2026-09-11 (OWNER window)", ""] + [f"- **{k}**: {v}" for k, v in rep.items() if k != "processes"] + ["", "```", rep["processes"], "```"]
OUT.with_suffix(".md").write_text("\n".join(md), encoding="utf-8")
print(OUT)
