import json
import sqlite3
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


def _artifacts(tmp_path: Path, monkeypatch, ea_id: str = "QM5_9901") -> dict[str, object]:
    root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_candidate"
    sets_dir = ea_dir / "sets"
    sets_dir.mkdir(parents=True)
    mq5 = ea_dir / f"{ea_dir.name}.mq5"
    ex5 = ea_dir / f"{ea_dir.name}.ex5"
    setfile = sets_dir / f"{ea_dir.name}_EURUSD.DWX_H1_backtest.set"
    mq5.write_text("// current source\n", encoding="utf-8")
    ex5.write_bytes(b"current compiled binary")
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    monkeypatch.setattr(farmctl, "REPO_ROOT", repo_root)
    farmctl.init_db(root)
    return {
        "root": root,
        "repo_root": repo_root,
        "ea_id": ea_id,
        "ea_dir": ea_dir,
        "mq5": mq5,
        "ex5": ex5,
        "setfile": setfile,
        "current_ex5": farmctl._sha256_file(ex5),
    }


def _payload(artifacts: dict[str, object], *, stale: bool) -> dict[str, object]:
    ea_dir = artifacts["ea_dir"]
    assert isinstance(ea_dir, Path)
    mq5 = artifacts["mq5"]
    ex5 = artifacts["ex5"]
    setfile = artifacts["setfile"]
    assert isinstance(mq5, Path)
    assert isinstance(ex5, Path)
    assert isinstance(setfile, Path)
    return {
        "expected_mq5_sha256": (
            "1" * 64 if stale else farmctl._sha256_file(mq5)
        ),
        "expected_ex5_sha256": (
            "2" * 64 if stale else farmctl._sha256_file(ex5)
        ),
        "expected_setfile_sha256": (
            "3" * 64 if stale else farmctl._sha256_file(setfile)
        ),
        "expected_symbol": "EURUSD.DWX",
        "expected_period": "H1",
        "expected_expert": f"QM\\{ea_dir.name}",
        "from_year": 2017,
        "to_year": 2022,
    }


