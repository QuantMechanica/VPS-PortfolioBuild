"""Snapshot the bounded Sep-08 latency repair evidence without changing gates."""
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shutil
import sqlite3

import psutil

from tools.strategy_farm.backtest_tail_watch import snapshot, tail
from tools.strategy_farm.mt5_latency_lab import ROOT, sha
from tools.strategy_farm.analyze_latency_recovery import report_tables


if __name__ == '__main__':
    base = Path('D:/QM/reports/maintenance/backtest_latency_20260908')
    destination = base / ('acceptance_' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
    destination.mkdir(exist_ok=False)
    rows = []
    with sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True) as con:
        con.row_factory = sqlite3.Row
        for receipt_path in sorted(base.glob('recovery_T*.json')):
            receipt = json.loads(receipt_path.read_text(encoding='utf-8-sig'))
            item = dict(con.execute('SELECT id,ea_id,phase,status,verdict,evidence_path FROM work_items WHERE id=?',
                                    (receipt['work_item_id'],)).fetchone())
            item.update({'terminal': receipt['terminal'], 'recovery_receipt': str(receipt_path),
                         'recovery_receipt_sha256': sha(receipt_path), 'original_engine_wait_seconds': receipt['engine_wait_seconds']})
            # Preserve a stable byte snapshot of the original native journal too.
            journal = Path(receipt['first']['journal_path'])
            if journal.is_file() and journal.stat().st_size < 64 * 1024 * 1024:
                journal_copy = destination / (receipt['terminal'] + '_native_journal_snapshot.log')
                before = sha(journal)
                shutil.copyfile(journal, journal_copy)
                item['journal_snapshot'] = {'path': str(journal_copy), 'sha256': sha(journal_copy),
                                             'copy_stable': before == sha(journal_copy) == sha(journal)}
            path = Path(item['evidence_path'] or '__absent__')
            if path.is_file() and path.name == 'summary.json':
                summary_copy = destination / (receipt['terminal'] + '_summary.json')
                shutil.copyfile(path, summary_copy)
                summary = json.loads(summary_copy.read_text(encoding='utf-8-sig'))
                item['summary_snapshot'] = {'path': str(summary_copy), 'sha256': sha(summary_copy)}
                good = [run for run in summary['runs'] if run['status'] == 'OK']
                item['valid_reports'] = []
                for run in good:
                    report = Path(run['report_canonical_path'])
                    copied = destination / (receipt['terminal'] + '_' + run['run'] + '_report.htm')
                    shutil.copyfile(report, copied)
                    native = Path(run['tester_log_path'])
                    finishes = [line for line in tail(native, 2 * 1024 * 1024).splitlines()
                                if item['ea_id'] in line and 'thread finished' in line]
                    finish = finishes[-1].split('\t')[2] if finishes else None
                    finish_epoch = datetime.strptime(native.stem + ' ' + finish, '%Y%m%d %H:%M:%S.%f').timestamp() if finish else None
                    source = Path(run['report_source_path'])
                    item['valid_reports'].append({'run': run['run'], 'path': str(copied), 'sha256': sha(copied),
                        'expected_sha256_matches': sha(copied) == run['report_sha256'],
                        'model': summary['model'], 'real_ticks_marker': run['real_ticks_marker'],
                        'total_trades': run['total_trades'], 'net_profit': run['net_profit'],
                        'engine_to_report_seconds': round(source.stat().st_mtime - finish_epoch, 3) if finish_epoch else None})
            rows.append(item)
        rerun = dict(con.execute("SELECT id,status,verdict FROM work_items WHERE id='cc3a5cd7-49e2-4105-8c2c-80a6d62132ab'").fetchone())
    lab = [report_tables(ROOT / name) for name in ('baseline1.htm', 'baseline2.htm', 'experiments/subdir1/subdir1.htm', 'experiments/subdir2/subdir2.htm')]
    observation = snapshot()
    result = {'schema': 'qm.latency-repair-acceptance/v1', 'at_utc': datetime.now(timezone.utc).isoformat(),
              'recoveries': rows, 't7_append_only_rerun': rerun,
              'all_four_lab_report_tables_equal': len({r['table_cells_sha256'] for r in lab}) == 1,
              'lab_reports': lab, 'trade_parity_proof': str(base / 'parity_20260908.json'),
              'current_observation': observation,
              'memory_available_gib': round(psutil.virtual_memory().available / 2**30, 2),
              'disk_d_free_gib': round(shutil.disk_usage('D:/').free / 2**30, 2),
              'limits': ['Underlying native MT5 hang not root-caused.', 'No report-directory speedup established.',
                         'Automatic 600-second failure/retry path covered by fixtures; real future stall acceptance still pending.',
                         'No trading strategy gate, live approval or historical verdict was fabricated.']}
    output = destination / 'acceptance.json'
    output.write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({'evidence': str(output), 'sha256': sha(output),
                      'completed_recoveries': sum(r['status'] == 'done' for r in rows),
                      'current_confirmed_report_stalls': [r['terminal'] for r in observation['terminals'] if r.get('finished_without_report_seconds', 0) >= 60]}))
