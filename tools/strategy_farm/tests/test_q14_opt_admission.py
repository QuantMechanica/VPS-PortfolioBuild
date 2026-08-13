from __future__ import annotations

import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from framework.scripts import q14_opt_admission as q14
from framework.scripts import q16_head_to_head as q16
from tools.strategy_farm import farmctl


def _database(path: Path) -> Path:
    conn = sqlite3.connect(path)
    conn.executescript(
        """
        CREATE TABLE work_items (
            id TEXT PRIMARY KEY,
            kind TEXT NOT NULL,
            phase TEXT NOT NULL,
            ea_id TEXT NOT NULL,
            symbol TEXT NOT NULL,
            setfile_path TEXT NOT NULL,
            status TEXT NOT NULL,
            verdict TEXT,
            attempt_count INTEGER NOT NULL DEFAULT 0,
            parent_task_id TEXT,
            evidence_path TEXT,
            claimed_by TEXT,
            payload_json TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        CREATE TABLE ea_metrics (
            work_item_id TEXT PRIMARY KEY,
            ea_id TEXT,
            phase TEXT,
            symbol TEXT,
            verdict TEXT,
            status TEXT,
            net_profit REAL,
            profit_factor REAL,
            trades INTEGER,
            drawdown_money REAL,
            drawdown_pct REAL,
            sharpe REAL,
            detail_json TEXT,
            source TEXT,
            evidence_path TEXT,
            evidence_mtime REAL,
            extracted_at TEXT,
            is_ablation INTEGER,
            parent_work_item_id TEXT
        );
        """
    )
    conn.close()
    return path


def _parent_files(repo: Path, ea_number: int, symbol: str, *, good_risk: bool = True) -> tuple[Path, Path, Path]:
    slug = f"QM5_{ea_number}_fixture"
    ea_dir = repo / "framework" / "EAs" / slug
    sets = ea_dir / "sets"
    sets.mkdir(parents=True, exist_ok=True)
    setfile = sets / f"{slug}_{symbol}_H1_backtest.set"
    risk_fixed = 1000 if good_risk else 1001
    setfile.write_text(f"RISK_FIXED={risk_fixed}\nRISK_PERCENT=0\n", encoding="utf-8")
    binary = ea_dir / f"{slug}.ex5"
    binary.write_bytes(f"binary-{ea_number}".encode())
    evidence = repo / "evidence" / f"{ea_number}_{symbol}.json"
    evidence.parent.mkdir(parents=True, exist_ok=True)
    evidence.write_text('{"verdict":"PASS"}\n', encoding="utf-8")
    return setfile, binary, evidence


def _insert_q10(
    db: Path,
    repo: Path,
    ea_number: int,
    symbol: str,
    *,
    trades: int | None,
    drawdown: float | None,
    updated_at: str = "2026-08-12T01:00:00+00:00",
    suffix: str = "a",
    good_risk: bool = True,
) -> str:
    setfile, _, evidence = _parent_files(repo, ea_number, symbol, good_risk=good_risk)
    item_id = f"q10-{ea_number}-{symbol}-{suffix}"
    conn = sqlite3.connect(db)
    conn.execute(
        """
        INSERT INTO work_items(
          id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
          parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at
        ) VALUES(?, 'backtest','Q10',?,?,?,'done','PASS',0,NULL,?,NULL,'{}',?,?)
        """,
        (item_id, f"QM5_{ea_number}", f"{symbol}.DWX", str(setfile), str(evidence), updated_at, updated_at),
    )
    conn.execute(
        """
        INSERT INTO ea_metrics(
          work_item_id,ea_id,phase,symbol,verdict,status,trades,drawdown_pct,
          detail_json,is_ablation
        ) VALUES(?,?,'Q10',?,'PASS','done',?,?,'{}',0)
        """,
        (item_id, f"QM5_{ea_number}", f"{symbol}.DWX", trades, drawdown),
    )
    conn.commit()
    conn.close()
    return item_id


