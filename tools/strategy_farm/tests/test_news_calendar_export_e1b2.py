import csv
import datetime as dt
import importlib.util
from pathlib import Path
import pytest

MODULE=Path(__file__).resolve().parents[3]/"framework/scripts/mt5_diagnostics/news_calendar_export_e1b2.py"
spec=importlib.util.spec_from_file_location("news_export_fixture",MODULE)
exporter=importlib.util.module_from_spec(spec)
spec.loader.exec_module(exporter)


def write(path, times, ids, importance="high"):
    with path.open("w",newline="") as f:
        w=csv.DictWriter(f,fieldnames=["broker_time","value_id","event_name","importance"])
        w.writeheader()
        for t,i in zip(times,ids):w.writerow(dict(broker_time=t,value_id=i,event_name="Fixture",importance=importance))


@pytest.mark.parametrize("times,ids",[([2,1],["a","b"]),([1,2],["a","a"])])
def test_rejects_invalid_release_sequence(tmp_path,times,ids):
    path=tmp_path/"T_EXPORT_USD_HIGH_2026H1_NATIVE.csv"
    write(path,times,ids)
    with pytest.raises(ValueError,match="unsorted or duplicate"):exporter.validate_output(path)


def test_impact_filter_preserves_catalog_low(tmp_path):
    path=tmp_path/"T_EXPORT_USD_ALL_CORE_PPI_2018_2025_NATIVE.csv"
    write(path,[1,2],["a","b"],"low")
    assert exporter.validate_output(path)["rows"]==2
    high=tmp_path/"T_EXPORT_USD_HIGH_2026H1_NATIVE.csv"
    write(high,[1],["a"],"low")
    with pytest.raises(ValueError,match="non-high"):exporter.validate_output(high)


def test_outside_staging_refuses_before_process_or_write(tmp_path,monkeypatch):
    monkeypatch.setattr(exporter.boot,"scan_terminal_processes",lambda:pytest.fail("process API reached"))
    with pytest.raises(ValueError,match="new E1-A staging child"):exporter.run(tmp_path/"outside",60)
    assert not (tmp_path/"outside").exists()


def test_process_handoff_requires_config_path_and_fresh_identity():
    ini=Path("D:/QM/reports/news_calendar/repair_e1a/task/startup.ini")
    start=dt.datetime(2026,9,5,10,0,tzinfo=dt.timezone.utc)
    row={"ExecutablePath":str(exporter.ROOT/"terminal64.exe"),"CommandLine":f'/portable /config:{ini}',
         "ProcessId":999,"CreationDate":"2026-09-05T10:00:01Z"}
    assert exporter.owned_match(row,ini,start)["pid"]==999
    assert exporter.owned_match({**row,"CommandLine":"/portable /config:foreign.ini"},ini,start) is None
    assert exporter.owned_match({**row,"ExecutablePath":"C:/QM/mt5/T_Live/terminal64.exe"},ini,start) is None
    assert exporter.owned_match({**row,"CreationDate":"2026-09-05T09:00:00Z"},ini,start) is None


def test_h1_profile_is_four_new_all_impact_targets_and_legacy_names_unchanged():
    assert len(exporter.expected_names())==10
    assert len(exporter.expected_names(True))==4
    assert all('_ALL_' in name and '_2026H1_' in name for name in exporter.expected_names(True))
    assert set(exporter.expected_names()).isdisjoint(exporter.expected_names(True))
