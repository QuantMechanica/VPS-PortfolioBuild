"""Governed news claimability overlay. No work-item/verdict mutations.

The shipped policy is INACTIVE. Dry-run evaluates its prospective impact.
Only this module's own physical holds may be released. Other holds survive.
"""
from __future__ import annotations
import argparse
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import sys

try:
    from tools.strategy_farm import news_calendar_scoped_activation as scoped_b
except ModuleNotFoundError:
    import news_calendar_scoped_activation as scoped_b

if __name__ == '__main__':
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

CONFIG = Path(__file__).resolve().parent / 'config/news_calendar_taint.v1.json'
HOLD = 'NEWS_CALENDAR_TAINTED'
PHASES = {'Q09_NEWS', 'Q10_NEWS'}
HEX = re.compile(r'^[0-9a-f]{64}$')
E1C_MARKER_KEY = 'e1c_optionb_release'
E1C_MARKER_SCHEMA = 'qm.e1c-optionb-release-marker/v1'
E1C_DECISION_ID = 'OWNER-E1C-OPTIONB-20260916'
E1C_RECORD_SCHEMA = 'qm.e1c-optionb-row-delta/v1'


def _record_digest(record: dict) -> str:
    """Canonical self-hash of a delta record (the record_sha256 field excluded)."""
    material = {k: v for k, v in record.items() if k != 'record_sha256'}
    canonical = (json.dumps(material, sort_keys=True, separators=(',', ':'),
                            allow_nan=False) + '\n').encode()
    return hashlib.sha256(canonical).hexdigest()


def _strict(path):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValueError('duplicate JSON key')
            result[key] = value
        return result
    return json.loads(Path(path).read_text(encoding='utf-8-sig'), object_pairs_hook=pairs)


def _activation_evidence_ok(value):
    if isinstance(value, str):
        return bool(value.strip())
    if isinstance(value, dict):
        declared_by = value.get('declared_by')
        evidence = value.get('evidence')
        return (isinstance(declared_by, str) and bool(declared_by.strip())
                and isinstance(evidence, list) and len(evidence) > 0
                and all(isinstance(e, str) and e.strip() for e in evidence))
    return False


def load_policy(path=CONFIG):
    try:
        data = _strict(path)
        if not isinstance(data, dict) or data['schema'] != 'qm.news-calendar-taint/v1' or type(data['enabled']) is not bool:
            raise ValueError('invalid policy envelope')
        if not isinstance(data['tainted'], list):
            raise ValueError('invalid taint list')
        for entry in data['tainted']:
            if not isinstance(entry, dict) or not HEX.fullmatch(entry['sha256']) or not isinstance(entry['evidence_path'], str) or not entry['evidence_path'].strip():
                raise ValueError('unbound taint declaration')
            if dt.datetime.fromisoformat(entry['declared_at'].replace('Z','+00:00')).tzinfo is None:
                raise ValueError('declaration requires timezone')
        # CEO activation evidence: a non-empty receipt string, or the structured form the shipped config uses
        # (dict with declared_by + evidence list). 2026-09-07: the dict form was refused as 'unavailable', so every
        # news-gate row fell into the fallback hold (TAINT_POLICY_UNAVAILABLE) instead of the declared taint hold.
        if data['enabled'] and not _activation_evidence_ok(data.get('activation_evidence')):
            raise ValueError('CEO activation evidence required')
        return data
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        return {'enabled': True, 'tainted': [], 'error': f'TAINT_POLICY_UNAVAILABLE:{exc}'}


def _content_sha(manifest):
    data = _strict(manifest)
    value = data['content_sha256']
    if not HEX.fullmatch(value):
        raise ValueError('invalid pinned content SHA256')
    return value


def _scoped_marker_present(item):
    try:
        payload = json.loads(item.get('payload_json') or '{}')
    except (TypeError, ValueError):
        return False
    return isinstance(payload, dict) and scoped_b.MARKER_KEY in payload


def _scoped_marker_allows(item, activation=None):
    if item.get('phase') != 'Q10_NEWS' or not _scoped_marker_present(item):
        return False
    try:
        activation = activation or scoped_b.load_activation()
        return scoped_b.marker_valid(item, activation)
    except (OSError, ValueError, TypeError, KeyError, scoped_b.ActivationError):
        return False


