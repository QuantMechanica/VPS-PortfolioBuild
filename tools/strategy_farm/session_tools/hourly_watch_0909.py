"""Hourly one-shot factory watch (read-only). Usage: python -X utf8 hourly_watch_0909.py
Prints ~15 lines; lines starting with ALERT need action."""
import datetime, json, os, re, shutil, sqlite3, subprocess, time

FACTORY_TERMINAL_COUNT = 10  # T1..T10 (T_Live / MT5_Base / FTMO are not factory slots)
DRAIN_STALL_MIN_IDLE_TERMINALS = 3
DRAIN_STALL_MIN_WAITED_S = 600  # 10 minutes


def idle_factory_terminals(terminals_field, total=FACTORY_TERMINAL_COUNT):
    """Idle factory terminals = total slots minus terminals currently backtesting.

    ``terminals_field`` is the comma-joined folder-leaf list of running
    terminal64.exe processes (e.g. ``"T1,T2,MT5_Base,FTMO"``).  Only ``T<digits>``
    leaves are factory slots; ``T_Live``, ``MT5_Base`` and ``FTMO`` are excluded.
    """
    active = 0
    for token in str(terminals_field or "").split(","):
        if re.fullmatch(r"T\d+", token.strip()):
            active += 1
    return max(0, total - active)


def census_stall_alert(
    census_done_60m,
    idle_terminals,
    drain_window,
    now_epoch,
    *,
    min_idle=DRAIN_STALL_MIN_IDLE_TERMINALS,
    min_waited_s=DRAIN_STALL_MIN_WAITED_S,
):
    """Return an ALERT string for the 15.09 census-stall-in-drain false-OK case.

    Fires when ALL hold: census throughput is zero (``census_done_60m == 0``),
    at least ``min_idle`` factory terminals sit idle, and ``drain_window`` has an
    open ``pre_drain`` OR a non-empty ``tracker`` that has been waiting at least
    ``min_waited_s`` seconds.  This is the situation where the
    ``q08_head_of_line_claim_starvation`` health check reads OK while several
    terminals are self-parked in ``drain_predrain`` behind an un-winnable RAM
    reservation.  Returns ``None`` when the condition does not hold.
    """
    drain_window = drain_window or {}
    pre_drain = drain_window.get("pre_drain") or {}
    tracker = drain_window.get("tracker") or {}
    if not (pre_drain or tracker):
        return None

    waited = 0.0
    if pre_drain.get("opened_epoch"):
        try:
            waited = max(waited, now_epoch - float(pre_drain["opened_epoch"]))
        except (TypeError, ValueError):
            pass
    for entry in tracker.values():
        if isinstance(entry, dict) and entry.get("first_skipped_epoch"):
            try:
                waited = max(waited, now_epoch - float(entry["first_skipped_epoch"]))
            except (TypeError, ValueError):
                pass

    if not (int(census_done_60m or 0) == 0 and int(idle_terminals or 0) >= min_idle
            and waited >= min_waited_s):
        return None

    def _first_tracker(field):
        for key, entry in tracker.items():
            if field == "item_id":
                return key
            if isinstance(entry, dict) and entry.get(field) is not None:
                return entry.get(field)
        return "?"

    block_ea = pre_drain.get("ea_id") or _first_tracker("ea_id")
    block_item = pre_drain.get("item_id") or _first_tracker("item_id")
    block_res = pre_drain.get("reservation_gb")
    if block_res is None:
        block_res = _first_tracker("reservation_gb")
    return (
        f"CENSUS STALL in drain: {idle_terminals} factory terminals idle "
        f"~{waited/60:.0f}min, census_done_60m=0, blocking ea_id={block_ea} "
        f"item={block_item} reservation_gb={block_res} "
        f"(q08 head-of-line health check may read false-OK)"
    )


def main():
    U = datetime.datetime.utcnow
    now = U(); print('WATCH', now.strftime('%Y-%m-%dT%H:%MZ'))
    c = sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True, timeout=60)
    N = "replace(substr(updated_at,1,19),'T',' ')"
    def q(s): return c.execute(s).fetchall()
    al = []
    ps = subprocess.run(['powershell','-NoProfile','-c',"(Get-CimInstance Win32_Process|?{$_.Name -match '^python' -and $_.CommandLine -match 'terminal_worker'}).Count;(Get-CimInstance Win32_Process -Filter \"Name='terminal64.exe'\"|%{Split-Path (Split-Path $_.ExecutablePath -Parent) -Leaf}) -join ',';[int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory/1MB);(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString('MM-dd HH:mm')"],capture_output=True,text=True).stdout.split('\n')
    ps=[x.strip() for x in ps if x.strip()]
    workers=int(ps[0]) if ps and ps[0].isdigit() else -1
    terminals_field = ps[1] if len(ps)>1 else ""
    print(f'workers={workers} terminals={terminals_field or "?"} ram_free_gb={ps[2] if len(ps)>2 else "?"} boot={ps[3] if len(ps)>3 else "?"}')
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
    # 2026-09-15: census-stall-in-drain tripwire. The q08 head-of-line health
    # check can read OK while >=3 factory terminals self-park in drain_predrain
    # behind an un-winnable RAM reservation and census throughput is zero. Name
    # the blocking item explicitly instead of trusting the false-OK check.
    try:
        idle_terms = idle_factory_terminals(terminals_field)
        dw = json.load(open('D:/QM/strategy_farm/state/drain_window.json'))
        stall = census_stall_alert(c60, idle_terms, dw, time.time())
        pd = dw.get('pre_drain') or {}
        print(f'drain census-stall probe: idle_factory_terminals={idle_terms} '
              f'pre_drain_ea={pd.get("ea_id")} tracker_open={bool(dw.get("tracker"))}')
        if stall: al.append(stall)
    except Exception as e: print('drain census-stall err', e)
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
        st=json.load(open('D:/QM/reports/state/pipeline_state.json',encoding='utf-8-sig')); bg=(st.get('operator_surface') or {}).get('book_guard',{}); print('counter', bg.get('qualified_pairs'),'qualified pool · reference pool size',bg.get('reference_pool_size', bg.get('minimum_qualified_pairs')),'(historical, superseded 2026-09-15) gen',str(st.get('generated_at',''))[:16])
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
    # 2026-09-15: head-of-line claim-order preflight starvation tripwire. The
    # 15-min QM_StrategyFarm_Health_15min task writes this check into health.json
    # via health.chk_q08_head_of_line_claim_starvation; reuse its verdict here
    # instead of re-scanning worker logs (single source of truth).
    try:
        hj = json.load(open('D:/QM/strategy_farm/state/health.json'))
        hc = next((r for r in hj.get('checks', []) if r.get('name') == 'q08_head_of_line_claim_starvation'), None)
        if hc:
            print('q08_head_of_line_claim_starvation', hc.get('status'), hc.get('detail'))
            if hc.get('status') == 'FAIL': al.append(f"q08_head_of_line_claim_starvation: {hc.get('detail')}")
    except Exception as e: print('q08_head_of_line_claim_starvation err', e)
    for a in al: print('ALERT', a)
    if not al: print('OK no alerts')


if __name__ == '__main__':
    main()
