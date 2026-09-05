"""Capture read-only, append-only inputs for routed M10; never invoke MT5."""
import datetime as dt
import hashlib
import json
import sqlite3
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent
REPO = Path('C:/QM/repo')


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as stream:
        stream.write(data)


def main():
    assert subprocess.check_output(['git', '-C', str(REPO), 'branch', '--show-current'], text=True).strip() == 'agents/board-advisor'
    captured = dt.datetime.now(dt.timezone.utc).isoformat()
    bindings = []

    def freeze(source, name):
        source = Path(source)
        data = source.read_bytes()
        write(ROOT / 'inputs' / name, data)
        bindings.append({'source': str(source), 'frozen': 'inputs/' + name,
                         'sha256': hashlib.sha256(data).hexdigest(), 'size': len(data)})
        return data

    pointer = json.loads(freeze('D:/QM/reports/state/live_deployment_pointer.json', 'pointer.json'))
    manifest = json.loads(freeze(pointer['manifest_path'], 'manifest.json'))
    freeze('C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/journal/live_deals_normalized.csv', 'deals.csv')
    freeze('D:/QM/reports/state/live_book_pulse.json', 'pulse.json')
    freeze('D:/QM/reports/portfolio/live_burnin/portfolio_live_burnin_report.json', 'previous_burnin.json')
    freeze('D:/QM/reports/portfolio/live_burnin/mc_reference_d2c_42d.json', 'mc_reference.json')
    freeze(REPO / 'framework/registry/portfolio_burnin.json', 'config.json')
    logs = Path('C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM')
    keep = {'EQUITY_SNAPSHOT', 'INIT_OK', 'DEINIT', 'TM_OPEN', 'TM_CLOSE', 'ENTRY_ACCEPTED', 'BASKET_WARMUP', 'KILL_SWITCH_INIT'}
    records, errors = [], []
    for source in sorted(logs.glob('QM5_*.log')):
        data = source.read_bytes()
        binding = {'source': str(source), 'sha256': hashlib.sha256(data).hexdigest(),
                   'size': len(data), 'selected_events_only': True}
        bindings.append(binding)
        for line, raw in enumerate(data.decode('utf-8-sig').splitlines(), 1):
            try:
                event = json.loads(raw)
            except ValueError:
                errors.append({'source': str(source), 'line': line})
                continue
            if event.get('event') in keep or str(event.get('event', '')).startswith('KS_'):
                records.append({'source_path': str(source), 'source_line': line, 'record': event})
    write(ROOT / 'inputs/events.jsonl', ''.join(json.dumps(r, sort_keys=True) + '\n' for r in records).encode())
    sources = []
    for ea in [1567, 12778, 12969, 13117, 10440]:
        for source in (REPO / 'framework/EAs').glob(f'QM5_{ea}_*/*.mq5'):
            data = freeze(source, f'source_{ea}.mq5')
            live = next(s for s in manifest['sleeves'] if s['ea_id'] == ea)
            binary = Path(live['ex5_path'])
            canonical = source.with_suffix('.ex5')
            sources.append({'ea_id': ea, 'source': str(source),
                            'source_sha256': hashlib.sha256(data).hexdigest(),
                            'canonical_binary_sha256': hashlib.sha256(canonical.read_bytes()).hexdigest() if canonical.exists() else None,
                            'deployed_binary_sha256': hashlib.sha256(binary.read_bytes()).hexdigest() if binary.exists() else None,
                            'deployed_binary': str(binary),
                            'source_to_binary_build_attestation': 'NOT_ESTABLISHED'})
    freeze(REPO / 'framework/include/QM/QM_EquityStream.mqh', 'QM_EquityStream.mqh')
    db = Path('D:/QM/strategy_farm/state/farm_state.sqlite')
    with sqlite3.connect(db.as_uri() + '?mode=ro', uri=True, timeout=10) as conn:
        conn.row_factory = sqlite3.Row
        qrows = [dict(r) for r in conn.execute("SELECT id,ea_id,symbol,phase,status,verdict,updated_at,evidence_path FROM work_items WHERE ea_id='QM5_10440' AND symbol='NDX.DWX' ORDER BY updated_at DESC")]
    write(ROOT / 'inputs/source_checks.json', json.dumps({'sources': sources, 'q10440': qrows}, indent=2).encode())
    write(ROOT / 'capture.json', json.dumps({'captured_at_utc': captured, 'bindings': bindings,
          'selected_event_rows': len(records), 'parse_errors': errors, 'mode': 'read_only_capture'}, indent=2).encode())
    print(json.dumps({'captured_at_utc': captured, 'event_rows': len(records), 'parse_errors': len(errors)}))


if __name__ == '__main__':
    main()
