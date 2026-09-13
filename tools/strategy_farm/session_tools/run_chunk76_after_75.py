"""Detached waiter: start reload chunk 76 once the chunk-75 process has exited (never two reload chunks at once)."""
import subprocess, sys, time
PY = sys.executable
def chunk75_alive() -> bool:
    out = subprocess.run(["powershell", "-NoProfile", "-Command", "(Get-CimInstance Win32_Process -Filter \"name='python.exe'\" | ? { $_.CommandLine -match 'reload_chunk75' } | Measure-Object).Count"], capture_output=True, text=True).stdout.strip()
    return out not in ("0", "")
deadline = time.time() + 4 * 3600
while chunk75_alive() and time.time() < deadline:
    time.sleep(30)
subprocess.run([PY, "-X", "utf8", r"C:/QM/repo/tools/strategy_farm/session_tools/reload_chunk76.py"], cwd=r"C:/QM/repo",
               stdout=open(r"D:/QM/strategy_farm/logs/reload_chunk76.log", "a"), stderr=open(r"D:/QM/strategy_farm/logs/reload_chunk76.err", "a"))
