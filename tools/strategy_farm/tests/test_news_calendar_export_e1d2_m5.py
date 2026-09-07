import csv
import datetime as dt
import importlib.util
from pathlib import Path

import pytest

MODULE = Path(__file__).resolve().parents[3] / "framework/scripts/mt5_diagnostics/news_calendar_export_e1d2_m5.py"
spec = importlib.util.spec_from_file_location("news_m5_export_fixture", MODULE)
exporter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(exporter)


def write_m5(path: Path, count: int, *, duplicate=False):
    with path.open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(exporter.HEADER)
        for index in range(count):
            epoch = 1_700_000_000 + (index if not duplicate or index < count - 1 else index - 1) * 300
            writer.writerow([epoch, "1.0", "1.2", "0.9", "1.1", 10])


def test_validate_output_binds_large_ordered_file(tmp_path):
    path = tmp_path / exporter.OUTPUTS[0]
    write_m5(path, 100_000)
    result = exporter.validate_output(path)
    assert result["rows"] == 100_000
    assert len(result["sha256"]) == 64


def test_validate_output_rejects_duplicate_time(tmp_path):
    path = tmp_path / exporter.OUTPUTS[0]
    write_m5(path, 100_000, duplicate=True)
    with pytest.raises(ValueError, match="order/duplicate"):
        exporter.validate_output(path)


def test_outside_staging_refuses_before_process_or_write(tmp_path, monkeypatch):
    monkeypatch.setattr(exporter.boot, "scan_terminal_processes", lambda: pytest.fail("process API reached"))
    with pytest.raises(ValueError, match="new E1-A staging child"):
        exporter.run(tmp_path / "outside", 60)


def test_owned_match_requires_exact_path_config_and_fresh_process():
    ini = Path("D:/QM/reports/news_calendar/repair_e1a/task/startup.ini")
    started = dt.datetime(2026, 9, 7, 2, 0, tzinfo=dt.timezone.utc)
    row = {"ExecutablePath": str(exporter.ROOT / "terminal64.exe"),
           "CommandLine": f"/portable /config:{ini}", "ProcessId": 123,
           "CreationDate": "2026-09-07T02:00:01Z"}
    assert exporter.owned_match(row, ini, started)["pid"] == 123
    assert exporter.owned_match({**row, "ExecutablePath": "D:/QM/mt5/T_Live/terminal64.exe"}, ini, started) is None
    assert exporter.owned_match({**row, "CommandLine": "/portable /config:foreign.ini"}, ini, started) is None


def test_mql_is_two_symbol_create_only_read_only_profile():
    source = exporter.SOURCE.read_text(encoding="utf-8-sig")
    assert 'root!="d:\\\\qm\\\\mt5\\\\t_export"' in source
    assert '"AUDUSD.DWX","USDCAD.DWX"' in source
    assert "FileIsExist(filename)" in source
    assert "CopyRates(symbol,PERIOD_M5" in source
    assert not any(__import__("re").search(pattern, source) for pattern in exporter.boot.FORBIDDEN_MQL_TOKENS)
