"""Produce a reviewable screen with explicit unresolved acceptance items."""
import csv, hashlib, json, re
from pathlib import Path
P=Path(__file__).parent
ROOT=Path('C:/QM/repo')
rows=list(csv.DictReader((P/'2026-09-09_fleet_clock_inventory.csv').open(encoding='utf-8')))
ranked=[]
for r in rows:
    w=r['window_inputs']
    if r['classification'] in ('MATCH','N-A') or not re.search('hour|hhmm',w,re.I) or '= false' in w: continue
    if 'strategy_session_start_hour  = 0;' in w and 'strategy_session_end_hour    = 24;' in w: continue
    n=float(r['reference_q02_trades'] or 0)
    if not n or r['pass_depth']=='none': continue
    shift=1 if 'fixed offset' in r['clock_construct'] else 3
    if r['ea_id'] in ('QM5_20007','QM5_33005'): shift=1
    score=int(r['pass_depth'][1:])*shift*n
    ranked.append((score,shift,r))
ranked.sort(key=lambda x:(-x[0],x[2]['ea_id']))
lines=['# Fleet session clock audit — 2026-09-09','',
'Task: `95b48188-1d1a-461f-96cb-3ceb6a2f0618` (priority 80).',
'RESULT: PARTIAL_REVIEW — reproducible inventory and provisional top 10 delivered; exhaustive placement-path classification and measured affected-trade ranking remain open. No EA source changes or factory work items were made for this task.','',
'## Evidence and scope','',
'The canonical active identity registry is intersected with work_items having a Q02-or-later PASS/PASS_SOFT/PASS_LOWFREQ, Q14, or optimization-census lineage. Source filename and active slug must match. Strategy time inputs and hour comparisons trigger inclusion; the shared qm_friday_close_hour_broker and timeframe-only inputs do not. Duration-only inputs remain explicit N-A rows. Historical PASS depth is an observation, not current qualification or permission to promote.','',
f'Inventory: **{len(rows)} EAs**. Automated classifications: '+', '.join(f'{k}={sum(r["classification"]==k for r in rows)}' for k in ('MATCH','MISMATCH','UNSTATED-IN-CARD','N-A'))+'. MATCH is a static screening label, not a proof that the upstream source uses that clock. Missing local cards are distinguished from alternate SPEC.md evidence.','',
'- `2026-09-09_fleet_clock_inventory.csv`: one row per EA, SHA-256, input defaults, source/card file:line citations, PASS work-item/report, reference Q02 trade count and report, pending-order evidence.','- `2026-09-09_fleet_clock_scope.json`: database URI, timestamp and excluded source rows.','- `2026-09-09_fleet_clock_audit.py`: read-only query and reproducible extraction.','',
'## Provisional top 10','',
'Requested score = PASS depth × shift hours × trades affected. Actual trades affected are unknown until a controlled counterfactual is measured. The following **triage proxy**, not that measured score, uses the latest cached Q02 report trade count and a conditional shift (1h for fixed +3 vs broker or European/US transition mismatch; 3h for an unconfirmed raw-broker vs UTC source). Runs differ in symbol and duration, and family members are correlated. These numbers cannot rank expected economic improvement.','',
'| Rank | EA | Historical depth | Reference trades | Conditional shift | Proxy score | Hypothesis / next evidence |',
'|---:|---|---|---:|---:|---:|---|']
for i,(score,shift,r) in enumerate(ranked[:10],1):
    hypothesis='Recover the source clock; same-number UTC hours would shift raw broker window by 2h winter / 3h summer.'
    if 'fixed offset' in r['clock_construct']: hypothesis='Fixed +3 agrees with some lineage specs; test a broker-following source only after confirming it (winter 1h difference).'
    if r['ea_id'] in ('QM5_20007','QM5_33005'): hypothesis='A constant broker-to-German-time offset may miss the March/October US/EU DST gap weeks by 1h.'
    lines.append(f'| {i} | {r["ea_id"]} | {r["pass_depth"]} | {r["reference_q02_trades"]} | {shift}h | {score:g} | {hypothesis} |')
    lines.extend([])
lines+=['','Every table row joins by ea_id to exact code/card/report citations in the inventory. These are candidates for source-clock confirmation first. A governed remeasurement is warranted for the confirmed Balke lineage clock alternative and the European session candidates if the intended local clock is confirmed; no measurement was started.','',
'## Manually checked control-flow findings','',
'- QM5_41398 source:303-339 builds two stops without an outside-range price check. Lines 622-637 send each permitted leg independently, ignore both return values, then mark the day complete from permission intent. Thus both failures can still consume the day; one accepted leg can remain. This contradicts the outcome-based wording in the shared straddle header. The shared helper itself only returns permission decisions (`QM_PatternPermissionStraddle.mqh`:75-103).',
'- QM5_33005 source:178-179 explicitly skips both entries if either trigger is already crossed or within one point. Its raw-clock defaults at :38-40 assume a constant one-hour relation between broker and German local time; that assumption needs separate treatment in US/EU DST transition weeks.',
'- QM5_13036 is a useful negative control: card :70-74 and :90 explicitly identify broker GMT+2/+3 on US DST, and source :54-57 reads raw broker time. GMT wording alone is not a mismatch.',
'- QM5_13213 has no local docs/strategy_card.md; SPEC.md:14-21 explicitly describes fixed +3 reprojection. This is a missing-card evidence gap, not proof that the code violates the spec.',
'',
'## Acceptance still open','',
f'{sum(r["outside_range_behavior"].startswith("UNRESOLVED") for r in rows)} pending-stop candidates need function-by-function review, including included strategy modules, to distinguish skip, market entry, one-leg placement and a truly undefined strategy rule. The CSV deliberately does not equate absence of a simple regex match with absence of a guard. Helper clock classifications also need call-site tracing before any correction. Actual affected trades, precise shifts where the source clock is absent, and an economic ranking cannot be inferred from static code or borrowed from another EA.','',
'Reports are under canonical docs/ops/evidence per the scheduled-task instruction, rather than the payload suggested docs/research path. This artifact is for REVIEW; it does not close the remaining acceptance items.','']
(P/'FLEET_SESSION_CLOCK_AUDIT_2026-09-09.md').write_text('\n'.join(lines),encoding='utf-8',newline='\n')
assert len({r['ea_id'] for r in rows})==len(rows)
assert all(hashlib.sha256((ROOT/r['source']).read_bytes()).hexdigest()==r['source_sha256'] for r in rows)
assert all(r['clock_code_evidence'] and r['card_clock_evidence'] for r in rows)
assert all('qm_friday_close_hour_broker' not in r['window_inputs'] for r in rows)
assert len(ranked)>=10
(P/'2026-09-09_fleet_clock_verification.json').write_text(json.dumps({'source_hashes_unchanged':len(rows),'unique_eas':len(rows),'clock_and_card_evidence_nonempty':True,'framework_friday_input_excluded':True,'top10_rows':10,'verification':'PASS','acceptance':'PARTIAL_REVIEW'},indent=2)+'\n',encoding='utf-8',newline='\n')
print('Focused inventory verification PASS; acceptance PARTIAL_REVIEW')