def _e1c_marker_allows(item, pinned):
    """OWNER E1-C Option B per-row release marker (decision OWNER-E1C-OPTIONB-20260916).

    Authenticated row-level counter-path, mirroring the scoped-B marker
    invariants: an append-only payload marker hash-bound to a per-row delta
    record that certifies UNCHANGED_EQUIVALENT. The record file is re-read and
    re-hashed on EVERY decision (sweep and claim), so a tampered, deleted, or
    wrong-status record fails closed and the hold re-arms. It never raises.
    """
    try:
        if item.get('phase') not in PHASES or item.get('status') != 'pending':
            return False
        payload = json.loads(item.get('payload_json') or '{}')
        if not isinstance(payload, dict):
            return False
        marker = payload.get(E1C_MARKER_KEY)
        if not isinstance(marker, dict) or marker.get('schema') != E1C_MARKER_SCHEMA:
            return False
        if marker.get('work_item_id') != item['id']:
            return False
        if marker.get('tainted_sha256') != pinned:
            return False
        record_raw = Path(str(marker.get('record_path') or '')).read_bytes()
        record = json.loads(record_raw.decode('utf-8-sig'))
        if _record_digest(record) != marker.get('record_sha256'):
            return False
        return (
            isinstance(record, dict)
            and record.get('schema') == E1C_RECORD_SCHEMA
            and record.get('work_item_id') == item['id']
            and record.get('record_sha256') == marker.get('record_sha256')
            and record.get('delta_validation_status') == 'UNCHANGED_EQUIVALENT'
            and record.get('option_b_hold_release_eligible') is True
            and (record.get('old_calendar') or {}).get('content_sha256') == pinned
        )
    except (OSError, ValueError, TypeError, AttributeError):
        return False


def decision(item, policy, pin_manifest, *, scoped_activation=None):
    if item['phase'] not in PHASES or item['status'] != 'pending':
        return None
    if policy.get('error'):
        return policy['error']
    if not policy['enabled']:
        return None
    taints = {entry['sha256']: entry['evidence_path'] for entry in policy['tainted']}
    if not taints:
        return None  # Explicit removal is the documented policy rollback.
    try:
        pinned = _content_sha(pin_manifest)
        if pinned in taints:
            # B is an authenticated row-level counter-path, never a global untaint.
            if _scoped_marker_allows(item, scoped_activation) or _e1c_marker_allows(item, pinned):
                return None
            return f'PINNED_CALENDAR_TAINTED:{pinned}; diagnostic={taints[pinned]}'
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        return f'CALENDAR_TAINT_IDENTITY_UNAVAILABLE:{exc}'
    return None


def inspect(conn, policy, pin_manifest, *, item_id=None, scoped_activation=None):
    sql = "SELECT id,phase,status,ea_id,symbol,setfile_path,payload_json FROM work_items WHERE phase IN ('Q09_NEWS','Q10_NEWS') AND status='pending'"
    params = ()
    if item_id is not None:
        sql += ' AND id=?'
        params = (item_id,)
    sql += ' ORDER BY id'
    result = []
    for row in conn.execute(sql, params):
        item = dict(row)
        reason = decision(item, policy, pin_manifest, scoped_activation=scoped_activation)
        hold = conn.execute('SELECT * FROM work_item_holds WHERE work_item_id=?', (item['id'],)).fetchone()
        action = 'NONE'
        if reason:
            if hold and hold['active']:
                action = 'ALREADY_HELD' if hold['hold_code'] == HOLD else 'PRESERVE_OTHER_HOLD'
            else:
                action = 'HOLD'
        elif hold and hold['active'] and hold['hold_code'] == HOLD and not policy.get('error'):
            action = ('AWAIT_SCOPED_OWNER_RELEASE'
                      if _scoped_marker_allows(item, scoped_activation) else 'RELEASE')
        result.append({k:item[k] for k in ('id','phase','ea_id','symbol')} | {
            'reason':reason, 'action':action,
            'other_hold':hold['hold_code'] if hold and hold['hold_code'] != HOLD else None})
    return result


