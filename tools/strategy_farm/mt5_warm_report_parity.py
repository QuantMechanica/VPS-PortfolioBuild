"""Read-only equivalence check of native HTML and MCP's native XLSX export.

Despite file_format='xml', build 6182 returns XLSX bytes. Detect the actual
format; never rename synthetic data to masquerade as a native MT5 report.
Not a gate adapter. Exact order/deal fields, including blanks, are compared.
"""
from __future__ import annotations

import argparse
from decimal import Decimal
import hashlib
import html
import json
from pathlib import Path
import re
import statistics
import xml.etree.ElementTree as ET
import zipfile

from tools.strategy_farm.mt5_warm_lab import ROOT, SESSION
from tools.strategy_farm.mt5_latency_lab import sha

NS = {'m': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}


def canonical(value: object) -> str:
    text = ' '.join(str(value if value is not None else '').split())
    compact = text.replace(' ', '')
    if re.fullmatch(r'-?\d+(?:\.\d+)?', compact):
        return format(Decimal(compact).normalize(), 'f')
    return text


def html_rows(path: Path) -> list[list[str]]:
    raw = path.read_bytes()
    text = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')
    if '</html>' not in text.lower():
        raise ValueError('Incomplete native HTML')
    return [[canonical(html.unescape(re.sub('<[^>]+>', '', cell)))
             for cell in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>', row, re.I | re.S)]
            for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>', text, re.I | re.S)]


def xlsx_rows(path: Path) -> list[list[str]]:
    with zipfile.ZipFile(path) as archive:
        if sum(info.file_size for info in archive.infolist()) > 64 * 1024**2:
            raise ValueError('Fixture workbook exceeds bounded parser size')
        strings = [''.join(node.itertext()) for node in ET.fromstring(archive.read('xl/sharedStrings.xml'))]
        sheet = ET.fromstring(archive.read('xl/worksheets/sheet1.xml'))
    rows = []
    for row in sheet.findall('.//m:row', NS):
        cells = [''] * 14
        for cell in row.findall('m:c', NS):
            letters = re.match('[A-Z]+', cell.attrib['r'])[0]
            column = 0
            for letter in letters:
                column = column * 26 + ord(letter) - 64
            if column > 14:
                raise ValueError('Unexpected fixture workbook column layout')
            value = cell.find('m:v', NS)
            if value is not None:
                value = strings[int(value.text)] if cell.get('t') == 's' else value.text
                cells[column - 1] = canonical(value)
        rows.append(cells)
    return rows


def ledger(rows: list[list[str]], section: str, xlsx: bool) -> list[list[str]]:
    starts = [i for i, row in enumerate(rows) if row and row[0] == section]
    if len(starts) != 1:
        raise ValueError(f'Exactly one {section} section required')
    start = starts[0]
    columns = ([0, 1, 2, 3, 4, 6, 7, 8, 9, 11, 12] if section == 'Orders'
               else list(range(13))) if xlsx else None
    selected = []
    for row in rows[start + 1:]:
        if row and row[0] == 'Deals':
            break
        if row and re.fullmatch(r'\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2}', row[0]):
            selected.append([row[i] for i in columns] if columns else row)
    if not selected:
        raise ValueError(f'No native {section} records')
    width = 11 if section == 'Orders' else 13
    if any(len(row) != width for row in selected):
        raise ValueError('Missing or extra native ledger fields')
    return selected


def digest(rows: object) -> str:
    return hashlib.sha256(json.dumps(rows, ensure_ascii=False).encode()).hexdigest()


def metadata(rows: list[list[str]]) -> dict:
    flat = [cell for row in rows for cell in row if cell]
    fields = ('Expert:', 'Symbol:', 'Period:', 'Currency:', 'Initial Deposit:', 'Leverage:',
              'History Quality:', 'Bars:', 'Ticks:', 'Total Net Profit:', 'Gross Profit:',
              'Gross Loss:', 'Total Trades:', 'Total Deals:')
    result = {name: flat[flat.index(name) + 1] for name in fields}
    result['all_inputs'] = [cell for cell in flat if re.fullmatch(r'[A-Za-z]\w*=.*', cell)]
    return result


def journal_run(text: str) -> dict:
    # Require a new actual native execution, not just cached aggregate statistics.
    if text.count('thread finished') != 1 or text.count('started with inputs:') != 1:
        raise ValueError('Journal delta must contain exactly one fresh execution')
    matches = re.findall(r'(\d+) ticks, (\d+) bars generated\..*?Test passed in (\d+:\d{2}:\d{2}\.\d{3})', text)
    if len(matches) != 1:
        raise ValueError('Exactly one successful native engine record required')
    ticks, bars, elapsed = matches[0]
    hh, mm, ss = elapsed.split(':')
    records = [line.split('\tTrade\t', 1)[1] for line in text.splitlines() if '\tTrade\t' in line]
    return {'ticks': int(ticks), 'bars': int(bars), 'engine_seconds': int(hh)*3600 + int(mm)*60 + float(ss),
            'native_trade_messages': len(records), 'trade_stream_sha256': digest(records)}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-name', default='parity.json')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9_]+\.json', args.output_name):
        raise ValueError('Output must be a new session-local JSON evidence file')
    baseline = html_rows(ROOT / 'warmcold.htm')
    orders, deals = ledger(baseline, 'Orders', False), ledger(baseline, 'Deals', False)
    reference = metadata(baseline)
    results = []
    for runroot in sorted(SESSION.iterdir()):
        if not runroot.is_dir() or not (runroot / 'summary.json').exists():
            continue
        summary = json.loads((runroot / 'summary.json').read_text())
        case_b = summary.get('fixture_from_date') == '2026.09.02'
        comparison = html_rows(ROOT / 'switchbcold.htm') if case_b else baseline
        expected_orders = ledger(comparison, 'Orders', False)
        expected_deals = ledger(comparison, 'Deals', False)
        expected_metadata = metadata(comparison)
        workbook = ROOT / 'MQL5/Files/QM_latency_lab' / f'{runroot.name}.xml'
        rows = xlsx_rows(workbook)
        native = [path for path in runroot.glob('Agent-*_journal_delta.bin') if path.stat().st_size]
        if len(native) != 1:
            raise ValueError('Exactly one fresh native agent journal required')
        journal = journal_run(native[0].read_bytes().decode('utf-16-le'))
        result = {'name': runroot.name, **summary, 'actual_report_format': 'native_xlsx',
                  'workbook_sha256': sha(workbook), 'orders': len(ledger(rows, 'Orders', True)),
                  'deals_including_deposit': len(ledger(rows, 'Deals', True)),
                  'reference_html': 'switchbcold.htm' if case_b else 'warmcold.htm',
                  'every_order_field_equal': ledger(rows, 'Orders', True) == expected_orders,
                  'every_deal_field_equal': ledger(rows, 'Deals', True) == expected_deals,
                  'fixture_metadata_equal': metadata(rows) == expected_metadata, 'native': journal}
        results.append(result)
    if not results:
        raise ValueError('No completed benchmark evidence')
    warm = [r['evidence_collected_seconds'] for r in results if not r.get('hidden_requested')
            and r.get('fixture_from_date', '2026.09.01') == '2026.09.01']
    hidden = [r['evidence_collected_seconds'] for r in results if r.get('hidden_requested')]
    result = {'schema': 'qm.mt5-warm-parity/v1', 'baseline_html_sha256': sha(ROOT / 'warmcold.htm'),
              'reference_metadata': reference, 'reference_order_sha256': digest(orders),
              'reference_deal_sha256': digest(deals), 'runs': results,
              'all_ledger_fields_and_fixture_metadata_equal': all(r['every_order_field_equal']
                  and r['every_deal_field_equal'] and r['fixture_metadata_equal'] for r in results),
              'warm_evidence_median_seconds': statistics.median(warm) if warm else None,
              'hidden_evidence_median_seconds': statistics.median(hidden) if hidden else None,
              'scope': 'Short native EURUSD fixture only, not a production gate or full metric-parser certification',
              'excluded': 'pilot1: initial observer used wrong stopped-status key; no accepted timing summary'}
    if (ROOT / 'coldreturn.htm').exists():
        later_cold = html_rows(ROOT / 'coldreturn.htm')
        result['later_cold_a_all_html_cells_equal'] = later_cold == baseline
        result['later_cold_a_sha256'] = sha(ROOT / 'coldreturn.htm')
    output = SESSION / args.output_name
    with output.open('x', encoding='utf-8') as stream:
        json.dump(result, stream, indent=2)
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
