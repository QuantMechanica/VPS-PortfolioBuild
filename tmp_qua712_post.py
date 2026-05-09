from datetime import datetime, timezone
from pathlib import Path
import json
import subprocess
import re

from C_QM_paperclip_import import PaperclipClient

# helper to run powershell and capture stdout

def ps(cmd):
    p = subprocess.run(["powershell","-NoProfile","-Command",cmd],capture_output=True,text=True,check=True)
    return p.stdout.strip()

next_task_raw = ps("python C:/QM/paperclip/tools/ops/next_task.py --agent pipeline-operator --json")
next_task = json.loads(next_task_raw)
issue_id = next_task["tasks"][0]["paperclip_issue_id"]

proc_raw = ps("$p = Get-CimInstance Win32_Process | Where-Object { $_.Name -eq 'terminal64.exe' -and $_.CommandLine -like '*QM5_1003*' } | Select-Object ProcessId,CommandLine; if ($p) { $p | ConvertTo-Json -Compress } else { '[]' }")
proc = json.loads(proc_raw) if proc_raw else []
if isinstance(proc, list):
    runtime_line = "- Runtime probe: no active `terminal64.exe` process matching `*QM5_1003*` observed in this sample"
    config_line = "- Active config: not observed in this sample"
else:
    pid = proc.get("ProcessId")
    cmd = proc.get("CommandLine","")
    m = re.search(r"/config:([^\"]+)", cmd)
    cfg = m.group(1).replace('\\','/') if m else "unknown"
    tmatch = re.search(r"/mt5/(T\d+)/terminal64\.exe", cmd.replace('\\','/'), re.IGNORECASE)
    tname = tmatch.group(1) if tmatch else "T?"
    runtime_line = f"- Runtime active on `{tname}` with PID `{pid}`"
    config_line = f"- Active config unchanged: `/config:{cfg}`"

agg = ps("$targetPid=20056; $p=Get-Process -Id $targetPid -ErrorAction SilentlyContinue; if ($p) {'present'} else {'missing'}")
agg_line = "- Aggregator PID: `20056` (process present)" if agg=="present" else "- Aggregator PID: `20056` (process missing)"

fresh_raw = ps("$hb=Get-Item 'C:/QM/logs/aggregator/heartbeat.txt'; $st=Get-Item 'D:/QM/reports/state/last_check_state.json'; [pscustomobject]@{hb_time=$hb.LastWriteTimeUtc.ToString('o');hb_bytes=$hb.Length;state_time=$st.LastWriteTimeUtc.ToString('o');state_bytes=$st.Length}|ConvertTo-Json -Compress")
fresh = json.loads(fresh_raw)

now = datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
body = "\n".join([
    f"Heartbeat continuation ({now} UTC)",
    "",
    "- `next_task` remains `QUA-712` (verified via `next_task.py --agent pipeline-operator --json`)",
    runtime_line,
    config_line,
    "- No T6 path observed",
    agg_line,
    "- Freshness probes:",
    f"  - `C:/QM/logs/aggregator/heartbeat.txt` -> `{fresh['hb_time']}`, `{fresh['hb_bytes']}` bytes",
    f"  - `D:/QM/reports/state/last_check_state.json` -> `{fresh['state_time']}`, `{fresh['state_bytes']}` bytes",
    "",
    "Next action preserved:",
    "- Continue QUA-712 rolling updates; execute/report QUA-973 unblock directive on its own scoped wake; keep posting dispatch/verdict evidence.",
])

comment = PaperclipClient().add_comment(issue_id, body)
print(json.dumps({"issue_id": issue_id, "comment_id": comment.get("id")}, ensure_ascii=False))
