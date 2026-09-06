"""Tick status query (read-only). Usage: python tick_status.py [ea_id_for_cascade ...]"""
import datetime
import json
import sqlite3
import sys
import time

con = sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True, timeout=30)
con.row_factory = sqlite3.Row
now = datetime.datetime.now(datetime.timezone.utc)
NORM = "replace(substr(updated_at,1,19),'T',' ')"


def q(sql, *a):
    for _ in range(8):
        try:
            return con.execute(sql, a).fetchall()
        except sqlite3.OperationalError as e:
            if 'locked' in str(e) or 'busy' in str(e):
                time.sleep(1)
                continue
            raise
    return []


def ago(minutes):
    return (now - datetime.timedelta(minutes=minutes)).strftime('%Y-%m-%d %H:%M:%S')


print('now', now.strftime('%Y-%m-%dT%H:%MZ'))
for r in q("select state, count(*) c from agent_tasks where state in ('TODO','IN_PROGRESS','REVIEW') group by state"):
    print('tasks', r['state'], r['c'])
for r in q("select substr(id,1,8) id, state, task_type, substr(updated_at,1,16) u, substr(json_extract(payload_json,'$.title'),1,90) t from agent_tasks where state in ('REVIEW','IN_PROGRESS') order by updated_at desc"):
    print(' ', r['state'], r['id'], r['task_type'], r['u'], r['t'])
for label, mins in (('60min', 60), ('15min', 15)):
    print('census done', label, q("select count(*) c from work_items where phase like 'OPT_CENSUS%' and status='done' and " + NORM + ">=?", ago(mins))[0]['c'])
for r in q("select phase, count(*) c from work_items where status='active' group by phase"):
    print('active', r['phase'], r['c'])
print('census pending', q("select count(*) c from work_items where phase like 'OPT_CENSUS%' and status='pending'")[0]['c'],
      '| Q02 pending', q("select count(*) c from work_items where phase='Q02' and status='pending'")[0]['c'],
      '| Q02 done 3h', q("select count(*) c from work_items where phase='Q02' and status='done' and " + NORM + ">=?", ago(180))[0]['c'],
      '| INFRA 3h', q("select count(*) c from work_items where verdict like ? and " + NORM + ">=?", '%INFRA%', ago(180))[0]['c'])
print('gate closes 3h', [(r['phase'], r['verdict'], r['c']) for r in q("select phase, verdict, count(*) c from work_items where phase not like 'OPT_CENSUS%' and phase<>'COMPILE_EA' and status in ('done','failed') and " + NORM + ">=? group by phase, verdict order by phase", ago(180))])
print('compile 3h', [(r['verdict'], r['c']) for r in q("select verdict, count(*) c from work_items where phase='COMPILE_EA' and status in ('done','failed') and " + NORM + ">=? group by verdict", ago(180))])
ps = json.load(open('D:/QM/reports/state/pipeline_state.json', encoding='utf-8-sig'))
bg = (ps.get('operator_surface') or {}).get('book_guard', {})
print('counter', bg.get('qualified_pairs'), '/', bg.get('minimum_qualified_pairs'), 'generated', ps.get('generated_at', '')[:16])
fd = json.load(open('D:/QM/reports/state/owner_decisions.json', encoding='utf-8-sig'))
its = fd['items']
t6 = (now - datetime.timedelta(hours=6)).strftime('%Y-%m-%dT%H:%M')
print('MC open', [i['id'] for i in its if i.get('status') == 'OPEN'])
print('MC receipts last 6h', [(i['id'], i.get('status')) for i in its if (i.get('last_receipt_at_utc') or i.get('decided_at_utc') or '')[:16] >= t6])
for ea in sys.argv[1:]:
    print('cascade', ea, [(r['phase'], r['symbol'][:10], r['status'], r['verdict'], r['u']) for r in q("select phase, symbol, status, verdict, substr(updated_at,1,16) u from work_items where ea_id=? order by created_at", ea)])
