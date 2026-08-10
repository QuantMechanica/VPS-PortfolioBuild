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


def _prebinding_payload(symbol: str = "EURUSD.DWX") -> dict[str, object]:
    return {
        "from_date": "2017.01.01",
        "host_symbol": symbol,
        "host_timeframe": "H1",
        "to_date": "2024.12.31",
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


def test_repaired_infra_q02_binds_current_artifacts_append_only(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    _insert_work_item(
        art,
        item_id="q02-infra-old-binary",
        phase="Q02",
        status="failed",
        verdict="INFRA_FAIL",
        payload=_payload(art, stale=True),
    )

    result = farmctl.enqueue_cascade_backtest_for_ea(
        art["root"],
        art["ea_id"],
        "Q02",
        predecessor_work_item_id="q02-infra-old-binary",
        append_only_rerun_of="q02-infra-old-binary",
        rerun_reason="runtime hot path repaired",
        expected_current_ex5_sha256=art["current_ex5"],
    )

    assert result["enqueued"]
    assert _work_item_count(art) == 2
    root = art["root"]
    assert isinstance(root, Path)
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        historical = conn.execute(
            "SELECT status,verdict FROM work_items WHERE id='q02-infra-old-binary'"
        ).fetchone()
        new_payload = json.loads(
            conn.execute(
                "SELECT payload_json FROM work_items WHERE id=?",
                (result["created"][0]["id"],),
            ).fetchone()[0]
        )
    assert historical == ("failed", "INFRA_FAIL")
    assert new_payload["stale_pass_rerun"] is False
    assert new_payload["repaired_infra_rerun"] is True
    assert new_payload["rerun_source_repaired_after_infra"] is True
    assert new_payload["rerun_source_current_ex5_mismatch_verified"] is True
    assert new_payload["rerun_source_expected_ex5_sha256"] == "2" * 64
    assert new_payload["expected_current_ex5_sha256"] == art["current_ex5"]
    assert new_payload["expected_ex5_sha256"] == art["current_ex5"]
    assert new_payload["risk_fixed"] == 1000.0
    assert new_payload["risk_percent"] == 0.0


def test_repaired_infra_q02_refuses_unsealed_historical_binding(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    payload = _payload(art, stale=True)
    payload.pop("expected_mq5_sha256")
    _insert_work_item(
        art,
        item_id="q02-infra-unsealed",
        phase="Q02",
        status="failed",
        verdict="INFRA_FAIL",
        payload=payload,
    )

    result = farmctl.enqueue_cascade_backtest_for_ea(
        art["root"],
        art["ea_id"],
        "Q02",
        predecessor_work_item_id="q02-infra-unsealed",
        append_only_rerun_of="q02-infra-unsealed",
        rerun_reason="must remain fail closed",
        expected_current_ex5_sha256=art["current_ex5"],
    )

    assert not result["enqueued"]
    assert result["reason"] == "repaired_infra_source_binding_missing_or_invalid"
    assert result["binding"] == "expected_mq5_sha256"
    assert _work_item_count(art) == 1


def test_repaired_infra_q02_refuses_wrong_current_ex5_hash(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    _insert_work_item(
        art,
        item_id="q02-infra-wrong-current",
        phase="Q02",
        status="failed",
        verdict="INFRA_FAIL",
        payload=_payload(art, stale=True),
    )

    result = farmctl.enqueue_cascade_backtest_for_ea(
        art["root"],
        art["ea_id"],
        "Q02",
        predecessor_work_item_id="q02-infra-wrong-current",
        append_only_rerun_of="q02-infra-wrong-current",
        rerun_reason="operator hash must bind current binary",
        expected_current_ex5_sha256="f" * 64,
    )

    assert not result["enqueued"]
    assert result["reason"] == "current_ex5_hash_mismatch"
    assert result["expected_sha256"] == "f" * 64
    assert result["actual_sha256"] == art["current_ex5"]
    assert _work_item_count(art) == 1


def test_fresh_q02_seed_requires_current_ex5_hash(tmp_path: Path, monkeypatch) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    _insert_work_item(
        art,
        item_id="q02-prebinding",
        phase="Q02",
        status="done",
        verdict="PASS",
        payload=_prebinding_payload(),
    )

    result = farmctl.enqueue_fresh_q02_seed(
        art["root"],
        art["ea_id"],
        old_work_item_id="q02-prebinding",
        requal_reason="owner-directed current-binary requalification",
        expected_current_ex5_sha256=None,
    )

    assert not result["enqueued"]
    assert result["reason"] == "expected_current_ex5_sha256_required_or_invalid"
    assert _work_item_count(art) == 1


def test_fresh_q02_seed_refuses_wrong_current_ex5_hash(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    _insert_work_item(
        art,
        item_id="q02-prebinding",
        phase="Q02",
        status="done",
        verdict="PASS",
        payload=_prebinding_payload(),
    )

    result = farmctl.enqueue_fresh_q02_seed(
        art["root"],
        art["ea_id"],
        old_work_item_id="q02-prebinding",
        requal_reason="owner-directed current-binary requalification",
        expected_current_ex5_sha256="f" * 64,
    )

    assert not result["enqueued"]
    assert result["reason"] == "current_ex5_hash_mismatch"
    assert _work_item_count(art) == 1


def test_fresh_q02_seed_is_sealed_append_only_and_double_enqueue_safe(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    evidence = _insert_work_item(
        art,
        item_id="q02-prebinding",
        phase="Q02",
        status="done",
        verdict="PASS",
        payload=_prebinding_payload(),
    )
    evidence.unlink()
    root = art["root"]
    assert isinstance(root, Path)
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        historical_before = conn.execute(
            "SELECT * FROM work_items WHERE id='q02-prebinding'"
        ).fetchone()

    kwargs = {
        "old_work_item_id": "q02-prebinding",
        "requal_reason": "owner-directed current-binary requalification",
        "expected_current_ex5_sha256": art["current_ex5"],
    }
    first = farmctl.enqueue_fresh_q02_seed(
        art["root"], art["ea_id"], **kwargs
    )
    repeat = farmctl.enqueue_fresh_q02_seed(
        art["root"], art["ea_id"], **kwargs
    )

    assert first["enqueued"]
    assert not repeat["enqueued"]
    assert repeat["reason"] == "fresh_q02_seed_open_row_exists"
    assert _work_item_count(art) == 2
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        historical_after = conn.execute(
            "SELECT * FROM work_items WHERE id='q02-prebinding'"
        ).fetchone()
        created = conn.execute(
            "SELECT symbol,setfile_path,status,payload_json FROM work_items WHERE id=?",
            (first["created"][0]["id"],),
        ).fetchone()
    assert historical_after == historical_before
    assert created is not None
    assert created[0] == "EURUSD.DWX"
    assert created[1] == str(art["setfile"])
    assert created[2] == "pending"
    payload = json.loads(created[3])
    assert payload["fresh_q02_seed"] is True
    assert payload["historical_work_item_preserved"] is True
    assert payload["pre_binding_source_verified"] is True
    assert payload["requalification_old_work_item_id"] == "q02-prebinding"
    assert payload["requalification_reason"] == kwargs["requal_reason"]
    assert payload["expected_current_ex5_sha256"] == art["current_ex5"]
    assert payload["expected_ex5_sha256"] == art["current_ex5"]
    assert payload["expected_setfile_sha256"] == farmctl._sha256_file(art["setfile"])
    assert payload["requalification_setfile_identity"] == {
        "path": str(art["setfile"]),
        "sha256": payload["expected_setfile_sha256"],
    }
    assert payload["risk_fixed"] == 1000.0
    assert payload["risk_percent"] == 0.0


def test_fresh_q02_seed_spawn_guard_refuses_setfile_drift(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    setfile = art["setfile"]
    mq5 = art["mq5"]
    assert isinstance(setfile, Path)
    assert isinstance(mq5, Path)
    setfile_sha = farmctl._sha256_file(setfile)
    mq5_sha = farmctl._sha256_file(mq5)
    payload = {
        "expected_current_ex5_sha256": art["current_ex5"],
        "expected_ex5_sha256": art["current_ex5"],
        "expected_expert": "QM\\QM5_9901_candidate",
        "expected_mq5_sha256": mq5_sha,
        "expected_period": "H1",
        "expected_setfile_sha256": setfile_sha,
        "expected_symbol": "EURUSD.DWX",
        "fresh_q02_seed": True,
        "requalification_setfile_identity": {
            "path": str(setfile),
            "sha256": setfile_sha,
        },
    }

    valid = farmctl._fresh_q02_seed_spawn_binding_failure(
        payload,
        ex5_sha256=art["current_ex5"],
        mq5_sha256=mq5_sha,
        setfile_path=setfile,
        setfile_sha256=setfile_sha,
        symbol="EURUSD.DWX",
        period="H1",
        expert="QM\\QM5_9901_candidate",
    )
    drift = farmctl._fresh_q02_seed_spawn_binding_failure(
        payload,
        ex5_sha256=art["current_ex5"],
        mq5_sha256=mq5_sha,
        setfile_path=setfile,
        setfile_sha256="f" * 64,
        symbol="EURUSD.DWX",
        period="H1",
        expert="QM\\QM5_9901_candidate",
    )

    assert valid is None
    assert drift is not None
    assert drift["reason"] == "fresh_q02_seed_binding_mismatch_before_spawn"
    assert drift["binding"] == "expected_setfile_sha256"


def test_fresh_q03_purged_seed_spawn_guard_refuses_binary_drift(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    setfile = art["setfile"]
    mq5 = art["mq5"]
    assert isinstance(setfile, Path)
    assert isinstance(mq5, Path)
    setfile_sha = farmctl._sha256_file(setfile)
    mq5_sha = farmctl._sha256_file(mq5)
    payload = {
        "expected_current_ex5_sha256": art["current_ex5"],
        "expected_ex5_sha256": art["current_ex5"],
        "expected_expert": "QM\\QM5_9901_candidate",
        "expected_mq5_sha256": mq5_sha,
        "expected_period": "H1",
        "expected_setfile_sha256": setfile_sha,
        "expected_symbol": "EURUSD.DWX",
        "fresh_q03_purged_evidence_fallback": True,
        "requalification_setfile_identity": {
            "path": str(setfile),
            "sha256": setfile_sha,
        },
    }

    valid = farmctl._fresh_q02_seed_spawn_binding_failure(
        payload,
        ex5_sha256=art["current_ex5"],
        mq5_sha256=mq5_sha,
        setfile_path=setfile,
        setfile_sha256=setfile_sha,
        symbol="EURUSD.DWX",
        period="H1",
        expert="QM\\QM5_9901_candidate",
    )
    drift = farmctl._fresh_q02_seed_spawn_binding_failure(
        payload,
        ex5_sha256="f" * 64,
        mq5_sha256=mq5_sha,
        setfile_path=setfile,
        setfile_sha256=setfile_sha,
        symbol="EURUSD.DWX",
        period="H1",
        expert="QM\\QM5_9901_candidate",
    )

    assert valid is None
    assert drift is not None
    assert drift["reason"] == "fresh_q03_seed_binding_mismatch_before_spawn"
    assert drift["binding"] == "expected_current_ex5_sha256"


def test_fresh_q02_seed_refuses_noncanonical_ea_directory(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    rogue_ea = tmp_path / "rogue" / "QM5_9901_candidate"
    rogue_sets = rogue_ea / "sets"
    rogue_sets.mkdir(parents=True)
    rogue_setfile = rogue_sets / "QM5_9901_candidate_EURUSD.DWX_H1_backtest.set"
    rogue_setfile.write_text(
        "RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8"
    )
    (rogue_ea / "QM5_9901_candidate.mq5").write_text(
        "// rogue source\n", encoding="utf-8"
    )
    (rogue_ea / "QM5_9901_candidate.ex5").write_bytes(b"rogue binary")
    _insert_work_item(
        art,
        item_id="q02-prebinding-rogue",
        phase="Q02",
        status="done",
        verdict="PASS",
        payload=_prebinding_payload(),
        setfile=rogue_setfile,
    )

    result = farmctl.enqueue_fresh_q02_seed(
        art["root"],
        art["ea_id"],
        old_work_item_id="q02-prebinding-rogue",
        requal_reason="must bind canonical repo bytes",
        expected_current_ex5_sha256=art["current_ex5"],
    )

    assert not result["enqueued"]
    assert result["reason"] == "current_execution_binding_not_in_canonical_ea_directory"
    assert _work_item_count(art) == 1


def test_fresh_q02_seed_reconciles_semantically_equal_worktree_setfile(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    canonical_ea = art["ea_dir"]
    canonical_setfile = art["setfile"]
    assert isinstance(canonical_ea, Path)
    assert isinstance(canonical_setfile, Path)
    worktree_ea = tmp_path / "worktrees" / "agent-1" / canonical_ea.name
    worktree_sets = worktree_ea / "sets"
    worktree_sets.mkdir(parents=True)
    worktree_setfile = worktree_sets / canonical_setfile.name
    worktree_setfile.write_text(
        "; stale build_hash comment only\nRISK_FIXED=1000\nRISK_PERCENT=0\n",
        encoding="utf-8",
    )
    _insert_work_item(
        art,
        item_id="q02-prebinding-worktree",
        phase="Q02",
        status="done",
        verdict="PASS",
        payload=_prebinding_payload(),
        setfile=worktree_setfile,
    )

    result = farmctl.enqueue_fresh_q02_seed(
        art["root"],
        art["ea_id"],
        old_work_item_id="q02-prebinding-worktree",
        requal_reason="governed worktree-to-canonical reconciliation",
        expected_current_ex5_sha256=art["current_ex5"],
        reconcile_noncanonical_setfile=True,
    )

    assert result["enqueued"]
    new_id = result["created"][0]["id"]
    with sqlite3.connect(art["root"] / farmctl.DB_REL) as conn:
        conn.row_factory = sqlite3.Row
        source = conn.execute(
            "SELECT setfile_path FROM work_items WHERE id='q02-prebinding-worktree'"
        ).fetchone()
        created = conn.execute(
            "SELECT setfile_path,payload_json FROM work_items WHERE id=?", (new_id,)
        ).fetchone()
    payload = json.loads(created["payload_json"])
    assert Path(source["setfile_path"]) == worktree_setfile
    assert Path(created["setfile_path"]) == canonical_setfile.resolve()
    assert payload["setfile_reconciliation"]["schema_version"] == (
        "qm-q02-setfile-reconciliation/v1"
    )
    assert payload["setfile_reconciliation"]["semantic_parameters_equal"] is True
    assert payload["requalification_source_setfile_identity"]["sha256"] == (
        farmctl._sha256_file(worktree_setfile)
    )
    assert payload["requalification_setfile_identity"]["sha256"] == (
        farmctl._sha256_file(canonical_setfile)
    )
    assert _work_item_count(art) == 2


def test_fresh_q02_seed_reconciliation_refuses_parameter_drift(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    canonical_ea = art["ea_dir"]
    canonical_setfile = art["setfile"]
    assert isinstance(canonical_ea, Path)
    assert isinstance(canonical_setfile, Path)
    worktree_ea = tmp_path / "worktrees" / "agent-1" / canonical_ea.name
    worktree_sets = worktree_ea / "sets"
    worktree_sets.mkdir(parents=True)
    worktree_setfile = worktree_sets / canonical_setfile.name
    worktree_setfile.write_text(
        "RISK_FIXED=500\nRISK_PERCENT=0\n", encoding="utf-8"
    )
    _insert_work_item(
        art,
        item_id="q02-prebinding-worktree-drift",
        phase="Q02",
        status="done",
        verdict="PASS",
        payload=_prebinding_payload(),
        setfile=worktree_setfile,
    )

    result = farmctl.enqueue_fresh_q02_seed(
        art["root"],
        art["ea_id"],
        old_work_item_id="q02-prebinding-worktree-drift",
        requal_reason="must refuse executable parameter drift",
        expected_current_ex5_sha256=art["current_ex5"],
        reconcile_noncanonical_setfile=True,
    )

    assert not result["enqueued"]
    assert result["reason"] == "noncanonical_setfile_semantic_mismatch"
    assert result["differing_parameter_keys"] == ["risk_fixed"]
    assert _work_item_count(art) == 1


def test_fresh_q02_seed_refuses_any_binding_era_source(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    _insert_work_item(
        art,
        item_id="q02-bound",
        phase="Q02",
        status="done",
        verdict="PASS",
        payload=_payload(art, stale=True),
    )

    result = farmctl.enqueue_fresh_q02_seed(
        art["root"],
        art["ea_id"],
        old_work_item_id="q02-bound",
        requal_reason="must not bypass stale-pass guard",
        expected_current_ex5_sha256=art["current_ex5"],
    )

    assert not result["enqueued"]
    assert result["reason"] == "fresh_q02_seed_requires_pre_binding_source"
    assert set(result["present_execution_bindings"]) == set(
        farmctl._Q02_EXECUTION_BINDING_KEYS
    )
    assert _work_item_count(art) == 1


def test_fresh_q02_seed_refuses_open_same_symbol_but_not_other_symbol(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    _insert_work_item(
        art,
        item_id="q02-prebinding",
        phase="Q02",
        status="done",
        verdict="PASS",
        payload=_prebinding_payload(),
    )
    _insert_work_item(
        art,
        item_id="q02-open-other-symbol",
        phase="Q02",
        status="pending",
        verdict=None,
        payload=_prebinding_payload("GBPUSD.DWX"),
        symbol="GBPUSD.DWX",
    )

    allowed = farmctl.enqueue_fresh_q02_seed(
        art["root"],
        art["ea_id"],
        old_work_item_id="q02-prebinding",
        requal_reason="symbol-specific current-binary requalification",
        expected_current_ex5_sha256=art["current_ex5"],
    )
    assert allowed["enqueued"]

    blocked = farmctl.enqueue_fresh_q02_seed(
        art["root"],
        art["ea_id"],
        old_work_item_id="q02-prebinding",
        requal_reason="symbol-specific current-binary requalification",
        expected_current_ex5_sha256=art["current_ex5"],
    )
    assert not blocked["enqueued"]
    assert blocked["reason"] == "fresh_q02_seed_open_row_exists"
    assert blocked["existing_work_item_id"] == allowed["created"][0]["id"]


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
    evidence = _insert_work_item(
        art,
        item_id="q03-other-symbol",
        phase="Q03",
        status="done",
        verdict="PASS",
        payload=current_payload,
        symbol="GBPUSD.DWX",
    )
    evidence.unlink()

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


def test_q03_purged_evidence_fallback_is_sealed_append_only(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    _insert_work_item(
        art,
        item_id="q02-current",
        phase="Q02",
        status="done",
        verdict="PASS",
        payload=_payload(art, stale=False),
    )
    evidence = _insert_work_item(
        art,
        item_id="q03-purged",
        phase="Q03",
        status="done",
        verdict="PASS",
        payload=_prebinding_payload(),
    )
    evidence.unlink()
    root = art["root"]
    assert isinstance(root, Path)
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        historical_before = conn.execute(
            "SELECT * FROM work_items WHERE id='q03-purged'"
        ).fetchone()

    result = farmctl.enqueue_cascade_backtest_for_ea(
        root,
        art["ea_id"],
        "Q03",
        predecessor_work_item_id="q02-current",
        append_only_rerun_of="q03-purged",
        rerun_reason="owner-directed current-binary requalification",
        expected_current_ex5_sha256=art["current_ex5"],
    )

    assert result["enqueued"]
    assert result["created"][0]["fresh_q03_purged_evidence_fallback"] is True
    assert _work_item_count(art) == 3
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        historical_after = conn.execute(
            "SELECT * FROM work_items WHERE id='q03-purged'"
        ).fetchone()
        created = conn.execute(
            "SELECT status,payload_json FROM work_items WHERE id=?",
            (result["created"][0]["id"],),
        ).fetchone()
    assert historical_after == historical_before
    assert created is not None and created[0] == "pending"
    payload = json.loads(created[1])
    assert payload["fresh_q03_purged_evidence_fallback"] is True
    assert payload["rerun_source_evidence_purged_at_enqueue"] is True
    assert payload["purged_identity_rows_verified"] == ["q03-purged"]
    assert payload["append_only_rerun_of_work_item"] == "q03-purged"
    assert payload["promoted_from_work_item"] == "q02-current"
    assert payload["expected_current_ex5_sha256"] == art["current_ex5"]
    assert payload["expected_ex5_sha256"] == art["current_ex5"]
    assert payload["requalification_setfile_identity"] == {
        "path": str(art["setfile"]),
        "sha256": farmctl._sha256_file(art["setfile"]),
    }
    assert payload["risk_fixed"] == 1000.0
    assert payload["risk_percent"] == 0.0


def test_q03_purged_fallback_refuses_current_binary_terminal_target(
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
    evidence = _insert_work_item(
        art,
        item_id="q03-current",
        phase="Q03",
        status="done",
        verdict="PASS",
        payload=current_payload,
    )
    evidence.unlink()

    result = farmctl.enqueue_cascade_backtest_for_ea(
        art["root"],
        art["ea_id"],
        "Q03",
        predecessor_work_item_id="q02-current",
        append_only_rerun_of="q03-current",
        rerun_reason="must dedupe current binary",
        expected_current_ex5_sha256=art["current_ex5"],
    )

    assert not result["enqueued"]
    assert result["reason"] == (
        "q03_exact_identity_already_has_current_binary_terminal_result"
    )
    assert result["existing_work_item_id"] == "q03-current"
    assert _work_item_count(art) == 2


def test_q03_purged_fallback_refuses_retained_exact_identity_evidence(
    tmp_path: Path, monkeypatch
) -> None:
    art = _artifacts(tmp_path, monkeypatch)
    _insert_work_item(
        art,
        item_id="q02-current",
        phase="Q02",
        status="done",
        verdict="PASS",
        payload=_payload(art, stale=False),
    )
    purged = _insert_work_item(
        art,
        item_id="q03-purged",
        phase="Q03",
        status="done",
        verdict="PASS",
        payload=_prebinding_payload(),
    )
    purged.unlink()
    retained = _insert_work_item(
        art,
        item_id="q03-retained",
        phase="Q03",
        status="done",
        verdict="PASS",
        payload=_payload(art, stale=True),
    )

    result = farmctl.enqueue_cascade_backtest_for_ea(
        art["root"],
        art["ea_id"],
        "Q03",
        predecessor_work_item_id="q02-current",
        append_only_rerun_of="q03-purged",
        rerun_reason="must not ignore retained evidence",
        expected_current_ex5_sha256=art["current_ex5"],
    )

    assert not result["enqueued"]
    assert result["reason"] == (
        "q03_purged_evidence_fallback_refused_retained_identity_evidence_exists"
    )
    assert result["retained_identity_evidence"] == [{
        "id": "q03-retained",
        "evidence_path": str(retained),
    }]
    assert _work_item_count(art) == 3


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
