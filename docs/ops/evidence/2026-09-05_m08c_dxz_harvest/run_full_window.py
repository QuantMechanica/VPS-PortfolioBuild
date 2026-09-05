"""One bounded measurement through canonical bootstrap reservation/launch helpers."""
from pathlib import Path
import datetime as dt
import gzip
import hashlib
import json
import sys
import time
sys.path[:0] = ['C:/QM/repo', 'C:/QM/repo/tools/strategy_farm']
from tools.strategy_farm import ftmo_m1_bootstrap as m

OUT = Path(__file__).resolve().parent
SOURCE = OUT / 'QM_M1_SpreadHarvest.mq5'
assert SOURCE.is_file()
run = OUT / ('run_' + dt.datetime.now(dt.UTC).strftime('%H%M%S'))
run.mkdir(exist_ok=False)
tag = 'M08C_' + dt.datetime.now(dt.UTC).strftime('%Y%m%dT%H%M%SZ')
owner = 'ftmo_m1_bootstrap:' + tag
SYMBOLS = ('GBPUSD','EURUSD','USDCAD','NZDUSD','XTIUSD','XAGUSD')
terminal = None
reservation = None
start = time.monotonic()
receipt = {'schema': 'qm.m08c-measurement/v1', 'tag': tag, 'started_utc': m.utc_now(),
           'timeout_seconds': 1800, 'maximum_factory_budget_seconds': 31800,
           'symbols': list(SYMBOLS), 'source': m.file_binding(SOURCE),
           'helper': m.file_binding(Path(m.__file__)), 'artifacts': []}


def freeze(path):
    raw = path.read_bytes()
    destination = run / (path.name + '.gz')
    stored = gzip.compress(raw, compresslevel=6, mtime=0)
    destination.write_bytes(stored)
    assert gzip.decompress(destination.read_bytes()) == raw
    return {'original_path': str(path), 'frozen_path': str(destination),
            'raw_sha256': hashlib.sha256(raw).hexdigest(),
            'stored_sha256': hashlib.sha256(stored).hexdigest(), 'raw_bytes': len(raw)}


try:
    with m.exclusive_bootstrap_lock():
        rows = m.scan_terminal_processes()
        snapshot = m.classified_terminal_snapshot(rows)
        if len(snapshot['challenge']) != 1:
            raise m.BootstrapError('Challenge process identity is unclear')
        claims = m.read_active_factory_claims()
        reservations = m.read_terminal_reservations()
        terminal = 'T2'
        if snapshot['factory'][terminal] or terminal in claims or terminal in reservations:
            raise m.BootstrapError('The one M08-C terminal T2 is no longer idle; no other slot will be used')
        receipt['preflight'] = {'terminal': terminal, 'active_claims': sorted(claims),
                                'reserved_terminals': sorted(reservations),
                                'factory_process_counts': {k: len(v) for k,v in snapshot['factory'].items()}}
        reservation = m.reserve_factory_terminal(terminal, owner, minutes=40)
        receipt['reservation'] = reservation
        try:
            root = m.MT5_ROOT / terminal
            if m._exact_process_for_path(m.scan_terminal_processes(), root/'terminal64.exe'):
                raise m.BootstrapError('Terminal became active after reservation')
            if terminal in m.read_active_factory_claims():
                raise m.BootstrapError('Work-item claim appeared after reservation')
            if m.read_terminal_reservations().get(terminal, {}).get('reserved_by') != owner:
                raise m.BootstrapError('Reservation is not durably owned')
            receipt['compile'] = m.compile_harvest_script(root, run, source_path=SOURCE)
            # Freeze the executed binary as evidence; it is never an EA/deploy artifact.
            receipt['compiled_binary'] = freeze(Path(receipt['compile']['ex5']['path']))
            login, server = m.load_dxz_factory_login()
            startup = m.prepare_startup_files(terminal_root=root, run_root=run,
                symbols=SYMBOLS, output_tag=tag, login=login, server=server, chart_symbol='EURUSD')
            ini = Path(startup['startup_ini']['path'])
            ini.write_text(ini.read_text().replace('[Experts]', '[Charts]\nMaxBars=250000\n[Experts]'), encoding='utf-8')
            startup['startup_ini'] = m.file_binding(ini)
            startup['bounded_max_bars'] = 250000
            receipt['previous_factory_seconds'] = 101.359
            receipt['startup_bindings'] = startup
            expected = [m.local_harvest_paths(root, tag, s)[1] for s in SYMBOLS]
            receipt['execution'] = m.launch_and_wait(terminal_root=root,
                startup_ini=Path(startup['startup_ini']['path']), expected_artifacts=expected,
                timeout_seconds=1800, challenge_identity=snapshot['challenge'][0])
            receipt['status'] = 'MEASUREMENT_FINISHED'
        finally:
            # The canonical launch helper closes only the exact process it created.
            # A foreign active backtest is never signaled by this driver.
            for symbol in SYMBOLS:
                for path in m.local_harvest_paths(m.MT5_ROOT/terminal, tag, symbol):
                    if path.is_file():
                        receipt['artifacts'].append(freeze(path))
            for path in (m.MT5_ROOT/terminal/'MQL5/Files/QM/m1_harvest').glob(tag+'*_download.json'):
                receipt['artifacts'].append(freeze(path))
            receipt['reservation_release'] = m.release_factory_terminal_if_owned(terminal, owner)
except Exception as exc:
    receipt['status'] = 'MEASUREMENT_REFUSED_OR_INCOMPLETE'
    receipt['error'] = type(exc).__name__ + ': ' + str(exc)
finally:
    receipt['elapsed_seconds'] = round(time.monotonic() - start, 3)
    receipt['finished_utc'] = m.utc_now()
    receipt['q_verdict'] = None
    receipt['economic_adoption'] = False
    receipt['active_backtests_interrupted'] = False
    (run/'receipt.json').write_text(json.dumps(receipt, indent=2)+'\n', encoding='utf-8')
    print(json.dumps({'run': str(run), 'status': receipt['status'], 'error': receipt.get('error'),
                      'seconds': receipt['elapsed_seconds'], 'artifacts': len(receipt['artifacts'])}, indent=2))
