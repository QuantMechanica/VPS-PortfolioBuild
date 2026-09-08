from pathlib import Path

from datetime import datetime

from tools.strategy_farm.backtest_tail_watch import tail, finished_marker_time
from tools.strategy_farm.mt5_latency_lab import ROOT, is_lab_updater, sha


def test_bounded_unicode_tail_preserves_native_marker(tmp_path):
    file = tmp_path / 'journal.log'
    file.write_text(('old\n' * 50000) + 'test exact thread finished\n', encoding='utf-16')
    original = sha(file)
    text = tail(file, 1024)
    assert 'test exact thread finished' in text
    assert len(text) < 520
    assert sha(file) == original


def test_bounded_utf8_tail(tmp_path):
    file = tmp_path / 'journal.log'
    file.write_text('old\n' * 50000 + 'finished\n', encoding='utf-8-sig')
    assert tail(file, 1024).splitlines()[-1] == 'finished'


def test_updater_requires_exact_lab_path():
    info = {'exe': str(Path('C:/vendor/liveupdate/terminal64.exe')),
            'cmdline': ['terminal64.exe', '/update', '/path:' + str(ROOT)]}
    assert is_lab_updater(info)
    assert not is_lab_updater({**info, 'cmdline': ['terminal64.exe', '/update', '/path:D:/QM/mt5/T_Live/MT5_Base']})
    assert not is_lab_updater({**info, 'cmdline': ['terminal64.exe', '/update', '/path:' + str(ROOT) + '_other']})
    assert not is_lab_updater({**info, 'cmdline': ['terminal64.exe', '/config:' + str(ROOT)]})


def test_completion_is_current_last_record_not_just_old_matching_marker():
    epoch = datetime(2026, 9, 8, 16, 0, 0).timestamp()
    text = ('CS\t0\t16:00:00.000\tTester\tTest passed in 0:00:01.0\n'
            'CS\t0\t16:00:00.000\tTester\ttest Experts\\QM\\EA.ex5 on EURUSD,Daily thread finished\n')
    kwargs = dict(expert='QM\\EA', symbol='EURUSD', period='D1', day='20260908',
                  started_epoch=epoch - 20, now_epoch=epoch + 600)
    assert finished_marker_time(text, **kwargs) == epoch
    assert finished_marker_time(text, **{**kwargs, 'started_epoch': epoch + 1}) is None
    assert finished_marker_time(text + 'CS\t0\t16:00:10.000\tTester\tnew testing started\n', **kwargs) is None
    assert finished_marker_time(text, **{**kwargs, 'expert': 'QM\\Other'}) is None
    assert finished_marker_time(text, **{**kwargs, 'symbol': 'GBPUSD'}) is None
