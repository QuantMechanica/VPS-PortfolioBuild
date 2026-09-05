"""Named public archive with an explicit exposure whitelist; no publication."""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import unicodedata
from collections import defaultdict
from pathlib import Path

import website_archive_contract as legacy
from rebaseline_census import build_pairs, open_ro, summarise_pair, vclass

SCHEMA = 'https://quantmechanica.com/schemas/strategy-archive/v3.json'
DISCLOSURE = 'named_gate_journey_without_metrics'
TOP = {'schema_version','$schema_id','generated_at','gate_contract_version','disclosure','gates','total','items'}
ITEM = {'public_id','slug','display_name','name_quality','family','summary','markets','first_tested','last_updated','terminal_gate','gate_journey'}
PRIVATE = re.compile(r'(?i)(?:[A-Z]:[\\/]|/QM/|T_Live|\bT(?:[1-9]|1[0-2])\b|\bmagic\b|\.set\b|\bRISK_|\bqm_|\bQM5_|\.mq[45]\b|\.ex[45]\b|https?://|\b[0-9a-f]{8}-[0-9a-f-]{27,}\b|\b[A-Za-z]+_[A-Za-z0-9_]+\b|\b[A-Za-z]+\([^)]*\)|[<>=])')
NUMBER_WORDS = re.compile(r'(?i)\b(?:zero|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety|hundred|thousand|million|first|second|third)\b')
TIMEFRAME = re.compile(r'^(?:M[1-9][0-9]?|H[1-9][0-9]?|D1|W1|MN1|UNKNOWN)$')
MARKET = re.compile(r'^[A-Z][A-Z0-9]{2,9}$')
REASONS = {
    'PASS':'Met the evidence requirements for this gate.',
    'FAIL':'Did not meet the gate criteria.',
    'ZERO_TRADES':'Produced no trades in the baseline window.',
    'LOW_SAMPLE':'The available sample was insufficient for this test.',
    'ROBUSTNESS':'The result did not remain robust under the test conditions.',
}


def public_text(raw, *, limit=60):
    text = legacy.scrub_text(str(raw or ''))
    text = re.sub(r'```.*?```|`[^`]*`', ' ', text, flags=re.S)
    text = re.sub(r'\[[^\]]*\]\([^)]*\)', ' ', text)
    # Never publish a sentence carrying a private locator or code name.
    sentences = re.split(r'(?<=[.!?])\s+|\n+', text)
    text = ' '.join(s for s in sentences if not PRIVATE.search(s) and legacy.REDACTED not in s
                    and not re.search(r'(?i)profit factor|drawdown|sharpe|win.rate|\b(?:parameter|threshold|lots|risk|true|false)\b|(?:framework|reports|artifacts)[\\/]|SPEC\.md',s))
    text = re.sub(r'\b\w*[a-z][A-Z]\w*\b', ' ', text)  # code identifiers
    text = re.sub(r'\b(?:M\d+|H\d+|D\d+|W\d+|MN\d+)\b', ' ', text, flags=re.I)
    text = re.sub(r'\d+(?:[.,]\d+)?', ' ', text)
    text = NUMBER_WORDS.sub(' ', text)
    text = re.sub(r'[<>=%+|#*_{}\[\]\\/]', ' ', text)
    text = re.sub(r'[-–—]+', ' ', text)
    text = re.sub(r'\s+', ' ', text).strip(' .,:;()')
    result = ' '.join(text.split()[:limit])
    # Removing digits can create a newly forbidden token (e.g. magic123).
    if PRIVATE.search(result) or legacy.scrub_text(result) != result:
        return ''
    return result


def market(value):
    value = str(value or '').upper().removesuffix('.DWX').removesuffix('.CASH')
    return value if MARKET.fullmatch(value) and not re.search(r'\d{6}',value) else None


def timeframe(value):
    value = str(value or '').upper().removeprefix('PERIOD_')
    return value if TIMEFRAME.fullmatch(value) else 'UNKNOWN'


def day(value):
    try:
        return dt.date.fromisoformat(str(value)[:10]).isoformat()
    except ValueError:
        return None


def name_slug(name, public_id):
    words = unicodedata.normalize('NFKD',name).encode('ascii','ignore').decode().lower()
    base=re.sub('[^a-z]+','-',words).strip('-')[:90].rstrip('-') or 'mechanical-strategy'
    return base+'-'+hashlib.sha256(public_id.encode()).hexdigest()[:6]


def reason(rows, verdict):
    if verdict == 'PASS':return REASONS['PASS']
    tokens=' '.join(str(r.get('verdict') or '')+' '+str(r.get('public_reason_input') or '') for r in rows).upper()
    if 'ZERO_TRADES' in tokens or 'NO_TRADES' in tokens:return REASONS['ZERO_TRADES']
    if 'LOW_SAMPLE' in tokens or 'NEED_MORE_DATA' in tokens:return REASONS['LOW_SAMPLE']
    if 'ROBUST' in tokens:return REASONS['ROBUSTNESS']
    return REASONS['FAIL']


