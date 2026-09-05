"""Exact nine-row append-only canonical path repair; dry run is the default."""
from __future__ import annotations

import csv
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import sqlite3

try:
    from . import canonical_setfile_paths as paths
    from . import farmctl, validate_build_guardrails as guardrails
    from .factory_mutation_lock import FactoryMutationLock, path_for_factory_flag
except ImportError:
    import canonical_setfile_paths as paths
    import farmctl
    import validate_build_guardrails as guardrails
    from factory_mutation_lock import FactoryMutationLock, path_for_factory_flag

AUTHORITY = 'router_ops_issue:a3ec5b69-ae8f-475c-b939-2c9b04224761'
PREVIEW_HASHES = {
    '0ff05819-1aab-42ff-a517-58724492c77b': '2a3436080bb58a86319e62ef25c097bd915d9122f71e25d040a3499bb0a49ba4',
    '1821432a-2f41-4417-b680-e3947b1c4ef7': '51271f7887dd818ce8a4be8e69af7c4645d633b4b305d145e4ca8ad26ebf91c5',
    '7c137654-dcb4-44dd-9cbd-d233b75684b9': '57b4a817e168ecc89ea5cc1ae3d7eecb917e87655d9c7ef9a86c103547aba1c9',
    '85590a54-63e5-443a-8f17-2bee061483b1': '648fae9bc7ec96a43a6c37a01476fa4e81cea1162ca3d5e194e36f3788038867',
    '995f36e9-b08c-4e28-aa77-5322cc419ecb': '4f158f647e3a5bd6a05a41edaa55c86075e6780ecf97faecb526410980c49d82',
    'adda1ec6-cc3e-4f60-b51f-2b566033adcb': '85ab5a15b529752fe005fcc63b83dc87b38f00bbc3dfe5221134d7e242bbeefb',
    'b1384ee3-e582-46ce-8432-193b4865a854': '8c40413d64311f221dc72416c489a3f2b74f4ef39e79b400a5e199ce41fe6cbd',
    'b7189709-abe5-4bff-ab28-d4f6a4fdd1e6': '3f7fa4c338325c447312b7113f063cfb1418965413af6c907e8855a956e0996d',
    'f7950e47-85b7-43dd-bc5f-a67e27e75c6a': '9341f93ca68f1325d6f648cd5080c3e1759518f33a337bee61f5af1d11aa542a',
}


class RepairRefused(ValueError):
    pass


def _current_guardrails(repo_root):
    # Dry runs from an isolated worktree still load the canonical checker and
    # its canonical session-offset registry. Integration uses the same path.
    source=repo_root/'tools/strategy_farm/validate_build_guardrails.py'
    spec=importlib.util.spec_from_file_location('qm_canonical_path_repair_guardrails',source)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def load_authorities(repo_root=paths.CANONICAL_REPO):
    result = {}
    for item_id, expected in PREVIEW_HASHES.items():
        path = repo_root/'docs/ops/evidence/2026-09-05_worktree_path_rows'/f'{item_id}.json'
        raw = path.read_bytes()
        if hashlib.sha256(raw).hexdigest() != expected:
            raise RepairRefused('APPROVED_PREVIEW_BYTES_CHANGED:'+item_id)
        result[item_id] = json.loads(raw)
    return result


