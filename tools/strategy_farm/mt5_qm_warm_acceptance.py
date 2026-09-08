"""Read-only real-QM lab comparison; emits diagnostics, never gate admission.

All native HTML cell values and all structured logger fields are compared.
Only logger ts_utc wall-clock milliseconds (GetTickCount()%1000) are normalized;
the original files remain untouched. Every accepted run needs a fresh successful
native engine journal, and full price-file hashes are rechecked after MT5 exits.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import json
from pathlib import Path
import re
import statistics

import psutil

from tools.strategy_farm import mt5_qm_warm_fixture as qm
from tools.strategy_farm.mt5_report_rescue import tester_config, validate_report
from tools.strategy_farm.mt5_warm_report_parity import digest, html_rows, journal_run, ledger, metadata

COHORTS = {
    'original_with_native_tick_gap': ('qm10012_colda2', 'qm10012_coldb', ('warm1', 'warm2', 'warm3'), ('a', 'b', 'a')),
    'clean_diagnostic_window': ('qm10012_coldc', 'qm10012_coldd', ('clean1', 'clean2', 'clean3'), ('c', 'd', 'c')),
}


def logger_rows(path: Path) -> list[dict]:
    rows = [json.loads(line) for line in path.read_text(encoding='utf-8-sig').splitlines() if line.strip()]
    if not rows:
        raise ValueError('Empty logger evidence')
    for row in rows:
        if row.get('ea_id') != 10012 or row.get('symbol') != 'EURUSD.DWX' or row.get('tf') != 'M30':
            raise ValueError('Foreign logger evidence')
        stamp = row.get('ts_utc', '')
        if not re.fullmatch(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z', stamp):
            raise ValueError('Unexpected logger timestamp format')
        row['ts_utc'] = re.sub(r'\.\d{3}Z$', 'Z', stamp)
    return rows


def logger_path(root: Path) -> Path:
    files = list(root.glob('logger_delta_*.jsonl')) or list(root.glob('logger_*.bin'))
    if len(files) != 1:
        raise ValueError('Exactly one preserved logger stream required')
    return files[0]


def window_lines(text: str, day: str, start: float, end: float) -> str:
    """Legacy cold sessions predate offset capture; select by native local time."""
    selected = []
    for line in text.splitlines():
        fields = line.split('\t')
        if len(fields) < 5:
            continue
        try:
            epoch = datetime.strptime(day + ' ' + fields[2], '%Y%m%d %H:%M:%S.%f').timestamp()
        except ValueError:
            continue
        if start <= epoch <= end:
            selected.append(line)
    return '\n'.join(selected)


def native_evidence(root: Path, archive: Path) -> dict:
    candidates = [p for p in root.glob('Agent-*_journal_delta.bin') if p.stat().st_size]
    legacy = not candidates
    if legacy:
        record = json.loads((root / 'session.json').read_text())
        end = (root / 'cold_result.json').stat().st_mtime
        for source in qm.ROOT.glob('Tester/Agent-*/logs/*.log'):
            text = window_lines(source.read_text(encoding='utf-16'), source.stem, record['started_epoch'], end)
            if 'started with inputs:' not in text or qm.EA not in text:
                continue
            target = archive / (root.name + '_' + source.parent.parent.name + '_cold_window.txt')
            with target.open('x', encoding='utf-8') as stream:
                stream.write(text)
            candidates.append(target)
    if len(candidates) != 1:
        raise ValueError('Exactly one preserved native execution journal required')
    source = candidates[0]
    text = source.read_text(encoding='utf-8' if legacy else 'utf-16-le').lstrip('\ufeff')
    result = {**journal_run(text), 'source': str(source), 'sha256': qm.sha(source),
            'tick_gap_warnings': [line for line in text.splitlines()
                if 'real ticks absent' in line or 'every tick generation used' in line],
            'legacy_timestamp_window_recovery': legacy}
    if (root / 'session.json').exists():
        record = json.loads((root / 'session.json').read_text())
        cold_result = json.loads((root / 'cold_result.json').read_text())
        result['cold_timeline'] = cold_timeline(text, record['started_epoch'],
            cold_result['first_byte_seconds'], result['engine_seconds'])
    return result


def cold_timeline(text: str, started: float, first_byte: float, engine_seconds: float) -> dict:
    lines = [line for line in text.splitlines() if line.endswith('thread finished')]
    if len(lines) != 1:
        raise ValueError('Ambiguous native engine finish timestamp')
    time_part = datetime.strptime(lines[0].split('\t')[2], '%H:%M:%S.%f').time()
    stamp = datetime.combine(datetime.fromtimestamp(started).date(), time_part)
    if stamp.timestamp() < started:
        stamp += timedelta(days=1)
    finished = stamp.timestamp() - started
    if finished > first_byte + 2 or finished < engine_seconds:
        raise ValueError('Native timestamp inconsistent with cold observation')
    return {'before_engine_seconds': finished - engine_seconds,
            'engine_seconds': engine_seconds, 'engine_finish_to_first_report_byte_seconds': first_byte - finished}


def assert_same_execution(left: dict, right: dict) -> bool:
    return all(left[key] == right[key] for key in ('ticks', 'bars', 'native_trade_messages', 'trade_stream_sha256'))


def collect(output: Path) -> dict:
    if output.exists():
        raise FileExistsError('Never overwrite acceptance evidence')
    if any(Path(p.info['exe'] or '').parent == qm.ROOT
           for p in psutil.process_iter(['exe'])):
        raise RuntimeError('Full post-close validation requires all lab processes exited')
    manifest = qm.verify_fixture()
    verified = []
    for entry in manifest['data_files']:
        source = qm.SOURCE / entry['relative']
        if qm.sha(source) != entry['sha256']:
            raise ValueError('Original reserved T11 price file changed')
        verified.append({**entry, 'source': str(source), 'source_and_private_copy_sha256_equal': True})
    archive = qm.FIXTURE / ('acceptance_' + output.stem)
    archive.mkdir(exist_ok=False)
    cohorts = []
    for name, (first, second, runs, arms) in COHORTS.items():
        cold = {}
        for session_name, arm in ((first, arms[0]), (second, arms[1])):
            root = qm.ROOT / 'experiments' / session_name
            if not json.loads((root / 'closed.json').read_text())['mcp_config_restored']:
                raise ValueError('Cold session cleanup not proven')
            report = qm.ROOT / (session_name + '_cold.htm')
            result = json.loads((root / 'cold_result.json').read_text())
            if qm.sha(report) != result['report_sha256']:
                raise ValueError('Cold HTML changed after initial capture')
            validation = validate_report(report, tester_config(root / 'cold.ini'),
                                          qm.PROFILES / f'QM_lab_qm10012_{arm}.set')
            rows = html_rows(report)
            log = logger_path(root)
            native = native_evidence(root, archive)
            if int(metadata(rows)['Ticks:']) != native['ticks'] or int(metadata(rows)['Bars:']) != native['bars']:
                raise ValueError('Cold report and native journal differ')
            cold[arm] = {'session': session_name, 'report': str(report), 'validation': validation,
                'all_html_rows': len(rows), 'all_html_cells_sha256': digest(rows), 'metadata': metadata(rows),
                'logger': str(log), 'logger_raw_sha256': qm.sha(log), 'logger_events': len(logger_rows(log)),
                'logger_normalized_sha256': digest(logger_rows(log)), 'native': native,
                'complete_observed_seconds': result['complete_observed_seconds']}
        if cold[arms[0]]['all_html_cells_sha256'] == cold[arms[1]]['all_html_cells_sha256']:
            raise ValueError('Input-switch negative control did not change results')
        results = []
        for run_name, arm in zip(runs, arms):
            root = qm.ROOT / 'experiments' / second / run_name
            summary = json.loads((root / 'summary.json').read_text())
            if summary['arm'] != arm:
                raise ValueError('Unexpected switch sequence')
            reference = cold[arm]
            rows = html_rows(root / 'native.html'); expected = html_rows(Path(reference['report']))
            log = logger_path(root); native = native_evidence(root, archive)
            if qm.sha(root / 'native.html') != summary['validation']['sha256']:
                raise ValueError('Warm report changed after capture')
            if summary['logger']['files'][0]['delta_sha256'] != qm.sha(log):
                raise ValueError('Warm logger changed after capture')
            result = {'name': run_name, 'arm': arm, 'run_id': summary['run_id'],
                'resident_terminal_pid': summary['resident_terminal_pid'],
                'quiesced_agent_pids': summary['quiesced_agent_pids'],
                'all_html_cells_equal': rows == expected,
                'all_order_fields_equal': ledger(rows, 'Orders', False) == ledger(expected, 'Orders', False),
                'all_deal_fields_equal': ledger(rows, 'Deals', False) == ledger(expected, 'Deals', False),
                'all_logger_fields_equal_except_wall_clock_millis': logger_rows(log) == logger_rows(Path(reference['logger'])),
                'native_execution_equal': assert_same_execution(native, reference['native']),
                'native': native, 'logger_raw_sha256': qm.sha(log), 'report_sha256': qm.sha(root / 'native.html'),
                'complete_evidence_seconds': summary['complete_evidence_seconds'],
                'native_export_seconds': summary['report']['elapsed_seconds'],
                'paired_seconds_saved': reference['complete_observed_seconds'] - summary['complete_evidence_seconds']}
            if not all(result[key] for key in ('all_html_cells_equal', 'all_order_fields_equal', 'all_deal_fields_equal',
                'all_logger_fields_equal_except_wall_clock_millis', 'native_execution_equal')):
                raise ValueError('Cold/warm parity failed: ' + name + '/' + run_name)
            results.append(result)
        if len({r['resident_terminal_pid'] for r in results}) != 1 or len({r['run_id'] for r in results}) != 3:
            raise ValueError('Must reuse one terminal with three distinct run IDs')
        gaps = any(r['native']['tick_gap_warnings'] for r in [*cold.values(), *results])
        if name == 'clean_diagnostic_window' and gaps:
            raise ValueError('Clean cohort has native real-tick gap warnings')
        cohorts.append({'name': name, 'cold': cold, 'warm': results, 'has_native_tick_gap_warnings': gaps,
            'all_comparisons_pass': True,
            'median_paired_seconds_saved': statistics.median(r['paired_seconds_saved'] for r in results)})
    result = {'schema': 'qm.real-ea-warm-acceptance/v1', 'collected_at_utc': datetime.now(timezone.utc).isoformat(),
        'ea': qm.EA, 'ex5_sha256': qm.EX5_HASH, 'model': 4, 'cohorts': cohorts,
        'post_close_data_verification': verified, 'all_comparisons_pass': True,
        'factory_warm_enabled': False, 'gate_admission': False,
        'limitations': ['One older QM EA binary, one symbol/timeframe; not current framework or cross-EA coverage.',
            'Two unique setfiles, two date windows; no 20-cell qualification or failure/recovery coverage.',
            'Factory load varies; engine duration also varies. Cold observation excludes later logger capture; warm timing includes export and writer quiescence.',
            'Main terminal stays resident; tester agents are stopped after complete validated reports for fresh logger isolation.',
            'Shared FILE_COMMON/news sidecars are not a production isolation contract; fixture refuses existing active/pending same-EA factory jobs.',
            'Original cohort uses one native generated-tick fallback minute despite HTML 100% real ticks. Clean window is diagnostic only, not a data repair or strategy result.']}
    with output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = collect(args.output)
    print(json.dumps({'all_comparisons_pass': result['all_comparisons_pass'],
                      'cohorts': [c['name'] for c in result['cohorts']], 'output': str(args.output)}))


if __name__ == '__main__':
    main()