def build(db_path, farm_root, repo_root, *, generated_at=None):
    cards_dir=Path(farm_root)/'artifacts/cards_approved'
    if not cards_dir.is_dir():raise legacy.PublicSnapshotContractError('approved-card directory unavailable')
    con=open_ro(str(db_path));con.execute('PRAGMA query_only=ON');con.execute('BEGIN')
    try:
        pairs=build_pairs(con,limit=None);summaries={k:summarise_pair(v) for k,v in pairs.items()}
        columns={r[1] for r in con.execute('PRAGMA table_info(work_items)')}
        def column(name):return name if name in columns else 'NULL AS '+name
        rows=[dict(r) for r in con.execute('SELECT '+','.join(column(k) for k in ['ea_id','symbol','phase','gate_contract_version','status','verdict','created_at','updated_at','payload_json'])+' FROM work_items WHERE ea_id IS NOT NULL')]
        phase_three=legacy._phase_three_pair_states(con,summaries)
    finally:con.close()
    by_ea=defaultdict(list);by_cell=defaultdict(list)
    for r in rows:
        g=legacy._public_gate(str(r['phase'] or ''),r['gate_contract_version']);r['public_gate']=g
        try:p=json.loads(r['payload_json'] or '{}')
        except (ValueError,TypeError):p={}
        if not isinstance(p,dict):p={}
        r['public_reason_input']=p.get('verdict_reason') or p.get('machine_reason') or ''
        r['public_timeframe']=timeframe(p.get('timeframe') or p.get('period'))
        by_ea[r['ea_id']].append(r);by_cell[(r['ea_id'],r['symbol'],g)].append(r)
    slug_map=legacy.build_slug_map(Path(repo_root));folders={}
    for p in (Path(repo_root)/'framework/EAs').glob('QM5_*'):
        m=re.match(r'(QM5_\d+)_',p.name)
        if m and p.is_dir():folders[m.group(1)]=p
    pair_by_ea=defaultdict(list)
    for pair in pairs:pair_by_ea[pair[0]].append(pair)
    items=[];review=[]
    for cp in sorted(cards_dir.glob('QM5_*.md')):
        projected=legacy.project_card(cp)
        if not projected:continue
        ea=projected['ea_id'];pid=projected['card_id'];fm,_=legacy._parse_frontmatter(cp.read_text(encoding='utf-8',errors='replace'))
        raw_name=fm.get('title') or fm.get('name');fallback=(slug_map.get(ea) or {}).get('slug') or fm.get('slug') or 'Mechanical Strategy'
        name=public_text(raw_name or str(fallback).replace('-',' ').title(),limit=16) or 'Mechanical Strategy'
        name=name[0].upper()+name[1:]
        quality='strong' if raw_name and not re.search(r'\d|_|`',str(raw_name)) and len(name.split())>=2 else 'weak'
        raw_summary=fm.get('public_summary')
        spec_path=(folders[ea]/'SPEC.md') if ea in folders else None
        if not raw_summary and spec_path and spec_path.is_file():
            spec=spec_path.read_text(encoding='utf-8',errors='replace');m=re.search(r'(?ims)^##\s*1\.\s*Strategy Logic\s*\n(.*?)(?=^##|\Z)',spec)
            if m:raw_summary=next((p.strip() for p in re.split(r'\n\s*\n',m.group(1)) if p.strip() and not p.strip().startswith(('#','---','|'))),'')
        summary=public_text(raw_summary) or 'A mechanical trading strategy undergoing evidence review.'
        concepts=fm.get('concepts') or fm.get('edge_type') or fm.get('type') or 'Mechanical strategy'
        if isinstance(concepts,list):concepts=', '.join(map(str,concepts))
        family=public_text(str(concepts).replace('concepts/','').replace('_',' '),limit=12) or 'Mechanical strategy'
        states={g:'UNTESTED' for g in legacy.PUBLIC_GATE_IDS};states['Q00']='PASS'
        if (slug_map.get(ea) or {}).get('has_binary') or by_ea[ea]:states['Q01']='PASS'
        backtests=defaultdict(list)
        for pair in pair_by_ea[ea]:
            public_symbol=market(pair[1])
            if not public_symbol:continue  # basket/internal host names never leak
            ps=legacy._pair_states(pairs[pair],summaries[pair]);ps.update(phase_three.get(pair,{}))
            for g, state in ps.items():
                if legacy._STATE_PRECEDENCE[state]>legacy._STATE_PRECEDENCE[states[g]]:states[g]=state
                if state not in ('PASS','FAIL'):continue
                cell=[r for r in by_cell[(ea,pair[1],g)] if str(r['status']).lower() in ('done','failed') and vclass(r['verdict'],g)==('PASS' if state=='PASS' else 'ECON_FAIL')]
                tfs={r['public_timeframe'] for r in cell} or {'UNKNOWN'}
                for tf in sorted(tfs):backtests[g].append({'symbol_public':public_symbol,'timeframe':tf,'verdict':state})
        journey=[]
        for g in legacy.PUBLIC_GATE_IDS:
            verdict=states[g]
            if verdict not in ('PASS','FAIL'):continue
            relevant=[r for r in by_ea[ea] if r['public_gate']==g]
            journey.append({'gate':g,'verdict':verdict,'public_reason':reason(relevant,verdict),'backtests':sorted(backtests[g],key=lambda b:(b['symbol_public'],b['timeframe'],b['verdict']))})
        intended=fm.get('target_symbols') or []
        if isinstance(intended,str):intended=[intended]
        markets=sorted({s for v in [*intended,*[r['symbol'] for r in by_ea[ea]]] if (s:=market(v))})
        dates=[d for r in by_ea[ea] if r['public_gate'] and r['public_gate']>='Q02' for d in [day(r['created_at'])] if d]
        updates=[d for r in by_ea[ea] for d in [day(r['updated_at'])] if d]
        item={'public_id':pid,'slug':name_slug(name,pid),'display_name':name,'name_quality':quality,'family':family,'summary':summary,
              'markets':[{'symbol_public':s,'timeframe':timeframe(fm.get('period'))} for s in markets],
              'first_tested':min(dates) if dates else None,'last_updated':max(updates) if updates else day(fm.get('last_updated')),
              'terminal_gate':journey[-1]['gate'] if journey else None,'gate_journey':journey}
        items.append(item)
        sample_class='passed' if states['Q14']=='PASS' else 'advancing' if 'IN_PROGRESS' in states.values() else 'failed' if 'FAIL' in states.values() else 'untested'
        review.append({'public_id':pid,'sample_class':sample_class,'name_quality':quality})
    items.sort(key=lambda x:x['public_id'])
    archive={'schema_version':3,'$schema_id':SCHEMA,'generated_at':generated_at or dt.datetime.now(dt.timezone.utc).isoformat(),'gate_contract_version':'v4','disclosure':DISCLOSURE,'gates':list(legacy.PUBLIC_GATE_IDS),'total':len(items),'items':items}
    validate(archive)
    return archive,review


