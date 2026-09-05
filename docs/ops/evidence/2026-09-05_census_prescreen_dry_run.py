"""Read-only database projection; manifests/output are new evidence artifacts."""
import argparse
import collections
import datetime as dt
import json
from pathlib import Path
import sqlite3
import sys

parser=argparse.ArgumentParser()
parser.add_argument('--code-root',type=Path,required=True)
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
sys.path.insert(0,str(args.code_root))
from tools.strategy_farm import dl089_prescreen as p
from tools.strategy_farm.research import pattern_fire_count as counter

con=sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro',uri=True)
con.row_factory=sqlite3.Row
con.execute('BEGIN')
results=[]
for ea,symbol in [('QM5_41196','XAUUSD.DWX'),('QM5_41197','GBPUSD.DWX')]:
    raw=con.execute("SELECT * FROM work_items WHERE ea_id=? AND phase='OPT_CENSUS'",(ea,)).fetchall()
    by={}
    for row in raw:
        payload=json.loads(row['payload_json'])
        if payload.get('year') in range(2019,2026) and payload.get('arm'):
            by[(payload['year'],payload['arm'])]=dict(row)
    baseline={y:p.measured(by.get((y,'baseline'))) for y in range(2019,2026)}
    reports={y:Path(v['report_path']) for y,v in baseline.items() if v}
    first_payload=json.loads(raw[0]['payload_json'])
    program=first_payload['program_id']
    contract=p.create_contract(symbol,sorted({year for year,_ in by}))
    manifest=p.validate_contract(contract)
    counts=counter.count_program(program,symbol,reports,Path(manifest['bars_path']))
    arms=list(counts['total'])
    choices={}
    for arm in arms:
        if any(counts['counts_by_year'].get(str(y),{}).get(arm,0)<5 for y in p.YEARS):
            choices[arm]='REJECTED_B5_STAGE1'
        else:
            pairs=[(p.measured(by.get((y,arm))),baseline[y]) for y in p.YEARS]
            if any(a is None or b is None for a,b in pairs):choices[arm]='WAITING_STAGE1_MEASUREMENT'
            elif all(p.qualifies(a,b) for a,b in pairs):choices[arm]='ADMITTED_B2'
            else:choices[arm]='REJECTED_B2'
    yearly=[]
    for y in range(2019,2026):
        yc=counts['counts_by_year'].get(str(y));known_rejected=sum(v.startswith('REJECTED') for v in choices.values())
        if y in p.YEARS:
            skipped=sum(v<5 for v in yc.values()) if yc else None
            admitted=154-skipped if skipped is not None else None
        else:
            admitted=sum(v=='ADMITTED_B2' and yc[a]>=5 for a,v in choices.items()) if yc else None
            skipped=sum(v.startswith('REJECTED') or (v=='ADMITTED_B2' and yc[a]<5) for a,v in choices.items()) if yc else known_rejected
        yearly.append({'year':y,'baseline_measured':bool(baseline[y]),'b5_below_5':sum(v<5 for v in yc.values()) if yc else None,
                       'hypothetical_skipped_known':skipped,'hypothetical_admitted_known':admitted,
                       'hypothetical_unknown':154-skipped-admitted if skipped is not None and admitted is not None else None,
                       'existing_annual_rows':sum(year==y for year,_ in by),'effective_new_skips':0})
    results.append({'ea':ea,'symbol':symbol,'program_id':program,'contract':contract,'manifest':manifest,
                    'baseline_proofs':baseline,'fire_counts':counts['counts_by_year'],
                    'stage2_classification':choices,'stage2_counts':dict(collections.Counter(choices.values())),
                    'per_year':yearly,'actual_existing_rows':len(by),'effective_projected_saving':0,
                    'limit':'All seven years are already enqueued. Hypothetical counts cannot be applied retroactively; unknown years/results are not imputed.'})
con.close()
args.output.write_text(json.dumps({'schema':p.SCHEMA,'observed_at_utc':dt.datetime.now(dt.timezone.utc).isoformat(),
                                 'read_only_database':True,'programs':results},indent=2)+'\n',encoding='utf-8')
print(json.dumps([{k:r[k] for k in ['ea','stage2_counts','per_year','effective_projected_saving']} for r in results],indent=2))