def synchronize(conn, policy, pin_manifest, *, item_id=None, apply=False):
    """Caller owns BEGIN IMMEDIATE. Never commits or changes work_items."""
    if apply and not conn.in_transaction:
        raise ValueError('transaction required for hold synchronization')
    rows = inspect(conn, policy, pin_manifest, item_id=item_id)
    now = dt.datetime.now(dt.timezone.utc).isoformat()
    for row in rows:
        if not apply or row['action'] not in {'HOLD','RELEASE'}:
            continue
        if row['action'] == 'HOLD':
            conn.execute("""INSERT INTO work_item_holds
              (work_item_id,hold_code,reason,active,release_on_restart,created_at,updated_at)
              VALUES(?,?,?,1,0,?,?) ON CONFLICT(work_item_id) DO UPDATE SET
              hold_code=excluded.hold_code,reason=excluded.reason,active=1,release_on_restart=0,
              updated_at=excluded.updated_at,released_at=NULL,release_note=NULL
              WHERE work_item_holds.active=0""", (row['id'],HOLD,row['reason'],now,now))
        else:
            conn.execute("""UPDATE work_item_holds SET active=0,updated_at=?,released_at=?,release_note=?
              WHERE work_item_id=? AND hold_code=? AND active=1""",
                         (now,now,'Untainted pinned bundle or explicit policy rollback',row['id'],HOLD))
        conn.execute('INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)',
                     (now,'work_item',row['id'],'news_calendar_taint_'+row['action'].lower(),json.dumps(row,sort_keys=True)))
    return rows


def release_scoped_item(conn, item_id, pin_manifest, *, config_path=None, adjudicated_at=None):
    """Stamp and release exactly one OWNER-adjudicated B row.

    The caller owns the write transaction.  This path never changes status,
    verdict, evidence, or any hold other than this module's active taint hold.
    """
    if not conn.in_transaction:
        raise ValueError('transaction required for scoped row release')
    policy = load_policy(CONFIG)
    if policy.get('error') or not policy.get('enabled'):
        raise ValueError('valid activated taint policy required')
    try:
        pinned = _content_sha(pin_manifest)
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        raise ValueError(f'calendar pin unavailable: {exc}') from exc
    tainted = {entry['sha256'] for entry in policy['tainted']}
    if pinned not in tainted:
        raise ValueError('scoped release is only valid for the declared tainted pin')
    row = conn.execute(
        'SELECT id,phase,status,ea_id,symbol,setfile_path,payload_json FROM work_items WHERE id=?',
        (item_id,),
    ).fetchone()
    if row is None:
        raise ValueError('work item not found')
    item = dict(row)
    hold = conn.execute(
        'SELECT * FROM work_item_holds WHERE work_item_id=? AND active=1', (item_id,)
    ).fetchone()
    if hold is None or hold['hold_code'] != HOLD:
        raise ValueError('active NEWS_CALENDAR_TAINTED hold required')
    activation = scoped_b.load_activation(
        scoped_b.CONFIG if config_path is None else Path(config_path)
    )
    now = adjudicated_at or dt.datetime.now(dt.timezone.utc).isoformat()
    marker = scoped_b.marker_for(item, activation, adjudicated_at=now)
    try:
        payload = json.loads(item.get('payload_json') or '{}')
    except (TypeError, ValueError) as exc:
        raise ValueError(f'payload JSON invalid: {exc}') from exc
    if not isinstance(payload, dict):
        raise ValueError('payload JSON must be an object')
    if scoped_b.MARKER_KEY in payload:
        raise ValueError('append-only marker already exists')
    payload[scoped_b.MARKER_KEY] = marker
    conn.execute('UPDATE work_items SET payload_json=? WHERE id=?',
                 (json.dumps(payload, sort_keys=True, separators=(',', ':')), item_id))
    note = (f"OWNER row-by-row B release; decision={marker['decision_id']}; "
            f"binding_sha256={marker['binding_sha256']}; "
            f"assessment_sha256={marker['assessment_sha256']}")
    changed = conn.execute(
        '''UPDATE work_item_holds SET active=0,updated_at=?,released_at=?,release_note=?
           WHERE work_item_id=? AND hold_code=? AND active=1''',
        (now, now, note, item_id, HOLD),
    ).rowcount
    if changed != 1:
        raise ValueError('scoped hold release race')
    detail = {'work_item_id': item_id, 'decision_id': marker['decision_id'],
              'binding_sha256': marker['binding_sha256'],
              'assessment_sha256': marker['assessment_sha256'],
              'footnote': marker['footnote']}
    conn.execute('INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)',
                 (now, 'work_item', item_id, 'news_calendar_scoped_b_release',
                  json.dumps(detail, sort_keys=True)))
    return marker