def current_gates(conn, row, proposal, repo_root):
    """Read-only subset of the existing dispatch gates; never auto-compile."""
    failures = []
    preset = Path(proposal['canonical_setfile_path'])
    ex5 = Path(proposal['canonical_ex5_path'])
    mq5 = ex5.with_suffix('.mq5')
    registry = repo_root/'framework/registry'
    input_hashes = {str(p):paths.digest(p) for p in
                   (mq5,registry/'ea_id_registry.csv',registry/'magic_numbers.csv',registry/'session_offset_minutes.csv')}
    fixed, fixed_detail = farmctl._q02_fixed_risk_contract(str(preset))
    if not fixed: failures.append('FIXED_RISK_GATE_FAILED')
    # Same cached-build predicate as farmctl._compile_gate_check. If it needs
    # compilation, refuse here; path repair never runs a compiler as a side effect.
    if not mq5.is_file() or not ex5.is_file() or ex5.stat().st_size <= 0 or ex5.stat().st_mtime < mq5.stat().st_mtime:
        failures.append('CURRENT_BUILD_REQUIRES_GOVERNED_COMPILE')
    if sorted(p.name for p in ex5.parent.glob('*.ex5')) != [ex5.name]:
        failures.append('CANONICAL_BUILD_BINARY_AMBIGUOUS')
    build = _current_guardrails(repo_root).validate_path(ex5.parent, max_news_stale_hours=336)
    if build['verdict'] != 'PASS': failures.append('BUILD_GUARDRAILS_FAILED')
    ea_number = row['ea_id'].removeprefix('QM5_')
    slug = ex5.parent.name.removeprefix(row['ea_id']+'_')
    with (registry/'ea_id_registry.csv').open(encoding='utf-8-sig',newline='') as f:
        identities = [r for r in csv.DictReader(f) if r['ea_id'].removeprefix('QM5_') == ea_number]
    if len(identities)!=1 or identities[0]['status']!='active' or identities[0]['slug']!=slug:
        failures.append('EA_REGISTRY_GATE_FAILED')
    values = guardrails._parse_setfile(preset)
    try: slot = int(values['qm_magic_slot_offset'])
    except (KeyError,ValueError): slot = -1
    with (registry/'magic_numbers.csv').open(encoding='utf-8-sig',newline='') as f:
        magics = list(csv.DictReader(f))
    expected_magic = int(ea_number)*10000+slot
    matches = [r for r in magics if r.get('magic') == str(expected_magic)]
    if (slot<0 or len(matches)!=1 or matches[0].get('status')!='active'
            or matches[0].get('ea_id')!=ea_number or matches[0].get('ea_slug')!=slug
            or matches[0].get('symbol')!=row['symbol'] or matches[0].get('symbol_slot')!=str(slot)):
        failures.append('MAGIC_REGISTRY_GATE_FAILED')
    parent = row.get('parent_task_id')
    payload = json.loads(row['payload_json'])
    if parent:
        found = conn.execute('SELECT * FROM tasks WHERE id=?',(parent,)).fetchone()
        if found is None:
            failures.append('PARENT_LINEAGE_MISSING')
        else:
            parent_payload = json.loads(found['payload_json'])
            if parent_payload.get('ea_id')!=row['ea_id'] or farmctl.phase_qid(parent_payload.get('phase',''))!=row['phase']:
                failures.append('PARENT_PHASE_LINEAGE_MISMATCH')
    prior = payload.get('requeue_source')
    if prior:
        ancestor = conn.execute('SELECT * FROM work_items WHERE id=?',(prior.get('work_item_id'),)).fetchone()
        if ancestor is None or any(ancestor[k]!=row[k] for k in ('ea_id','phase','symbol')):
            failures.append('REQUEUE_PHASE_LINEAGE_MISMATCH')
    return {'failures': failures, 'fixed_risk': fixed_detail, 'build_guardrails': build,
            'parent_task_id_preserved': parent, 'requeue_source_preserved': prior,
            'recheck_file_hashes': input_hashes}


def revalidate(conn, item_id, authorities, repo_root, *, gate_check=current_gates):
    approved = authorities.get(item_id)
    if not approved: raise RepairRefused('WORK_ITEM_NOT_PREVIEWED')
    found = conn.execute('SELECT * FROM work_items WHERE id=?',(item_id,)).fetchone()
    if found is None: raise RepairRefused('PREDECESSOR_MISSING')
    row = dict(found)
    if row['status']!='pending' or row['claimed_by'] is not None:
        raise RepairRefused('PREDECESSOR_NOT_UNCLAIMED_PENDING')
    current = paths.pending_successor_proposal(row,repo_root)
    fields = ('source_row_sha256','source_payload_sha256','ea_id','phase','symbol',
              'old_setfile_path','old_setfile_sha256','canonical_setfile_path',
              'canonical_setfile_sha256','canonical_ex5_path','canonical_ex5_sha256','proposed_successor_id')
    for field in fields:
        if current[field] != approved[field]: raise RepairRefused('APPROVED_'+field.upper()+'_CHANGED')
    # The CEO selected the exact canonical bytes for these nine, including the
    # reviewed 5->34 slot correction. No other equivalence blocker is waived.
    blockers = [b for b in current['blockers'] if b!='SETFILE_BYTES_DIFFER_SOURCE_REVIEW_REQUIRED']
    if blockers: raise RepairRefused(';'.join(blockers))
    if row['kind']!='backtest' or row['phase'] not in {'Q02','Q04'}:
        raise RepairRefused('PHASE_KIND_LINEAGE_UNSUPPORTED')
    successor = approved['proposed_successor_id']
    if conn.execute('SELECT 1 FROM work_items WHERE id=?',(successor,)).fetchone():
        raise RepairRefused('SUCCESSOR_ALREADY_EXISTS')
    if conn.execute('SELECT 1 FROM work_item_supersedes WHERE work_item_id=? OR superseded_by_work_item_id=?',(item_id,successor)).fetchone():
        raise RepairRefused('EXISTING_SUPERSESSION')
    # A path repair may not manufacture a second open row for the same pair.
    competitors = conn.execute("SELECT id,setfile_path FROM work_items WHERE ea_id=? AND phase=? AND symbol=? AND status IN ('pending','active') AND id<>? AND NOT EXISTS (SELECT 1 FROM work_item_supersedes s WHERE s.work_item_id=work_items.id)",
                               (row['ea_id'],row['phase'],row['symbol'],item_id)).fetchall()
    if competitors: raise RepairRefused('COMPETING_OPEN_SUCCESSOR:'+','.join(r['id'] for r in competitors))
    gates = gate_check(conn,row,current,repo_root)
    if gates['failures']: raise RepairRefused(';'.join(gates['failures']))
    holds = [dict(r) for r in conn.execute('SELECT * FROM work_item_holds WHERE work_item_id=?',(item_id,))]
    current.update(apply_supported=True,authority_status='CANONICAL_BYTES_SELECTED_BY_TASK',
                   reviewed_byte_difference=current['old_setfile_sha256']!=current['canonical_setfile_sha256'],blockers=[])
    return {'source':row,'proposal':current,'holds':holds,'gates':gates,'authority':AUTHORITY}


