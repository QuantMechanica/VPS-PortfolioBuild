"""Pinned real-QM cold/warm fixture on reserved T11; never gate evidence.

The original EX5 and A setfile are unchanged. B changes only RISK_FIXED to
authenticate explicit MCP inputs loading. Private copies of EURUSD.DWX history,
ticks and symbol metadata; no charts, services, AutoTrading or live account calls.
"""
from __future__ import annotations

import argparse
import configparser
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import shutil
import sqlite3
import time

import psutil

from tools.strategy_farm.mt5_latency_lab import ROOT, SOURCE, admitted, sha

REPO = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / 'experiments/qm10012_fixture'
EA = 'QM5_10012_rw-fx-intraday-seas'
EA_SOURCE = REPO / 'framework/EAs' / EA
EX5_HASH = '7235ca08884367a70f0740c83e0eeb7c6d7db6324aaa402f6b7680eef9aa091b'
SET_HASH = 'a4fe3429279d29316e3ab306d0acecc7a53babb7f461f3c9049dfcc5a860cea9'
PROFILES = ROOT / 'MQL5/Profiles/Tester'
ARMS = {'a': ('a', '2025.01.11'), 'b': ('b', '2025.01.11'),
        'c': ('a', '2025.01.10'), 'd': ('b', '2025.01.10')}


def no_factory_conflict() -> None:
    with sqlite3.connect('file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro', uri=True) as db:
        if db.execute('SELECT id FROM work_items WHERE ea_id=? AND status IN (?,?)',
                      ('QM5_10012', 'active', 'pending')).fetchone():
            raise RuntimeError('Fixture EA has factory work; refuse shared-common evidence conflict')


def expected_inputs(arm: str) -> bytes:
    if arm not in ARMS:
        raise ValueError('Unknown fixture arm')
    arm = ARMS[arm][0]
    source = EA_SOURCE / 'sets' / f'{EA}_EURUSD.DWX_M30_backtest.set'
    if sha(source) != SET_HASH:
        raise ValueError('Original fixture setfile changed')
    raw = source.read_bytes()
    if arm == 'a':
        return raw
    if arm != 'b' or raw.count(b'RISK_FIXED=1000') != 1:
        raise ValueError('Unknown fixture arm')
    return raw.replace(b'RISK_FIXED=1000', b'RISK_FIXED=500')


def verify_fixture(*, resident: bool = False) -> dict:
    no_factory_conflict()
    manifest = json.loads((FIXTURE / 'manifest.json').read_text())
    spec = json.loads((FIXTURE / 'symbol_spec_manifest.json').read_text())
    if sha(ROOT / 'bases/symbols.custom.dat') != spec['sha256']:
        raise ValueError('Custom symbol definition differs from the private snapshot')
    if sha(ROOT / f'MQL5/Experts/QM/{EA}.ex5') != EX5_HASH:
        raise ValueError('Pinned real QM EX5 changed')
    for arm in ('a', 'b'):
        if (PROFILES / f'QM_lab_qm10012_{arm}.set').read_bytes() != expected_inputs(arm):
            raise ValueError('Fixture input bytes changed')
    for entry in manifest['data_files']:
        path = Path(entry['destination'])
        try:
            current_hash = sha(path)
        except PermissionError:
            if not resident:
                raise
            # MT5 keeps HCC handles denying other readers while resident. Bind
            # unchanged file identity/size/mtime to the pre-start full SHA256,
            # and require full post-close SHA256 before accepting parity.
            from tools.strategy_farm import mt5_warm_lab as lab
            lab.fenced_process(lab.state())
            preflight = json.loads((lab.SESSION / 'data_preflight.json').read_text())
            expected = preflight['files'][str(path)]
            stat = path.stat()
            if (stat.st_ino != expected['file_id'] or stat.st_size != expected['size']
                    or stat.st_mtime_ns != expected['mtime_ns'] or expected['sha256'] != entry['sha256']):
                raise ValueError('Locked history identity changed')
            current_hash = expected['sha256']
        if current_hash != entry['sha256']:
            raise ValueError('Private native history/tick bytes changed: ' + entry['relative'])
    return manifest


