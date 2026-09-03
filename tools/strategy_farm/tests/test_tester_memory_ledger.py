"""Tester-memory measurement ledger (2026-09-03, CEO).

Covers the JSONL ledger writer schema + GB conversions, the lookup-key
normalization across symbol/TF/run-kind classes, writer fail-open on an
unwritable path, and the subtree working-set sampler (accumulation + fail-open).
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import terminal_worker  # noqa: E402

GIB = float(1024 ** 3)


def test_writer_emits_one_line_with_v1_schema_and_gb(tmp_path, monkeypatch):
    ledger = tmp_path / "state" / "tester_memory_ledger.jsonl"
    monkeypatch.setenv("QM_TESTER_MEMORY_LEDGER", str(ledger))
    monkeypatch.setenv("QM_TESTER_MEMORY_ADMISSION", "0")  # no expectations read
    monkeypatch.setattr(terminal_worker, "_multisymbol_ea_ids", lambda: frozenset())

    acc = {
        "samples": 4,
        "peak_subtree_ws": int(23 * GIB),
        "peak_subtree_private": int(21 * GIB),
        "peak_metatester_ws": int(20 * GIB),
        "metatester_os_peak_ws": int(23 * GIB),
        "peak_terminal_ws": int(2 * GIB),
    }
    item = {"ea_id": "QM5_10569", "symbol": "EURJPY.DWX", "phase": "Q05"}
    payload = {"host_timeframe": "H4"}

    terminal_worker._write_tester_memory_ledger(
        tmp_path, item, payload, {"pid": 123}, acc, "T3",
        run_seconds=612.5, outcome="finished",
    )

    lines = ledger.read_text(encoding="utf-8").splitlines()
    assert len(lines) == 1
    rec = json.loads(lines[0])
    assert rec["schema"] == "qm.tester_memory_ledger/v1"
    assert rec["ea_id"] == "QM5_10569"
    assert rec["symbol"] == "EURJPY.DWX"
    assert rec["symbol_class"] == "fx_cross"
    assert rec["timeframe"] == "H4"
    assert rec["phase"] == "Q05"
    assert rec["run_kind"] == "backtest"
    assert rec["ram_class"] == terminal_worker.MULTISYMBOL_COMMIT_CLASS_ORDINARY
    assert rec["reservation_gb"] == 8.0
    assert rec["lookup_key"] == "fx_cross|H4|backtest"
    assert rec["run_seconds"] == 612.5
    assert rec["samples"] == 4
    assert rec["peak_subtree_working_set_gb"] == 23.0
    assert rec["peak_metatester_working_set_gb"] == 20.0
    assert rec["metatester_os_peak_working_set_gb"] == 23.0
    assert rec["peak_terminal_working_set_gb"] == 2.0
    assert rec["peak_subtree_private_gb"] == 21.0
    assert rec["outcome"] == "finished"
    assert rec["terminal"] == "T3"
    assert isinstance(rec["worker_pid"], int)
    # every declared v1 field is present
    for field in (
        "schema", "ts_utc", "ea_id", "symbol", "symbol_class", "timeframe",
        "phase", "run_kind", "ram_class", "reservation_gb", "lookup_key",
        "run_seconds", "samples", "peak_subtree_working_set_gb",
        "peak_metatester_working_set_gb", "metatester_os_peak_working_set_gb",
        "peak_terminal_working_set_gb", "peak_subtree_private_gb", "outcome",
        "worker_pid", "terminal",
    ):
        assert field in rec, field


def test_lookup_key_normalization_across_classes():
    sym = terminal_worker._tester_memory_symbol_class
    # symbol classes
    assert sym({"symbol": "EURUSD.DWX"}, {}, False) == "fx_major"
    assert sym({"symbol": "EURJPY.DWX"}, {}, False) == "fx_cross"
    assert sym({"symbol": "USDTRY.DWX"}, {}, False) == "fx_exotic"
    assert sym({"symbol": "GDAXI.DWX"}, {}, False) == "index"
    assert sym({"symbol": "XAUUSD.DWX"}, {}, False) == "metal"
    assert sym({"symbol": "XTIUSD.DWX"}, {}, False) == "energy"
    assert sym({"symbol": "BTCUSD.DWX"}, {}, False) == "other"
    assert sym({"symbol": "X"}, {"basket_symbols": ["EURUSD", "GBPUSD"]}, True) == "basket2"
    assert sym({"symbol": "X"}, {"basket_symbol_count": 5}, True) == "basket3_9"
    assert sym({"symbol": "X"}, {"basket_symbol_count": 12}, True) == "basket10+"

    # timeframe normalization
    tf = terminal_worker._normalize_timeframe
    assert tf({}, {"host_timeframe": "H4"}) == "H4"
    assert tf({}, {"period": "PERIOD_D1"}) == "D1"
    assert tf({}, {"host_timeframe": "ZZ"}) == "TF?"

    # run kinds
    rk = terminal_worker._tester_memory_run_kind
    assert rk({"phase": "OPT_CENSUS"}, {}) == "census"
    assert rk({"phase": "COMPILE_EA"}, {}) == "compile"
    assert rk({"phase": "Q07"}, {terminal_worker.farmctl.RECOVERY_CLASS_PAYLOAD_KEY: True}) == "recovery"
    assert rk({"phase": terminal_worker._Q09_NEWS_PHASE}, {}) == "news"
    assert rk({"phase": terminal_worker.farmctl._PARAM_OPT_PHASE}, {}) == "wf"
    assert rk({"phase": "Q02"}, {}) == "smoke"
    assert rk({"phase": "Q05"}, {}) == "backtest"

    # composite key
    assert (
        terminal_worker._tester_memory_lookup_key("fx_cross", "H4", "backtest")
        == "fx_cross|H4|backtest"
    )


def test_writer_fail_open_on_unwritable_path(tmp_path, monkeypatch):
    # A regular file where the ledger's PARENT directory should be -> mkdir
    # raises -> the writer must swallow it and never raise.
    blocker = tmp_path / "blocker"
    blocker.write_text("x", encoding="utf-8")
    ledger = blocker / "ledger.jsonl"
    monkeypatch.setenv("QM_TESTER_MEMORY_LEDGER", str(ledger))
    monkeypatch.setenv("QM_TESTER_MEMORY_ADMISSION", "0")
    monkeypatch.setattr(terminal_worker, "_multisymbol_ea_ids", lambda: frozenset())

    acc = {
        "samples": 1, "peak_subtree_ws": int(8 * GIB), "peak_subtree_private": 0,
        "peak_metatester_ws": 0, "metatester_os_peak_ws": 0, "peak_terminal_ws": 0,
    }
    # must not raise
    terminal_worker._write_tester_memory_ledger(
        tmp_path, {"ea_id": "QM5_1", "symbol": "EURUSD.DWX", "phase": "Q05"},
        {"host_timeframe": "H1"}, {"pid": 1}, acc, "T1",
        run_seconds=1.0, outcome="finished",
    )
    assert not ledger.exists()


def test_sampler_accumulates_subtree_metatester_and_os_peak(monkeypatch):
    # pwsh(100) -> terminal64(200) -> three concurrent metatester64 grid children
    children = {100: [200], 200: [300, 301, 302]}
    alive = {100, 200, 300, 301, 302}
    private = {100: int(0.5 * GIB), 200: int(1 * GIB),
               300: int(7 * GIB), 301: int(7 * GIB), 302: int(6 * GIB)}
    working_set = {100: int(1 * GIB), 200: int(2 * GIB),
                   300: int(8 * GIB), 301: int(8 * GIB), 302: int(7 * GIB)}
    peak_working_set = {300: int(9 * GIB), 301: int(8 * GIB), 302: int(7 * GIB)}
    image = {100: "pwsh.exe", 200: "terminal64.exe",
             300: "metatester64.exe", 301: "metatester64.exe", 302: "metatester64.exe"}

    def fake_snapshot():
        terminal_worker._process_snapshot_cache["working_set"] = working_set
        terminal_worker._process_snapshot_cache["peak_working_set"] = peak_working_set
        terminal_worker._process_snapshot_cache["image"] = image
        return children, private, alive

    monkeypatch.setattr(terminal_worker, "_process_private_snapshot", fake_snapshot)

    acc = {
        "samples": 0, "peak_subtree_ws": 0, "peak_subtree_private": 0,
        "peak_metatester_ws": 0, "metatester_os_peak_ws": 0, "peak_terminal_ws": 0,
    }
    terminal_worker._sample_tester_memory(100, acc)

    assert acc["samples"] == 1
    # subtree WS = 1+2+8+8+7 = 26 GB (concurrent grid captured at one instant)
    assert acc["peak_subtree_ws"] == int(26 * GIB)
    # metatester WS sum = 8+8+7 = 23 GB
    assert acc["peak_metatester_ws"] == int(23 * GIB)
    # OS-maintained lifetime peak (max over metatester pids) = 9 GB
    assert acc["metatester_os_peak_ws"] == int(9 * GIB)
    # terminal64 WS = 2 GB
    assert acc["peak_terminal_ws"] == int(2 * GIB)
    # subtree private = 0.5+1+7+7+6 = 21.5 GB
    assert acc["peak_subtree_private"] == int(0.5 * GIB) + int(1 * GIB) + int(7 * GIB) + int(7 * GIB) + int(6 * GIB)

    # a second sample with a smaller footprint must NOT lower the running maxima
    def fake_small():
        terminal_worker._process_snapshot_cache["working_set"] = {100: int(1 * GIB)}
        terminal_worker._process_snapshot_cache["peak_working_set"] = {}
        terminal_worker._process_snapshot_cache["image"] = {100: "pwsh.exe"}
        return {100: []}, {100: int(1 * GIB)}, {100}

    monkeypatch.setattr(terminal_worker, "_process_private_snapshot", fake_small)
    terminal_worker._sample_tester_memory(100, acc)
    assert acc["samples"] == 2
    assert acc["peak_subtree_ws"] == int(26 * GIB)  # unchanged
    assert acc["peak_metatester_ws"] == int(23 * GIB)  # unchanged


def test_sampler_fail_open_on_snapshot_error(monkeypatch):
    def boom():
        raise RuntimeError("snapshot exploded")

    monkeypatch.setattr(terminal_worker, "_process_private_snapshot", boom)
    acc = {
        "samples": 0, "peak_subtree_ws": 0, "peak_subtree_private": 0,
        "peak_metatester_ws": 0, "metatester_os_peak_ws": 0, "peak_terminal_ws": 0,
    }
    terminal_worker._sample_tester_memory(100, acc)  # must not raise
    assert acc == {
        "samples": 0, "peak_subtree_ws": 0, "peak_subtree_private": 0,
        "peak_metatester_ws": 0, "metatester_os_peak_ws": 0, "peak_terminal_ws": 0,
    }
