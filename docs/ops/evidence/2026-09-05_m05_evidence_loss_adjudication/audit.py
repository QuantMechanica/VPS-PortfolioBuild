"""Read-only M05 inventory and heartbeat delta. Only --out receives new files."""
import argparse
import collections
import datetime as dt
import gzip
import hashlib
import json
import re
import sqlite3
import sys
from pathlib import Path

sys.path.insert(0, 'C:/QM/repo')
from tools.strategy_farm import release_status as rs
from tools.strategy_farm import tester_cache_purge_guard as guard

BASELINE = Path('C:/QM/repo/artifacts/evidence_cohort_baseline.json')
REPORTS = Path('D:/QM/reports')
CENSUS = Path('D:/QM/strategy_farm/artifacts/opt_census')


def digest(data):
    return hashlib.sha256(data).hexdigest()


def inspect(path, quarantines):
    p = Path(path)
    candidates = [(p, 'PRESENT'), (Path(str(p)+'.gz'), 'RETENTION_BY_RULE_GZIP')]
    try:
        rel = p.relative_to(REPORTS)
        candidates += [(q/rel, 'ARCHIVED_QUARANTINE') for q in quarantines]
    except ValueError:
        pass
    for candidate, kind in candidates:
        if not candidate.is_file():
            continue
        try:
            raw = candidate.read_bytes()
            decoded = gzip.decompress(raw) if candidate.suffix.lower() == '.gz' else raw
            if p.suffix.lower() == '.json':
                json.loads(decoded.decode('utf-8-sig'))
            return {'classification': kind, 'located_path': str(candidate), 'observed_sha256': digest(raw),
                    'decoded_sha256': digest(decoded), 'bytes': len(raw),
                    'original_hash_comparison': 'UNAVAILABLE_UNLESS_DEPENDENCY_HAS_EXPECTED_HASH',
                    'retention_authority': 'DL-090' if kind != 'PRESENT' else None}
        except (OSError, ValueError, UnicodeError, EOFError) as exc:
            return {'classification': 'UNEXPLAINED', 'located_path': str(candidate), 'error': str(exc)}
    return {'classification': 'UNEXPLAINED', 'located_path': None}


def path_refs(node, prefix=''):
    if isinstance(node, dict):
        for k, v in node.items():
            field = f'{prefix}.{k}' if prefix else k
            if isinstance(v, str) and re.match(r'^[A-Za-z]:[\\/]', v) and ('path' in k.lower() or k.endswith(('evidence','artifact','source','report','setfile'))):
                expected = node.get(k.replace('_path', '_sha256')) if k.endswith('_path') else node.get('sha256')
                yield field, v, expected if isinstance(expected, str) and re.fullmatch('[0-9a-f]{64}', expected) else None
            elif isinstance(v, (list, dict)):
                yield from path_refs(v, field)
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from path_refs(v, f'{prefix}[{i}]')


