"""Bounded, tester-only persistent MT5 experiment. NEVER a factory runner.

Only the separately reserved T11 latency lab and its process-owned loopback MCP
port are admitted. No account, trading, chart, shell or generic MCP tools.
Existing credentials stay local and are never included in evidence/output.
"""
from __future__ import annotations

import argparse
import configparser
from contextlib import contextmanager
from datetime import datetime, timezone
import json
from pathlib import Path
import re
import subprocess
import time
import urllib.error
import urllib.request

import psutil

from tools.strategy_farm.mt5_latency_lab import ROOT, admitted, sha

PORT = 22357
ENDPOINT = f'http://127.0.0.1:{PORT}/mcp'
SESSION = ROOT / 'experiments' / 'warm20260908'
ALLOWED = frozenset({'tester_run_backtest', 'tester_get_status', 'tester_get_report',
                     'tester_get_configuration', 'get_workspace_info'})
_MCP_HEADERS: dict[str, str] = {}


def save(name: str, data: object) -> None:
    (SESSION / name).write_text(json.dumps(data, indent=2), encoding='utf-8')


def state() -> dict:
    return json.loads((SESSION / 'session.json').read_text(encoding='utf-8'))


def fenced_process(record: dict) -> psutil.Process:
    process = psutil.Process(record['pid'])
    if (Path(process.exe()).resolve() != (ROOT / 'terminal64.exe').resolve()
            or abs(process.create_time() - record['create_time']) > .01):
        raise RuntimeError('Lab process identity changed')
    return process


def fence_endpoint(record: dict) -> None:
    process = fenced_process(record)
    listeners = [c for c in psutil.net_connections(kind='tcp')
                 if c.status == psutil.CONN_LISTEN and c.laddr.port == PORT]
    if not listeners or any(c.pid != process.pid or c.laddr.ip != '127.0.0.1'
                            for c in listeners):
        raise RuntimeError('Unique loopback endpoint is not exclusively owned by lab PID')


def validate_call(method: str, params: dict) -> None:
    if method in {'initialize', 'notifications/initialized', 'tools/list'}:
        return
    if method != 'tools/call' or params.get('name') not in ALLOWED:
        raise ValueError('Only tester allowlist or MCP discovery is permitted')
    if params['name'] == 'tester_run_backtest':
        arguments = params.get('arguments', {})
        if set(arguments) != {'config_path', 'wait'} or arguments['wait'] is not False:
            raise ValueError('Only non-blocking fixed-fixture runs are permitted')
        ini = Path(arguments['config_path']).resolve()
        if (ini.parent != (ROOT / 'MQL5/Profiles/Tester').resolve()
                or not re.fullmatch(r'QM_lab_warm_[a-z0-9]{1,16}\.ini', ini.name)):
            raise ValueError('Not a lab-owned tester configuration')
        cfg = configparser.ConfigParser(interpolation=None)
        cfg.read(ini, encoding='utf-16')
        tester = dict(cfg['Tester'])
        expected = {'expert': 'Examples\\Moving Average\\Moving Average', 'symbol': 'EURUSD',
                    'period': 'M5', 'model': '4', 'executionmode': '0', 'optimization': '0',
                    'fromdate': '2026.09.01', 'todate': '2026.09.05', 'deposit': '100000',
                    'currency': 'USD', 'leverage': '100', 'uselocal': '1', 'useremote': '0',
                    'usecloud': '0', 'visual': '0', 'replace': '1', 'replacereport': '1',
                    'shutdownterminal': '0'}
        report = tester.pop('report', '')
        if tester.get('fromdate') == '2026.09.02':
            expected['fromdate'] = '2026.09.02'
        if cfg.sections() != ['Tester'] or tester != expected:
            raise ValueError('Fixture quality or isolation settings changed')
        if not re.fullmatch(r'QM_lab_warm_[a-z0-9]{1,16}\.htm', report):
            raise ValueError('Report must be a new lab-relative file')
        expert = ROOT / 'MQL5/Experts/Examples/Moving Average/Moving Average.ex5'
        if sha(expert) != 'e5c16f9b6bd88c768ece376e5f87d9fd30e3304154482c85cc7cb09e5511081f':
            raise ValueError('Fixture EA changed')
    elif params['name'] == 'tester_get_report' and 'path' in params.get('arguments', {}):
        path = Path(params['arguments']['path']).resolve()
        if path.parent != (ROOT / 'MQL5/Files/QM_latency_lab').resolve() or path.exists():
            raise ValueError('Report output must be a new lab evidence file')


