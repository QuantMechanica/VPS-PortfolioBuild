"""Read-only, bounded 15s MT5 engine/report/factory latency observer.

Only writes its own append-only observation stream. Never kills, releases,
claims, places orders, edits terminal settings or changes pipeline evidence.
"""
from __future__ import annotations

import argparse
import json
import re
import sqlite3
import time
from datetime import datetime, timezone
from pathlib import Path

import psutil

DB = Path('D:/QM/strategy_farm/state/farm_state.sqlite')
MT5 = Path('D:/QM/mt5')


def tail(path: Path, maximum: int = 16000) -> str:
    with path.open('rb') as handle:
        prefix = handle.read(4)
        start = max(0, path.stat().st_size - maximum)
        handle.seek(start - start % 2)
        raw = handle.read(maximum + 2)
    encoding = 'utf-16-le' if b'\x00' in prefix or prefix.startswith(b'\xff\xfe') else 'utf-8-sig'
    return raw.decode(encoding, errors='replace')


def finished_marker_time(text: str, *, expert: str, symbol: str, period: str,
                         day: str, started_epoch: float, now_epoch: float) -> float | None:
    """Never credit an old same-EA completion after a retry starts appending."""
    lines = [line for line in text.splitlines() if line.strip()]
    display = {'D1': 'Daily', 'W1': 'Weekly', 'MN1': 'Monthly'}.get(period.upper(), period)
    expert = expert[:-4] if expert.lower().endswith('.ex5') else expert
    exact = f'test Experts\\{expert}.ex5 on {symbol},{display} thread finished'
    if not expert or not lines or not lines[-1].lower().endswith(exact.lower()):
        return None
    fields = lines[-1].split('\t')
    if len(fields) < 5 or 'Test passed in ' not in text:
        return None
    try:
        epoch = datetime.strptime(day + ' ' + fields[2], '%Y%m%d %H:%M:%S.%f').timestamp()
    except ValueError:
        return None
    return epoch if started_epoch <= epoch <= now_epoch + 2 else None


def snapshot() -> dict:
    now = datetime.now(timezone.utc)
    with sqlite3.connect(DB.resolve().as_uri() + '?mode=ro', uri=True, timeout=5) as con:
        con.row_factory = sqlite3.Row
        active = {str(row['claimed_by']): dict(row) for row in con.execute(
            "SELECT id,ea_id,phase,claimed_by,payload_json FROM work_items WHERE status='active'")}
    processes: dict[str, list[dict]] = {}
    for process in psutil.process_iter(['pid', 'name', 'exe', 'create_time']):
        info = process.info
        match = re.fullmatch(r'D:\\QM\\mt5\\(T(?:[1-9]|1[012]))\\(terminal64|metatester64)\.exe',
                             info.get('exe') or '', re.I)
        if not match:
            continue
        try:
            counters = process.io_counters()
            processes.setdefault(match[1].upper(), []).append({
                'pid': process.pid, 'name': info['name'], 'created_at_epoch': info['create_time'],
                'cpu_seconds': sum(process.cpu_times()[:2]),
                'read_bytes': counters.read_bytes, 'write_bytes': counters.write_bytes,
                'memory_bytes': process.memory_info().rss,
            })
        except psutil.Error:
            continue
    rows = []
    for number in range(1, 13):
        terminal = f'T{number}'
        root = MT5 / terminal
        item = active.get(terminal)
        row = {'terminal': terminal, 'work_item_id': item['id'] if item else None,
               'phase': item['phase'] if item else None, 'processes': processes.get(terminal, [])}
        if item:
            payload = json.loads(item['payload_json'])
            row['ea_id'] = item['ea_id']
            report_root = Path(payload.get('report_root') or 'D:/QM/reports/work_items')
            # Restrict traversal to this exact work item, never the full archive.
            if report_root.name == item['id'] and report_root.is_dir():
                inis = list(report_root.rglob('tester.ini'))
                if inis:
                    ini = max(inis, key=lambda p: p.stat().st_mtime)
                    params = dict(line.split('=', 1) for line in tail(ini, 100000).splitlines()
                                  if '=' in line)
                    row['ini_path'] = str(ini)
                    row['ini_created_epoch'] = ini.stat().st_mtime
                    row['expert'] = params.get('Expert')
                    row['symbol'] = params.get('Symbol')
                    row['period'] = params.get('Period')
                    row['model'] = params.get('Model')
                    if params.get('Report'):
                        report = Path(params['Report'])
                        if not report.is_absolute():
                            report = root / report
                        row['report_path'] = str(report)
                        row['report_exists'] = report.is_file()
                        if report.is_file():
                            row['report_size_bytes'] = report.stat().st_size
                            row['report_mtime_epoch'] = report.stat().st_mtime
        agent_logs = list(root.glob(f'Tester/Agent-*/logs/{now.astimezone():%Y%m%d}.log'))
        if agent_logs:
            latest = max(agent_logs, key=lambda p: p.stat().st_mtime)
            latest_text = tail(latest)
            relevant = [line for line in latest_text.splitlines()
                        if any(key in line for key in ('Test passed in', 'thread finished',
                                                       'MetaTester 5 stopped', 'final balance'))]
            row['agent_log_path'] = str(latest)
            row['agent_log_mtime_epoch'] = latest.stat().st_mtime
            row['engine_markers'] = relevant[-4:]
            # Observation only: never sufficient on its own to accept a run.
            completed = finished_marker_time(latest_text, expert=row.get('expert') or '',
                symbol=row.get('symbol') or '', period=row.get('period') or '',
                day=latest.stem, started_epoch=row.get('ini_created_epoch', float('inf')),
                now_epoch=now.timestamp())
            writers_alive = {p['name'].lower() for p in row['processes']}
            row['matching_engine_finished'] = bool(completed is not None and
                {'terminal64.exe', 'metatester64.exe'} <= writers_alive)
            row['engine_finished_epoch'] = completed
            if row['matching_engine_finished'] and not row.get('report_exists'):
                row['finished_without_report_seconds'] = round(max(
                    0, now.timestamp() - completed), 1)
        rows.append(row)
    return {'schema': 'qm.backtest-tail-observation/v1', 'at_utc': now.isoformat(), 'terminals': rows}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--minutes', type=float, default=90)
    parser.add_argument('--interval', type=float, default=15)
    args = parser.parse_args()
    if not 0 < args.minutes <= 720 or not 5 <= args.interval <= 60:
        parser.error('bounded duration <=720 minutes and interval 5..60 seconds required')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + args.minutes * 60
    with args.output.open('x', encoding='utf-8') as output:
        while True:
            try:
                result = snapshot()
            except (OSError, ValueError, sqlite3.Error) as exc:
                result = {'at_utc': datetime.now(timezone.utc).isoformat(), 'observer_error': str(exc)}
            output.write(json.dumps(result, sort_keys=True) + '\n')
            output.flush()
            print(json.dumps({'at': result['at_utc'], 'stalled': {
                row['terminal']: row['finished_without_report_seconds']
                for row in result.get('terminals', [])
                if row.get('finished_without_report_seconds', 0) >= 60},
                'error': result.get('observer_error')}), flush=True)
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            time.sleep(min(args.interval, remaining))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
