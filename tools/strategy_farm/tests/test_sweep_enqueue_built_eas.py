from __future__ import annotations

import csv
import hashlib
import json
import os
import sqlite3
import subprocess
import sys
from pathlib import Path

from tools.strategy_farm import agent_router, farmctl


REPO = Path(__file__).resolve().parents[3]
SWEEP = REPO / "tools" / "strategy_farm" / "sweep_enqueue_built_eas.py"
SWEEP_SUBPROCESS_TIMEOUT_SEC = 180


def _init_test_db(farm_root: Path) -> None:
    farmctl.init_db(farm_root)
    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        agent_router.init_schema(conn)


def test_never_tested_sweep_enqueues_one_logical_basket_item(
    tmp_path: Path,
) -> None:
    farm_root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    report_root = tmp_path / "reports"
    ea_id = "QM5_9001"
    ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_fxpair"
    sets_dir = ea_dir / "sets"
    registry = repo_root / "framework" / "registry" / "ea_id_registry.csv"
    sets_dir.mkdir(parents=True)
    registry.parent.mkdir(parents=True)
    report_root.joinpath("state").mkdir(parents=True)

    (ea_dir / f"{ea_dir.name}.ex5").write_text("compiled\n", encoding="utf-8")
    logical_symbol = "QM5_9001_GBPUSD_USDCHF_COINTEGRATION_D1"
    manifest = {
        "logical_symbol": logical_symbol,
        "host_symbol": "GBPUSD.DWX",
        "host_timeframe": "D1",
        "tester_currency": "USD",
        "tester_deposit": 100000,
        "basket_symbols": ["GBPUSD.DWX", "USDCHF.DWX"],
    }
    manifest_path = ea_dir / "basket_manifest.json"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    logical_setfile = (
        sets_dir / f"{ea_dir.name}_{logical_symbol}_D1_backtest.set"
    )
    logical_setfile.write_text("; logical basket\n", encoding="utf-8")
    physical_setfile = (
        sets_dir / f"{ea_dir.name}_GBPUSD.DWX_D1_backtest.set"
    )
    physical_setfile.write_text("; legacy physical host\n", encoding="utf-8")

    with registry.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["ea_id", "slug", "status"],
        )
        writer.writeheader()
        writer.writerow({"ea_id": "9001", "slug": "fxpair", "status": "active"})

    _init_test_db(farm_root)
    env = os.environ.copy()
    env.update({
        "QM_STRATEGY_FARM_ROOT": str(farm_root),
        "QM_CANONICAL_REPO_ROOT": str(repo_root),
        "QM_REPORT_ROOT": str(report_root),
    })
    result = subprocess.run(
        [sys.executable, str(SWEEP), "--apply", "--ea", ea_id],
        cwd=REPO,
        env=env,
        capture_output=True,
        text=True,
        timeout=SWEEP_SUBPROCESS_TIMEOUT_SEC,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        rows = conn.execute(
            """
            SELECT symbol, setfile_path, payload_json
            FROM work_items
            WHERE ea_id=? AND phase='Q02'
            """,
            (ea_id,),
        ).fetchall()

    assert len(rows) == 1
    symbol, setfile_path, raw_payload = rows[0]
    assert symbol == logical_symbol
    assert Path(setfile_path) == logical_setfile.resolve()
    payload = json.loads(raw_payload)
    assert payload["host_symbol"] == "GBPUSD.DWX"
    assert payload["host_timeframe"] == "D1"
    assert payload["logical_symbol"] == logical_symbol
    assert payload["portfolio_scope"] == "basket"
    assert payload["basket_manifest"] == str(manifest_path.resolve())
    assert payload["tester_currency"] == "USD"
    assert payload["priority_track"] is True
    assert payload["timeout_min"] == farmctl.BASKET_Q02_ACTIVE_TIMEOUT_MIN

    report = json.loads(
        (report_root / "state" / "claude_sweep_enqueue_2026-06-10.json")
        .read_text(encoding="utf-8")
    )
    assert report["part1_never_tested"]["enqueued"] == [{
        "ea_id": ea_id,
        "symbol": logical_symbol,
        "setfile": logical_setfile.name,
        "priority_track": True,
    }]
    assert any(
        row.get("reason") == "basket_manifest_logical_setfile_preferred"
        and row.get("setfile") == physical_setfile.name
        for row in report["part1_never_tested"]["skipped"]
    )


def test_never_tested_sweep_enqueues_only_liquid_canary_with_priority(
    tmp_path: Path,
) -> None:
    farm_root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    report_root = tmp_path / "reports"
    ea_id = "QM5_9002"
    ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_multisym"
    sets_dir = ea_dir / "sets"
    registry = repo_root / "framework" / "registry" / "ea_id_registry.csv"
    sets_dir.mkdir(parents=True)
    registry.parent.mkdir(parents=True)
    report_root.joinpath("state").mkdir(parents=True)

    (ea_dir / f"{ea_dir.name}.ex5").write_text("compiled\n", encoding="utf-8")
    for symbol in ("EURUSD.DWX", "GBPUSD.DWX"):
        (sets_dir / f"{ea_dir.name}_{symbol}_H1_backtest.set").write_text(
            "; first Q02 cohort\n",
            encoding="utf-8",
        )

    with registry.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["ea_id", "slug", "status"])
        writer.writeheader()
        writer.writerow({"ea_id": "9002", "slug": "multisym", "status": "active"})

    _init_test_db(farm_root)
    env = os.environ.copy()
    env.update({
        "QM_STRATEGY_FARM_ROOT": str(farm_root),
        "QM_CANONICAL_REPO_ROOT": str(repo_root),
        "QM_REPORT_ROOT": str(report_root),
    })
    result = subprocess.run(
        [sys.executable, str(SWEEP), "--apply", "--ea", ea_id],
        cwd=REPO,
        env=env,
        capture_output=True,
        text=True,
        timeout=SWEEP_SUBPROCESS_TIMEOUT_SEC,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        payloads = [
            json.loads(row[0])
            for row in conn.execute(
                "SELECT payload_json FROM work_items WHERE ea_id=? AND phase='Q02'",
                (ea_id,),
            ).fetchall()
        ]

    assert len(payloads) == 1
    assert payloads[0]["host_symbol"] == "EURUSD.DWX"
    assert payloads[0]["priority_track"] is True
    assert payloads[0]["q02_fanout_canary"] is True
    assert payloads[0]["q02_fanout_canary_index"] == 1

    deferred_state = json.loads(
        (farm_root / "state" / "q02_deferred_symbols.json").read_text(
            encoding="utf-8"
        )
    )
    assert deferred_state[ea_id]["canary_symbols"] == ["EURUSD.DWX"]
    assert [
        row["symbol"] for row in deferred_state[ea_id]["setfiles"]
    ] == ["GBPUSD.DWX"]


def test_apply_preserves_new_deferral_when_sidecar_was_already_nonempty(
    tmp_path: Path,
) -> None:
    farm_root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    report_root = tmp_path / "reports"
    ea_id = "QM5_9004"
    ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_multisym"
    sets_dir = ea_dir / "sets"
    registry = repo_root / "framework" / "registry" / "ea_id_registry.csv"
    sets_dir.mkdir(parents=True)
    registry.parent.mkdir(parents=True)
    report_root.joinpath("state").mkdir(parents=True)

    (ea_dir / f"{ea_dir.name}.ex5").write_text("compiled\n", encoding="utf-8")
    symbols = (
        "AUDUSD.DWX",
        "EURUSD.DWX",
        "GBPJPY.DWX",
        "GBPUSD.DWX",
        "USDJPY.DWX",
    )
    for symbol in symbols:
        (sets_dir / f"{ea_dir.name}_{symbol}_D1_backtest.set").write_text(
            "; staged Q02 cohort\n",
            encoding="utf-8",
        )

    with registry.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["ea_id", "slug", "status"])
        writer.writeheader()
        writer.writerow({"ea_id": "9004", "slug": "multisym", "status": "active"})

    _init_test_db(farm_root)
    deferred_file = farm_root / "state" / "q02_deferred_symbols.json"
    deferred_file.write_text(
        json.dumps({
            "QM5_8999": {
                "setfiles": [{
                    "setfile": str(tmp_path / "missing.set"),
                    "symbol": "EURCHF.DWX",
                    "tf": "D1",
                }],
                "source": "fixture",
                "deferred_at": "2026-08-01T00:00:00+00:00",
            }
        }),
        encoding="utf-8",
    )

    env = os.environ.copy()
    env.update({
        "QM_STRATEGY_FARM_ROOT": str(farm_root),
        "QM_CANONICAL_REPO_ROOT": str(repo_root),
        "QM_REPORT_ROOT": str(report_root),
    })
    result = subprocess.run(
        [sys.executable, str(SWEEP), "--apply", "--ea", ea_id],
        cwd=REPO,
        env=env,
        capture_output=True,
        text=True,
        timeout=SWEEP_SUBPROCESS_TIMEOUT_SEC,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        q02_count = conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE ea_id=? AND phase='Q02'",
            (ea_id,),
        ).fetchone()[0]
    assert q02_count == 1

    deferred_state = json.loads(deferred_file.read_text(encoding="utf-8"))
    assert ea_id in deferred_state
    assert deferred_state[ea_id]["priority_track"] is True
    assert deferred_state[ea_id]["q02_cohort_size"] == 5
    assert {
        row["symbol"] for row in deferred_state[ea_id]["setfiles"]
    } == {"AUDUSD.DWX", "GBPJPY.DWX", "GBPUSD.DWX", "USDJPY.DWX"}
    assert deferred_state[ea_id]["canary_symbols"] == ["EURUSD.DWX"]