def release_e1c_item(conn, item_id, pin_manifest, *, record_path, record_sha256,
                     released_by, adjudicated_at=None):
    """Stamp and release exactly one OWNER E1-C Option-B UNCHANGED_EQUIVALENT row.

    The caller owns the write transaction. This path never changes status,
    verdict, evidence, or any hold other than this module's active taint hold.
    The append-only marker is hash-bound to the per-row delta record; the
    guard re-verifies record bytes on every sweep/claim, so later tampering
    re-arms the hold (fail closed).
    """
    if not conn.in_transaction:
        raise ValueError('transaction required for E1-C hold release')
    policy = load_policy(CONFIG)
    if policy.get('error') or not policy.get('enabled'):
        raise ValueError('valid activated taint policy required')
    try:
        pinned = _content_sha(pin_manifest)
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        raise ValueError(f'calendar pin unavailable: {exc}') from exc
    tainted = {entry['sha256'] for entry in policy['tainted']}
    if pinned not in tainted:
        raise ValueError('E1-C release is only valid for the declared tainted pin')
    record_file = Path(str(record_path))
    try:
        record_raw = record_file.read_bytes()
    except OSError as exc:
        raise ValueError(f'delta record unavailable: {exc}') from exc
    try:
        record = json.loads(record_raw.decode('utf-8-sig'))
    except (UnicodeError, ValueError) as exc:
        raise ValueError(f'delta record invalid: {exc}') from exc
    if not (
        isinstance(record, dict)
        and record.get('schema') == E1C_RECORD_SCHEMA
        and record.get('work_item_id') == str(item_id)
        and record.get('record_sha256') == record_sha256
        and _record_digest(record) == record_sha256
        and record.get('delta_validation_status') == 'UNCHANGED_EQUIVALENT'
        and record.get('option_b_hold_release_eligible') is True
        and (record.get('old_calendar') or {}).get('content_sha256') == pinned
    ):
        raise ValueError('delta record does not certify this row as UNCHANGED_EQUIVALENT')
    row = conn.execute(
        'SELECT id,phase,status,ea_id,symbol,setfile_path,payload_json FROM work_items WHERE id=?',
        (str(item_id),),
    ).fetchone()
    if row is None:
        raise ValueError('work item not found')
    item = dict(row)
    if item['phase'] not in PHASES or item['status'] != 'pending':
        raise ValueError('E1-C release requires a pending Q09_NEWS/Q10_NEWS row')
    hold = conn.execute(
        'SELECT * FROM work_item_holds WHERE work_item_id=? AND active=1', (str(item_id),)
    ).fetchone()
    if hold is None or hold['hold_code'] != HOLD:
        raise ValueError('active NEWS_CALENDAR_TAINTED hold required')
    try:
        payload = json.loads(item.get('payload_json') or '{}')
    except (TypeError, ValueError) as exc:
        raise ValueError(f'payload JSON invalid: {exc}') from exc
    if not isinstance(payload, dict):
        raise ValueError('payload JSON must be an object')
    if E1C_MARKER_KEY in payload:
        raise ValueError('append-only marker already exists')
    now = adjudicated_at or dt.datetime.now(dt.timezone.utc).isoformat()
    marker = {
        'schema': E1C_MARKER_SCHEMA,
        'decision_id': E1C_DECISION_ID,
        'work_item_id': str(item_id),
        'record_path': str(record_file),
        'record_sha256': record_sha256,
        'tainted_sha256': pinned,
        'released_by': str(released_by),
        'adjudicated_at': now,
    }
    payload[E1C_MARKER_KEY] = marker
    conn.execute('UPDATE work_items SET payload_json=? WHERE id=?',
                 (json.dumps(payload, sort_keys=True, separators=(',', ':')), str(item_id)))
    note = (f"OWNER E1-C Option B row-by-row release; decision={E1C_DECISION_ID}; "
            f"record_sha256={record_sha256}")
    changed = conn.execute(
        '''UPDATE work_item_holds SET active=0,updated_at=?,released_at=?,release_note=?
           WHERE work_item_id=? AND hold_code=? AND active=1''',
        (now, now, note, str(item_id), HOLD),
    ).rowcount
    if changed != 1:
        raise ValueError('E1-C hold release race')
    detail = {'work_item_id': str(item_id), 'decision_id': E1C_DECISION_ID,
              'record_sha256': record_sha256, 'tainted_sha256': pinned,
              'released_by': str(released_by)}
    conn.execute('INSERT INTO events(ts,entity_type,entity_id,event,detail_json) VALUES(?,?,?,?,?)',
                 (now, 'work_item', str(item_id), 'news_calendar_e1c_optionb_release',
                  json.dumps(detail, sort_keys=True)))
    return marker