def _insert_work_item(
    artifacts: dict[str, object],
    *,
    item_id: str,
    phase: str,
    status: str,
    verdict: str | None,
    payload: dict[str, object],
    symbol: str = "EURUSD.DWX",
    setfile: Path | None = None,
) -> Path:
    root = artifacts["root"]
    default_setfile = artifacts["setfile"]
    assert isinstance(root, Path)
    assert isinstance(default_setfile, Path)
    setfile = setfile or default_setfile
    evidence = root.parent / f"{item_id}.json"
    evidence.write_text('{"evidence":true}\n', encoding="utf-8")
    now = "2026-08-02T00:00:00Z"
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
                id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,
                created_at,updated_at
            ) VALUES(?, 'backtest', ?, ?, ?, ?, ?, ?, 0, NULL, ?, NULL, ?, ?, ?)
            """,
            (
                item_id,
                phase,
                artifacts["ea_id"],
                symbol,
                str(setfile),
                status,
                verdict,
                str(evidence),
                json.dumps(payload, sort_keys=True),
                now,
                now,
            ),
        )
        conn.commit()
    return evidence


def _work_item_count(artifacts: dict[str, object]) -> int:
    root = artifacts["root"]
    assert isinstance(root, Path)
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        return int(conn.execute("SELECT count(*) FROM work_items").fetchone()[0])


def test_stale_pass_q02_refuses_wrong_current_ex5_hash(tmp_path: Path, monkeypatch) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    _insert_work_item(
        art,
        item_id="q02-stale",
        phase="Q02",
        status="done",
        verdict="PASS",
        payload=_payload(art, stale=True),
    )

    result = farmctl.enqueue_cascade_backtest_for_ea(
        art["root"],
        art["ea_id"],
        "Q02",
        predecessor_work_item_id="q02-stale",
        append_only_rerun_of="q02-stale",
        rerun_reason="candidate repair",
        expected_current_ex5_sha256="f" * 64,
    )

    assert not result["enqueued"]
    assert result["reason"] == "current_ex5_hash_mismatch"
    assert _work_item_count(art) == 1


def test_stale_pass_q02_refuses_nonterminal_source(tmp_path: Path, monkeypatch) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    _insert_work_item(
        art,
        item_id="q02-active",
        phase="Q02",
        status="active",
        verdict=None,
        payload=_payload(art, stale=True),
    )

    result = farmctl.enqueue_cascade_backtest_for_ea(
        art["root"],
        art["ea_id"],
        "Q02",
        predecessor_work_item_id="q02-active",
        append_only_rerun_of="q02-active",
        rerun_reason="candidate repair",
        expected_current_ex5_sha256=art["current_ex5"],
    )

    assert not result["enqueued"]
    assert result["reason"] == "q02_rerun_target_mismatch_or_not_terminal_supported_verdict"
    assert _work_item_count(art) == 1


def test_stale_pass_q02_is_append_only_and_double_enqueue_safe(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    _insert_work_item(
        art,
        item_id="q02-stale",
        phase="Q02",
        status="done",
        verdict="PASS",
        payload=_payload(art, stale=True),
    )

    kwargs = {
        "predecessor_work_item_id": "q02-stale",
        "append_only_rerun_of": "q02-stale",
        "rerun_reason": "candidate repair",
        "expected_current_ex5_sha256": art["current_ex5"],
    }
    first = farmctl.enqueue_cascade_backtest_for_ea(
        art["root"], art["ea_id"], "Q02", **kwargs
    )
    repeat = farmctl.enqueue_cascade_backtest_for_ea(
        art["root"], art["ea_id"], "Q02", **kwargs
    )

    assert first["enqueued"]
    assert not repeat["enqueued"]
    assert repeat["skipped"][0]["reason"] == "append_only_rerun_already_exists"
    assert _work_item_count(art) == 2
    root = art["root"]
    assert isinstance(root, Path)
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        historical = conn.execute(
            "SELECT status,verdict FROM work_items WHERE id='q02-stale'"
        ).fetchone()
        new_payload = json.loads(
            conn.execute(
                "SELECT payload_json FROM work_items WHERE id=?",
                (first["created"][0]["id"],),
            ).fetchone()[0]
        )
    assert historical == ("done", "PASS")
    assert new_payload["stale_pass_rerun"] is True
    assert new_payload["rerun_source_current_ex5_mismatch_verified"] is True
    assert new_payload["expected_ex5_sha256"] == art["current_ex5"]
    assert new_payload["risk_fixed"] == 1000.0
    assert new_payload["risk_percent"] == 0.0


def test_q03_exact_identity_refuses_broad_fanout(tmp_path: Path, monkeypatch) -> None:
    art = _artifacts(tmp_path, monkeypatch)

    result = farmctl.enqueue_cascade_backtest_for_ea(
        art["root"],
        art["ea_id"],
        "Q03",
        expected_current_ex5_sha256=art["current_ex5"],
    )

    assert not result["enqueued"]
    assert result["reason"] == "q03_exact_identity_requires_exact_q02_predecessor"
    assert _work_item_count(art) == 0


def test_q03_append_only_refuses_nonmatching_target_identity(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    current_payload = _payload(art, stale=False)
    _insert_work_item(
        art,
        item_id="q02-current",
        phase="Q02",
        status="done",
        verdict="PASS",
        payload=current_payload,
    )
    _insert_work_item(
        art,
        item_id="q03-other-symbol",
        phase="Q03",
        status="done",
        verdict="PASS",
        payload=current_payload,
        symbol="GBPUSD.DWX",
    )

    result = farmctl.enqueue_cascade_backtest_for_ea(
        art["root"],
        art["ea_id"],
        "Q03",
        predecessor_work_item_id="q02-current",
        append_only_rerun_of="q03-other-symbol",
        rerun_reason="candidate repair",
        expected_current_ex5_sha256=art["current_ex5"],
    )

    assert not result["enqueued"]
    assert result["reason"] == "q03_append_only_target_identity_mismatch_or_not_terminal"
    assert _work_item_count(art) == 2


def test_q03_exact_identity_creates_only_one_bound_row(tmp_path: Path, monkeypatch) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    _insert_work_item(
        art,
        item_id="q02-current",
        phase="Q02",
        status="done",
        verdict="PASS",
        payload=_payload(art, stale=False),
    )

    first = farmctl.enqueue_cascade_backtest_for_ea(
        art["root"],
        art["ea_id"],
        "Q03",
        predecessor_work_item_id="q02-current",
        expected_current_ex5_sha256=art["current_ex5"],
    )
    repeat = farmctl.enqueue_cascade_backtest_for_ea(
        art["root"],
        art["ea_id"],
        "Q03",
        predecessor_work_item_id="q02-current",
        expected_current_ex5_sha256=art["current_ex5"],
    )

    assert first["enqueued"]
    assert not repeat["enqueued"]
    assert repeat["reason"] == "q03_exact_identity_already_exists"
    assert _work_item_count(art) == 2
    root = art["root"]
    assert isinstance(root, Path)
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        payload = json.loads(
            conn.execute(
                "SELECT payload_json FROM work_items WHERE id=?",
                (first["created"][0]["id"],),
            ).fetchone()[0]
        )
    assert payload["candidate_specific_exact_identity"] is True
    assert payload["promoted_from_work_item"] == "q02-current"
    assert payload["expected_current_ex5_sha256"] == art["current_ex5"]


def test_append_only_q09_portfolio_from_q08_pass_binds_exact_dependency(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    _insert_work_item(
        art,
        item_id="q08-current",
        phase="Q08",
        status="done",
        verdict="PASS",
        payload=_payload(art, stale=False),
    )
    _insert_work_item(
        art,
        item_id="q09p-historical",
        phase="Q09_PORTFOLIO",
        status="done",
        verdict="FAIL_PORTFOLIO",
        payload=_payload(art, stale=True),
    )

    result = farmctl.enqueue_cascade_backtest_for_ea(
        art["root"],
        art["ea_id"],
        "Q09_PORTFOLIO",
        predecessor_work_item_id="q08-current",
        append_only_rerun_of="q09p-historical",
        rerun_reason="candidate repair",
        expected_current_ex5_sha256=art["current_ex5"],
    )

    assert result["enqueued"]
    assert len(result["created"]) == 1
    new_id = result["created"][0]["id"]
    root = art["root"]
    assert isinstance(root, Path)
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        dependency = conn.execute(
            """
            SELECT dependency_role,parent_work_item_id
            FROM work_item_dependencies WHERE child_work_item_id=?
            """,
            (new_id,),
        ).fetchone()
        historical = conn.execute(
            "SELECT status,verdict FROM work_items WHERE id='q09p-historical'"
        ).fetchone()
    assert dependency == ("Q08_INPUT", "q08-current")
    assert historical == ("done", "FAIL_PORTFOLIO")


def test_append_only_q04_accepts_one_exact_q03_pass_predecessor(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    current_payload = _payload(art, stale=False)
    _insert_work_item(
        art,
        item_id="q03-current",
        phase="Q03",
        status="done",
        verdict="PASS",
        payload=current_payload,
    )
    _insert_work_item(
        art,
        item_id="q04-historical",
        phase="Q04",
        status="done",
        verdict="PASS",
        payload=_payload(art, stale=True),
    )

    result = farmctl.enqueue_cascade_backtest_for_ea(
        art["root"],
        art["ea_id"],
        "Q04",
        predecessor_work_item_id="q03-current",
        append_only_rerun_of="q04-historical",
        rerun_reason="candidate repair",
        expected_current_ex5_sha256=art["current_ex5"],
    )

    assert result["enqueued"]
    assert result["previous_phase"] == "Q03"
    assert len(result["created"]) == 1
    root = art["root"]
    assert isinstance(root, Path)
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        payload = json.loads(
            conn.execute(
                "SELECT payload_json FROM work_items WHERE id=?",
                (result["created"][0]["id"],),
            ).fetchone()[0]
        )
    assert payload["promoted_from_phase"] == "Q03"
    assert payload["promoted_from_work_item"] == "q03-current"