def rpc(method: str, params: dict, api_key: str | None = None) -> dict:
    validate_call(method, params)
    record = state()
    if time.time() >= record['deadline_epoch']:
        raise RuntimeError('Lab session expired')
    fence_endpoint(record)
    headers = {'Content-Type': 'application/json', 'Accept': 'application/json, text/event-stream'}
    headers.update(_MCP_HEADERS)
    if api_key:
        headers['Authorization'] = 'Bearer ' + api_key
    payload = {'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params}
    if method.startswith('notifications/'):
        payload.pop('id')
    request = urllib.request.Request(ENDPOINT, data=json.dumps(payload).encode(), headers=headers)
    # No proxy or redirects: credentials may only go to this verified loopback socket.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    try:
        with opener.open(request, timeout=15) as response:
            if response.headers.get('Mcp-Session-Id'):
                _MCP_HEADERS['Mcp-Session-Id'] = response.headers['Mcp-Session-Id']
                _MCP_HEADERS['MCP-Protocol-Version'] = '2025-06-18'
            raw = response.read(2 * 1024 * 1024).decode('utf-8')
            if not raw.strip():
                return {'http_status': response.status}
            if raw.startswith('event:') or raw.startswith('data:'):
                raw = '\n'.join(line[5:].strip() for line in raw.splitlines() if line.startswith('data:'))
            return json.loads(raw)
    except urllib.error.HTTPError as error:
        return {'http_error': error.code}  # Never echo request headers or secrets.


def ui_key() -> str:
    """Read our own lab's key through its normal MCP settings, never print/store it.

    The on-disk key is encrypted and is not an HTTP bearer credential. Native
    Options is opened/cancelled without saving settings or generating a key.
    """
    import site
    site.addsitedir('D:/QM/console_design_20260907/python_deps')
    import win32gui
    from pywinauto import Application
    app = Application(backend='win32').connect(process=fenced_process(state()).pid)
    window = app.window(class_name='MetaQuotes::MetaTrader::5.00', visible_only=False)
    win32gui.ShowWindow(window.handle, 8)
    if app.windows(title='Options', class_name='#32770', visible_only=True):
        raise RuntimeError('Lab Options is already open; refuse another modal dialog')
    options = window.menu().get_menu_path('Tools')[0].sub_menu().items()[-1]
    if options.text() != '&Options\tCtrl+O' or options.item_id() != 32849:
        raise RuntimeError('Options command identity changed')
    window.post_message(0x111, options.item_id(), 0)
    dialog = app.window(title='Options', class_name='#32770', visible_only=True)
    dialog.wait('visible', timeout=5)
    try:
        dialog.child_window(class_name='SysTabControl32').select('MCP')
        if dialog.child_window(control_id=10030, class_name='Edit').window_text() != ENDPOINT:
            raise RuntimeError('Wrong MCP endpoint in lab settings')
        return dialog.child_window(control_id=11145, class_name='Edit').window_text()
    finally:
        # Direct normal IDCANCEL; synthetic mouse clicks can leave MT5's modal
        # dialog open and make the next credential read ambiguous.
        dialog.post_message(0x111, 2, 0)
        dialog.wait_not('visible', timeout=5)


def client() -> str:
    key = ui_key()
    _MCP_HEADERS.clear()
    result = rpc('initialize', {'protocolVersion': '2025-06-18', 'capabilities': {},
                 'clientInfo': {'name': 'QM-T11-lab', 'version': '0.1'}}, api_key=key)
    if 'result' not in result:
        raise RuntimeError('MCP initialize failed')
    rpc('notifications/initialized', {}, api_key=key)
    result = rpc('tools/call', {'name': 'get_workspace_info', 'arguments': {}}, api_key=key)
    save('workspace_info.json', result)
    if result.get('error') or result.get('result', {}).get('isError'):
        raise RuntimeError('MCP workspace discovery failed')
    return key


def call(name: str, arguments: dict, key: str) -> dict:
    result = rpc('tools/call', {'name': name, 'arguments': arguments}, api_key=key)
    if result.get('error') or result.get('result', {}).get('isError'):
        raise RuntimeError(json.dumps(result))
    payload = result.get('result', {})
    if 'structuredContent' in payload:
        return payload['structuredContent']
    content = payload.get('content', [])
    if len(content) == 1 and content[0].get('type') == 'text':
        return json.loads(content[0]['text'])
    return payload


@contextmanager
def session_lock():
    """MCP identifies only the current tester job; never allow two controllers."""
    import msvcrt
    with (SESSION / 'controller.lock').open('a+b') as stream:
        stream.seek(0)
        msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
        try:
            yield
        finally:
            stream.seek(0)
            msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)


