"""Read-only comparison contracts with synthetic local evidence."""
from datetime import datetime
import json

import pytest

from tools.strategy_farm import mt5_qm_warm_acceptance as acceptance


def write_logger(path, **fields):
    record = {'ea_id': 10012, 'symbol': 'EURUSD.DWX', 'tf': 'M30',
              'ts_utc': '2025-01-06T00:00:00.123Z', 'ts_broker': '2025-01-06T00:00:00',
              'payload': {'price': 1.02345, 'volume': 1.23}, **fields}
    path.write_text(json.dumps(record) + '\n', encoding='utf-8')


def test_only_wallclock_milliseconds_ignored_and_raw_preserved(tmp_path):
    left, right = tmp_path / 'left.jsonl', tmp_path / 'right.jsonl'
    write_logger(left)
    write_logger(right, ts_utc='2025-01-06T00:00:00.987Z')
    before = left.read_bytes(), right.read_bytes()
    assert acceptance.logger_rows(left) == acceptance.logger_rows(right)
    assert (left.read_bytes(), right.read_bytes()) == before


@pytest.mark.parametrize('changes', [
    {'ts_utc': '2025-01-06T00:00:01.123Z'}, {'ts_broker': '2025-01-06T00:00:01'},
    {'payload': {'price': 1.02346, 'volume': 1.23}}, {'payload': {'price': 1.02345, 'volume': 1.24}},
    {'extra': 1}, {'sv': 1}, {'event': 'different'},
])
def test_no_trading_timestamp_payload_or_schema_difference_ignored(tmp_path, changes):
    left, right = tmp_path / 'left.jsonl', tmp_path / 'right.jsonl'
    write_logger(left); write_logger(right, **changes)
    assert acceptance.logger_rows(left) != acceptance.logger_rows(right)


@pytest.mark.parametrize('changes', [{'ts_utc': 'malformed'}, {'ea_id': 10013}, {'tf': 'H1'}, {'symbol': 'EURUSD'}])
def test_logger_identity_and_timestamp_fail_closed(tmp_path, changes):
    path = tmp_path / 'logger.jsonl'; write_logger(path, **changes)
    with pytest.raises(ValueError):
        acceptance.logger_rows(path)


def test_legacy_window_never_credits_old_same_ea_execution():
    text = ('CS\t0\t23:00:00.100\tTester\told\n'
            'CS\t0\t23:01:00.200\tTester\tnew\n'
            'CS\t0\t23:02:00.300\tTester\tfuture\n')
    start = datetime(2026, 9, 8, 23, 1).timestamp()
    assert acceptance.window_lines(text, '20260908', start, start + 1) == 'CS\t0\t23:01:00.200\tTester\tnew'


def test_execution_comparison_ignores_only_engine_runtime():
    reference = dict(ticks=100, bars=10, native_trade_messages=2, trade_stream_sha256='abc', engine_seconds=1)
    assert acceptance.assert_same_execution(reference, dict(reference, engine_seconds=5))
    for key, changed in [('ticks', 101), ('bars', 11), ('native_trade_messages', 3), ('trade_stream_sha256', 'def')]:
        assert not acceptance.assert_same_execution(reference, dict(reference, **{key: changed}))


@pytest.mark.parametrize('start,finish', [(datetime(2026, 9, 9, 0, 0), '00:00:10.000'),
                                         (datetime(2026, 9, 8, 23, 59, 55), '00:00:05.000')])
def test_cold_timeline_separates_startup_engine_and_report_including_midnight(start, finish):
    text = 'CS\t0\t' + finish + '\tTester\tthread finished'
    result = acceptance.cold_timeline(text, start.timestamp(), 12, 4)
    assert result == {'before_engine_seconds': 6, 'engine_seconds': 4, 'engine_finish_to_first_report_byte_seconds': 2}


def test_impossible_finish_timestamp_rejected():
    with pytest.raises(ValueError, match='inconsistent'):
        acceptance.cold_timeline('CS\t0\t00:00:30.000\tTester\tthread finished',
                                 datetime(2026, 9, 9).timestamp(), 12, 4)
