"""Offline checks; never start terminals, contact MCP or read account settings."""
from pathlib import Path
from types import SimpleNamespace
import zipfile

import pytest

from tools.strategy_farm import mt5_warm_lab as lab
from tools.strategy_farm import mt5_warm_report_parity as parity


@pytest.mark.parametrize('tool', ['trade_send_market_order', 'tester_stop', 'tester_run_optimization',
                                  'file_write', 'terminal_set_autotrading', 'chart_set_symbol_period'])
def test_deny_non_fixture_tools(tool):
    with pytest.raises(ValueError):
        lab.validate_call('tools/call', {'name': tool, 'arguments': {}})


def test_no_arbitrary_rpc_method():
    with pytest.raises(ValueError):
        lab.validate_call('resources/read', {})


def test_no_generic_run_input_or_wait():
    for args in ({'config_path': 'C:/elsewhere/test.ini', 'wait': False},
                 {'config_path': 'test.ini', 'wait': True},
                 {'config_path': 'test.ini', 'wait': False, 'inputs_path': 'other.set'}):
        with pytest.raises(ValueError):
            lab.validate_call('tools/call', {'name': 'tester_run_backtest', 'arguments': args})


def fixture_config(root: Path) -> Path:
    ini = root / 'MQL5/Profiles/Tester/QM_lab_warm_unit.ini'
    ini.parent.mkdir(parents=True)
    ini.write_text('[Tester]\nExpert=Examples\\Moving Average\\Moving Average\n'
        'Symbol=EURUSD\nPeriod=M5\nModel=4\nExecutionMode=0\nOptimization=0\n'
        'FromDate=2026.09.01\nToDate=2026.09.05\nDeposit=100000\nCurrency=USD\n'
        'Leverage=100\nUseLocal=1\nUseRemote=0\nUseCloud=0\nVisual=0\n'
        'Replace=1\nReplaceReport=1\nShutdownTerminal=0\nReport=QM_lab_warm_unit.htm\n', encoding='utf-16')
    return ini


@pytest.mark.parametrize('old,new', [('Model=4', 'Model=1'), ('UseCloud=0', 'UseCloud=1'),
    ('UseRemote=0', 'UseRemote=1'), ('Optimization=0', 'Optimization=1'),
    ('Symbol=EURUSD', 'Symbol=XAUUSD'), ('ShutdownTerminal=0', 'ShutdownTerminal=1'),
    ('FromDate=2026.09.01', 'FromDate=2025.01.01'), ('Report=QM_lab_warm_unit.htm', 'Report=../victim.htm')])
def test_refuse_quality_or_scope_change(tmp_path, monkeypatch, old, new):
    monkeypatch.setattr(lab, 'ROOT', tmp_path)
    ini = fixture_config(tmp_path)
    ini.write_text(ini.read_text(encoding='utf-16').replace(old, new), encoding='utf-16')
    with pytest.raises(ValueError):
        lab.validate_call('tools/call', {'name': 'tester_run_backtest',
                          'arguments': {'config_path': str(ini), 'wait': False}})


def test_fixed_fixture_admitted_only_with_pinned_ex5(tmp_path, monkeypatch):
    monkeypatch.setattr(lab, 'ROOT', tmp_path)
    ini = fixture_config(tmp_path)
    args = {'name': 'tester_run_backtest', 'arguments': {'config_path': str(ini), 'wait': False}}
    monkeypatch.setattr(lab, 'sha', lambda _: 'different')
    with pytest.raises(ValueError, match='EA changed'):
        lab.validate_call('tools/call', args)
    monkeypatch.setattr(lab, 'sha', lambda _: 'e5c16f9b6bd88c768ece376e5f87d9fd30e3304154482c85cc7cb09e5511081f')
    lab.validate_call('tools/call', args)


