"""Read-only census for router task 27c0ea5a. No apply mode exists."""
import argparse
import collections
import datetime as dt
import hashlib
import json
from pathlib import Path
import sqlite3
import sys

REPO = Path('C:/QM/repo')
FARM = Path('D:/QM/strategy_farm')
OUT = Path(__file__).resolve().parent
sys.path[:0] = [str(REPO), str(REPO / 'tools/strategy_farm')]
from tools.strategy_farm import compile_work_items as cw


def ro(_root=None):
    c = sqlite3.connect((FARM / 'state/farm_state.sqlite').as_uri() + '?mode=ro', uri=True)
    c.row_factory = sqlite3.Row
    c.execute('PRAGMA query_only=ON')
    return c


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--dry-run', action='store_true', required=True)
    ap.parse_args()
    cw._connect = ro  # Enforce read-only even inside the existing inventory helper.
    inventory = cw._inventory(FARM, REPO)
    with ro() as c:
        c.execute('BEGIN')
        all_rows = [dict(r) for r in c.execute("SELECT * FROM work_items WHERE phase='COMPILE_EA' AND (status='pending' OR (status='failed' AND updated_at>='2026-09-05')) ORDER BY created_at,id")]
        holds = {r['work_item_id'] for r in c.execute("SELECT work_item_id FROM work_item_holds WHERE active=1 AND hold_code='COMPILE_EA_WORKER_ROLLOUT_PENDING'")}
        tasks = {r['id']: dict(r) for r in c.execute("SELECT * FROM tasks WHERE kind='build_ea'")}
        agents = [dict(r) for r in c.execute("SELECT id,state,verdict,payload_json FROM agent_tasks WHERE task_type IN ('build_ea','ea_build','ops_issue')")]
    selected = []
    for w in all_rows:
        p = json.loads(w['payload_json'])
        if w['id'] not in holds and w['id'] not in {
            '059d4860-337e-4833-91f3-5fdf81b55603', 'c71f00bd-1f15-4db5-b4e8-20d73936a092',
            'c495527e-9058-41e9-a63f-d791c25d7554', '8fd59f9d-96d1-4a13-b820-f2960886822d'}:
            continue
        label = p.get('ea_label', '')
        source = REPO / 'framework/EAs' / label / (label + '.mq5')
        actual = sha(source)
        stale = actual != p.get('mq5_sha256')
        tid = p.get('bound_build_task_id')
        t = tasks.get(tid)
        tp = json.loads(t['payload_json']) if t else {}
        reason = tp.get('blocked_reason') or tp.get('duplicate_dedup_reason') or tp.get('codex_result', {}).get('blocked_reason')
        peers = [x for x in tasks.values() if x['card_id'] == w['ea_id']]
        opened = [x for x in peers if x['status'] in ('pending', 'active')]
        related = [{'id': a['id'], 'state': a['state'], 'verdict': a['verdict']} for a in agents if tid and tid in a['payload_json']]
        binding = cw._build_task_binding(REPO, label, w['ea_id'].split('_')[1], tid, inventory)
        if stale:
            action = 'SOURCE_AUTHORITY_TICKET_FD5E3CE3'
        elif w['status'] == 'failed':
            action = 'USE_SOLE_OPEN_ALTERNATIVE_OR_MINT_THEN_RECHECK_SUCCESSOR'
        elif t and t['status'] in ('pending', 'active'):
            action = 'KEEP_OPEN_BINDING_RECHECK_BEFORE_WAVE'
        elif tid and opened:
            action = 'KEEP_OLD_CLOSED_EXISTING_OPEN_ALTERNATIVE_REQUIRES_PENDING_LINEAGE_REVIEW'
        elif t and t['status'] == 'blocked' and reason and 'ROLLOUT_PENDING' in reason:
            action = 'PROPOSE_REOPEN_SAME_TASK_AFTER_FRESH_PRECHECK'
        elif tid:
            action = 'HOLD_CLOSED_BINDING_RENEWAL_NOT_SUPPORTED_FOR_PENDING_ROW'
        else:
            action = 'UNBOUND_RECHECK_EXISTING_GOVERNED_AUTHORITY'
        row = {'ea_id': w['ea_id'], 'work_item_id': w['id'], 'ea_label': label,
               'status': w['status'], 'created_at': w['created_at'], 'updated_at': w['updated_at'],
               'verdict': w['verdict'], 'active_rollout_hold': w['id'] in holds,
               'build_task_id': tid, 'build_task_status': t['status'] if t else None,
               'build_task_block_reason': reason, 'build_task_payload': tp,
               'related_agent_tasks': related,
               'other_build_tasks': [{'id': x['id'], 'status': x['status'], 'payload': json.loads(x['payload_json'])} for x in peers if x['id'] != tid],
               'sole_open_task_id': opened[0]['id'] if len(opened) == 1 else None,
               'open_task_count': len(opened), 'binding': binding,
               'expected_mq5_sha256': p.get('mq5_sha256'), 'actual_mq5_sha256': actual,
               'source_path': str(source), 'source_state': 'STALE_OR_MISSING' if stale else 'MATCH',
               'action': action, 'build_task_mutation_executed': False,
               'task_action_cli': None,
               'task_action_cli_reason': 'farmctl build-ea writes immediately and has no dry-run; no governed blocked-to-pending CLI was found. This report is the proposal, not a fabricated executable command.'}
        if w['status'] == 'failed':
            # A proposed UUID is intentionally not minted. Existing sole open alternatives
            # can be verified; otherwise the current blocked ID proves the refusal.
            probe_id = row['sole_open_task_id'] or tid
            row['dry_run_command'] = f'python C:/QM/repo/tools/strategy_farm/retry_compile_stale_build_binding.py --predecessor {w["id"]} --build-task-id {probe_id}'
            row['dry_run'] = cw.enqueue_recheck_successor(FARM, REPO, w['id'], probe_id, apply=False)
        else:
            row['dry_run_command'] = f'python C:/QM/repo/tools/strategy_farm/release_compile_wave.py --max-items 1 --work-item-id {w["id"]}'
            # Source-freshness-only wave checks do not establish compile authority.
            sanctioned = cw._sanctioned_compile_predecessor_ids(p, inventory, w['ea_id'].split('_')[1], current_work_item_id=w['id'])
            row['candidate_recheck'] = cw.classify_candidate(
                FARM, REPO, label, inventory, current_work_item_id=w['id'],
                sanctioned_predecessor_ids=sanctioned,
                force_rebuild_ea_ids=cw.force_rebuild_allowlist(FARM, REPO),
                source_repair_authority=p.get('compile_source_repair_authority')
                if p.get('append_only_source_repair') is True and p.get('compile_source_repair_contract_version') == cw.SOURCE_REPAIR_CONTRACT_VERSION else None,
                bound_build_task_id=tid if p.get('compile_build_task_binding_contract_version') == cw.BUILD_TASK_BINDING_CONTRACT_VERSION else None)
        selected.append(row)
    payload = {'schema': 'qm.compile-backlog-binding-review/v1', 'as_of': dt.datetime.now(dt.timezone.utc).isoformat(),
               'mode': 'read_only_dry_run', 'database_open_mode': 'ro + query_only',
               'scope': 'all active held pending utility compile rows plus the four named failed backlog waves',
               'initial_brief_rows': 25, 'rows': selected,
               'count': len(selected), 'active_held_pending': sum(r['active_rollout_hold'] for r in selected),
               'actions': dict(collections.Counter(r['action'] for r in selected)),
               'all_pending_failed_today_count': len(all_rows), 'all_pending_failed_today': all_rows,
               'canonical_files': {str(p.relative_to(REPO)): sha(p) for p in [REPO/'tools/strategy_farm/compile_work_items.py', REPO/'tools/strategy_farm/retry_compile_stale_build_binding.py', REPO/'tools/strategy_farm/farmctl.py']}}
    (OUT/'census.json').write_text(json.dumps(payload, indent=2, sort_keys=True)+'\n', encoding='utf-8')
    print(json.dumps({k:payload[k] for k in ('as_of','count','active_held_pending','actions','all_pending_failed_today_count')}, indent=2))


if __name__ == '__main__':
    main()
