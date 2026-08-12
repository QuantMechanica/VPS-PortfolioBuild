from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import pytest

from tools.strategy_farm import ftmo_lane_runner as runner


def _lane(tmp_path: Path, *, server: str = "FTMO-Demo", enabled: str = "0") -> Path:
    root = tmp_path / "mt5" / "FTMO_STREAM1"
    config = root / "Config"
    config.mkdir(parents=True)
    (root / "Bases").mkdir()
    (root / "terminal64.exe").write_bytes(b"terminal")
    (config / "servers.dat").write_bytes(b"servers")
    (config / "accounts.dat").write_bytes(b"opaque-account-state")
    (config / "common.ini").write_text(
        "\n".join(
            [
                "[Common]",
                "Login=1514165262",
                f"Server={server}",
                "Source=trader.ftmo.com",
                "[Experts]",
                f"Enabled={enabled}",
                "AllowDllImport=0",
                "WebRequest=0",
                "",
            ]
        ),
        encoding="utf-8",
    )
    return root


def _register(monkeypatch: pytest.MonkeyPatch, root: Path) -> None:
    monkeypatch.setitem(runner.LANE_ROOTS, "FTMO_STREAM1", root)


def _receipt(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
    *,
    server: str = "FTMO-Demo",
    enabled: str = "0",
    processes: list[dict[str, object]] | None = None,
) -> tuple[Path, dict[str, object]]:
    root = _lane(tmp_path, server=server, enabled=enabled)
    _register(monkeypatch, root)
    value = runner.build_provision_receipt(
        "FTMO_STREAM1", process_rows=[] if processes is None else processes
    )
    return root, value


