import csv
import datetime as dt
import importlib.util
from pathlib import Path

import pytest

MODULE = Path(__file__).resolve().parents[3] / "framework/scripts/mt5_diagnostics/qm1537_native_d1_export.py"
spec = importlib.util.spec_from_file_location("qm1537_d1_export_fixture", MODULE)
exporter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(exporter)


def write_d1(path: Path, count: int, *, duplicate=False):
    start = exporter.MIN_LAST_EPOCH - (count - 1) * 86400
    with path.open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(exporter.HEADER)
        for index in range(count):
            epoch = start + (index if not duplicate or index < count - 1 else index - 1) * 86400
            writer.writerow([epoch, "1.0", "1.2", "0.9", "1.1", 10, 2])


def test_validate_output_binds_complete_ordered_file(tmp_path):
    path = tmp_path / "XAUUSD.DWX_D1.csv"
    write_d1(path, 300)
    result = exporter.validate_output(path, "XAUUSD.DWX")
    assert result["rows"] == 300
    assert len(result["sha256"]) == 64
    assert result["native_symbol"] == "XAUUSD"


def test_validate_output_rejects_duplicate_time(tmp_path):
    path = tmp_path / "XAUUSD.DWX_D1.csv"
    write_d1(path, 300, duplicate=True)
    with pytest.raises(ValueError, match="order/duplicate"):
        exporter.validate_output(path, "XAUUSD.DWX")


def test_outside_staging_refuses_before_process_or_write(tmp_path, monkeypatch):
    monkeypatch.setattr(exporter.boot, "scan_terminal_processes", lambda: pytest.fail("process API reached"))
    with pytest.raises(ValueError, match="new QM5_1537 staging child"):
        exporter.run(tmp_path / "outside", 300)


def test_owned_match_requires_exact_path_config_and_fresh_process():
    ini = Path("D:/QM/reports/qm1537_native_d1/task/startup.ini")
    started = dt.datetime(2026, 9, 7, 9, 0, tzinfo=dt.timezone.utc)
    row = {"ExecutablePath": str(exporter.ROOT / "terminal64.exe"),
           "CommandLine": f"/portable /config:{ini}", "ProcessId": 123,
           "CreationDate": "2026-09-07T09:00:01Z"}
    assert exporter.owned_match(row, ini, started)["pid"] == 123
    assert exporter.owned_match({**row, "ExecutablePath": "C:/QM/mt5/T_Live/terminal64.exe"}, ini, started) is None
    assert exporter.owned_match({**row, "CommandLine": "/portable /config:foreign.ini"}, ini, started) is None


def test_mql_is_exact_universe_create_only_read_only_profile():
    source = exporter.SOURCE.read_text(encoding="utf-8-sig")
    assert 'root!="d:\\\\qm\\\\mt5\\\\t_export"' in source
    assert "ArraySize(canonical)!=37" in source
    assert "FileIsExist(filename)" in source
    assert "CopyRates(native,PERIOD_D1" in source
    assert not any(__import__("re").search(pattern, source) for pattern in exporter.boot.FORBIDDEN_MQL_TOKENS)
