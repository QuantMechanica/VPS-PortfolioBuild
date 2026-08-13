from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from framework.scripts import q15_freeze_check as q15
from tools.strategy_farm import farmctl


def _write(path: Path, value: str | bytes | dict) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(value, bytes):
        path.write_bytes(value)
    elif isinstance(value, dict):
        path.write_text(
            json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n",
            encoding="utf-8",
        )
    else:
        path.write_text(value, encoding="utf-8", newline="\n")
    return path


def _bound(path: Path) -> dict[str, object]:
    return {
        "path": str(path.resolve()),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "size_bytes": path.stat().st_size,
    }


def _fixture(tmp_path: Path) -> dict[str, Path | str]:
    repo = tmp_path / "repo"
    farm = tmp_path / "farm"
    reports = tmp_path / "reports" / "opt_track"
    card_id = "OPT-13213-USDJPY-EXIT-SURGERY-fixture01"
    card_dir = reports / card_id
    challenger = repo / "framework" / "EAs" / "QM5_20301_balke-gmt3-exit-v2"
    parent = repo / "framework" / "EAs" / "QM5_13213_balke-gmt3-range-breakout"
    parent_binary = _write(parent / f"{parent.name}.ex5", b"parent-binary")
    parent_set = _write(
        parent / "sets" / f"{parent.name}_USDJPY.DWX_H1_q10_confirmation.set",
        "RISK_FIXED=1000\nRISK_PERCENT=0\nstrategy_exit_hour=18\n",
    )
    q10_evidence = _write(tmp_path / "evidence" / "q10.json", {"phase": "Q10", "verdict": "PASS"})

    source = _write(
        challenger / f"{challenger.name}.mq5",
        """#property strict
input bool strategy_opt_enabled = false;
input int strategy_exit_hour = 18;
bool Strategy_NoTradeFilter()
  {
   if(!strategy_opt_enabled) return false;
   return (TimeHour(TimeCurrent()) >= strategy_exit_hour);
  }
""",
    )
    binary = _write(challenger / f"{challenger.name}.ex5", b"challenger-binary")
    q02_set = _write(
        challenger / "sets" / f"{challenger.name}_USDJPY.DWX_H1_backtest.set",
        "RISK_FIXED=1000\nRISK_PERCENT=0\nstrategy_opt_enabled=true\nstrategy_exit_hour=19\n",
    )
    off_set = _write(
        challenger / "sets" / f"{challenger.name}_USDJPY.DWX_H1_opt_control_off.set",
        "RISK_FIXED=1000\nRISK_PERCENT=0\nstrategy_opt_enabled=false\nstrategy_exit_hour=18\n",
    )

    registry = repo / "framework" / "registry"
    _write(
        registry / "ea_id_registry.csv",
        "ea_id,slug,strategy_id,status,owner,created_at\n"
        "20301,balke-gmt3-exit-v2,OPT-FIXTURE,active,Development,2026-08-13\n",
    )
    magic = _write(
        registry / "magic_numbers.csv",
        "ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status\n"
        "20301,balke-gmt3-exit-v2,0,USDJPY.DWX,203010000,2026-08-13,Development,active\n",
    )
    magic_hash = hashlib.sha256(magic.read_bytes().replace(b"\r\n", b"\n")).hexdigest().upper()
    _write(
        repo / "framework" / "include" / "QM" / "QM_MagicResolver.mqh",
        f"""#define QM_MAGIC_REGISTRY_SHA256 \"{magic_hash}\"
#define QM_MAGIC_REGISTRY_ROWS 1
static const int QM_MAGIC_REG_EA_ID[QM_MAGIC_REGISTRY_ROWS] = {{20301}};
static const int QM_MAGIC_REG_SLOT[QM_MAGIC_REGISTRY_ROWS] = {{0}};
static const string QM_MAGIC_REG_SYMBOL[QM_MAGIC_REGISTRY_ROWS] = {{\"USDJPY.DWX\"}};
static const int QM_MAGIC_REG_MAGIC[QM_MAGIC_REGISTRY_ROWS] = {{203010000}};
""",
    )

    card = {
        "schema": q15.OPT_CARD_SCHEMA,
        "card_id": card_id,
        "program": {
            "program_id": "SURVIVOR_OPTIMIZATION_TEST",
            "config_sha256": "1" * 64,
            "q10_snapshot_sha256": "2" * 64,
        },
        "parent": {
            "ea_id": "QM5_13213",
            "symbol": "USDJPY.DWX",
            "binary": _bound(parent_binary),
            "setfile": _bound(parent_set),
            "q10": {
                "work_item_id": "parent-q10",
                "verdict": "PASS",
                "evidence": _bound(q10_evidence),
                "metrics": {"trades": 100},
            },
        },
        "lever": "EXIT_SURGERY",
        "hypothesis": "Fixture hypothesis",
        "parameter_surface": {
            "fixed_parameters": {},
            "parameters": [{
                "name": "strategy_exit_hour",
                "type": "integer",
                "incumbent": 18,
                "candidate_values": [19, 20],
                "bounds": {"minimum": 18, "maximum": 20},
            }],
            "selection_rule": "DEV only",
        },
        "comparison_windows": [
            {"id": "F1", "kind": "Q04_ANCHORED_OOS", "start": "2023-01-01", "end": "2023-12-31"},
            {"id": "F2", "kind": "Q04_ANCHORED_OOS", "start": "2024-01-01", "end": "2024-12-31"},
            {"id": "F3", "kind": "Q04_ANCHORED_OOS", "start": "2025-01-01", "end": "2025-12-31"},
            {"id": "H1", "kind": "POST_DEV_HOLDOUT", "start": "2026-01-01", "end": "2026-07-31"},
        ],
        "success_metric": {
            "primary": "annual_return_pct",
            "direction": "MAXIMIZE",
            "minimum_improvement": 0,
        },
        "trial_ledger_path": str((card_dir / "trial_ledger.json").resolve()),
    }
    card_path = _write(card_dir / "opt_card.json", card)
    ledger_path = _write(card_dir / "trial_ledger.json", {
        "schema": q15.TRIAL_LEDGER_SCHEMA,
        "card_id": card_id,
        "status": "OPENED",
        "declared_trial_count": 2,
        "planned_trials": [
            {"trial_id": "T001", "parameters": {"strategy_exit_hour": 19}},
            {"trial_id": "T002", "parameters": {"strategy_exit_hour": 20}},
        ],
        "trials": [],
    })
    trial_1 = _write(card_dir / "trials" / "T001.json", {"metric": 1.0})
    trial_2 = _write(card_dir / "trials" / "T002.json", {"metric": 1.03})
    sweep_path = _write(card_dir / "dev_sweep.json", {
        "schema": q15.DEV_SWEEP_SCHEMA,
        "card_id": card_id,
        "window": {"kind": "DEV_IS", "start": "2018-01-01", "end": "2022-12-31"},
        "selection_metric": {"name": "annual_return_pct", "direction": "MAXIMIZE"},
        "trials": [
            {"trial_id": "T001", "parameters": {"strategy_exit_hour": 19}, "metric_value": 1.0, "evidence": _bound(trial_1)},
            {"trial_id": "T002", "parameters": {"strategy_exit_hour": 20}, "metric_value": 1.03, "evidence": _bound(trial_2)},
        ],
        "selection": {"chosen_trial_id": "T001"},
    })
    behavior = {"schema": q15.TRADE_BEHAVIOR_SCHEMA, "events": [{"entry": "2022-01-03T09:00:00Z", "side": "BUY", "exit": "2022-01-03T18:00:00Z"}]}
    parent_trace = _write(card_dir / "smoke" / "parent_behavior.json", behavior)
    challenger_trace = _write(card_dir / "smoke" / "challenger_behavior.json", behavior)
    equivalence_path = _write(card_dir / "default_off_equivalence.json", {
        "schema": q15.EQUIVALENCE_SCHEMA,
        "card_id": card_id,
        "lever_control": {"name": q15.LEVER_ENABLE_INPUT, "value": False},
        "smoke_window": {
            "symbol": "USDJPY.DWX", "timeframe": "H1",
            "start": "2022-01-01", "end": "2022-03-31",
        },
        "parent": {
            "binary": _bound(parent_binary),
            "setfile": _bound(parent_set),
            "behavior_trace": _bound(parent_trace),
        },
        "challenger": {
            "binary": _bound(binary),
            "setfile": _bound(off_set),
            "behavior_trace": _bound(challenger_trace),
        },
    })

    farmctl.init_db(farm)
    now = "2026-08-13T00:00:00+00:00"
    q14_payload = {
        "schema": "qm.q14-opt-admission/v1",
        "card_id": card_id,
        "opt_card_path": str(card_path.resolve()),
        "opt_card_sha256": hashlib.sha256(card_path.read_bytes()).hexdigest(),
    }
    with farmctl.connect(farm) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
                id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
                parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
            ) VALUES('q14-fixture','analytic','Q14','QM5_13213','USDJPY.DWX',?,
                     'done','OPT_ELIGIBLE',0,NULL,?,NULL,?,?,?)
            """,
            (str(parent_set), str(card_path), json.dumps(q14_payload, sort_keys=True), now, now),
        )
        conn.commit()
    return {
        "repo": repo,
        "farm": farm,
        "reports": reports,
        "card_id": card_id,
        "card_path": card_path,
        "ledger_path": ledger_path,
        "challenger": challenger,
        "source": source,
        "parent_binary": parent_binary,
        "sweep": sweep_path,
        "equivalence": equivalence_path,
        "q02_set": q02_set,
    }


def _run(paths: dict[str, Path | str], *, apply: bool = False) -> dict:
    return q15.run_freeze_check(
        card_id=str(paths["card_id"]),
        challenger_dir=Path(paths["challenger"]),
        repo_root=Path(paths["repo"]),
        farm_root=Path(paths["farm"]),
        report_root=Path(paths["reports"]),
        sweep_evidence_path=Path(paths["sweep"]),
        equivalence_evidence_path=Path(paths["equivalence"]),
        backtest_set_path=Path(paths["q02_set"]),
        apply=apply,
        enforce_apply_guards=False,
    )


def test_q15_dry_run_is_read_only_and_deterministic(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    before = Path(paths["ledger_path"]).read_bytes()
    first = _run(paths)
    second = _run(paths)
    assert first == second
    assert first["verdict"] == "CHALLENGER_SPAWNED"
    assert first["chosen_parameters"] == {"strategy_exit_hour": 19}
    assert not (Path(paths["ledger_path"]).parent / "freeze_addendum.json").exists()
    assert Path(paths["ledger_path"]).read_bytes() == before
    with farmctl.connect(Path(paths["farm"])) as conn:
        assert conn.execute("SELECT count(*) FROM work_items WHERE phase IN ('Q15','Q02')").fetchone()[0] == 0


def test_q15_apply_freezes_ledger_binds_q14_and_seeds_one_q02(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    first = _run(paths, apply=True)
    repeated = _run(paths, apply=True)
    assert first["created_q15_work_item"] is True
    assert first["created_q02_work_item"] is True
    assert repeated["idempotent"] is True
    ledger = json.loads(Path(paths["ledger_path"]).read_text(encoding="utf-8"))
    assert ledger["status"] == "CLOSED"
    assert len(ledger["trials"]) == ledger["declared_trial_count"] == 2
    assert ledger["freeze"]["addendum"]["sha256"] == first["freeze_addendum_sha256"]
    with farmctl.connect(Path(paths["farm"])) as conn:
        q15_row = conn.execute("SELECT phase,status,verdict,evidence_path FROM work_items WHERE id=?", (first["q15_work_item_id"],)).fetchone()
        q02_row = conn.execute("SELECT phase,status,verdict,payload_json FROM work_items WHERE id=?", (first["q02_work_item_id"],)).fetchone()
        dependency = conn.execute(
            "SELECT dependency_role,parent_work_item_id,required_verdicts_json FROM work_item_dependencies WHERE child_work_item_id=?",
            (first["q15_work_item_id"],),
        ).fetchone()
        event_count = conn.execute(
            "SELECT count(*) FROM events WHERE entity_id=? AND event='q15_challenger_frozen'",
            (first["q15_work_item_id"],),
        ).fetchone()[0]
    assert tuple(q15_row[:3]) == ("Q15", "done", "CHALLENGER_SPAWNED")
    assert tuple(q02_row[:3]) == ("Q02", "pending", None)
    assert json.loads(q02_row["payload_json"])["expected_setfile_sha256"] == hashlib.sha256(Path(paths["q02_set"]).read_bytes()).hexdigest()
    assert tuple(dependency) == ("Q14_ADMISSION", "q14-fixture", '["OPT_ELIGIBLE"]')
    assert event_count == 1


def test_q15_rejects_parent_hash_mismatch(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    Path(paths["parent_binary"]).write_bytes(b"tampered-parent")
    with pytest.raises(q15.Q15Error, match="parent binary SHA-256 mismatch"):
        _run(paths)


def test_q15_rejects_unwired_lever_parameter(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    source = Path(paths["source"])
    source.write_text(
        "input bool strategy_opt_enabled=false;\n"
        "input int strategy_exit_hour=18;\n"
        "bool Strategy_NoTradeFilter(){ return !strategy_opt_enabled; }\n",
        encoding="utf-8",
    )
    with pytest.raises(q15.Q15Error, match="unwired input: strategy_exit_hour"):
        _run(paths)


def test_q15_rejects_missing_sweep_evidence(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    Path(paths["sweep"]).unlink()
    with pytest.raises(q15.Q15Error, match="DEV sweep evidence is missing or invalid"):
        _run(paths)


def test_q15_rejects_below_plateau_choice(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    sweep_path = Path(paths["sweep"])
    sweep = json.loads(sweep_path.read_text(encoding="utf-8"))
    sweep["trials"][0]["metric_value"] = 0.5
    _write(sweep_path, sweep)
    with pytest.raises(q15.Q15Error, match="below the permitted 5% plateau"):
        _run(paths)


def test_q15_rejects_wrong_backtest_risk_mode(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    Path(paths["q02_set"]).write_text(
        "RISK_FIXED=0\nRISK_PERCENT=1\nstrategy_opt_enabled=true\nstrategy_exit_hour=19\n",
        encoding="utf-8",
    )
    with pytest.raises(q15.Q15Error, match="RISK_FIXED=1000 and RISK_PERCENT=0"):
        _run(paths)


def test_q15_hermetic_fixture_ignores_user_profile_paths(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    paths = _fixture(tmp_path)
    monkeypatch.setenv("APPDATA", str(tmp_path / "nonexistent-system-profile"))
    monkeypatch.setenv("LOCALAPPDATA", str(tmp_path / "nonexistent-system-local-profile"))
    result = _run(paths)
    assert result["dry_run"] is True
    assert result["challenger_ea_id"] == "QM5_20301"