def guard_claim(conn, item_id, pin_manifest, *, config_path=None):
    """Called in the actual claim write transaction, covering unseen successors."""
    # Fast phase filter before touching policy files for unrelated work.
    item = conn.execute('SELECT phase FROM work_items WHERE id=?', (item_id,)).fetchone()
    if item is None or item['phase'] not in PHASES:
        return None
    policy = load_policy(CONFIG if config_path is None else config_path)
    if not policy['enabled']:
        return None
    rows = synchronize(conn,policy,pin_manifest,item_id=item_id,apply=True)
    return next((row['reason'] for row in rows if row['reason']),None)


def sweep(root, pin_manifest, *, apply=False, config_path=None, preview=False):
    try:
        from tools.strategy_farm import farmctl
    except ModuleNotFoundError:
        import farmctl
    config_path = CONFIG if config_path is None else config_path
    policy = load_policy(config_path)
    if not policy['enabled'] and not preview:
        return {'enabled':False,'applied':False,'rows':[]}
    if preview and not policy.get('error'):
        policy = dict(policy,enabled=True)
    if not apply:
        conn = sqlite3.connect(farmctl.db_path(root).resolve().as_uri()+'?mode=ro',uri=True)
        conn.row_factory = sqlite3.Row
        try:
            conn.execute('BEGIN')
            rows = synchronize(conn,policy,pin_manifest)
        finally:
            conn.close()
        return {'enabled':load_policy(config_path)['enabled'],'applied':False,'preview':preview,'rows':rows}
    if preview or policy.get('error'):
        raise ValueError('apply requires valid activated policy; preview cannot apply')
    # 2026-09-13 (Orchestrator, ticket f5d30fc9 continuation): this sweep runs every 10 min and
    # used to take a full governed state backup (1.27 GB, FACTORY_MUTATION.lock held 1-2 min)
    # BEFORE knowing whether any row needs a HOLD/RELEASE. A read-only preflight decides first;
    # the backup + lock + apply path runs only when at least one row would change.
    preflight_conn = sqlite3.connect(farmctl.db_path(root).resolve().as_uri()+'?mode=ro',uri=True)
    preflight_conn.row_factory = sqlite3.Row
    try:
        preflight_conn.execute('BEGIN')
        preflight_rows = synchronize(preflight_conn,policy,pin_manifest)
    finally:
        preflight_conn.close()
    if not any(row.get('action') in {'HOLD','RELEASE'} for row in preflight_rows):
        return {'enabled':policy['enabled'],'applied':False,'preview':False,'rows':preflight_rows,
                'skipped':'no_row_needs_hold_or_release','backup':None,'backup_sha256':None}
    backup, digest = farmctl._governed_state_backup(root,'news_calendar_taint')
    with farmctl.FactoryMutationLock(farmctl.path_for_factory_flag(farmctl.factory_off_flag_path(root)),owner='news_calendar_taint'):
        with farmctl.connect_short_under_mutation_lock(root) as conn:
            conn.execute('BEGIN IMMEDIATE')
            # Re-read mutable policy inside the transaction as claims do.
            policy = load_policy(config_path)
            if policy.get('error') or not policy['enabled']:
                raise ValueError('policy changed before apply; valid activated policy required')
            rows = synchronize(conn,policy,pin_manifest,apply=True)
            conn.commit()
    return {'enabled':policy['enabled'],'applied':True,'rows':rows,'backup':str(backup),'backup_sha256':digest}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root',type=Path,default=Path('D:/QM/strategy_farm'))
    parser.add_argument('--config',type=Path,default=CONFIG)
    parser.add_argument('--apply',action='store_true')
    args = parser.parse_args()
    try:
        from tools.strategy_farm import farmctl
    except ModuleNotFoundError:
        import farmctl
    print(json.dumps(sweep(args.root,farmctl.Q09_AUTOPILOT_CALENDAR_MANIFEST,
                           apply=args.apply,config_path=args.config,preview=not args.apply),indent=2))


if __name__ == '__main__':
    main()