def validate(archive):
    fail=legacy.PublicSnapshotContractError
    if set(archive)!=TOP or archive['schema_version']!=3 or archive['$schema_id']!=SCHEMA or archive['disclosure']!=DISCLOSURE or archive['gate_contract_version']!='v4':raise fail('archive v3 root contract mismatch')
    if archive['gates']!=list(legacy.PUBLIC_GATE_IDS) or archive['total']!=len(archive['items']):raise fail('archive v3 population mismatch')
    if type(archive['total']) is not int or not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|\+00:00)',str(archive['generated_at'])):raise fail('archive v3 timestamp/count')
    seen=set();slugs=set()
    def text(value):
        if not isinstance(value,str) or not value or re.search(r'\d',value) or NUMBER_WORDS.search(value) or PRIVATE.search(value) or legacy.scrub_text(value)!=value or legacy.REDACTED in value:raise fail('archive v3 unsafe prose')
    def market_row(row,with_verdict=False):
        if set(row)!=({'symbol_public','timeframe','verdict'} if with_verdict else {'symbol_public','timeframe'}):raise fail('archive v3 market fields')
        if market(row['symbol_public'])!=row['symbol_public'] or not TIMEFRAME.fullmatch(row['timeframe']):raise fail('archive v3 invalid market/timeframe')
        if with_verdict and row['verdict'] not in ('PASS','FAIL'):raise fail('archive v3 invented result')
    for item in archive['items']:
        if set(item)!=ITEM or not legacy._PUBLIC_ID_RE.fullmatch(item['public_id']):raise fail('archive v3 item whitelist')
        if item['public_id'] in seen or item['slug'] in slugs:raise fail('archive v3 duplicate identity')
        seen.add(item['public_id']);slugs.add(item['slug'])
        if item['slug']!=name_slug(item['display_name'],item['public_id']):raise fail('archive v3 unstable slug')
        for k in ('display_name','family','summary'):text(item[k])
        if len(item['summary'].split())>60 or item['name_quality'] not in ('strong','weak'):raise fail('archive v3 copy bounds')
        for d in ('first_tested','last_updated'):
            if item[d] is not None and day(item[d])!=item[d]:raise fail('archive v3 invalid date')
        for row in item['markets']:market_row(row)
        gates=[]
        for j in item['gate_journey']:
            if set(j)!={'gate','verdict','public_reason','backtests'} or j['gate'] not in legacy.PUBLIC_GATE_IDS or j['verdict'] not in ('PASS','FAIL'):raise fail('archive v3 gate whitelist')
            if j['public_reason'] not in REASONS.values():raise fail('archive v3 reason is not public taxonomy')
            text(j['public_reason']);gates.append(j['gate'])
            for b in j['backtests']:market_row(b,True)
        if gates!=sorted(set(gates)) or item['terminal_gate']!=(gates[-1] if gates else None):raise fail('archive v3 journey order')
