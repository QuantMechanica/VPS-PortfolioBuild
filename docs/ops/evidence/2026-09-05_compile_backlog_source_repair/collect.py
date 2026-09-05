"""Read-only source-history inventory and seven proposed authority receipts."""
from pathlib import Path
import concurrent.futures
import datetime as dt
import difflib
import hashlib
import json
import sqlite3
import subprocess

REPO = Path('C:/QM/repo')
OUT = Path(__file__).resolve().parent
TASK = 'fd5e3ce3-9f48-497d-9c2f-3b6be0f2eac8'


def git(*args):
    return subprocess.check_output(['git', *args], cwd=REPO)


def sha(raw):
    return hashlib.sha256(raw).hexdigest()


wave = json.loads(subprocess.check_output(['python', str(REPO/'tools/strategy_farm/release_compile_wave.py'),
                                         '--max-items', '10'], cwd=REPO))
(OUT/'wave_dry_run.json').write_text(json.dumps(wave,indent=2)+'\n',encoding='utf-8')
c = sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True)
c.row_factory = sqlite3.Row
c.execute('PRAGMA query_only=ON')
groups = {}
for row in wave['deferred']:
    if row['reason'] != 'SOURCE_SHA_STALE_OR_MISSING':
        continue
    row['work_item'] = dict(c.execute('SELECT * FROM work_items WHERE id=?',(row['work_item_id'],)).fetchone())
    groups.setdefault(row['ea_id'], []).append(row)
c.close()


def inspect(pair):
    ea, rows = pair
    directory = OUT/ea
    directory.mkdir(exist_ok=False)
    source = Path(rows[0]['source_path'])
    raw = source.read_bytes()
    relative = source.relative_to(REPO).as_posix()
    commits = git('log','--all','-100','--format=%H','--',relative).decode().splitlines()
    versions = []
    for commit in commits:
        try:
            blob = git('show', commit+':'+relative)
        except subprocess.CalledProcessError:
            continue
        normalized = blob.replace(b'\r\n',b'\n')
        versions.append((commit, normalized, {sha(blob),sha(normalized),sha(normalized.replace(b'\n',b'\r\n'))}))
    details = []
    for i,row in enumerate(rows):
        expected = row['expected_mq5_sha256']
        match = next(((commit,blob) for commit,blob,hashes in versions if expected in hashes),None)
        item = {'work_item_id':row['work_item_id'],'created_at':row['work_item']['created_at'],
                'expected_sha256':expected,'expected_git_commit':match[0] if match else None,
                'evidence_path':row['work_item'].get('evidence_path')}
        history = git('log','--all','--since='+row['work_item']['created_at'],
                      '--format=%H %aI %s','--',relative).decode('utf-8','replace')
        (directory/f'history_{i}.txt').write_text(history,encoding='utf-8')
        if match:
            before=match[1].decode('utf-8-sig')
            after=raw.decode('utf-8-sig').replace('\r\n','\n')
            patch=''.join(difflib.unified_diff(before.splitlines(True),after.splitlines(True),
                                              fromfile='expected/'+relative,tofile='current/'+relative))
            (directory/f'source_diff_{i}.patch').write_text(patch,encoding='utf-8')
            item['diff_path']=str(directory/f'source_diff_{i}.patch')
        evidence_path=Path(item['evidence_path'] or '')
        item['evidence_sha256']=sha(evidence_path.read_bytes()) if evidence_path.is_file() else None
        details.append(item)
    (directory/'current_source.mq5').write_bytes(raw)
    inventory={'ea_id':ea,'ea_label':rows[0]['ea_label'],'source_path':str(source),'source_sha256':sha(raw),
               'predecessors':details,'history_basis':'All refs, max 100 source commits; expected hash matches raw/LF/CRLF variants.',
               'candidate_intent':'PENDING_SOURCE_DIFF_REVIEW','recorded_at':dt.datetime.now(dt.UTC).isoformat()}
    (directory/'inventory.json').write_text(json.dumps(inventory,indent=2)+'\n',encoding='utf-8')
    authority={'schema':'qm.compile-source-repair-proposal/v1','status':'PROPOSED_NOT_REGISTERED',
               'router_task_id':TASK,'authority_key':'router_ops_issue:'+TASK,'ea_id':ea,
               'ea_label':inventory['ea_label'],'source_path':str(source),'source_sha256':sha(raw),
               'predecessors':details,'source_review_evidence':{'path':str(directory/'inventory.json'),
               'sha256':sha((directory/'inventory.json').read_bytes())},
               'admission_authorized':False,'note':'The current source-repair API accepts registered authority keys; it has no generic JSON-authority-file loader.'}
    (directory/'authority_proposal.json').write_text(json.dumps(authority,indent=2)+'\n',encoding='utf-8')
    request=directory/'compile_request.txt';request.write_text(inventory['ea_label']+'\n',encoding='utf-8')
    command=['python',str(REPO/'tools/strategy_farm/farmctl.py'),'enqueue-compile','--from-file',str(request),
             '--source-repair-authority','router_ops_issue:'+TASK]
    result=subprocess.run(command,cwd=REPO,capture_output=True,text=True,encoding='utf-8')
    try: output=json.loads(result.stdout)
    except ValueError: output={'stdout':result.stdout,'stderr':result.stderr}
    (directory/'enqueue_dry_run.json').write_text(json.dumps({'command':command,'exit_code':result.returncode,'result':output},indent=2)+'\n',encoding='utf-8')
    return inventory


with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    results=list(pool.map(inspect,sorted(groups.items())))
(OUT/'inventory.json').write_text(json.dumps({'snapshot_utc':dt.datetime.now(dt.UTC).isoformat(),
    'dry_run':True,'ea_count':len(results),'predecessor_count':sum(len(x['predecessors']) for x in results),
    'rows':results},indent=2)+'\n',encoding='utf-8')
print(json.dumps({'ea_count':len(results),'predecessor_count':sum(len(x['predecessors']) for x in results),
                  'expected_versions_found':sum(p['expected_git_commit'] is not None for x in results for p in x['predecessors'])},indent=2))