@pytest.mark.parametrize('ip,pid', [('0.0.0.0', 1), ('127.0.0.1', 2)])
def test_wrong_listener_or_non_loopback_rejected(monkeypatch, ip, pid):
    monkeypatch.setattr(lab, 'fenced_process', lambda _: SimpleNamespace(pid=1))
    monkeypatch.setattr(lab.psutil, 'net_connections', lambda **_: [SimpleNamespace(
        status=lab.psutil.CONN_LISTEN, laddr=SimpleNamespace(ip=ip, port=lab.PORT), pid=pid)])
    with pytest.raises(RuntimeError, match='exclusively owned'):
        lab.fence_endpoint({})


def test_existing_or_external_export_is_never_overwritten(tmp_path, monkeypatch):
    monkeypatch.setattr(lab, 'ROOT', tmp_path)
    path = tmp_path / 'MQL5/Files/QM_latency_lab/test.xml'
    path.parent.mkdir(parents=True)
    args = {'name': 'tester_get_report', 'arguments': {'run_id': '1', 'path': str(path), 'file_format': 'xml'}}
    lab.validate_call('tools/call', args)
    path.write_bytes(b'original')
    with pytest.raises(ValueError):
        lab.validate_call('tools/call', args)
    assert path.read_bytes() == b'original'


def test_numeric_normalization_preserves_value_and_text():
    assert parity.canonical('99 652.1600') == '99652.16'
    assert parity.canonical('-0.5800') == '-0.58'
    assert parity.canonical('2026.09.01 01:15:01') == '2026.09.01 01:15:01'
    assert parity.canonical('0.52 / 0.52') == '0.52 / 0.52'
    assert parity.canonical(None) == ''


def test_deal_columns_preserve_empty_fields():
    row = ['2026.09.01 00:00:00', '1', '', 'balance', '', '', '', '', '0', '0', '100000', '100000', '']
    assert parity.ledger([['Deals'], row], 'Deals', False) == [row]
    changed = row.copy()
    changed[8] = '-1'
    assert parity.ledger([['Deals'], changed], 'Deals', False) != [row]
    with pytest.raises(ValueError, match='ledger fields'):
        parity.ledger([['Deals'], row[:-1]], 'Deals', False)


def test_report_without_complete_html_refused(tmp_path):
    path = tmp_path / 'report.htm'
    path.write_text('<html><tr><td>deals</td></tr>', encoding='utf-16')
    with pytest.raises(ValueError, match='Incomplete'):
        parity.html_rows(path)


def test_xlsx_content_detected_with_xml_extension(tmp_path):
    path = tmp_path / 'report.xml'
    with zipfile.ZipFile(path, 'w') as z:
        z.writestr('xl/sharedStrings.xml', ('<?xml version="1.0" encoding="utf-16"?>'
            '<sst xmlns="'+parity.NS['m']+'"><si><t>Deals</t></si></sst>').encode('utf-16'))
        z.writestr('xl/worksheets/sheet1.xml', ('<?xml version="1.0" encoding="utf-16"?>'
            '<worksheet xmlns="'+parity.NS['m']+'"><sheetData><row r="1">'
            '<c r="A1" t="s"><v>0</v></c><c r="C1"><v>-0.5800</v></c>'
            '</row></sheetData></worksheet>').encode('utf-16'))
    row = parity.xlsx_rows(path)[0]
    assert row[:4] == ['Deals', '', '-0.58', '']


def test_native_execution_required_not_cached_summary():
    text = ('started with inputs:\nCS\t0\t22:00:00.100\tTrade\tx\n'
        '516822 ticks, 1151 bars generated. Test passed in 0:00:00.211.\nthread finished')
    result = parity.journal_run(text)
    assert result['engine_seconds'] == .211
    assert result['native_trade_messages'] == 1
    with pytest.raises(ValueError):
        parity.journal_run(text + text)
    with pytest.raises(ValueError):
        parity.journal_run(text.replace('started with inputs:', 'cached summary'))