def benchmark(name: str, hidden: bool = False, from_date: str = '2026.09.01') -> None:
    with session_lock():
        _benchmark(name, hidden, from_date)


def _benchmark(name: str, hidden: bool, from_date: str) -> None:
    if not re.fullmatch('[a-z0-9]{1,16}', name):
        raise ValueError('Invalid unique benchmark name')
    if from_date not in {'2026.09.01', '2026.09.02'}:
        raise ValueError('Only the two explicit state-isolation fixtures are admitted')
    key = client()
    import site
    site.addsitedir('D:/QM/console_design_20260907/python_deps')
    import win32gui
    from pywinauto import Application
    app = Application(backend='win32').connect(process=fenced_process(state()).pid)
    hwnd = app.window(class_name='MetaQuotes::MetaTrader::5.00').handle
    win32gui.ShowWindow(hwnd, 0 if hidden else 8)  # Only the fenced lab, no focus.
    runroot = SESSION / name
    runroot.mkdir(exist_ok=False)
    ini = ROOT / 'MQL5/Profiles/Tester' / f'QM_lab_warm_{name}.ini'
    report = ROOT / f'QM_lab_warm_{name}.htm'
    if ini.exists() or report.exists():
        raise ValueError('Benchmark never overwrites input or native report')
    ini.parent.mkdir(parents=True, exist_ok=True)
    config = (SESSION / 'cold.ini').read_text(encoding='utf-16')
    config = config.replace('FromDate=2026.09.01', f'FromDate={from_date}')
    ini.write_text(re.sub(r'(?m)^Report=.*$', f'Report={report.name}', config), encoding='utf-16')
    offsets = {str(p): p.stat().st_size for p in ROOT.glob('Tester/**/logs/*.log')}
    (runroot / 'journal_offsets.json').write_text(json.dumps(offsets, indent=2))
    started = time.time()
    started_mono = time.monotonic()
    result = call('tester_run_backtest', {'config_path': str(ini), 'wait': False}, key)
    (runroot / 'launch.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps({'launched': result, 'call_seconds': time.monotonic() - started_mono}), flush=True)
    run_id = result['run_id']
    with (runroot / 'observations.jsonl').open('x', encoding='utf-8') as stream:
        for _ in range(120):
            status = call('tester_get_status', {'run_id': run_id}, key)
            sample = {'elapsed_seconds': time.monotonic() - started_mono, 'status': status,
                      'html_exists': report.exists()}
            stream.write(json.dumps(sample) + '\n')
            stream.flush()
            if status.get('tester_status', status.get('status')) in {'completed', 'finished', 'stopped', 'failed', 'error'}:
                break
            time.sleep(.5)
        else:
            raise RuntimeError('Bounded 120-poll lab observation expired')
    summary = {'started_epoch': started, 'elapsed_seconds': time.monotonic() - started_mono,
               'status': status, 'run_id': run_id, 'ini_sha256': sha(ini),
               'html_exists': report.exists(), 'pid': state()['pid'], 'hidden_requested': hidden,
               'fixture_from_date': from_date,
               'window_visible_at_stop': bool(win32gui.IsWindowVisible(hwnd))}
    for tool, output in [('tester_get_configuration', 'configuration'), ('tester_get_report', 'report')]:
        result = call(tool, {'run_id': run_id}, key)
        (runroot / f'{output}.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    output = ROOT / 'MQL5/Files/QM_latency_lab' / f'{name}.xml'
    output.parent.mkdir(parents=True, exist_ok=True)
    export_started = time.monotonic()
    result = call('tester_get_report', {'run_id': run_id, 'path': str(output), 'file_format': 'xml'}, key)
    summary['native_export_seconds'] = time.monotonic() - export_started
    (runroot / 'xml_response.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    for path, offset in offsets.items():
        with Path(path).open('rb') as source:
            source.seek(offset)
            (runroot / (Path(path).parent.parent.name + '_journal_delta.bin')).write_bytes(source.read())
    summary['xml_exists'] = output.exists()
    summary['evidence_collected_seconds'] = time.monotonic() - started_mono
    (runroot / 'summary.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print(json.dumps(summary), flush=True)


def relaunch_probe() -> None:
    """Does a second /config invocation control an already-running terminal?"""
    with session_lock():
        record = state()
        fenced_process(record)
        ini = SESSION / 'relaunch.ini'
        report = ROOT / 'warmrelaunch.htm'
        if ini.exists() or report.exists():
            raise ValueError('Probe output already exists')
        ini.write_text(re.sub(r'(?m)^Report=.*$', 'Report=warmrelaunch.htm',
            (SESSION / 'cold.ini').read_text(encoding='utf-16')), encoding='utf-16')
        logs = {str(p): p.stat().st_size for p in ROOT.glob('Tester/**/logs/*.log')}
        started = time.time()
        command = (f"$p=Start-Process -FilePath '{ROOT / 'terminal64.exe'}' -ArgumentList "
                   f"'/portable','/config:{ini}' -WindowStyle Hidden -PassThru; $p.Id")
        launch = subprocess.run(['powershell.exe', '-NoProfile', '-Command', command],
                                capture_output=True, text=True, check=True)
        launched_pid = int(launch.stdout.strip())
        if psutil.pid_exists(launched_pid):
            process = psutil.Process(launched_pid)
            try:
                process.wait(timeout=5)
            except psutil.TimeoutExpired:
                if (Path(process.exe()).resolve() == (ROOT / 'terminal64.exe').resolve()
                        and process.create_time() >= started):
                    process.terminate()
                    process.wait(timeout=5)
                raise RuntimeError('Second lab process did not hand off promptly; probe aborted')
        time.sleep(10)
        fenced_process(record)
        deltas = {p: Path(p).stat().st_size - offset for p, offset in logs.items()}
        result = {'started_epoch': started, 'observation_seconds': time.time() - started,
                  'second_process_pid': launched_pid, 'original_pid_alive': record['pid'],
                  'native_report_exists': report.exists(), 'native_journal_byte_deltas': deltas}
        save('relaunch_probe.json', result)
        print(json.dumps(result), flush=True)


def start() -> None:
    admitted()
    if any(c.laddr and c.laddr.port == PORT for c in psutil.net_connections(kind='tcp')):
        raise RuntimeError('Lab port already occupied')
    SESSION.mkdir(exist_ok=False)
    assistant = ROOT / 'Config/assistant.ini'
    original = assistant.read_bytes()
    (SESSION / 'assistant.before.bin').write_bytes(original)
    text = original.decode('utf-16')
    if text.count('http://127.0.0.1:22346/mcp') != 1:
        raise RuntimeError('Unexpected original MCP config')
    text = text.replace('http://127.0.0.1:22346/mcp', ENDPOINT)
    assistant.write_text(text, encoding='utf-16')
    ini = SESSION / 'cold.ini'
    cold_name = 'warmcold.htm' if SESSION.name == 'warm20260908' else SESSION.name + '_cold.htm'
    ini.write_text('[Tester]\nExpert=Examples\\Moving Average\\Moving Average\n'
                   'Symbol=EURUSD\nPeriod=M5\nModel=4\nExecutionMode=0\nOptimization=0\n'
                   'FromDate=2026.09.01\nToDate=2026.09.05\nDeposit=100000\nCurrency=USD\n'
                   'Leverage=100\nUseLocal=1\nUseRemote=0\nUseCloud=0\nVisual=0\n'
                   f'Replace=1\nReplaceReport=1\nShutdownTerminal=0\nReport={cold_name}\n', encoding='utf-16')
    if (ROOT / cold_name).exists():
        raise RuntimeError('Never overwrite an existing report')
    started = time.time()
    command = (f"$p=Start-Process -FilePath '{ROOT / 'terminal64.exe'}' -ArgumentList "
               f"'/portable','/config:{ini}' -WindowStyle Hidden -PassThru; $p.Id")
    try:
        launch = subprocess.run(['powershell.exe', '-NoProfile', '-Command', command],
                                capture_output=True, text=True, check=True)
        process = psutil.Process(int(launch.stdout.strip()))
        record = {'pid': process.pid, 'create_time': process.create_time(),
                  'started_epoch': started, 'deadline_epoch': started + 1800,
                  'terminal_sha256': sha(ROOT / 'terminal64.exe'),
                  'endpoint': ENDPOINT, 'mode': 'EXPERIMENT_ONLY_NO_GATE_ADMISSION'}
        save('session.json', record)
        subprocess.Popen(['python', '-m', 'tools.strategy_farm.mt5_warm_lab', 'watchdog', '--session', SESSION.name],
                         cwd=Path(__file__).resolve().parents[2],
                         creationflags=subprocess.CREATE_NO_WINDOW,
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(json.dumps(record), flush=True)
        last_size = 0
        first = None
        for _ in range(240):
            fenced_process(record)
            report = ROOT / cold_name
            size = report.stat().st_size if report.exists() else 0
            if size and first is None:
                first = time.time() - started
                save('cold_first_byte.json', {'seconds': first})
            if size and size == last_size and '</html>' in report.read_text(encoding='utf-16').lower():
                result = {'first_byte_seconds': first, 'complete_observed_seconds': time.time() - started,
                          'report_sha256': sha(report), 'pid_still_running': process.pid}
                save('cold_result.json', result)
                print(json.dumps(result), flush=True)
                return
            last_size = size
            time.sleep(.5)
        print(json.dumps({'cold_report': 'not_complete_within_120_seconds'}), flush=True)
    except Exception:
        if (SESSION / 'session.json').exists():
            close()
        else:
            assistant.write_bytes(original)
        raise


def close() -> None:
    record = state()
    victims = []
    for process in psutil.process_iter(['pid', 'exe', 'create_time']):
        if (Path(process.info['exe'] or '').parent == ROOT
                and Path(process.info['exe'] or '').name.lower() in {'terminal64.exe', 'metatester64.exe'}
                and process.info['create_time'] >= record['started_epoch']):
            if process.name().lower() == 'terminal64.exe':
                fenced_process(record)
            victims.append(process)
    for process in victims:
        try:
            process.terminate()
        except psutil.NoSuchProcess:
            pass
    _, alive = psutil.wait_procs(victims, timeout=5)
    if alive:
        raise RuntimeError('Lab processes did not exit; config not restored')
    (ROOT / 'Config/assistant.ini').write_bytes((SESSION / 'assistant.before.bin').read_bytes())
    save('closed.json', {'closed_utc': datetime.now(timezone.utc).isoformat(),
                         'terminated_owned_pids': [p.pid for p in victims], 'mcp_config_restored': True})


def main() -> None:
    global SESSION
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['start', 'discover', 'close', 'watchdog', 'benchmark', 'relaunch-probe'])
    parser.add_argument('--name', default='pilot1')
    parser.add_argument('--hidden', action='store_true')
    parser.add_argument('--from-date', choices=['2026.09.01', '2026.09.02'], default='2026.09.01')
    parser.add_argument('--session', default='warm20260908')
    args = parser.parse_args()
    if not re.fullmatch('[a-z0-9_]{1,40}', args.session):
        parser.error('Session must be a bounded lab-local name')
    SESSION = ROOT / 'experiments' / args.session
    if args.action == 'start':
        start()
    elif args.action == 'close':
        close()
    elif args.action == 'benchmark':
        benchmark(args.name, args.hidden, args.from_date)
    elif args.action == 'relaunch-probe':
        relaunch_probe()
    elif args.action == 'discover':
        key = client()
        result = rpc('tools/list', {}, api_key=key)
        save('tools_list.json', result)
        print(json.dumps([t for t in result.get('result', {}).get('tools', [])
                          if t['name'] in ALLOWED]), flush=True)
    else:
        while not (SESSION / 'closed.json').exists() and time.time() < state()['deadline_epoch']:
            time.sleep(2)
        if not (SESSION / 'closed.json').exists():
            close()


if __name__ == '__main__':
    main()