def run(out, previous=None):
    out.mkdir(parents=True, exist_ok=False)
    raw = BASELINE.read_bytes(); baseline = json.loads(raw)
    quarantines = sorted(p for p in (REPORTS/'_retention_quarantine').iterdir() if p.is_dir())
    logs = {}
    for name in ('report_retention.log', 'report_retention_purge.log', 'tester_cache_purge.log', 'reports_log_purge.log'):
        p = REPORTS/'state'/name
        if p.exists():
            b = p.read_bytes(); logs[name] = b.decode('utf-8-sig', errors='replace').splitlines()
            (out/name).write_bytes(b)
    entries = []
    log_hits = collections.defaultdict(list)
    uuid_pattern = re.compile(r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}', re.I)
    for name, lines in logs.items():
        for i, line in enumerate(lines, 1):
            for wid in set(m.lower() for m in uuid_pattern.findall(line)):
                log_hits[wid].append({'log': name, 'line': i, 'text': line})
    losses = baseline.get('losses', [])
    last_check = baseline['observations'][-1]['checked_at_utc']
    previous_check = baseline['observations'][-2]['checked_at_utc']
    last_ids = {r['work_item_id'] for r in losses if r['observed_missing_at_utc'][:10] == last_check[:10]}
    prior_ids = {r['work_item_id'] for r in losses if r['observed_missing_at_utc'][:10] == previous_check[:10]}
    for wid, e in baseline['entries'].items():
        item = {**e, **inspect(e['evidence_path'], quarantines)}
        item['first_recorded_missing_utc'] = min((r['observed_missing_at_utc'] for r in losses if r['work_item_id'] == wid), default=None)
        item['in_last_watcher_loss'] = wid in last_ids
        item['in_32_watcher_delta'] = wid in last_ids-prior_ids
        item['exact_purge_log_hits'] = log_hits[wid.lower()]
        if wid.lower() not in e['evidence_path'].lower():
            item['exact_purge_log_hits'] += [{'log':name,'line':i,'text':line} for name, lines in logs.items() for i,line in enumerate(lines,1) if e['evidence_path'].lower() in line.lower()]
        # A coarse batch log or present-day eligibility never proves a missing file was deleted lawfully.
        if item['classification'] == 'UNEXPLAINED' and item['exact_purge_log_hits']:
            item['purge_log_hit_requires_adjudication'] = True
        entries.append(item)
    c = rs.rc.open_ro(str(guard.DEFAULT_DB));c.execute('PRAGMA query_only=ON');c.execute('BEGIN')
    thin = [dict(r) for r in c.execute('SELECT id,ea_id,symbol,phase,status,verdict,gate_contract_version,updated_at,evidence_path FROM work_items WHERE ea_id IS NOT NULL')]
    frontier = [r for r in thin if rs.gate(r) == 'Q11' and rs.passing(r)]
    frontier_pairs = {(r['ea_id'],r['symbol']) for r in frontier}
    ledgers = []
    for p in sorted(CENSUS.glob('*/ledger.json')):
        try:
            j = json.loads(p.read_text(encoding='utf-8-sig'))
            ledgers.append((p,j))
        except (ValueError,OSError) as exc:
            raise RuntimeError(f'Cannot audit census ledger {p}: {exc}')
    census_pairs = {(f"QM5_{guard.normalize_ea_id(j.get('subject_ea_id') or j['ea_id'])}",j['symbol']) for _,j in ledgers}
    live = rs.read_json(guard.DEFAULT_LIVE_PULSE); mp = Path(live['book_manifest']['path']); manifest = rs.read_json(mp)
    live_pairs = {(f"QM5_{r['ea_id']}",r['symbol']) for r in manifest['sleeves']}
    sources = collections.defaultdict(set)
    for name,pairs in [('Q11_PASS_PAIR',frontier_pairs),('DL089_PROGRAM_PAIR',census_pairs),('LIVE_BOOK_PAIR',live_pairs)]:
        for pair in pairs:sources[pair].add(name)
    dependencies = []
    seen = set()
    def add(path, owner, expected=None, field=None):
        key=(str(path),owner,expected)
        if key in seen:return
        seen.add(key)
        p=Path(path)
        if p.is_dir():return
        detail=inspect(str(path),quarantines)
        if expected:
            detail['binding_status']='MATCH' if detail.get('decoded_sha256')==expected or detail.get('observed_sha256')==expected else 'MISSING' if not detail.get('located_path') else 'MISMATCH'
        else:detail['binding_status']='NO_EXPECTED_HASH' if detail.get('located_path') else 'MISSING'
        dependencies.append({'path':str(path),'owner':owner,'field':field,'expected_sha256':expected,
                             'artifact_role':'JOURNAL_OUTSIDE_DL090_KEEP_SET' if p.suffix.lower()=='.log' else 'DECLARED_DEPENDENCY_EXISTENCE_NOT_PROOF_OF_PRIOR_PRODUCTION',**detail})
    # Traverse declared work-item parent links, not every historical row of a pair.
    pending=[(r['id'],'Q11:'+r['id']) for r in frontier];visited=set()
    while pending:
        wid,owner=pending.pop()
        if (wid,owner) in visited:continue
        visited.add((wid,owner))
        row=c.execute('SELECT * FROM work_items WHERE id=?',(wid,)).fetchone()
        if not row:continue
        r=dict(row);p=rs.obj(r.get('payload_json'))
        if r.get('evidence_path'):add(r['evidence_path'],owner,field='work_item.evidence_path')
        for field,path,expected in path_refs(p):add(path,owner,expected,field)
        parent=p.get('parent_work_item_id')
        if parent:pending.append((parent,owner))
    for p,j in ledgers:
        owner='DL089:'+j['program_id'];add(p,owner)
        for field,path,expected in path_refs(j):add(path,owner,expected,field)
    add(mp,'LIVE_MANIFEST',live['book_manifest']['sha256'])
    for field,path,expected in path_refs(manifest):add(path,'LIVE_MANIFEST',expected,field)
    for e in entries:e['active_pair_dependency_tags']=sorted(sources.get((e['ea_id'],e['symbol']),set()))
    c.close()
    counts=collections.Counter(e['classification'] for e in entries)
    result={'schema':'qm.evidence-loss-adjudication/v1','observed_at_utc':dt.datetime.now(dt.timezone.utc).isoformat(),
            'baseline_path':str(BASELINE),'baseline_sha256':digest(raw),'counts':dict(counts),'watched':len(entries),
            'last_watcher_observation':baseline['observations'][-1], 'watcher_delta_ids':sorted(last_ids-prior_ids),
            'watcher_750_classification':dict(collections.Counter(e['classification'] for e in entries if e['in_last_watcher_loss'])),
            'watcher_32_classification':dict(collections.Counter(e['classification'] for e in entries if e['in_32_watcher_delta'])),
            'source_counts':{'Q11_PASS_rows':len(frontier),'Q11_PASS_pairs':len(frontier_pairs),'DL089_ledgers':len(ledgers),'live_pairs':len(live_pairs)},
            'dependency_counts':dict(collections.Counter(d['binding_status'] for d in dependencies)),
            'acceptance_test_seal_status':'NO_RATIFIED_SEAL_LOCATED; OWNER receipt item 18 remains ready for ratification; no presumed seal',
            'limits':['Original baseline stores no content hashes; a recovered file cannot be compared with original bytes.',
                      'Quarantine and gzip inventory is an observed manifest, not a historical signed archive manifest.',
                      'Coarse retention logs do not provide per-file deletion receipts; unexplained remains unexplained.',
                      'Pair overlap is a conservative potential dependency, distinct from traversed parent/path references.',
                      'Ledger changes and file changes can occur outside the SQLite snapshot.'],
            'entries':entries,'dependencies':dependencies}
    if previous:
        old=json.loads(previous.read_text(encoding='utf-8-sig')); before={e['work_item_id']:e for e in old['entries']}
        result['daily_delta']=[{'work_item_id':e['work_item_id'],'before':before.get(e['work_item_id'],{}).get('classification'),'after':e['classification']} for e in entries if before.get(e['work_item_id'],{}).get('classification')!=e['classification']]
    (out/'inventory.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    (out/'baseline_snapshot.json').write_bytes(raw)
    # Observation manifest includes every recovered file's current and decoded hashes.
    (out/'recovery_manifest.json').write_text(json.dumps({'schema':'qm.observed-recovery-manifest/v1','original_hash_attestation':False,'files':[e for e in entries if e['classification'] in ('RETENTION_BY_RULE_GZIP','ARCHIVED_QUARANTINE')]},indent=2)+'\n')
    print(json.dumps({k:result[k] for k in ('counts','watcher_750_classification','watcher_32_classification','source_counts','dependency_counts')}))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--out',type=Path,required=True);p.add_argument('--previous',type=Path);a=p.parse_args();run(a.out,a.previous)