def _success() -> dict[str, object]:
    return {
        "primary": "return_to_maxdd",
        "direction": "MAXIMIZE",
        "minimum_improvement": 0,
        "require_maxdd_not_worse": True,
        "require_worst_day_not_worse": True,
    }


def _surface(name: str = "strategy_test") -> dict[str, object]:
    return {
        "fixed_parameters": {},
        "parameters": [{
            "name": name,
            "type": "number",
            "incumbent": 1,
            "candidate_values": [1.1, 1.2],
            "bounds": {"minimum": 1, "maximum": 1.2},
        }],
    }


def _categorical_surface() -> dict[str, object]:
    return {
        "surface_type": "CATEGORICAL",
        "fixed_parameters": {"strategy_opt_enabled": True},
        "parameters": [],
        "minimum_dev_fire_count": 30,
        "predicate_trials": [
            {"predicate_id": "QM_PP_DOJI", "direction": "buy"},
            {"predicate_id": "QM_PP_HAMMER", "direction": "SELL"},
        ],
    }


def _program(cohort: list[dict[str, object]], *, max_cards: int = 12, max_parent: int = 2) -> dict[str, object]:
    return {
        "schema": "qm.opt-program/v1",
        "program_id": "FIXTURE_V1",
        "risk_contract": {"RISK_FIXED": 1000, "RISK_PERCENT": 0},
        "caps": {"max_concurrent_opt_cards": max_cards, "max_cards_per_parent": max_parent},
        "comparison_windows": [
            {"id": "F1", "kind": "Q04_ANCHORED_OOS", "start": "2023-01-01", "end": "2023-12-31"},
            {"id": "F2", "kind": "Q04_ANCHORED_OOS", "start": "2024-01-01", "end": "2024-12-31"},
            {"id": "F3", "kind": "Q04_ANCHORED_OOS", "start": "2025-01-01", "end": "2025-12-31"},
            {"id": "H1", "kind": "POST_DEV_HOLDOUT", "start": "2026-01-01", "end": "2026-07-31"},
        ],
        "levers": {
            "LOCKED_PORT": {"enabled": True, "order": 5, "carrier_list_required": True, "success_metric": _success()},
            "EXIT_SURGERY": {"enabled": True, "order": 10, "min_trades": 60, "success_metric": _success()},
            "VOL_REGIME_FILTER": {
                "enabled": True, "order": 20, "min_trades": 150,
                "min_max_drawdown_pct": 12, "success_metric": _success(),
            },
            "PREDICATE_ABLATION": {"enabled": True, "order": 25, "success_metric": _success()},
            "MTF_ENTRY": {"enabled": True, "order": 30, "backlog_only": True, "success_metric": _success()},
        },
        "surface_profiles": {
            "exit": _surface("strategy_exit"),
            "vol": _surface("strategy_vol_ratio"),
            "mtf": _surface("strategy_mtf_window"),
            "port": {"fixed_parameters": {"parent_parameters_locked": True}, "parameters": []},
        },
        "cohort_freeze": cohort,
    }


