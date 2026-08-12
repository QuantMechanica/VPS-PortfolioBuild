import json
import sys
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


def _payload(*, contract: str | None) -> dict:
    payload = {
        "host_timeframe": "H1",
        "from_year": 2018,
        "to_year": 2025,
        "from_date": "2018.07.02",
        "to_date": "2025.12.31",
    }
    if contract is not None:
        payload["measurement_contract"] = contract
    return payload


def _dispatch(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    payload: dict,
) -> tuple[dict, list[list[str]]]:
    root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    ea_id = "QM5_9936"
    ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_demo"
    sets_dir = ea_dir / "sets"
    sets_dir.mkdir(parents=True)
    (ea_dir / f"{ea_id}_demo.ex5").write_bytes(b"test-ex5")
    setfile = sets_dir / f"{ea_id}_demo_USDJPY.DWX_H1_backtest.set"
    setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")

    item = {
        "id": "ftmo-book3-q02-dispatch-test",
        "ea_id": ea_id,
        "symbol": "USDJPY.DWX",
        "setfile_path": str(setfile.resolve()),
        "phase": "Q02",
        "payload_json": json.dumps(payload, sort_keys=True),
    }
    commands: list[list[str]] = []

    class FakeProc:
        pid = 9936

        def __init__(self, cmd, **_kwargs):
            commands.append([str(part) for part in cmd])

    real_path = Path

    def path_proxy(value) -> Path:
        if str(value) == r"D:\QM\reports\work_items":
            return tmp_path / "reports" / "work_items"
        return real_path(value)

    monkeypatch.setattr(farmctl, "REPO_ROOT", repo_root)
    monkeypatch.setattr(farmctl, "Path", path_proxy)
    monkeypatch.setattr(farmctl, "_load_basket_manifest", lambda _ea_id: None)
    monkeypatch.setattr(
        farmctl,
        "_compile_gate_check",
        lambda _ea_dir_name: {
            "allowed": True,
            "verdict": "COMPILED_CACHED",
            "source": "test",
        },
    )
    monkeypatch.setattr(
        farmctl,
        "_expected_trade_frequency_for_ea",
        lambda _root, _ea_id: {
            "expected_trades_per_year_per_symbol": 20,
            "expected_trades_per_year_card": 20,
            "card_universe_symbol_count": 1,
            "min_trade_scope": "per_symbol_test",
        },
    )
    monkeypatch.setattr(farmctl, "reap_finished_job_objects", lambda: None)
    monkeypatch.setattr(farmctl, "suspended_runner_creation_flags", lambda: 0)
    monkeypatch.setattr(
        farmctl,
        "bind_spawned_process_to_kill_job",
        lambda *_args, **_kwargs: {
            "process_creation_key": "test-creation-key",
            "process_image_path": "pwsh.exe",
            "process_started_at_epoch": 1.0,
        },
    )
    monkeypatch.setattr(farmctl.subprocess, "Popen", FakeProc)

    result = farmctl._spawn_run_smoke_for_work_item(root, item, "T10")
    return result, commands


def test_exact_ftmo_book3_q02_contract_uses_full_immutable_window(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    result, commands = _dispatch(
        monkeypatch,
        tmp_path,
        _payload(contract=farmctl.FTMO_BOOK3_FIDELITY_MEASUREMENT_CONTRACT),
    )

    assert result["spawned"] is True
    assert result["p2_run_stage"] == "full"
    assert result["from_date"] == result["expected_from_date"] == "2018.07.02"
    assert result["to_date"] == result["expected_to_date"] == "2025.12.31"
    assert len(commands) == 1
    command = commands[0]
    assert command[command.index("-Runs") + 1] == "1"
    assert command[command.index("-FromDate") + 1] == "2018.07.02"
    assert command[command.index("-ToDate") + 1] == "2025.12.31"


@pytest.mark.parametrize(
    "contract",
    [
        None,
        "FTMO_BOOK3_FIDELITY_LADDER_V1",
        "FTMO_BOOK3_FIDELITY_LADDER_V1_NEAR_MATCH",
        "FTMO_BOOK3_FIDELITY_LADDER_V2_FULL_LIFECYCLE_NET_NEAR_MATCH",
    ],
)
def test_ordinary_and_near_match_q02_contracts_retain_prescreen(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path, contract: str | None
) -> None:
    result, commands = _dispatch(monkeypatch, tmp_path, _payload(contract=contract))

    assert result["spawned"] is True
    assert result["p2_run_stage"] == "prescreen"
    assert result["from_date"] == result["expected_from_date"] == "2025.07.01"
    assert result["to_date"] == result["expected_to_date"] == "2025.12.31"
    assert len(commands) == 1


@pytest.mark.parametrize(
    ("from_date", "to_date"),
    [
        (None, "2025.12.31"),
        ("2018.07.02", None),
        ("2018.02.30", "2025.12.31"),
        ("2025.12.31", "2018.07.02"),
    ],
)
def test_exact_ftmo_book3_q02_contract_rejects_invalid_window_before_spawn(
    tmp_path: Path, from_date: str | None, to_date: str | None
) -> None:
    payload = _payload(contract=farmctl.FTMO_BOOK3_FIDELITY_MEASUREMENT_CONTRACT)
    payload["from_date"] = from_date
    payload["to_date"] = to_date
    item = {
        "id": "ftmo-book3-invalid-window-test",
        "ea_id": "QM5_9936",
        "symbol": "USDJPY.DWX",
        "setfile_path": str(tmp_path / "missing.set"),
        "phase": "Q02",
        "payload_json": json.dumps(payload, sort_keys=True),
    }

    result = farmctl._spawn_run_smoke_for_work_item(tmp_path / "farm", item, "T10")

    assert result["spawned"] is False
    assert result["reason"] == "ftmo_book3_fidelity_window_invalid"
    assert result["measurement_contract"] == (
        farmctl.FTMO_BOOK3_FIDELITY_MEASUREMENT_CONTRACT
    )
