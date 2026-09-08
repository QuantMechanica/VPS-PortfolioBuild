"""Read-only exact-run parity analysis; writes only new diagnostic evidence."""
from datetime import datetime, timezone
import hashlib
import html
import json
from pathlib import Path
import re

from tools.strategy_farm.backtest_tail_watch import tail
from tools.strategy_farm.mt5_latency_lab import ROOT, sha


def native_run(path: Path, start_clock: str) -> dict:
    text = tail(path, 2 * 1024 * 1024)
    identity = 'XTIUSD.DWX,Daily: testing of Experts\\QM\\QM5_41305_brent-nov-fade-opt.ex5 from 2025.01.01 00:00 to 2025.12.31 00:00 started with inputs:'
    matching = [match for match in re.finditer(re.escape(identity), text)
                if f'\t{start_clock}\t' in text[text.rfind('\n', 0, match.start()) + 1:match.start()]]
    index = matching[-1].start() if matching else -1
    if index < 0:
        raise ValueError('Exact native run start is not in bounded journal tail')
    end = text.find('test Experts\\QM\\QM5_41305_brent-nov-fade-opt.ex5 on XTIUSD.DWX,Daily thread finished', index)
    if end < 0:
        raise ValueError('Exact native completion is absent')
    block = text[index:end]
    trades = [line.split('\tTrade\t', 1)[1] for line in block.splitlines() if '\tTrade\t' in line]
    if not trades:
        raise ValueError('No native trade stream')
    ticks = re.search(r'(\d+) ticks, (\d+) bars generated', block)
    balance = re.search(r'final balance ([\d.]+) USD', block)
    return {'path': str(path), 'journal_sha256': sha(path), 'trade_records': len(trades),
            'trade_stream_sha256': hashlib.sha256('\n'.join(trades).encode()).hexdigest(),
            'ticks': int(ticks[1]), 'bars': int(ticks[2]), 'final_balance': balance[1]}


def report_tables(path: Path) -> dict:
    raw = path.read_bytes()
    text = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')
    # All text cells, in order. No selective profit-only comparison. Image
    # filenames are intentionally absent; no economic/report field is removed.
    cells = [' '.join(html.unescape(re.sub('<[^>]+>', '', cell)).split())
             for cell in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>', text, re.I | re.S)]
    if len(cells) < 100:
        raise ValueError('Report is not complete enough for parity comparison')
    return {'path': str(path), 'file_sha256': sha(path), 'cell_count': len(cells),
            'table_cells_sha256': hashlib.sha256(json.dumps(cells, ensure_ascii=False).encode()).hexdigest()}


if __name__ == '__main__':
    before = native_run(Path('D:/QM/mt5/T9/Tester/Agent-127.0.0.1-3000/logs/20260908.log'), '16:06:30.373')
    after = native_run(Path('D:/QM/mt5/T9/Tester/Agent-127.0.0.1-3002/logs/20260908.log'), '16:53:27.568')
    reports = [report_tables(ROOT / name) for name in ('baseline1.htm', 'baseline2.htm', 'experiments/subdir1/subdir1.htm')]
    result = {'schema': 'qm.latency-parity/v1', 'at_utc': datetime.now(timezone.utc).isoformat(),
              'factory_stalled_original': before, 'factory_recovered_native_run': after,
              'factory_exact_trade_stream_equal': before['trade_stream_sha256'] == after['trade_stream_sha256'],
              'factory_ticks_bars_balance_equal': all(before[k] == after[k] for k in ('ticks', 'bars', 'final_balance')),
              'lab_reports': reports,
              'lab_all_table_cells_equal': len({r['table_cells_sha256'] for r in reports}) == 1,
              'lab_subdir1_note': 'Initial observer ended on updater handoff. Native report arrived later at 16:44:03 local; original result.json retained, not a valid timing comparison.',
              'quality_limit': 'Native input/output parity evidence, not a strategy robustness gate or live approval.'}
    output = Path('D:/QM/reports/maintenance/backtest_latency_20260908/parity_20260908.json')
    with output.open('x', encoding='utf-8') as handle:
        json.dump(result, handle, indent=2)
    print(json.dumps(result, indent=2))
