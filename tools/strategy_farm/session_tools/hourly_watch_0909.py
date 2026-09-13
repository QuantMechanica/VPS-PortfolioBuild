"""Hourly one-shot factory watch (read-only). Usage: python -X utf8 hourly_watch_0909.py
Prints ~15 lines; lines starting with ALERT need action."""
import datetime, json, os, shutil, sqlite3, subprocess
U = datetime.datetime.utcnow
now = U(); print('WATCH', now.strftime('%Y-%m-%dT%H:%MZ'))
c = sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True, timeout=60)
N = "replace(substr(updated_at,1,19),'T',' ')"
def q(s): return c.execute(s).fetchall()
al = []
ps = subprocess.run(['powershell','-NoProfile','-c',"(Get-CimInstance Win32_Process|?{$_.Name -match '^python' -and $_.CommandLine -match 'terminal_worker'}).Count;(Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\"|%{Split-Path (Split-Path $_.ExecutablePath -Parent) -Leaf}) -join ',';[int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB);(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString('MM-dd HH:mm')"],capture_output=True,text=True).stdout.split('\n')
ps=[x.strip() for x in ps if x.strip()]
workers=int(ps[0]) if ps and ps[0].isdigit() else -1
print(f'workers={workers} terminals={ps[1] if len(ps)>1 else "?"} ram_free_gb={ps[2] if len(ps)>2 else "?"} boot={ps[3] if len(ps)>3 else "?"}')
if workers < 10: al.append(f'workers={workers}<10')
dfree = shutil.disk_usage('D:/').free/2**30; print(f'd_free_gb={dfree:.0f}')
if dfree < 60: al.append(f'D_free={dfree:.0f}GB')
try:
    m = json.load(open('D:/QM/strategy_farm/state/custom_history_containment_mode.json')); print('containment_enabled=', m.get('enabled'))
    if m.get('enabled'): al.append('CONTAINMENT ENGAGED')
except Exception as e: print('containment read err', e)
for f in ('FACTORY_OFF.flag','FACTORY_OFF_REQUEST.flag'):
    if os.path.exists('D:/QM/strategy_farm/state/'+f): al.append(f+' present')
c60 = q(f"select count(*) from work_items where phase like 'OPT_CENSUS%' and status='done' and {N} > datetime('now','-60 minutes')")[0][0]
act = q("select phase,count(*) from work_items where status='active' group by phase")
q02_3h = q(f"select count(*) from work_items where phase='Q02' and status='done' and {N} > datetime('now','-3 hours')")[0][0]
infra = q(f"select count(*) from work_items where verdict like '%INFRA%' and {N} > datetime('now','-3 hours')")[0][0]
print(f'census_done_60m={c60} active={act} q02_done_3h={q02_3h} infra_3h={infra}')
if c60 == 0 and not act: al.append('census_done_60m=0 and nothing active')
print('tasks', q("select state,count(*) from agent_tasks where state in ('TODO','IN_PROGRESS','REVIEW','BLOCKED') group by state"))
for f,k in (('ftmo_trial_pulse.json',('verdict','terminal_up','effective_state','magics_seen')),('live_book_pulse.json',('effective_state','expected_state','generated_at_utc'))):
    try:
        d=json.load(open('D:/QM/reports/state/'+f)); print(f, {x:d.get(x) for x in k})
        if d.get('terminal_up') is False or (d.get('effective_state') not in (None,'RUNNING')): al.append(f'{f} {d.get("effective_state")} up={d.get("terminal_up")}')
    except Exception as e: print(f,'err',e)
try:
    qg=json.load(open('D:/QM/reports/state/quota_governor_state.json'))['agents']; print('quota', {a:(qg[a].get('used_pct'),qg[a].get('elapsed_pct')) for a in qg})
except Exception as e: print('quota err',e)
try:
    st=json.load(open('D:/QM/reports/state/pipeline_state.json',encoding='utf-8-sig')); bg=(st.get('operator_surface') or {}).get('book_guard',{}); print('counter', bg.get('qualified_pairs'),'/',bg.get('minimum_qualified_pairs'),'gen',str(st.get('generated_at',''))[:16])
except Exception as e: print('counter err',e)
b=q("select status,count(*) from work_items where json_extract(payload_json,'$.program_id')='DL089_QM5_13213_USDJPY_DWX_2019_2025' group by status")
print('balke41398 PATTERN census (DL089_13213 program)', b)
ws=q("select status,count(*) from work_items where json_extract(payload_json,'$.cell_key') like 'WINSWEEP%' group by status"); print('winsweep', ws)
m=q("select status,count(*) from work_items where json_extract(payload_json,'$.program_id')='WINSWEEP_QM5_41405_USDJPY_DWX_2019_2025' and phase='OPT_CENSUS' group by status"); print('balke2_41405 matrix', m)
# 2026-09-13: live sleeve drift monitor (read-only, ~1 s). ALARM outside the known dark set (12778/12969/13117,
# repair staged under DXZ_V2 repair_v2, cutover pending) is a watch ALERT; the known set is reported as a note.
try:
    import subprocess as _sp
    _known_dark = {12778, 12969, 13117}
    _drift_out = 'D:/QM/reports/state/live_sleeve_drift.json'
    _sp.run(['python', '-X', 'utf8', 'C:/QM/repo/tools/strategy_farm/live_sleeve_drift_monitor.py', '--out', _drift_out],
            capture_output=True, text=True, timeout=120)
    _dr = json.load(open(_drift_out, encoding='utf-8'))
    _rows = _dr.get('sleeves') or []
    _counts = {}
    for _r in _rows: _counts[_r.get('verdict')] = _counts.get(_r.get('verdict'), 0) + 1
    _alarm = [(int(_r.get('ea_id') or 0), _r.get('symbol'), _r.get('alarm_codes')) for _r in _rows if _r.get('verdict') == 'ALARM']
    _new = [x for x in _alarm if x[0] not in _known_dark]
    _warn = [(_r.get('ea_id'), _r.get('symbol')) for _r in _rows if _r.get('verdict') == 'WARN']
    print('live drift', _counts, 'known-dark', sorted(x[0] for x in _alarm if x[0] in _known_dark), 'warn', _warn)
    for x in _new: al.append(f'live_sleeve_drift ALARM {x[0]}/{x[1]} {x[2]}')
except Exception as e: print('live drift err', e)
for a in al: print('ALERT', a)
if not al: print('OK no alerts')