def write_preflight(session: Path) -> None:
    manifest = verify_fixture()
    files = {}
    for entry in manifest['data_files']:
        path = Path(entry['destination']); stat = path.stat()
        files[str(path)] = {'file_id': stat.st_ino, 'size': stat.st_size,
                           'mtime_ns': stat.st_mtime_ns, 'sha256': sha(path)}
    with (session / 'data_preflight.json').open('x') as stream:
        json.dump({'files': files, 'post_close_full_hash_required': True}, stream, indent=2)


def prepare() -> None:
    admitted()
    no_factory_conflict()
    if sha(EA_SOURCE / f'{EA}.ex5') != EX5_HASH:
        raise ValueError('Fixture EX5 is not the reviewed existing binary')
    FIXTURE.mkdir(exist_ok=False)
    records = []
    relative_data = ['bases/Custom/history/EURUSD.DWX/2024.hcc',
                     'bases/Custom/history/EURUSD.DWX/2025.hcc',
                     'bases/Custom/ticks/EURUSD.DWX/202412.tkc',
                     'bases/Custom/ticks/EURUSD.DWX/202501.tkc']
    for relative in relative_data:
        source, destination = SOURCE / relative, ROOT / relative
        if destination.exists() or not source.resolve().is_relative_to(SOURCE.resolve()):
            raise ValueError('Fixture data destination exists or source escapes reserved T11')
        before = sha(source)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        if sha(destination) != before or sha(source) != before or source.stat().st_ino == destination.stat().st_ino:
            raise ValueError('Private copy/source identity verification failed')
        records.append({'relative': relative, 'destination': str(destination), 'sha256': before,
                        'size_bytes': destination.stat().st_size})
    symbols = SOURCE / 'bases/Darwinex-Live/symbols'
    symbol_records = []
    backup = FIXTURE / 'prior_lab_symbol_metadata'
    backup.mkdir()
    for source in symbols.glob('*.dat'):
        destination = ROOT / 'bases/Darwinex-Live/symbols' / source.name
        if destination.exists():
            shutil.copy2(destination, backup / destination.name)
        shutil.copy2(source, destination)
        symbol_records.append({'source': str(source), 'destination': str(destination), 'sha256': sha(destination)})
    expert = ROOT / f'MQL5/Experts/QM/{EA}.ex5'
    expert.parent.mkdir(exist_ok=True, parents=True)
    if expert.exists():
        raise ValueError('Fixture EX5 destination already exists')
    shutil.copy2(EA_SOURCE / f'{EA}.ex5', expert)
    PROFILES.mkdir(parents=True, exist_ok=True)
    for arm in ('a', 'b'):
        with (PROFILES / f'QM_lab_qm10012_{arm}.set').open('xb') as stream:
            stream.write(expected_inputs(arm))
    manifest = {'schema': 'qm.real-ea-warm-fixture/v1', 'created_at_utc': datetime.now(timezone.utc).isoformat(),
        'ea': EA, 'ex5_sha256': EX5_HASH, 'original_setfile_sha256': SET_HASH,
        'symbol': 'EURUSD.DWX', 'period': 'M30', 'model': 4, 'from_date': '2025.01.06', 'to_date': '2025.01.11',
        'data_files': records, 'symbol_metadata': symbol_records,
        'disposition': 'EXPERIMENT_ONLY_NO_GATE_ADMISSION; no strategy or registry change'}
    (FIXTURE / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
    print(json.dumps(manifest), flush=True)


def prepare_symbol_spec() -> None:
    admitted()
    # T11 had price history but no native custom-symbol catalogue. Reuse the
    # same file already required by the governed DEV1/DEV2 isolation runners.
    # T1 and T10 must independently agree; no edits to either running terminal.
    first = Path('D:/QM/mt5/T1/bases/symbols.custom.dat')
    second = Path('D:/QM/mt5/T10/bases/symbols.custom.dat')
    digest = sha(first)
    if digest != sha(second):
        raise ValueError('Factory custom-symbol definition snapshots disagree')
    target = ROOT / 'bases/symbols.custom.dat'
    if target.exists():
        raise ValueError('Never replace an existing custom-symbol definition')
    shutil.copy2(first, target)
    if sha(first) != digest or sha(target) != digest or first.stat().st_ino == target.stat().st_ino:
        raise ValueError('Symbol definition private copy changed')
    record = {'source': str(first), 'corroborating_source': str(second), 'destination': str(target),
              'sha256': digest, 'size_bytes': target.stat().st_size,
              'reason': 'T11 source lacked Bases/symbols.custom.dat; history alone is insufficient'}
    with (FIXTURE / 'symbol_spec_manifest.json').open('x') as stream:
        json.dump(record, stream, indent=2)
    print(json.dumps(record), flush=True)


def prepare_clean_window() -> None:
    admitted()
    verify_fixture()
    for arm in ('c', 'd'):
        with (PROFILES / f'QM_lab_qm10012_{arm}.set').open('xb') as stream:
            stream.write(expected_inputs(arm))
    record = {'schema': 'qm.real-ea-warm-clean-window/v1',
        'from_date': '2025.01.06', 'to_date': '2025.01.10',
        'reason': 'Original data warns about absent real ticks on 2025.01.10 23:59; clean diagnostic window ends before Friday. Original data/reports retained, no source repair or strategy verdict claimed.',
        'arms': {'c': 'original A setfile bytes', 'd': 'original B setfile bytes'},
        'zero_native_tick_gap_warnings_required': True}
    with (FIXTURE / 'clean_window.json').open('x') as stream:
        json.dump(record, stream, indent=2)
    print(json.dumps(record), flush=True)


def cold_config(fixture: str, report_name: str, *, resident: bool = False) -> str:
    if fixture not in tuple('qm10012_' + arm for arm in ARMS) or not re.fullmatch(r'[a-z0-9_]+\.htm', report_name):
        raise ValueError('Unknown fixed QM cold fixture')
    verify_fixture(resident=resident)
    arm = fixture[-1]
    if (PROFILES / f'QM_lab_qm10012_{arm}.set').read_bytes() != expected_inputs(arm):
        raise ValueError('Fixture setfile changed')
    return ('[Tester]\n' + f'Expert=QM\\{EA}\nExpertParameters=QM_lab_qm10012_{arm}.set\n'
        'Symbol=EURUSD.DWX\nPeriod=M30\nModel=4\nExecutionMode=0\nOptimization=0\n'
        f'FromDate=2025.01.06\nToDate={ARMS[arm][1]}\nDeposit=100000\nCurrency=USD\nLeverage=100\n'
        'UseLocal=1\nUseRemote=0\nUseCloud=0\nVisual=0\nReplace=1\nReplaceReport=1\n'
        f'ShutdownTerminal=0\nReport={report_name}\n')


def validate_run(arguments: dict) -> None:
    if set(arguments) != {'config_path', 'inputs_path', 'wait'} or arguments['wait'] is not False:
        raise ValueError('QM fixture requires exact nonblocking run and explicit inputs_path')
    ini = Path(arguments['config_path']).resolve()
    if ini.parent != PROFILES.resolve() or not re.fullmatch(r'QM_lab_qm10012_[abcd][a-z0-9]{1,14}\.ini', ini.name):
        raise ValueError('Not a new QM fixture configuration')
    arm = ini.name[len('QM_lab_qm10012_')]
    inputs = Path(arguments['inputs_path']).resolve()
    if inputs != (PROFILES / f'QM_lab_qm10012_{arm}.set').resolve():
        raise ValueError('Wrong fixture input path')
    config = configparser.ConfigParser(interpolation=None)
    config.read(ini, encoding='utf-16')
    expected = configparser.ConfigParser(interpolation=None)
    expected.read_string(cold_config('qm10012_' + arm, 'fixture.htm', resident=True))
    actual = dict(config['Tester'])
    report = actual.pop('report')
    expected_values = dict(expected['Tester']); expected_values.pop('report')
    if config.sections() != ['Tester'] or actual != expected_values or report != ini.stem + '.htm':
        raise ValueError('QM fixture settings or report binding changed')


def quiesce_agent(session_record: dict) -> list[int]:
    from tools.strategy_farm.mt5_warm_lab import fenced_process
    terminal = fenced_process(session_record)
    agents = [p for p in psutil.process_iter(['exe', 'create_time'])
              if Path(p.info['exe'] or '').resolve() == (ROOT / 'metatester64.exe').resolve()
              and p.info['create_time'] >= session_record['started_epoch']]
    for agent in agents:
        agent.terminate()
    _, alive = psutil.wait_procs(agents, timeout=5)
    if alive or not terminal.is_running():
        raise RuntimeError('Cannot prove writer quiescence with resident terminal alive')
    return [p.pid for p in agents]


def logger_state() -> dict[str, bytes]:
    return {str(p): p.read_bytes() for p in ROOT.glob('Tester/Agent-*/MQL5/Files/QM/QM5_10012_*.log')}


def capture_logger(destination: Path, *, before: dict[str, bytes] | None = None,
                   since_epoch: float = 0) -> dict:
    files = list(ROOT.glob('Tester/Agent-*/MQL5/Files/QM/QM5_10012_*.log'))
    if not files:
        raise RuntimeError('No native QM structured logger file')
    snapshots = []
    for index, source in enumerate(files):
        raw = source.read_bytes()
        previous = (before or {}).get(str(source), b'')
        if (before is not None and raw == previous) or source.stat().st_mtime < since_epoch:
            continue
        delta = raw[len(previous):] if previous and raw.startswith(previous) else raw
        if not delta:
            continue
        target = destination / f'logger_{index}.bin'
        with target.open('xb') as stream:
            stream.write(raw)
        delta_path = destination / f'logger_delta_{index}.jsonl'
        with delta_path.open('xb') as stream:
            stream.write(delta)
        rows = [json.loads(line) for line in delta.decode('utf-8-sig').splitlines() if line.strip()]
        if not rows or any(row.get('ea_id') != 10012 or row.get('symbol') != 'EURUSD.DWX'
                           or row.get('tf') != 'M30' for row in rows):
            raise ValueError('Logger run identity differs')
        snapshots.append({'source': str(source), 'snapshot': str(target), 'size': len(raw), 'sha256': sha(target),
                          'delta_path': str(delta_path), 'delta_sha256': sha(delta_path), 'events': len(rows),
                          'previous_exact_prefix_bytes': len(previous) if raw.startswith(previous) else 0})
    if len(snapshots) != 1:
        raise RuntimeError('Exactly one fresh native QM logger stream required')
    return {'files': snapshots}


def capture_journals(destination: Path, offsets: dict[str, int], arm: str) -> dict:
    from tools.strategy_farm.mt5_warm_report_parity import journal_run
    native, warnings = [], []
    for source in ROOT.glob('Tester/**/logs/*.log'):
        offset = offsets.get(str(source), 0)
        if source.stat().st_size < offset:
            raise RuntimeError('Native journal truncated during experiment')
        with source.open('rb') as stream:
            stream.seek(offset)
            raw = stream.read()
        if not raw:
            continue
        with (destination / (source.parent.parent.name + '_journal_delta.bin')).open('xb') as stream:
            stream.write(raw)
        if source.parent.parent.name.startswith('Agent-'):
            decoded = raw.decode('utf-16-le').lstrip('\ufeff')
            native.append(journal_run(decoded))
            warnings.extend(line for line in decoded.splitlines()
                            if 'real ticks absent' in line or 'every tick generation used' in line)
    if len(native) != 1:
        raise RuntimeError('Exactly one fresh native QM execution required')
    if arm in ('c', 'd') and warnings:
        raise RuntimeError('Clean diagnostic window still contains native real-tick gaps')
    return {'native_journals': native, 'native_tick_gap_warnings': warnings}


def capture_cold() -> None:
    from tools.strategy_farm import mt5_warm_lab as lab
    from tools.strategy_farm.mt5_report_rescue import tester_config, validate_report
    from tools.strategy_farm.mt5_warm_report_parity import html_rows, metadata
    with lab.session_lock():
        verify_fixture(resident=True)
        tester = tester_config(lab.SESSION / 'cold.ini')
        setfile = PROFILES / tester['expertparameters']
        arm = setfile.stem[-1]
        if arm not in ARMS or setfile.read_bytes() != expected_inputs(arm):
            raise ValueError('Cold fixture inputs changed')
        cold = ROOT / (lab.SESSION.name + '_cold.htm')
        validation = validate_report(cold, tester, setfile)
        result = json.loads((lab.SESSION / 'cold_result.json').read_text())
        if result['report_sha256'] != sha(cold):
            raise ValueError('Cold report changed after completion')
        stopped = quiesce_agent(lab.state())
        logger = capture_logger(lab.SESSION, since_epoch=lab.state()['started_epoch'])
        offsets = json.loads((lab.SESSION / 'cold_journal_offsets.json').read_text())
        journals = capture_journals(lab.SESSION, offsets, arm)
        summary = {'arm': arm, 'validation': validation, 'logger': logger,
                   'metadata': metadata(html_rows(cold)), 'quiesced_agent_pids': stopped,
                   'resident_terminal_pid': lab.state()['pid'], **result, **journals}
        with (lab.SESSION / 'cold_capture.json').open('x') as stream:
            json.dump(summary, stream, indent=2)
        print(json.dumps(summary), flush=True)


def run(arm: str, name: str) -> None:
    from tools.strategy_farm import mt5_warm_lab as lab
    from tools.strategy_farm.mt5_native_html_export import export
    from tools.strategy_farm.mt5_report_rescue import validate_report, tester_config
    from tools.strategy_farm.mt5_warm_report_parity import html_rows, metadata
    if arm not in ARMS or not re.fullmatch('[a-z0-9]{1,14}', name):
        raise ValueError('Invalid QM fixture run name')
    with lab.session_lock():
        verify_fixture(resident=True)
        runroot = lab.SESSION / name
        runroot.mkdir(exist_ok=False)
        ini = PROFILES / f'QM_lab_qm10012_{arm}{name}.ini'
        if ini.exists():
            raise ValueError('Never overwrite configuration')
        config = cold_config('qm10012_' + arm, 'fixture.htm', resident=True).replace('Report=fixture.htm', 'Report=' + ini.stem + '.htm')
        ini.write_text(config, encoding='utf-16')
        offsets = {str(p):p.stat().st_size for p in ROOT.glob('Tester/**/logs/*.log')}
        prior_logger = logger_state()
        key = lab.client()
        started = time.monotonic()
        result = lab.call('tester_run_backtest', {'config_path': str(ini),
            'inputs_path': str(PROFILES / f'QM_lab_qm10012_{arm}.set'), 'wait': False}, key)
        (runroot / 'launch.json').write_text(json.dumps(result, indent=2))
        for _ in range(120):
            status = lab.call('tester_get_status', {'run_id': result['run_id']}, key)
            if status.get('tester_status', status.get('status')) in ('completed','finished','stopped','failed','error'):
                break
            time.sleep(.5)
        else:
            raise RuntimeError('QM fixture did not finish within bounded polls')
        if status.get('tester_status', status.get('status')) not in ('completed', 'finished', 'stopped'):
            raise RuntimeError('Native tester reported a failed run')
        path = runroot / 'native.html'
        report = export(lab.fenced_process(lab.state()).pid, path,
                        identity_guard=lambda: lab.fenced_process(lab.state()))
        validated = validate_report(path, tester_config(ini), PROFILES / f'QM_lab_qm10012_{arm}.set')
        stopped = quiesce_agent(lab.state())
        logger = capture_logger(runroot, before=prior_logger)
        journals = capture_journals(runroot, offsets, arm)
        summary = {'arm': arm, 'run_id': result['run_id'], 'status': status, 'report': report,
                   'validation': validated, 'metadata': metadata(html_rows(path)), 'logger': logger,
                   'quiesced_agent_pids': stopped, 'resident_terminal_pid': lab.state()['pid'],
                   **journals,
                   'complete_evidence_seconds': time.monotonic()-started}
        (runroot / 'summary.json').write_text(json.dumps(summary, indent=2))
        print(json.dumps(summary), flush=True)


def main():
    from tools.strategy_farm import mt5_warm_lab as lab
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['prepare','prepare-spec','prepare-clean','run','capture-cold'])
    parser.add_argument('--session', default='qm10012_colda')
    parser.add_argument('--arm', choices=list(ARMS), default='a')
    parser.add_argument('--name', default='warm1')
    args = parser.parse_args()
    if not re.fullmatch('[a-z0-9_]{1,40}', args.session):
        raise ValueError('Invalid lab-local session')
    lab.SESSION = ROOT / 'experiments' / args.session
    if args.action == 'prepare':
        prepare()
    elif args.action == 'prepare-spec':
        prepare_symbol_spec()
    elif args.action == 'prepare-clean':
        prepare_clean_window()
    elif args.action == 'run':
        run(args.arm, args.name)
    else:
        capture_cold()


if __name__ == '__main__':
    main()
