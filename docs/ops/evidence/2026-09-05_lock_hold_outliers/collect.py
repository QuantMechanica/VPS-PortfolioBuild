"""Freeze observed lock holds and correlate worker events without taking a claim."""
from pathlib import Path
import datetime as dt
import hashlib
import json
import os
import sqlite3
import statistics

OUT=Path(__file__).resolve().parent
START='2026-09-05T11:25:20+00:00'
END='2026-09-05T13:25:20+00:00'


def read_rows(path):
    raw=path.read_bytes()
    rows=[]
    for line in raw.decode('utf-8-sig',errors='replace').splitlines():
        try:rows.append(json.loads(line))
        except (ValueError,TypeError):continue
    return rows,hashlib.sha256(raw).hexdigest(),len(raw)


def main():
    path=Path('D:/QM/reports/state/factory_mutation_lock_holds.jsonl')
    rows,sha,length=read_rows(path)
    holds=[r for r in rows if START <= r.get('acquired_at_utc','') <= END
           and r.get('lock_path','').replace('\\','/').casefold()=='d:/qm/strategy_farm/state/factory_mutation.lock']
    summaries=[]
    for owner in sorted(set(r.get('owner') for r in holds)):
        release=[r for r in holds if r.get('owner')==owner and r.get('event')=='RELEASED']
        if release:summaries.append({'owner':owner,'unique_released_holds':len(release),
            'median_hold_seconds':statistics.median(r['hold_seconds'] for r in release),
            'max_hold_seconds':max(r['hold_seconds'] for r in release)})
    logs={};bindings=[{'path':str(path),'sha256':sha,'bytes':length}]
    for terminal in ('T10','T5'):
        p=Path('D:/QM/strategy_farm/logs')/('terminal_worker_'+terminal+'.log')
        lr,ls,ll=read_rows(p);bindings.append({'path':str(p),'sha256':ls,'bytes':ll})
        logs[terminal]=[r for r in lr if START<=r.get('at_utc','')<=END]
    occupancy=[]
    for terminal in ('T10','T5','T1'):
        base=Path('D:/QM/mt5')/terminal/'Bases/Custom';total=0;count=0;errors=[]
        for directory,_,files in os.walk(base):
            for filename in files:
                p=Path(directory)/filename
                try:total+=p.stat().st_size;count+=1
                except OSError as exc:errors.append(str(exc))
        occupancy.append({'terminal':terminal,'path':str(base),'files':count,'bytes':total,'errors':errors})
    c=sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro',uri=True);c.row_factory=sqlite3.Row;c.execute('PRAGMA query_only=ON')
    items=[];receipts=[]
    for terminal,lr in logs.items():
        for r in lr:
            if r.get('event')!='claimed' or not r.get('item_id'):continue
            row=c.execute('SELECT id,ea_id,phase,symbol,claimed_by,payload_json FROM work_items WHERE id=?',(r['item_id'],)).fetchone()
            if row:
                d=dict(row);p=json.loads(d.pop('payload_json'));d['terminal_observed']=terminal;d['claim_event']=r
                d['payload_keys']=sorted(p);d['program_id']=p.get('program_id');d['year']=p.get('year')
                d['copy_on_claim']=p.get('custom_history_copy_on_claim');items.append(d)
                if isinstance(d['copy_on_claim'],dict):
                    rp=d['copy_on_claim'].get('receipt_path')
                    if rp and Path(rp).is_file():
                        raw=Path(rp).read_bytes();receipts.append({'path':rp,'sha256':hashlib.sha256(raw).hexdigest(),'receipt':json.loads(raw)})
    result={'captured_at':dt.datetime.now(dt.timezone.utc).isoformat(),'read_only':True,'window_start':START,'window_end':END,
            'input_bindings':bindings,'hold_summaries':summaries,'holds':holds,'worker_events':logs,
            'custom_tree_stat_only':occupancy,'claimed_items':items,'copy_receipts':receipts}
    (OUT/'diagnosis.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'hold_summaries':summaries,'custom_tree_stat_only':occupancy,'claimed_items':len(items),'copy_receipts':len(receipts)},indent=2))


if __name__=='__main__':main()
