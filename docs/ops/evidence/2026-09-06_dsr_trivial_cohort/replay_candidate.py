"""Read-only replay. Numerical n=1 scenarios are explicitly not sealed authority."""
from pathlib import Path
import hashlib
import json
import sqlite3
import sys

ROOT = Path('C:/QM/worktrees/codex-dsr-trivial-cohort-20260906')
sys.path[:0] = [str(ROOT), str(ROOT/'framework/scripts')]
from tools.strategy_farm import dsr_cohort as producer
from q08_davey import dsr_v2 as v2
from q08_davey.common import load_trades_from_mt5_report

OUT = Path(__file__).resolve().parent
db = sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True)
db.row_factory = sqlite3.Row
rows = [dict(row) for row in db.execute("SELECT * FROM work_items WHERE phase='Q08' AND verdict='INVALID' ORDER BY updated_at DESC LIMIT 3")]
results = []
for row in rows:
    aggregate_path = Path(row['evidence_path'])
    aggregate = json.loads(aggregate_path.read_text(encoding='utf-8'))
    baseline = aggregate['baseline_run']
    summary_path = Path(baseline['baseline_summary_path'])
    summary = json.loads(summary_path.read_text(encoding='utf-8'))
    report = Path(baseline['baseline_report_path'])
    payload = json.loads(row['payload_json'])
    payload.update(from_date=summary['from_date'], to_date=summary['to_date'], expected_period=baseline['period'])
    bindings = {}
    for role,path,key in [('aggregate',aggregate_path,None),('summary',summary_path,'baseline_summary_sha256'),('report',report,'baseline_report_sha256')]:
        sha = hashlib.sha256(path.read_bytes()).hexdigest()
        if key: assert sha == baseline[key], (role,'HASH_MISMATCH')
        bindings[role] = {'path':str(path),'sha256':sha}
    entry = {'id':row['id'],'ea_id':row['ea_id'],'symbol':row['symbol'],'stored_verdict':row['verdict'],'provenance':bindings}
    try:
        context = producer.assemble(db,row,payload)
        entry['governed_context_status'] = 'AVAILABLE'
    except producer.CohortUnavailable as error:
        entry.update(governed_context_status='UNAVAILABLE',governed_v2_outcome='INVALID',refusal=str(error))
    paths = {'mq5':Path(baseline['baseline_mq5_path']), 'ex5':Path(baseline['baseline_mq5_path']).with_suffix('.ex5'), 'setfile':Path(baseline['baseline_setfile_path'])}
    entry['current_build_matches_historical']={role:path.is_file() and hashlib.sha256(path.read_bytes()).hexdigest()==baseline['baseline_'+role+'_sha256'] for role,path in paths.items()}
    card = Path('D:/QM/strategy_farm/artifacts/cards_approved')/(paths['mq5'].stem+'.md')
    text = card.read_text(encoding='utf-8')
    entry['card']={'path':str(card),'sha256':hashlib.sha256(card.read_bytes()).hexdigest(),
                   'search_related_lines':[line for line in text.splitlines() if any(word in line.lower() for word in ['sweep','optimis','optimiz','search','trial','locked'])]}
    samples=load_trades_from_mt5_report(report)
    assert len(samples)==baseline['baseline_total_trades'],('TRADE_COUNT_MISMATCH',row['ea_id'],len(samples))
    values,active=v2.daily_series(samples,producer._date_text(summary['from_date']),producer._date_text(summary['to_date']),timezone='UTC',initial_balance=100000)
    result=v2.calculate(v2.moments(values),1,0)
    entry['hypothetical_unsealed_n1']={'basis':'DIAGNOSTIC_ONLY_NO_CARD_AUTHORITY_NO_PIPELINE_VERDICT','threshold':0.05,
         'would_return':'PASS' if result['dsr_p']<0.05 else 'FAIL','trade_count':len(samples),'active_days':active,**result}
    results.append(entry)
successor=dict(db.execute("SELECT id,status,verdict FROM work_items WHERE id='34d0e1ba-8c74-4b84-94ef-5f0681d4a60c'").fetchone())
for original in rows:
    now=db.execute('SELECT verdict,evidence_path FROM work_items WHERE id=?',(original['id'],)).fetchone()
    assert now['verdict']==original['verdict'] and now['evidence_path']==original['evidence_path']
document={'read_only':True,'stored_verdicts_unchanged':True,'successor_11015':successor,'rows':results}
(OUT/'replay.json').write_text(json.dumps(document,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
print(json.dumps([{'ea':r['ea_id'],'governed':r['governed_v2_outcome'],'hypothetical':r['hypothetical_unsealed_n1']['would_return'],'p':r['hypothetical_unsealed_n1']['dsr_p'],'identity':r['current_build_matches_historical']} for r in results],indent=2))