def run(item_ids, *, apply=False, database=paths.DATABASE, repo_root=paths.CANONICAL_REPO,
        authorities=None, receipt_path=None, gate_check=current_gates):
    authorities = load_authorities(repo_root) if authorities is None else authorities
    if not item_ids or len(set(item_ids))!=len(item_ids): raise RepairRefused('EMPTY_OR_DUPLICATE_TARGETS')
    database = Path(database)
    farm_root = database.parent.parent
    receipt = {'schema':'qm.canonical-setfile-apply/v1','authority':AUTHORITY,
               'dry_run':not apply,'applied':False,'targets':list(item_ids),'rows':[]}
    def inspect(conn):
        plans=[]
        for item_id in item_ids:
            try:
                plan=revalidate(conn,item_id,authorities,repo_root,gate_check=gate_check)
                receipt['rows'].append({'id':item_id,'eligible':True,**plan})
                plans.append(plan)
            except (ValueError,OSError,KeyError,TypeError) as exc:
                receipt['rows'].append({'id':item_id,'eligible':False,'reason':str(exc)})
        return plans
    if not apply:
        with sqlite3.connect(database.as_uri()+'?mode=ro',uri=True) as conn:
            conn.row_factory=sqlite3.Row;conn.execute('PRAGMA query_only=ON')
            inspect(conn)
        receipt['eligible']=all(r['eligible'] for r in receipt['rows'])
        return receipt
    if receipt_path is None: raise RepairRefused('DURABLE_RECEIPT_PATH_REQUIRED')
    receipt_path=Path(receipt_path).resolve()
    if not receipt_path.is_relative_to((repo_root/'docs/ops/evidence').resolve()):
        raise RepairRefused('RECEIPT_NOT_CANONICAL_EVIDENCE')
    if receipt_path.exists(): raise RepairRefused('RECEIPT_ALREADY_EXISTS')
    flag=farmctl.factory_off_flag_path(farm_root)
    with FactoryMutationLock(path_for_factory_flag(flag),owner='canonical_setfile_paths.apply'):
        if farmctl.factory_is_off(farm_root): raise RepairRefused('FACTORY_OFF')
        # Online backup precedes BEGIN IMMEDIATE, avoiding backup/write deadlock.
        backup,sha=farmctl._governed_state_backup(farm_root,'canonical_setfile_paths')
        receipt['backup']={'path':str(backup),'sha256':sha}
        if not Path(backup).is_file() or paths.digest(Path(backup))!=sha:
            raise RepairRefused('GOVERNED_BACKUP_UNVERIFIED')
        if farmctl.factory_is_off(farm_root): raise RepairRefused('FACTORY_OFF')
        with sqlite3.connect(database) as conn:
            conn.row_factory=sqlite3.Row;conn.execute('PRAGMA foreign_keys=ON');conn.execute('BEGIN IMMEDIATE')
            if not conn.execute("SELECT 1 FROM sqlite_master WHERE type='trigger' AND name='trg_work_items_superseded_no_activate'").fetchone():
                raise RepairRefused('SUPERSESSION_CLAIM_GUARD_MISSING')
            plans=inspect(conn)
            if len(plans)!=len(item_ids):
                conn.rollback();receipt['eligible']=False;return receipt
            now=dt.datetime.now(dt.UTC).isoformat()
            columns={r['name'] for r in conn.execute('PRAGMA table_info(work_items)')}
            for plan in plans:
                predecessor=plan['source'];proposal=plan['proposal'];new=dict(predecessor)
                payload=json.loads(predecessor['payload_json'])
                payload['canonical_path_repair']={'authority':AUTHORITY,'supersedes_work_item_id':predecessor['id'],
                    'source_row_sha256':proposal['source_row_sha256'],'old_setfile_sha256':proposal['old_setfile_sha256'],
                    'canonical_setfile_sha256':proposal['canonical_setfile_sha256'],'canonical_ex5_sha256':proposal['canonical_ex5_sha256'],
                    'receipt_path':str(receipt_path),'backup_sha256':sha}
                payload['expected_ex5_sha256']=proposal['canonical_ex5_sha256']
                payload['expected_setfile_sha256']=proposal['canonical_setfile_sha256']
                new.update(id=proposal['proposed_successor_id'],setfile_path=proposal['canonical_setfile_path'],
                           created_at=now,updated_at=now,payload_json=json.dumps(payload,sort_keys=True),attempt_count=0,
                           ex5_sha256=proposal['canonical_ex5_sha256'],setfile_sha256=proposal['canonical_setfile_sha256'],
                           sh3_enforced=1,gate_contract_version='v4')
                new={k:v for k,v in new.items() if k in columns}
                conn.execute('INSERT INTO work_items ('+','.join(new)+') VALUES ('+','.join('?' for _ in new)+')',tuple(new.values()))
                for old_hold in plan['holds']:
                    hold={**old_hold,'work_item_id':new['id']}
                    conn.execute('INSERT INTO work_item_holds ('+','.join(hold)+') VALUES ('+','.join('?' for _ in hold)+')',tuple(hold.values()))
                conn.execute('INSERT INTO work_item_supersedes (work_item_id,superseded_by_work_item_id,reason,source_encoding,evidence_path,recorded_by,recorded_at) VALUES (?,?,?,?,?,?,?)',
                             (predecessor['id'],new['id'],'canonical setfile authority; original row preserved','canonical_path_repair',str(receipt_path),AUTHORITY,now))
                after=dict(conn.execute('SELECT * FROM work_items WHERE id=?',(predecessor['id'],)).fetchone())
                if after!=predecessor: raise RepairRefused('PREDECESSOR_CHANGED_DURING_APPLY')
            for plan in plans:
                proposal=plan['proposal']
                checks={proposal['old_setfile_path']:proposal['old_setfile_sha256'],
                        proposal['canonical_setfile_path']:proposal['canonical_setfile_sha256'],
                        proposal['canonical_ex5_path']:proposal['canonical_ex5_sha256'],
                        **plan['gates'].get('recheck_file_hashes',{})}
                if any(paths.digest(Path(path))!=expected for path,expected in checks.items()):
                    raise RepairRefused('ARTIFACT_CHANGED_BEFORE_COMMIT')
            if farmctl.factory_is_off(farm_root): raise RepairRefused('FACTORY_OFF')
            receipt.update(eligible=True,applied=True,recorded_at=now)
            # The transactional audit event is the durable receipt/outbox. A
            # sidecar publication failure can be recovered without reapplying.
            conn.execute('INSERT INTO events (ts,entity_type,entity_id,event,detail_json) VALUES (?,?,?,?,?)',
                         (now,'canonical_setfile_paths',AUTHORITY,'canonical_path_repair_applied',json.dumps(receipt,sort_keys=True)))
            conn.commit()
        try:
            receipt_path.parent.mkdir(parents=True,exist_ok=True)
            with receipt_path.open('x',encoding='utf-8') as handle:
                json.dump(receipt,handle,indent=2,sort_keys=True);handle.write('\n');handle.flush();os.fsync(handle.fileno())
        except OSError as exc:
            receipt['sidecar_error']=str(exc)
            receipt['receipt_recovery']='Recover the committed canonical_path_repair_applied event; do not reapply'
    return receipt
