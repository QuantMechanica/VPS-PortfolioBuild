"""Read-only fleet inventory. Outputs only evidence files alongside this script."""
import csv
import datetime as dt
import hashlib
import json
import re
import sqlite3
from pathlib import Path

ROOT = Path('C:/QM/repo')
OUT = Path(__file__).parent
DB = 'file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro'
def qphase(p):
    return {'P2':'Q02'}.get(p,p)
def evidence(path, lines, pattern):
    return ' | '.join(f'{path.relative_to(ROOT).as_posix()}:{i}: {s.strip()}' for i,s in enumerate(lines,1) if re.search(pattern,s,re.I))
def main():
    c=sqlite3.connect(DB,uri=True)
    c.row_factory=sqlite3.Row
    items=[dict(r) for r in c.execute("SELECT id,ea_id,phase,verdict,evidence_path FROM work_items WHERE verdict IN ('PASS','PASS_SOFT','PASS_LOWFREQ') OR phase IN ('Q14','OPT_CENSUS')")]
    by={}
    for r in items:
        p=qphase(r['phase'])
        if p.startswith('Q') and p[1:3].isdigit() and int(p[1:3])>=2 or p=='OPT_CENSUS':
            by.setdefault(r['ea_id'],[]).append(r)
    metrics={}
    for r in c.execute('SELECT ea_id,work_item_id,trades,evidence_path,phase FROM ea_metrics WHERE trades IS NOT NULL ORDER BY extracted_at'):
        if qphase(r['phase'])=='Q02': metrics[r['ea_id']]=dict(r)
    registry=list(csv.DictReader((ROOT/'framework/registry/ea_id_registry.csv').open(encoding='utf-8-sig')))
    active={f"QM5_{r['ea_id']}_{r['slug']}" for r in registry if r['status']=='active'}
    rows=[]; excluded=[]
    for path in sorted((ROOT/'framework/EAs').glob('*/*.mq5')):
        match=re.match(r'(QM5_\d+)',path.name)
        if not match or match[1] not in by or path.parent.name not in active or path.stem!=path.parent.name: continue
        ea=match[1]; lines=path.read_text(encoding='utf-8-sig',errors='replace').splitlines()
        src='\n'.join(lines)
        # Strategy-specific inputs only: generic Friday close/news settings are not triggers.
        inputs=[]
        for s in lines:
            im=re.match(r'\s*input\s+\w+\s+(\w+)\s*=',s)
            if im and not im[1].startswith('qm_') and 'timeframe' not in im[1].lower() and re.search(r'hour|session|time|minute|hhmm',im[1],re.I): inputs.append(s.strip())
        noncomments='\n'.join(s.split('//')[0] for s in lines if not re.match(r'\s*//',s))
        hour_use=any(re.search(r'\.hour\s*(?:[<>]|==|!=)|(?:[<>]=?|==|!=)\s*\w+\.hour',s) and 'qm_friday' not in s for s in noncomments.splitlines())
        if not inputs and not hour_use:
            excluded.append({'ea_id':ea,'source':str(path),'reason':'no strategy time input or hour comparison'}); continue
        card=path.parent/'docs/strategy_card.md'
        cl=card.read_text(encoding='utf-8-sig',errors='replace').splitlines() if card.exists() else []
        clock_pat=r'UTC|GMT|CET|CEST|broker.*(?:time|hour)|(?:server|local|Berlin|London|New York)\s*(?:time|clock)|DST'
        card_lines=[(i,s) for i,s in enumerate(cl,1) if re.search(clock_pat,s,re.I) and not re.search('qm_friday|Friday|stale_max|temporal|compliance|Retrieved|Accessed',s,re.I)]
        ce=' | '.join(f'{card.relative_to(ROOT).as_posix()}:{i}: {s.strip()}' for i,s in card_lines)
        clock='UNRESOLVED'
        if re.search(r'QM_BrokerToUTC',noncomments):
            clock='UTC conversion; fixed offset' if re.search(r'(?:utc\s*\+|GMT3|Gmt3|gmt3|\+\s*[1-9]\s*\*\s*3600)',noncomments) else 'UTC conversion; inspect helper use'
        elif re.search(r'TimeGMT\s*\(',noncomments): clock='TimeGMT; tester semantics require verification'
        elif re.search(r'(?:UTC|GMT|DST|Local|London|NewYork|Berlin)\w*\s*\(',noncomments): clock='local/custom helper; inspect rule'
        elif re.search(r'TimeCurrent\s*\(|TimeTradeServer\s*\(|TimeToStruct',noncomments): clock='raw broker/bar timestamp hour'
        risk='UNSTATED-IN-CARD' if not card_lines else 'N-A'
        reason='No strategy clock declaration located' if not card_lines else 'Clock declaration found; semantic comparison requires review'
        shift='UNKNOWN'
        if clock=='raw broker/bar timestamp hour' and re.search(r'\b(?:UTC|GMT)\b',ce,re.I) and not re.search(r'broker time|server time|broker.*GMT',ce,re.I):
            risk='MISMATCH';reason='Candidate: raw timestamp hour versus UTC/GMT card wording; inspect offset wording';shift='2 winter / 3 summer vs UTC (conditional)'
        if clock=='UTC conversion; fixed offset' and re.search(r'GMT\s*\+?\s*3|UTC\s*\+\s*3',ce,re.I):
            risk='MATCH';reason='Fixed +3 implementation agrees with explicit +3 card; upstream source clock still requires evidence';shift='0 vs card; -1 winter / 0 summer vs broker clock'
        if clock=='raw broker/bar timestamp hour' and re.search(r'broker time|server time',ce,re.I):
            risk='MATCH';reason='Raw server timestamp agrees with card broker/server time declaration';shift='0 vs card'
        if risk=='N-A':
            risk='UNSTATED-IN-CARD';reason='Card mentions a clock but does not establish an unambiguous clock contract for the implemented window'
        if clock=='raw broker/bar timestamp hour' and risk=='UNSTATED-IN-CARD': shift='-2 winter / -3 summer vs same-number UTC window (conditional, source unconfirmed)'
        if clock=='UTC conversion; fixed offset' and risk=='UNSTATED-IN-CARD': shift='UNKNOWN offset; inspect helper; fixed +3 implies -1 winter / 0 summer vs broker (conditional)'
        stop=bool(re.search(r'ORDER_TYPE_(?:BUY|SELL)_STOP|\.BuyStop\(|\.SellStop\(',noncomments))
        stop=stop or bool(re.search(r'\bQM_(?:BUY|SELL)_STOP\b',noncomments))
        alternate=path.parent/'SPEC.md'
        alternate_evidence=evidence(alternate,alternate.read_text(encoding='utf-8-sig',errors='replace').splitlines(),clock_pat) if alternate.exists() else ''
        if not ce: ce='MISSING docs/strategy_card.md' if not card.exists() else 'No unambiguous strategy clock line located in docs/strategy_card.md'
        if inputs and all(re.search(r'time_stop|holding|pending_expir|pending_hours',s,re.I) for s in inputs) and not hour_use:
            risk='N-A';reason='Duration input only; no clock window comparison found';shift='N-A'
        outside='UNRESOLVED: placement-path inspection remains required' if stop else 'N-A'
        if 'balke' in path.name and 'range' in src.lower():
            outside='No outside-level branch in straddle plan; attempts stops independently; one accepted leg can remain, subject to framework rejection'
        if ea=='QM5_41398':
            outside='Independent stops; no market conversion; marks day from permission intent even if both placements fail (mq5:622-637)'
        if ea=='QM5_33005':
            outside='SKIP both stops when buy_trigger<=ask+point OR sell_trigger>=bid-point (mq5:178-179); no market conversion'
        wi=by[ea]
        passed=[r for r in wi if r['verdict'] in ('PASS','PASS_SOFT','PASS_LOWFREQ') and re.match(r'Q\d\d$',qphase(r['phase']))]
        best=max(passed,key=lambda r:int(qphase(r['phase'])[1:]),default=None)
        m=metrics.get(ea,{})
        rows.append(dict(ea_id=ea,source=path.relative_to(ROOT).as_posix(),source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),clock_construct=clock,window_inputs=' | '.join(inputs),clock_code_evidence=evidence(path,lines,r'TimeCurrent\(|TimeTradeServer\(|TimeGMT\(|TimeToStruct\(|QM_BrokerToUTC|\.hour|(?:utc|gmt3)\s*='),card_clock_evidence=ce,alternate_spec_evidence=alternate_evidence,classification=risk,reason=reason,seasonal_shift_hours=shift,pending_stop_class=stop,outside_range_behavior=outside,pending_code_evidence=evidence(path,lines,r'ORDER_TYPE_(?:BUY|SELL)_STOP|\bQM_(?:BUY|SELL)_STOP\b|\.BuyStop\(|\.SellStop\(|QM_TM_OpenPosition|QM_PPS_Decide|SYMBOL_ASK|SYMBOL_BID') if stop else '',pass_depth=qphase(best['phase']) if best else 'none',pass_work_item=best['id'] if best else '',pass_evidence=best['evidence_path'] if best else '',q14_lineage=any(r['phase'] in ('Q14','OPT_CENSUS') for r in wi),reference_q02_trades=m.get('trades',''),reference_trade_evidence=m.get('evidence_path',''),trades_affected='UNKNOWN; counterfactual requires governed measurement'))
    dest=OUT/'2026-09-09_fleet_clock_inventory.csv'
    with dest.open('w',encoding='utf-8',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]),lineterminator='\n');w.writeheader();w.writerows(rows)
    (OUT/'2026-09-09_fleet_clock_scope.json').write_text(json.dumps({'generated_utc':dt.datetime.now(dt.timezone.utc).isoformat(),'database':DB,'eligible_eas_in_database':len(by),'included_source_rows':len(rows),'excluded_no_time_trigger':excluded},indent=2)+'\n',encoding='utf-8',newline='\n')
    print(json.dumps({'rows':len(rows),'classifications':{k:sum(r['classification']==k for r in rows) for k in sorted({r['classification'] for r in rows})},'pending_stop_rows':sum(r['pending_stop_class'] for r in rows)},indent=2))
    for r in sorted(rows,key=lambda r:(r['pass_depth'],float(r['reference_q02_trades'] or 0)),reverse=True)[:30]:
        print(r['ea_id'],r['pass_depth'],r['reference_q02_trades'],r['clock_construct'],r['classification'])
if __name__=='__main__': main()
