"""One-shot native report rescue; never a gate verdict or a warm factory runner.

Only the checked-in, expiring canary policy admits a factory terminal. The
request must be made by its live run_smoke parent and bind the exact native
engine, INI, EX5, setfile, work item and newly spawned terminal. Any uncertainty
leaves the normal CLI finalization/retry path in charge. No MCP/trading tools.
"""
from __future__ import annotations

import argparse
import configparser
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
import hashlib
import html
import json
import os
from pathlib import Path
import re
import sqlite3
import time
import uuid

import psutil

from tools.strategy_farm.backtest_tail_watch import finished_marker_time, tail
from tools.strategy_farm.mt5_native_html_export import export

REPO = Path(__file__).resolve().parents[2]
POLICY = REPO / 'framework/registry/mt5_native_report_rescue.json'
MT5 = Path('D:/QM/mt5')
DB = Path('D:/QM/strategy_farm/state/farm_state.sqlite')
REPORTS = Path('D:/QM/reports')


def sha(path: Path) -> str:
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def read_text(path: Path) -> str:
    raw = path.read_bytes()
    return raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')


def tester_config(path: Path) -> dict:
    config = configparser.ConfigParser(interpolation=None)
    config.read_string(read_text(path))
    tester = dict(config['Tester'])
    if tester.get('model') != '4' or tester.get('optimization', '0') != '0':
        raise ValueError('Only real-tick, non-optimization single tests admitted')
    if tester.get('visual', '0') != '0':
        raise ValueError('Visual tester not admitted')
    return tester


def normalized(value: str) -> str:
    value = value.strip()
    try:
        number = Decimal(value)
        return str(number.normalize()) if number.is_finite() else value
    except InvalidOperation:
        return value