def _write_program(path: Path, body: dict[str, object]) -> Path:
    path.write_text(json.dumps(body, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return path


def _cohort(ea_number: int, symbol: str, levers: dict[str, dict[str, object]], *, priority: int = 1) -> dict[str, object]:
    return {"ea_id": f"QM5_{ea_number}", "symbol": f"{symbol}.DWX", "priority": priority, "levers": levers}


def test_dry_run_is_deterministic_and_uses_latest_distinct_q10(tmp_path: Path) -> None:
    db = _database(tmp_path / "farm.sqlite")
    repo = tmp_path / "repo"
    _insert_q10(db, repo, 20001, "EURUSD", trades=59, drawdown=20, updated_at="2026-08-11T00:00:00+00:00", suffix="old")
    latest_id = _insert_q10(db, repo, 20001, "EURUSD", trades=60, drawdown=20, updated_at="2026-08-12T00:00:00+00:00", suffix="new")
    config = _write_program(tmp_path / "program.json", _program([
        _cohort(20001, "EURUSD", {"EXIT_SURGERY": {"surface_profile": "exit", "hypothesis": "Later exit captures continuation."}})
    ]))
    reports = tmp_path / "reports"

    first = q14.run_admission(db_path=db, config_path=config, repo_root=repo, report_root=reports)
    second = q14.run_admission(db_path=db, config_path=config, repo_root=repo, report_root=reports)

    assert first == second
    assert first["source_q10_pass_pairs"] == 1
    assert first["counts"] == {"OPT_ELIGIBLE": 1, "OPT_REJECTED": 0}
    assert first["decisions"][0]["source_q10_work_item_id"] == latest_id
    assert not reports.exists()


def test_categorical_predicate_surface_is_deterministic_and_emits_named_trials(tmp_path: Path) -> None:
    db = _database(tmp_path / "farm.sqlite")
    repo = tmp_path / "repo"
    _insert_q10(db, repo, 20008, "EURUSD", trades=200, drawdown=8)
    config = _write_program(tmp_path / "program.json", _program([
        _cohort(20008, "EURUSD", {
            "PREDICATE_ABLATION": {
                "parameter_surface": _categorical_surface(),
                "hypothesis": "Named blacklist predicates reduce weak entries without numeric ordering.",
            },
        }),
    ]))
    reports = tmp_path / "reports"

    first = q14.run_admission(db_path=db, config_path=config, repo_root=repo, report_root=reports)
    second = q14.run_admission(db_path=db, config_path=config, repo_root=repo, report_root=reports)

    assert first == second
    decision = first["decisions"][0]
    assert decision["verdict"] == "OPT_ELIGIBLE"
    assert decision["reason"] == "PREDICATE_ABLATION_Q10_PASS"
    normalized_surface, planned_trials = q14._surface(
        {"parameter_surface": _categorical_surface()}, "PREDICATE_ABLATION"
    )
    assert normalized_surface == {
        "surface_type": "CATEGORICAL",
        "fixed_parameters": {"strategy_opt_enabled": True},
        "parameters": [],
        "minimum_dev_fire_count": 30,
        "predicate_trials": [
            {"predicate_id": "QM_PP_DOJI", "direction": "BUY"},
            {"predicate_id": "QM_PP_HAMMER", "direction": "SELL"},
        ],
    }
    assert planned_trials == [
        {"trial_id": "T001", "predicate_id": "QM_PP_DOJI", "direction": "BUY"},
        {"trial_id": "T002", "predicate_id": "QM_PP_HAMMER", "direction": "SELL"},
    ]
    assert not reports.exists()


def test_numeric_surface_still_rejects_named_candidates() -> None:
    surface = _surface()
    parameter = surface["parameters"][0]
    assert isinstance(parameter, dict)
    parameter["candidate_values"] = ["QM_PP_DOJI", "QM_PP_HAMMER"]

    with pytest.raises(q14.Q14Error, match="bounds/values must be numeric"):
        q14._surface({"parameter_surface": surface}, "EXIT_SURGERY")


def test_opt_card_schema_declares_predicate_ablation() -> None:
    schema_path = Path(__file__).resolve().parents[1] / "config" / "opt_card.v1.schema.json"
    schema = json.loads(schema_path.read_text(encoding="utf-8"))

    assert "PREDICATE_ABLATION" in schema["properties"]["lever"]["enum"]


@pytest.mark.parametrize(
    ("lever", "trades", "drawdown", "expected", "reason"),
    [
        ("EXIT_SURGERY", 59, 20.0, "OPT_REJECTED", "TRADES_BELOW_60"),
        ("EXIT_SURGERY", 60, 1.0, "OPT_ELIGIBLE", "TRADES_GTE_60"),
        ("VOL_REGIME_FILTER", 149, 50.0, "OPT_REJECTED", "TRADES_BELOW_150"),
        ("VOL_REGIME_FILTER", 150, 11.999, "OPT_REJECTED", "MAX_DRAWDOWN_BELOW_12"),
        ("VOL_REGIME_FILTER", 150, 12.0, "OPT_ELIGIBLE", "TRADES_GTE_150_AND_MAX_DRAWDOWN_GTE_12"),
    ],
)
def test_binding_arithmetic_thresholds(
    tmp_path: Path, lever: str, trades: int, drawdown: float, expected: str, reason: str,
) -> None:
    db = _database(tmp_path / "farm.sqlite")
    repo = tmp_path / "repo"
    _insert_q10(db, repo, 20002, "GBPUSD", trades=trades, drawdown=drawdown)
    profile = "exit" if lever == "EXIT_SURGERY" else "vol"
    config = _write_program(tmp_path / "program.json", _program([
        _cohort(20002, "GBPUSD", {lever: {"surface_profile": profile, "hypothesis": "A predeclared mechanical test."}})
    ]))

    result = q14.run_admission(db_path=db, config_path=config, repo_root=repo, report_root=tmp_path / "reports")

    assert result["decisions"][0]["verdict"] == expected
    assert result["decisions"][0]["reason"] == reason


def test_locked_port_requires_carriers_and_mtf_stays_backlog(tmp_path: Path) -> None:
    db = _database(tmp_path / "farm.sqlite")
    repo = tmp_path / "repo"
    _insert_q10(db, repo, 20003, "USDJPY", trades=None, drawdown=None)
    config = _write_program(tmp_path / "program.json", _program([
        _cohort(20003, "USDJPY", {
            "LOCKED_PORT": {
                "surface_profile": "port", "hypothesis": "Frozen parameters transfer to declared carriers.",
                "carrier_list": ["EURJPY.DWX", "AUDJPY.DWX"],
            },
            "MTF_ENTRY": {"surface_profile": "mtf", "hypothesis": "Closed-bar trigger improves entry quality."},
        })
    ]))

    result = q14.run_admission(db_path=db, config_path=config, repo_root=repo, report_root=tmp_path / "reports")
    by_lever = {row["lever"]: row for row in result["decisions"]}

    assert by_lever["LOCKED_PORT"]["verdict"] == "OPT_ELIGIBLE"
    assert by_lever["MTF_ENTRY"]["verdict"] == "OPT_REJECTED"
    assert by_lever["MTF_ENTRY"]["reason"] == "BACKLOG_ONLY"

    body = json.loads(config.read_text(encoding="utf-8"))
    body["cohort_freeze"][0]["levers"]["LOCKED_PORT"].pop("carrier_list")
    missing = _write_program(tmp_path / "missing.json", body)
    rejected = q14.run_admission(db_path=db, config_path=missing, repo_root=repo, report_root=tmp_path / "reports2")
    assert {row["lever"]: row for row in rejected["decisions"]}["LOCKED_PORT"]["reason"] == "CARRIER_LIST_REQUIRED"


def test_global_and_parent_caps_are_fail_closed(tmp_path: Path) -> None:
    db = _database(tmp_path / "farm.sqlite")
    repo = tmp_path / "repo"
    _insert_q10(db, repo, 20004, "EURUSD", trades=200, drawdown=20)
    _insert_q10(db, repo, 20005, "GBPUSD", trades=200, drawdown=20)
    levers = {
        "EXIT_SURGERY": {"surface_profile": "exit", "hypothesis": "Exit hypothesis."},
        "VOL_REGIME_FILTER": {"surface_profile": "vol", "hypothesis": "Volatility hypothesis."},
    }
    config = _write_program(tmp_path / "program.json", _program([
        _cohort(20004, "EURUSD", levers, priority=1),
        _cohort(20005, "GBPUSD", levers, priority=2),
    ], max_cards=2, max_parent=2))

    result = q14.run_admission(db_path=db, config_path=config, repo_root=repo, report_root=tmp_path / "reports")

    assert [row["verdict"] for row in result["decisions"]] == [
        "OPT_ELIGIBLE", "OPT_ELIGIBLE", "OPT_REJECTED", "OPT_REJECTED",
    ]
    assert all(row["reason"] == "MAX_CONCURRENT_OPT_CARDS_2" for row in result["decisions"][2:])


def test_apply_writes_valid_immutable_card_open_ledger_and_idempotent_q14_row(tmp_path: Path) -> None:
    db = _database(tmp_path / "farm.sqlite")
    repo = tmp_path / "repo"
    _, binary, _ = _parent_files(repo, 20006, "AUDUSD")
    _insert_q10(db, repo, 20006, "AUDUSD", trades=100, drawdown=14)
    config = _write_program(tmp_path / "program.json", _program([
        _cohort(20006, "AUDUSD", {"EXIT_SURGERY": {"surface_profile": "exit", "hypothesis": "Later exit captures continuation."}})
    ]))
    reports = tmp_path / "reports"

    first = q14.run_admission(db_path=db, config_path=config, repo_root=repo, report_root=reports, apply=True)
    decision = first["decisions"][0]
    card_path = Path(decision["opt_card_path"])
    ledger_path = Path(decision["trial_ledger_path"])
    card = json.loads(card_path.read_text(encoding="utf-8"))
    ledger = json.loads(ledger_path.read_text(encoding="utf-8"))

    assert first["apply_result"] == {
        "created_opt_cards": 1,
        "created_trial_ledgers": 1,
        "created_q14_rows": 1,
        "idempotent_q14_rows": 0,
    }
    assert card["schema"] == "qm.opt-card/v1"
    assert card["parent"]["binary"]["sha256"] == hashlib.sha256(binary.read_bytes()).hexdigest()
    assert hashlib.sha256(card_path.read_bytes()).hexdigest() == decision["opt_card_sha256"]
    assert len(q16.load_windows(card)) == 4
    assert ledger["schema"] == "qm.opt-trial-ledger/v1"
    assert ledger["status"] == "OPENED"
    assert ledger["declared_trial_count"] == len(ledger["planned_trials"]) == 2
    assert ledger["trials"] == []
    assert not any(key.endswith("_at") for key in card)

    conn = sqlite3.connect(db)
    row = conn.execute("SELECT phase,status,verdict,kind,payload_json FROM work_items WHERE id=?", (decision["work_item_id"],)).fetchone()
    conn.close()
    assert row[:4] == ("Q14", "done", "OPT_ELIGIBLE", "analytic")
    assert json.loads(row[4])["card_id"] == decision["card_id"]

    second = q14.run_admission(db_path=db, config_path=config, repo_root=repo, report_root=reports, apply=True)
    assert second["apply_result"] == {
        "created_opt_cards": 0,
        "created_trial_ledgers": 0,
        "created_q14_rows": 0,
        "idempotent_q14_rows": 1,
    }


def test_bad_parent_risk_is_rejected_without_artifact(tmp_path: Path) -> None:
    db = _database(tmp_path / "farm.sqlite")
    repo = tmp_path / "repo"
    _insert_q10(db, repo, 20007, "USDCAD", trades=100, drawdown=20, good_risk=False)
    config = _write_program(tmp_path / "program.json", _program([
        _cohort(20007, "USDCAD", {"EXIT_SURGERY": {"surface_profile": "exit", "hypothesis": "Exit hypothesis."}})
    ]))
    reports = tmp_path / "reports"

    result = q14.run_admission(db_path=db, config_path=config, repo_root=repo, report_root=reports)

    assert result["decisions"][0]["verdict"] == "OPT_REJECTED"
    assert "RISK_FIXED=1000" in result["decisions"][0]["reason"]
    assert not reports.exists()


def test_farmctl_subcommand_is_dry_run_by_default_and_apply_is_mutating() -> None:
    parser = farmctl.build_parser()
    dry = parser.parse_args(["enqueue-opt-admission"])
    applied = parser.parse_args(["enqueue-opt-admission", "--apply"])
    compatibility = parser.parse_args(["admit-optimization"])

    assert dry.apply is False
    assert compatibility.apply is False
    assert farmctl._command_mutates_state(dry) is False
    assert farmctl._command_mutates_state(compatibility) is False
    assert farmctl._command_mutates_state(applied) is True