def test_provision_receipt_is_durable_hold_without_inventing_history(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root, receipt = _receipt(tmp_path, monkeypatch)

    assert receipt["schema"] == runner.PROVISION_RECEIPT_SCHEMA
    assert receipt["status"] == "HOLD"
    assert receipt["campaign_ready"] is False
    assert receipt["profile"]["server"] == "FTMO-Demo"
    assert receipt["profile"]["experts_enabled"] is False
    assert receipt["autotrading_touched"] is False
    assert receipt["dedicated_research_root"]["portable_mode_assertion"].endswith(
        "ROOT_LOCAL_CONFIG"
    )
    assert receipt["history"]["XAUUSD"]["real_ticks"]["coverage_proven"] is False
    assert receipt["history"]["GER40.cash"]["m1_bars"]["coverage_proven"] is False
    assert receipt["bindings"]["accounts_dat"]["path"] == str(
        (root / "Config/accounts.dat").resolve()
    )
    assert "opaque-account-state" not in json.dumps(receipt)


def test_receipt_refuses_wrong_server(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _lane(tmp_path, server="Darwinex-Demo")
    _register(monkeypatch, root)
    with pytest.raises(runner.FtmoLaneError, match="not FTMO-Demo"):
        runner.build_provision_receipt("FTMO_STREAM1", process_rows=[])


def test_receipt_refuses_enabled_experts_autotrading(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _lane(tmp_path, enabled="1")
    _register(monkeypatch, root)
    with pytest.raises(runner.FtmoLaneError, match="explicitly disabled"):
        runner.build_provision_receipt("FTMO_STREAM1", process_rows=[])


def test_receipt_refuses_live_or_appdata_root(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "AppData" / "Roaming" / "MetaQuotes" / "Terminal" / "FTMO_STREAM1"
    _register(monkeypatch, root)
    with pytest.raises(runner.FtmoLaneError, match="live/AppData"):
        runner.build_provision_receipt("FTMO_STREAM1", process_rows=[])


def test_campaign_validation_refuses_missing_history(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    _root, receipt = _receipt(tmp_path, monkeypatch)
    with pytest.raises(runner.FtmoLaneError, match="HOLD|unproven"):
        runner.validate_provision_receipt(
            receipt,
            lane="FTMO_STREAM1",
            native_symbol="XAUUSD",
            execution_model="M1_MODELLED",
            requested_from=dt.date(2018, 7, 2),
            requested_to=dt.date(2025, 12, 31),
            require_campaign_ready=True,
        )


def test_receipt_refuses_capacity_violation(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    processes = [
        {
            "ProcessId": index,
            "ExecutablePath": f"D:/QM/mt5/FTMO_STREAM{index}/terminal64.exe",
        }
        for index in (1, 2)
    ]
    _root, receipt = _receipt(tmp_path, monkeypatch, processes=processes)
    assert receipt["capacity"]["permit"] is False
    assert receipt["capacity"]["reason"] == "CAPACITY_LIMIT"
    with pytest.raises(runner.FtmoLaneError, match="capacity permit"):
        runner.validate_provision_receipt(receipt, lane="FTMO_STREAM1")


def test_symbol_rebinding_changes_only_provenance_comment(
    tmp_path: Path,
) -> None:
    source = tmp_path / "sealed.set"
    source.write_text(
        "; symbol:       GDAXI.DWX\n"
        "RISK_FIXED=1000\n"
        "RISK_PERCENT=0\n"
        "qm_news_stale_max_hours=336\n"
        "strategy_period=20\n",
        encoding="utf-8",
    )
    original = source.read_bytes()
    target = tmp_path / "run" / "native.set"

    receipt = runner.derive_ftmo_set(
        source,
        target,
        source_symbol="GDAXI.DWX",
        native_symbol="GER40.cash",
    )

    assert source.read_bytes() == original
    assert "; symbol:       GER40.cash" in target.read_text(encoding="utf-8")
    assert receipt["strategy_inputs_identical"] is True
    assert receipt["source"]["sha256"] == runner.sha256_file(source)
    assert receipt["derived"]["sha256"] == runner.sha256_file(target)


def test_symbol_rebinding_preserves_build_guardrails(tmp_path: Path) -> None:
    source = tmp_path / "bad.set"
    source.write_text(
        "; symbol: XAUUSD.DWX\nRISK_FIXED=1000\nRISK_PERCENT=1\n",
        encoding="utf-8",
    )
    with pytest.raises(runner.FtmoLaneError, match="RISK_FIXED"):
        runner.derive_ftmo_set(
            source,
            tmp_path / "derived.set",
            source_symbol="XAUUSD.DWX",
            native_symbol="XAUUSD",
        )


def test_runner_binding_rehashes_every_bound_input_and_model_class(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _lane(tmp_path)
    _register(monkeypatch, root)
    evidence_root = tmp_path / "reports/ftmo_stream/wave1"
    run_root = evidence_root / "job"
    run_root.mkdir(parents=True)
    monkeypatch.setattr(runner, "DEFAULT_OUTPUT_ROOT", evidence_root)
    files: dict[str, Path] = {
        "terminal_exe": root / "terminal64.exe",
        "server_profile": root / "Config/common.ini",
    }
    for name in ("ex5", "provision_receipt", "symbol_probe", "cost_snapshot"):
        path = tmp_path / "inputs" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(name, encoding="utf-8")
        files[name] = path
    files["tester_ini"] = run_root / "tester.ini"
    files["tester_ini"].write_text("tester_ini", encoding="utf-8")
    source = tmp_path / "sealed.set"
    derived = run_root / "derived.set"
    source.write_text("sealed", encoding="utf-8")
    derived.write_text("derived", encoding="utf-8")
    manifest = {
        "schema": runner.JOB_MANIFEST_SCHEMA,
        "lane": "FTMO_STREAM1",
        "lane_root": str(root.resolve()),
        "execution_model": {"name": "M1_MODELLED", "mt5_model": 1},
        "evidence_class": "FTMO_M1_MODELLED",
        "max_concurrent": 2,
        "run_root": str(run_root),
        "artifact_contract": {
            "report": str(run_root / "report.htm"),
            "q08_delta": str(run_root / "q08.jsonl"),
            "equity_delta": str(run_root / "equity.jsonl"),
            "run_receipt": str(run_root / "receipt.json"),
        },
        "export_contract": {
            "summary": str(run_root / "summary.json"),
            "stream": str(run_root / "stream.jsonl"),
            "receipt": str(run_root / "export-receipt.json"),
        },
        "bindings": {name: runner.file_binding(path) for name, path in files.items()},
        "set_rebinding": {
            "source": runner.file_binding(source),
            "derived": runner.file_binding(derived),
        },
    }

    runner.verify_job_binding(manifest, lane="FTMO_STREAM1")
    files["ex5"].write_text("drift", encoding="utf-8")
    with pytest.raises(runner.FtmoLaneError, match="binding drift: ex5"):
        runner.verify_job_binding(manifest, lane="FTMO_STREAM1")


def test_runner_refuses_evidence_class_fallback(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = _lane(tmp_path)
    _register(monkeypatch, root)
    evidence_root = tmp_path / "reports/ftmo_stream/wave1"
    run_root = evidence_root / "job"
    run_root.mkdir(parents=True)
    monkeypatch.setattr(runner, "DEFAULT_OUTPUT_ROOT", evidence_root)
    path = tmp_path / "bound"
    path.write_text("x", encoding="utf-8")
    tester_ini = run_root / "tester.ini"
    tester_ini.write_text("ini", encoding="utf-8")
    manifest = {
        "schema": runner.JOB_MANIFEST_SCHEMA,
        "lane": "FTMO_STREAM1",
        "lane_root": str(root.resolve()),
        "execution_model": {"name": "M1_MODELLED", "mt5_model": 1},
        "evidence_class": "FTMO_REAL_TICKS",
        "max_concurrent": 2,
        "run_root": str(run_root),
        "artifact_contract": {
            "report": str(run_root / "report.htm"),
            "q08_delta": str(run_root / "q08.jsonl"),
            "equity_delta": str(run_root / "equity.jsonl"),
            "run_receipt": str(run_root / "receipt.json"),
        },
        "export_contract": {
            "summary": str(run_root / "summary.json"),
            "stream": str(run_root / "stream.jsonl"),
            "receipt": str(run_root / "export-receipt.json"),
        },
        "bindings": {
            "terminal_exe": runner.file_binding(root / "terminal64.exe"),
            "server_profile": runner.file_binding(root / "Config/common.ini"),
            "tester_ini": runner.file_binding(tester_ini),
            "only": runner.file_binding(path),
        },
        "set_rebinding": {
            "source": runner.file_binding(path),
            "derived": runner.file_binding(tester_ini),
        },
    }
    with pytest.raises(runner.FtmoLaneError, match="evidence class/model mismatch"):
        runner.verify_job_binding(manifest, lane="FTMO_STREAM1")


def test_daily_export_handoff_refuses_m1_evidence(tmp_path: Path) -> None:
    with pytest.raises(runner.FtmoLaneError, match="refuses non-tick"):
        runner._export_real_ticks(
            {"evidence_class": "FTMO_M1_MODELLED"},
            report=tmp_path / "never-opened.htm",
            q08_path=tmp_path / "never-opened.jsonl",
            equity_path=tmp_path / "never-opened-equity.jsonl",
        )


def test_duplicate_ea_directories_block_build_identity(tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    first = repo / "framework/EAs/QM5_13301_first"
    second = repo / "framework/EAs/QM5_13301_second"
    first.mkdir(parents=True)
    second.mkdir(parents=True)
    ex5 = first / "QM5_13301_first.ex5"
    ex5.write_bytes(b"ex5")
    with pytest.raises(runner.FtmoLaneError, match="ambiguous: 2 directories"):
        runner._ea_directory(repo, 13301, ex5)


def test_run_next_requires_explicit_execute() -> None:
    with pytest.raises(runner.FtmoLaneError, match="reviewer authorization"):
        runner.run_next(
            lane="FTMO_STREAM1",
            queue_root=Path("unused"),
            common_files_root=Path("unused"),
            timeout_seconds=1,
            execute=False,
        )