def validate_report(path: Path, tester: dict, setfile: Path | None) -> dict:
    text = read_text(path)
    if '</html>' not in text.lower() or 'content="strategy tester"' not in text.lower():
        raise ValueError('Not a complete native tester HTML report')
    cells = [html.unescape(re.sub('<[^>]+>', '', cell)).strip()
             for cell in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>', text, re.I | re.S)]

    def field(name):
        indexes = [i for i, v in enumerate(cells) if v == name + ':']
        if len(indexes) != 1 or indexes[0] + 1 >= len(cells):
            raise ValueError('Missing/ambiguous native field: ' + name)
        return cells[indexes[0] + 1]

    expert = tester['expert'].replace('\\', '/').split('/')[-1]
    expert = re.sub(r'\.ex5$', '', expert, flags=re.I)
    period = {'D1': 'Daily', 'W1': 'Weekly', 'MN1': 'Monthly'}.get(tester['period'], tester['period'])
    expected = {'Expert': expert, 'Symbol': tester['symbol'],
                'Period': f"{period} ({tester['fromdate']} - {tester['todate']})",
                'Currency': tester.get('currency', 'USD')}
    if any(field(key) != value for key, value in expected.items()):
        raise ValueError('Native report belongs to different test settings')
    if normalized(field('Initial Deposit').replace(' ', '')) != normalized(tester['deposit']):
        raise ValueError('Native deposit differs')
    if field('Leverage') != '1:' + tester['leverage']:
        raise ValueError('Native leverage differs')
    # Require the complete native metrics surface, including signed gross loss;
    # do not substitute the MCP JSON summary or synthesize native-looking HTML.
    for key in ('History Quality', 'Bars', 'Ticks', 'Total Trades', 'Total Net Profit',
                'Gross Profit', 'Gross Loss', 'Profit Factor', 'Equity Drawdown Maximal'):
        field(key)
    inputs = {}
    for value in cells:
        match = re.fullmatch(r'([A-Za-z_]\w*)=(.*)', value)
        if match:
            if match[1] in inputs:
                raise ValueError('Duplicate native input')
            inputs[match[1]] = match[2]
    if setfile:
        for line in read_text(setfile).splitlines():
            if not line.strip() or line.lstrip().startswith(';'):
                continue
            name, separator, value = line.partition('=')
            if not separator:
                raise ValueError('Malformed setfile')
            value = value.split('||', 1)[0].strip()
            # Unknown/inert legacy set keys also refuse rescue; the unchanged
            # CLI path remains available. Never silently assume they applied.
            if name.strip() not in inputs or normalized(inputs[name.strip()]) != normalized(value):
                raise ValueError('Native inputs differ from exact setfile: ' + name.strip())
    return {'settings': expected, 'native_inputs_checked': len(inputs), 'sha256': sha(path)}


def validate_policy(policy: dict, terminal: str, terminal_sha: str, now: datetime) -> None:
    if (policy.get('schema') != 'qm.native-report-rescue/v1' or policy.get('enabled') is not True
            or terminal not in policy.get('terminals', [])
            or terminal_sha.lower() != policy.get('terminal_sha256', '').lower()
            or now >= datetime.fromisoformat(policy['expires_at_utc'])):
        raise ValueError('Terminal/build/time not admitted by report-rescue canary')


def rescue(request: dict) -> dict:
    started = time.monotonic()
    root = Path(request['terminal_root']).resolve()
    if (not re.fullmatch('T(?:[1-9]|10)', request['terminal'])
            or root != (MT5 / request['terminal']).resolve() or root.parent != MT5.resolve()):
        raise ValueError('Not an exact factory root; live and lab roots are excluded')
    terminal = psutil.Process(int(request['terminal_pid']))
    owner = psutil.Process(int(request['owner_pid']))
    agent = psutil.Process(int(request['observation']['agent_pid']))
    expected_terminal_time = datetime.fromisoformat(request['terminal_created_utc']).timestamp()
    expected_owner_time = datetime.fromisoformat(request['owner_created_utc']).timestamp()
    expected_agent_time = datetime.fromisoformat(request['observation']['agent_started_at_utc']).timestamp()
    ini = Path(request['ini_path']).resolve()
    destination = Path(request['report_path']).resolve()
    if not ini.is_relative_to(REPORTS.resolve()) or destination.parent != root:
        raise ValueError('INI/report is outside the canonical factory evidence layout')
    if destination.exists() or destination.suffix.lower() != '.htm':
        raise ValueError('Existing report keeps its normal finalization contract')
    if psutil.Process().ppid() != owner.pid:
        raise ValueError('Rescue must be a direct child of its run_smoke owner')
    policy = json.loads(POLICY.read_text(encoding='utf-8'))
    validate_policy(policy, root.name, sha(root / 'terminal64.exe'), datetime.now(timezone.utc))

    def identity_guard():
        for proc, path, created in ((terminal, root / 'terminal64.exe', expected_terminal_time),
                                    (agent, root / 'metatester64.exe', expected_agent_time)):
            if Path(proc.exe()).resolve() != path or abs(proc.create_time() - created) > .01:
                raise RuntimeError('Native process identity changed')
        if (abs(owner.create_time() - expected_owner_time) > .01
                or not any(p.pid == owner.pid for p in terminal.parents())):
            raise RuntimeError('Terminal no longer belongs to the run_smoke owner')
        args = owner.cmdline()
        if not any(Path(a).name.lower() == 'run_smoke.ps1' for a in args):
            raise RuntimeError('Owner is not a run_smoke invocation')

    identity_guard()
    with sqlite3.connect(DB.as_uri() + '?mode=ro', uri=True, timeout=2) as con:
        row = con.execute('SELECT id FROM work_items WHERE id=? AND status=? AND claimed_by=?',
                          (request['work_item_id'], 'active', root.name)).fetchall()
    if len(row) != 1 or request['work_item_id'] != os.environ.get('QM_WORK_ITEM_ID'):
        raise ValueError('Active worker binding changed')
    config = tester_config(ini)
    ini_hash = sha(ini)
    config_report = (root / config['report']).resolve()
    expert = (root / 'MQL5/Experts' / (re.sub(r'\.ex5$', '', config['expert'], flags=re.I) + '.ex5')).resolve()
    if config_report != destination or not expert.is_relative_to(root / 'MQL5/Experts'):
        raise ValueError('INI/executable/report path binding differs')
    expert_hash = sha(expert)
    if expert_hash.lower() != request['expected_ex5_sha256'].lower():
        raise ValueError('EX5 differs from the runner-authenticated build')
    setfile = None
    if config.get('expertparameters'):
        setfile = (root / 'MQL5/Profiles/Tester' / config['expertparameters']).resolve()
        if setfile.parent != root / 'MQL5/Profiles/Tester':
            raise ValueError('Setfile outside canonical tester input directory')
    set_hash = sha(setfile) if setfile else None
    observation = request['observation']
    journal = Path(observation['journal_path']).resolve()
    if not journal.is_relative_to(root / 'Tester'):
        raise ValueError('Foreign journal')
    if journal.stat().st_size != observation['journal_bytes']:
        raise ValueError('Engine journal progressed; do not intervene')
    finished = finished_marker_time(tail(journal, 65536), expert=config['expert'],
        symbol=config['symbol'], period=config['period'], day=journal.stem,
        started_epoch=expected_terminal_time, now_epoch=time.time())
    if finished is None or time.time() - finished < 60 or request['idle_seconds'] < 60:
        raise ValueError('No fresh completed engine with sufficient idle grace')
    # An existing file, including an empty shell, is never replaced. Export to
    # a unique sibling, validate, then atomically link it into the expected
    # location. All native chart assets remain alongside both HTML artifacts.
    rescued = root / ('QM_rescue_' + uuid.uuid4().hex + '.html')
    result = export(terminal.pid, rescued, timeout=20, identity_guard=identity_guard)
    identity_guard()
    result['validation'] = validate_report(rescued, config, setfile)
    if sha(ini) != ini_hash or sha(expert) != expert_hash or (setfile and sha(setfile) != set_hash):
        raise RuntimeError('Test inputs changed during export')
    if destination.exists():
        raise RuntimeError('Native CLI report appeared; keep both and do not overwrite')
    # Windows os.link is atomic, never replaces a target and keeps the original
    # native report as evidence. No partial file becomes visible to the runner.
    os.link(rescued, destination)
    result.update({'schema': 'qm.native-report-rescue-result/v1', 'published_report': str(destination),
                   'ini_sha256': ini_hash, 'ex5_sha256': expert_hash, 'setfile_sha256': set_hash,
                   'total_seconds': time.monotonic() - started,
                   'disposition': 'native artifact only; all normal run_smoke checks still required'})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--request', type=Path, required=True)
    args = parser.parse_args()
    try:
        result = rescue(json.loads(args.request.read_text(encoding='utf-8-sig')))
    except Exception as error:
        print(json.dumps({'rescued': False, 'error_type': type(error).__name__, 'reason': str(error)}), flush=True)
        raise SystemExit(2)
    print(json.dumps({'rescued': True, **result}), flush=True)


if __name__ == '__main__':
    main()
