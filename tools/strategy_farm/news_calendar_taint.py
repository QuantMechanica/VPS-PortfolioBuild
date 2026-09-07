"""Governed news claimability overlay. No work-item/verdict mutations.

The shipped policy is INACTIVE. Dry-run evaluates its prospective impact.
Only this module's own physical holds may be released. Other holds survive.
"""
from __future__ import annotations
import argparse
import datetime as dt
import json
from pathlib import Path
import re
import sqlite3
import sys

if __name__ == '__main__':
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

CONFIG = Path(__file__).resolve().parent / 'config/news_calendar_taint.v1.json'
HOLD = 'NEWS_CALENDAR_TAINTED'
PHASES = {'Q09_NEWS', 'Q10_NEWS'}
HEX = re.compile(r'^[0-9a-f]{64}$')


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


def decision(item, policy, pin_manifest):
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
            return f'PINNED_CALENDAR_TAINTED:{pinned}; diagnostic={taints[pinned]}'
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as exc:
        return f'CALENDAR_TAINT_IDENTITY_UNAVAILABLE:{exc}'
    return None


def inspect(conn, policy, pin_manifest, *, item_id=None):
    sql = "SELECT id,phase,status,ea_id,symbol,payload_json FROM work_items WHERE phase IN ('Q09_NEWS','Q10_NEWS') AND status='pending'"
    params = ()
    if item_id is not None:
        sql += ' AND id=?'
        params = (item_id,)
    sql += ' ORDER BY id'
    result = []
    for row in conn.execute(sql, params):
        item = dict(row)
        reason = decision(item, policy, pin_manifest)
        hold = conn.execute('SELECT * FROM work_item_holds WHERE work_item_id=?', (item['id'],)).fetchone()
        action = 'NONE'
        if reason:
            if hold and hold['active']:
                action = 'ALREADY_HELD' if hold['hold_code'] == HOLD else 'PRESERVE_OTHER_HOLD'
            else:
                action = 'HOLD'
        elif hold and hold['active'] and hold['hold_code'] == HOLD and not policy.get('error'):
            action = 'RELEASE'
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