def test_heterogeneous_canaries_release_deferred_symbol_in_apply_mode(
    tmp_path: Path,
) -> None:
    farm_root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    report_root = tmp_path / "reports"
    ea_id = "QM5_9005"
    eas_dir = repo_root / "framework" / "EAs"
    registry = repo_root / "framework" / "registry" / "ea_id_registry.csv"
    deferred_setfile = (
        tmp_path / "QM5_9005_multisym_USDJPY.DWX_D1_backtest.set"
    )
    eas_dir.mkdir(parents=True)
    registry.parent.mkdir(parents=True)
    report_root.joinpath("state").mkdir(parents=True)
    registry.write_text("ea_id,slug,status\n", encoding="utf-8")
    deferred_setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")

    _init_test_db(farm_root)
    build_task_id = "build-9005"
    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        for work_item_id, symbol, verdict in (
            ("canary-zero", "EURUSD.DWX", "ZERO_TRADES"),
            ("canary-pass", "GBPUSD.DWX", "PASS"),
        ):
            conn.execute(
                """
                INSERT INTO work_items(
                    id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                    attempt_count,payload_json,created_at,updated_at
                ) VALUES(?, 'backtest', 'Q02', ?, ?, ?, 'done', ?, 0, ?, ?, ?)
                """,
                (
                    work_item_id,
                    ea_id,
                    symbol,
                    str(tmp_path / f"{symbol}.set"),
                    verdict,
                    json.dumps({
                        "build_task_id": build_task_id,
                        "verdict_reason": (
                            "Q02_ZERO_TRADES" if verdict == "ZERO_TRADES" else "OK"
                        ),
                    }),
                    "2026-08-21T08:00:00+00:00",
                    "2026-08-21T09:00:00+00:00",
                ),
            )
        conn.commit()

    deferred_file = farm_root / "state" / "q02_deferred_symbols.json"
    deferred_file.write_text(
        json.dumps({
            ea_id: {
                "setfiles": [{
                    "setfile": str(deferred_setfile),
                    "symbol": "USDJPY.DWX",
                    "tf": "D1",
                }],
                "source": "fixture",
                "deferred_at": "2026-08-21T07:59:00+00:00",
                "build_task_id": build_task_id,
                "canary_symbols": ["EURUSD.DWX", "GBPUSD.DWX"],
                "fanout_policy": farmctl.Q02_CANARY_FANOUT_POLICY,
                "fanout_state": "AWAITING_CONFIRMATION",
            }
        }),
        encoding="utf-8",
    )

    env = os.environ.copy()
    env.update({
        "QM_STRATEGY_FARM_ROOT": str(farm_root),
        "QM_CANONICAL_REPO_ROOT": str(repo_root),
        "QM_REPORT_ROOT": str(report_root),
    })
    result = subprocess.run(
        [sys.executable, str(SWEEP), "--apply", "--ea", ea_id],
        cwd=REPO,
        env=env,
        capture_output=True,
        text=True,
        timeout=SWEEP_SUBPROCESS_TIMEOUT_SEC,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        promoted = conn.execute(
            "SELECT symbol,payload_json FROM work_items "
            "WHERE ea_id=? AND status='pending'",
            (ea_id,),
        ).fetchone()
    assert promoted is not None
    assert promoted[0] == "USDJPY.DWX"
    promoted_payload = json.loads(promoted[1])
    assert promoted_payload["promotion_reason"] == "economic_or_heterogeneous_canary"
    assert promoted_payload["q02_fanout_canary"] is False

    assert ea_id not in json.loads(deferred_file.read_text(encoding="utf-8"))
    report = json.loads(
        (report_root / "state" / "claude_sweep_enqueue_2026-06-10.json")
        .read_text(encoding="utf-8")
    )
    assert report["part3_deferred_promotion"]["stopped"] == []
    assert report["part3_deferred_promotion"]["promoted"] == [{
        "ea_id": ea_id,
        "symbol": "USDJPY.DWX",
        "reason": "economic_or_heterogeneous_canary",
    }]


def test_part2_requeues_terminal_failed_logical_basket_with_auditable_source(
    tmp_path: Path,
) -> None:
    farm_root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    report_root = tmp_path / "reports"
    ea_id = "QM5_9003"
    ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_basket"
    sets_dir = ea_dir / "sets"
    registry = repo_root / "framework" / "registry" / "ea_id_registry.csv"
    sets_dir.mkdir(parents=True)
    registry.parent.mkdir(parents=True)
    report_root.joinpath("state").mkdir(parents=True)

    logical_symbol = "QM5_9003_XAU_XAG_FIXTURE_D1"
    manifest = {
        "logical_symbol": logical_symbol,
        "host_symbol": "XAUUSD.DWX",
        "host_timeframe": "D1",
        "basket_symbols": ["XAUUSD.DWX", "XAGUSD.DWX"],
        "tester_currency": "USD",
        "tester_deposit": 100000,
    }
    manifest_path = ea_dir / "basket_manifest.json"
    manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
    setfile = sets_dir / f"{ea_dir.name}_{logical_symbol}_D1_backtest.set"
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    with registry.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["ea_id", "slug", "status"])
        writer.writeheader()
        writer.writerow({"ea_id": "9003", "slug": "basket", "status": "active"})

    _init_test_db(farm_root)
    source_id = "terminal-failed-basket"
    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
                id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                attempt_count,payload_json,created_at,updated_at
            ) VALUES(?, 'backtest', 'Q02', ?, ?, ?, 'failed', 'INFRA_FAIL',
                     0, ?, '2026-08-06T00:00:00+00:00',
                     '2026-08-06T01:00:00+00:00')
            """,
            (
                source_id,
                ea_id,
                logical_symbol,
                str(setfile.resolve()),
                json.dumps({
                    "basket_manifest": str(manifest_path.resolve()),
                    "portfolio_scope": "basket",
                    "priority_track": True,
                }),
            ),
        )
        conn.commit()

    env = os.environ.copy()
    env.update({
        "QM_STRATEGY_FARM_ROOT": str(farm_root),
        "QM_CANONICAL_REPO_ROOT": str(repo_root),
        "QM_REPORT_ROOT": str(report_root),
    })
    result = subprocess.run(
        [
            sys.executable,
            str(SWEEP),
            "--apply",
            "--ea",
            ea_id,
            "--max-part2-per-run",
            "1",
        ],
        cwd=REPO,
        env=env,
        capture_output=True,
        text=True,
        timeout=SWEEP_SUBPROCESS_TIMEOUT_SEC,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr

    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            "SELECT * FROM work_items WHERE ea_id=? AND status='pending'",
            (ea_id,),
        ).fetchone()
    assert row is not None
    payload = json.loads(row["payload_json"])
    assert payload["logical_symbol"] == logical_symbol
    assert payload["host_symbol"] == "XAUUSD.DWX"
    assert payload["portfolio_scope"] == "basket"
    assert payload["priority_track"] is True
    assert payload["timeout_min"] == farmctl.BASKET_Q02_ACTIVE_TIMEOUT_MIN
    assert payload["requeue_source"] == {
        "work_item_id": source_id,
        "status": "failed",
        "verdict": "INFRA_FAIL",
        "updated_at": "2026-08-06T01:00:00+00:00",
    }
    report = json.loads(
        (report_root / "state" / "claude_sweep_enqueue_2026-06-10.json")
        .read_text(encoding="utf-8")
    )
    assert report["part2_stranded"]["enqueued"] == [{
        "ea_id": ea_id,
        "phase": "Q02",
        "symbol": logical_symbol,
        "setfile": setfile.name,
        "work_item_id": row["id"],
        "source_work_item_id": source_id,
        "source_status": "failed",
        "logical_basket": True,
        "reason": "stranded_infra_fail",
    }]


def test_part2_refuses_terminal_disposition_and_historical_phase(
    tmp_path: Path,
) -> None:
    farm_root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    report_root = tmp_path / "reports"
    registry = repo_root / "framework" / "registry" / "ea_id_registry.csv"
    registry.parent.mkdir(parents=True)
    report_root.joinpath("state").mkdir(parents=True)

    fixtures = {}
    for ea_id, slug in (
        ("QM5_9005", "terminal-disposition"),
        ("QM5_9006", "historical-phase"),
    ):
        ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_{slug}"
        sets_dir = ea_dir / "sets"
        sets_dir.mkdir(parents=True)
        setfile = sets_dir / f"{ea_dir.name}_EURUSD.DWX_D1_backtest.set"
        setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
        fixtures[ea_id] = setfile.resolve()

    with registry.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["ea_id", "slug", "status"])
        writer.writeheader()
        writer.writerow({"ea_id": "9005", "slug": "terminal-disposition", "status": "active"})
        writer.writerow({"ea_id": "9006", "slug": "historical-phase", "status": "active"})

    _init_test_db(farm_root)
    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        rows = [
            (
                "terminal-infra", "Q02", "QM5_9005", str(fixtures["QM5_9005"]),
                "failed", "INFRA_FAIL", "2026-08-01T00:00:00+00:00",
            ),
            (
                "terminal-retired", "Q02", "QM5_9005", str(fixtures["QM5_9005"]),
                "failed", "RETIRED_LOW_FREQ", "2026-08-02T00:00:00+00:00",
            ),
            (
                "historical-infra", "Q02", "QM5_9006", str(fixtures["QM5_9006"]),
                "failed", "INFRA_FAIL", "2026-08-01T00:00:00+00:00",
            ),
            (
                "advanced-q04", "Q04", "QM5_9006", str(fixtures["QM5_9006"]),
                "done", "PASS", "2026-08-02T00:00:00+00:00",
            ),
        ]
        for item_id, phase, ea_id, setfile, status, verdict, stamp in rows:
            conn.execute(
                """
                INSERT INTO work_items(
                    id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                    attempt_count,payload_json,created_at,updated_at
                ) VALUES(?, 'backtest', ?, ?, 'EURUSD.DWX', ?, ?, ?, 0, '{}', ?, ?)
                """,
                (item_id, phase, ea_id, setfile, status, verdict, stamp, stamp),
            )
        conn.commit()

    env = os.environ.copy()
    env.update({
        "QM_STRATEGY_FARM_ROOT": str(farm_root),
        "QM_CANONICAL_REPO_ROOT": str(repo_root),
        "QM_REPORT_ROOT": str(report_root),
    })
    result = subprocess.run(
        [
            sys.executable,
            str(SWEEP),
            "--apply",
            "--ea",
            "QM5_9005,QM5_9006",
            "--max-part2-per-run",
            "10",
        ],
        cwd=REPO,
        env=env,
        capture_output=True,
        text=True,
        timeout=SWEEP_SUBPROCESS_TIMEOUT_SEC,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr

    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        pending = conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE status='pending'"
        ).fetchone()[0]
    assert pending == 0

    report = json.loads(
        (report_root / "state" / "claude_sweep_enqueue_2026-06-10.json")
        .read_text(encoding="utf-8")
    )
    assert report["part2_stranded"]["enqueued"] == []
    assert report["part2_stranded"]["rate_limited"] is False


def test_part2_requeues_q04_and_q07_but_preserves_infra_cap(
    tmp_path: Path,
) -> None:
    farm_root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    report_root = tmp_path / "reports"
    registry = repo_root / "framework" / "registry" / "ea_id_registry.csv"
    registry.parent.mkdir(parents=True)
    report_root.joinpath("state").mkdir(parents=True)

    fixtures = {}
    for ea_id, slug in (
        ("QM5_9007", "q04-recovery"),
        ("QM5_9008", "q07-recovery"),
        ("QM5_9009", "q07-capped"),
    ):
        ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_{slug}"
        sets_dir = ea_dir / "sets"
        sets_dir.mkdir(parents=True)
        setfile = sets_dir / f"{ea_dir.name}_EURUSD.DWX_D1_backtest.set"
        setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
        fixtures[ea_id] = setfile.resolve()

    with registry.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["ea_id", "slug", "status"])
        writer.writeheader()
        writer.writerow({"ea_id": "9007", "slug": "q04-recovery", "status": "active"})
        writer.writerow({"ea_id": "9008", "slug": "q07-recovery", "status": "active"})
        writer.writerow({"ea_id": "9009", "slug": "q07-capped", "status": "active"})

    _init_test_db(farm_root)
    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        rows = [
            ("q04-infra", "Q04", "QM5_9007", "2026-08-01T00:00:00+00:00"),
            ("q07-infra", "Q07", "QM5_9008", "2026-08-01T00:00:00+00:00"),
        ]
        rows.extend(
            (
                f"q07-capped-{attempt:02d}",
                "Q07",
                "QM5_9009",
                f"2026-08-{attempt + 1:02d}T00:00:00+00:00",
            )
            for attempt in range(12)
        )
        for item_id, phase, ea_id, stamp in rows:
            conn.execute(
                """
                INSERT INTO work_items(
                    id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                    attempt_count,payload_json,created_at,updated_at
                ) VALUES(?, 'backtest', ?, ?, 'EURUSD.DWX', ?, 'done',
                         'INFRA_FAIL', 0, '{}', ?, ?)
                """,
                (item_id, phase, ea_id, str(fixtures[ea_id]), stamp, stamp),
            )
        conn.commit()

    env = os.environ.copy()
    env.update({
        "QM_STRATEGY_FARM_ROOT": str(farm_root),
        "QM_CANONICAL_REPO_ROOT": str(repo_root),
        "QM_REPORT_ROOT": str(report_root),
    })
    result = subprocess.run(
        [
            sys.executable,
            str(SWEEP),
            "--apply",
            "--ea",
            "QM5_9007,QM5_9008,QM5_9009",
            "--max-part2-per-run",
            "10",
        ],
        cwd=REPO,
        env=env,
        capture_output=True,
        text=True,
        timeout=SWEEP_SUBPROCESS_TIMEOUT_SEC,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr

    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        pending = conn.execute(
            "SELECT ea_id,phase FROM work_items WHERE status='pending' ORDER BY ea_id"
        ).fetchall()
    assert pending == [("QM5_9007", "Q04"), ("QM5_9008", "Q07")]

    report = json.loads(
        (report_root / "state" / "claude_sweep_enqueue_2026-06-10.json")
        .read_text(encoding="utf-8")
    )
    assert {
        (row["ea_id"], row["phase"])
        for row in report["part2_stranded"]["enqueued"]
    } == {("QM5_9007", "Q04"), ("QM5_9008", "Q07")}
    assert any(
        row.get("ea_id") == "QM5_9009"
        and row.get("phase") == "Q07"
        and row.get("reason") == "infra_retry_cap_reached"
        and row.get("attempts") == 12
        for row in report["part2_stranded"]["skipped"]
    )


def test_q08_stranded_retry_carries_hash_pinned_requal_lineage(
    tmp_path: Path,
) -> None:
    farm_root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    report_root = tmp_path / "reports"
    ea_id = "QM5_10582"
    symbol = "XAUUSD.DWX"
    ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_fixture"
    sets_dir = ea_dir / "sets"
    registry = repo_root / "framework" / "registry" / "ea_id_registry.csv"
    sets_dir.mkdir(parents=True)
    registry.parent.mkdir(parents=True)
    report_root.joinpath("state").mkdir(parents=True)

    setfiles = []
    bindings = []
    for index in range(3):
        path = sets_dir / f"fixture_ablation_{index:02d}.set"
        path.write_text(f"strategy_period={20 + index}\n", encoding="utf-8")
        setfiles.append(path)
        bindings.append({
            "role": f"setfile_ablation_{index:02d}",
            "path": str(path.resolve()),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "bytes": path.stat().st_size,
            "sha256_basis": "RAW_BYTES",
        })

    with registry.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["ea_id", "slug", "status"])
        writer.writeheader()
        writer.writerow({"ea_id": "10582", "slug": "fixture", "status": "active"})

    archive = report_root / "work_items" / "old.requeued_20260727T0341290000"
    archive_leaf = archive / ea_id / "Q08" / symbol.replace(".", "_")
    archive_leaf.mkdir(parents=True)
    (archive_leaf / "aggregate.json").write_text(
        '{"verdict":"INVALID"}\n', encoding="utf-8"
    )
    (archive_leaf / "8_5_neighborhood.json").write_text(
        '{"status":"INVALID"}\n', encoding="utf-8"
    )

    _init_test_db(farm_root)
    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        old_payload = {
            "q08_single_target_requalification": {
                "archived_report_root": str(archive.resolve()),
                "artifact_bindings": bindings,
            }
        }
        rows = [
            (
                "old", json.dumps(old_payload), "2026-07-27T00:00:00Z",
                str(archive_leaf / "aggregate.json"),
            ),
            ("latest-failed", "{}", "2026-08-02T00:00:00Z", None),
        ]
        for item_id, payload, stamp, evidence_path in rows:
            conn.execute(
                """
                INSERT INTO work_items(
                    id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                    attempt_count,evidence_path,payload_json,created_at,updated_at
                ) VALUES(?, 'backtest', 'Q08', ?, ?, ?, 'done', 'INFRA_FAIL',
                         0, ?, ?, ?, ?)
                """,
                (
                    item_id, ea_id, symbol, str(setfiles[0]), evidence_path,
                    payload, stamp, stamp,
                ),
            )
        conn.commit()

    env = os.environ.copy()
    env.update({
        "QM_STRATEGY_FARM_ROOT": str(farm_root),
        "QM_CANONICAL_REPO_ROOT": str(repo_root),
        "QM_REPORT_ROOT": str(report_root),
    })
    result = subprocess.run(
        [
            sys.executable,
            str(SWEEP),
            "--apply",
            "--ea",
            ea_id,
            "--max-infra-attempts",
            "20",
        ],
        cwd=REPO,
        env=env,
        capture_output=True,
        text=True,
        timeout=SWEEP_SUBPROCESS_TIMEOUT_SEC,
        check=False,
    )

    assert result.returncode == 0, result.stdout + result.stderr
    with sqlite3.connect(farm_root / farmctl.DB_REL) as conn:
        pending = conn.execute(
            "SELECT id,payload_json FROM work_items WHERE phase='Q08' AND status='pending'"
        ).fetchall()
    assert len(pending) == 1
    new_id, raw_payload = pending[0]
    payload = json.loads(raw_payload)
    lineage = payload["q08_recovery_lineage"]
    assert lineage["retry_source_work_item_id"] == "latest-failed"
    assert lineage["lineage_source_work_item_id"] == "old"
    assert all(row["sha256"] for row in lineage["artifact_bindings"])

    report = json.loads(
        (report_root / "state" / "claude_sweep_enqueue_2026-06-10.json")
        .read_text(encoding="utf-8")
    )
    assert report["part2_stranded"]["enqueued"][0]["work_item_id"] == new_id
