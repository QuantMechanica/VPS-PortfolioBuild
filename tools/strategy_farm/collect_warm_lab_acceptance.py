"""Collect a new, non-gate acceptance record after the isolated lab is closed."""
from datetime import datetime, timezone
import json
from pathlib import Path
import shutil
import statistics

import psutil

from tools.strategy_farm.mt5_latency_lab import ROOT, SOURCE, is_lab_updater, sha
from tools.strategy_farm.mt5_warm_lab import SESSION
from tools.strategy_farm.mt5_warm_report_parity import html_rows
from tools.strategy_farm.backtest_tail_watch import snapshot


def main():
    for process in psutil.process_iter(['exe', 'cmdline']):
        if (process.info['exe'] or '').lower().startswith(str(SOURCE).lower() + '\\') or is_lab_updater(process.info):
            raise RuntimeError('T11 must be idle before final evidence capture')
    parity = json.loads((SESSION / 'parity_final.json').read_text())
    if len(parity['runs']) != 8 or not parity['all_ledger_fields_and_fixture_metadata_equal']:
        raise RuntimeError('Order/deal/metadata equivalence did not pass')
    baseline = html_rows(ROOT / 'warmcold.htm')
    cold = [{'name': 'warmcold', **json.loads((SESSION / 'cold_result.json').read_text())}]
    for name in ('coldreturn', 'coldconfirm'):
        if html_rows(ROOT / f'{name}.htm') != baseline:
            raise RuntimeError('Fresh cold control has different native report cells')
        result = json.loads((ROOT / 'experiments' / name / 'result.json').read_text())
        cold.append({'name': name, 'first_byte_seconds': result['report_first_byte_seconds'],
                     'natural_exit_seconds': result['elapsed_seconds'], 'report_sha256': result['report_sha256']})
    output = SESSION / 'acceptance'
    output.mkdir(exist_ok=False)
    files = []
    for name in ('warmcold.htm', 'coldreturn.htm', 'coldconfirm.htm', 'switchbcold.htm'):
        target = output / name
        shutil.copy2(ROOT / name, target)
        files.append({'path': str(target), 'sha256': sha(target)})
    for source in ROOT.glob('Tester/Agent-*/logs/20260908.log'):
        target = output / (source.parent.parent.name + '_20260908.log')
        shutil.copy2(source, target)
        files.append({'path': str(target), 'sha256': sha(target)})
    observation = snapshot()
    (output / 'factory_observation.json').write_text(json.dumps(observation, indent=2), encoding='utf-8')
    visible_a = [r['evidence_collected_seconds'] for r in parity['runs']
                 if not r.get('hidden_requested') and r.get('fixture_from_date', '2026.09.01') == '2026.09.01']
    result = {'schema': 'qm.mt5-persistent-lab-acceptance/v1', 'at_utc': datetime.now(timezone.utc).isoformat(),
              'status': 'EXPERIMENT_ACCEPTED_NOT_FACTORY_QUALIFIED', 'cold_a': cold,
              'cold_a_first_byte_median_seconds': statistics.median(r['first_byte_seconds'] for r in cold),
              'warm_a_visible_complete_evidence_median_seconds': statistics.median(visible_a),
              'scope_limit': 'Different observation resolution, small sequential sample, shared factory load; not a universal speed multiplier',
              'parity_path': str(SESSION / 'parity_final.json'), 'parity_sha256': sha(SESSION / 'parity_final.json'),
              'full_html_cells_equal_across_all_three_cold_a_controls': True,
              'all_eight_warm_runs_native_order_deal_metadata_equal_to_their_cold_reference': True,
              't11_processes_remaining': [], 'files': files,
              'live_terminals': [{'pid': p.pid, 'exe': p.info['exe']} for p in psutil.process_iter(['exe'])
                                 if p.pid in {15464, 31728}],
              'factory_report_tail_alerts': [{'terminal': r['terminal'], 'seconds': r['finished_without_report_seconds']}
                                            for r in observation['terminals'] if r.get('finished_without_report_seconds', 0) >= 60]}
    (output / 'acceptance.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
