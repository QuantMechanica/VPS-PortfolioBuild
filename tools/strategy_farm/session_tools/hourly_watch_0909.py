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
b=q("select status,count(*) from work_items where ea_id='QM5_41398' and phase like 'OPT_CENSUS%' group by status"); bq=q("select status,coalesce(verdict,'') from work_items where id like '2fc84747%'")
print('balke41398 census', b, 'q02_baseline', bq)
for a in al: print('ALERT', a)
if not al: print('OK no alerts')
