import hashlib
import json
import sqlite3
import sys
from pathlib import Path
from unittest.mock import patch


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import dl089_scheduling as scheduling  # noqa: E402
import opt_census  # noqa: E402


FIXTURE = Path(__file__).parent / "fixtures" / "dl089_same_program_replay.json"


def _digest(value: object) -> str:
    return hashlib.sha256(
        json.dumps(value, sort_keys=True, separators=(",", ":")).encode("utf-8")
    ).hexdigest()


def _logical_replay(lanes: int, *, reverse: bool, stale_retry: bool = False) -> dict:
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    years = fixture["years"]
    rows = {
        (arm["arm"], year): {
            "status": "pending",
            "verdict": None,
            "trades": arm["trades"][index],
            "direction": arm["direction"],
            "predicate_id": arm["predicate_id"],
            "score": arm["score"],
        }
        for arm in fixture["arms"]
        for index, year in enumerate(years)
    }
    trace: list[str] = []
    receipts: list[dict] = []
    stale_done = False
    while any(row["status"] == "pending" for row in rows.values()):
        heads = []
        for arm in fixture["arms"]:
            for year in years:
                if rows[(arm["arm"], year)]["status"] == "pending":
                    heads.append((arm["arm"], year))
                    break
        batch = heads[:lanes]
        if reverse:
            batch.reverse()
        if stale_retry and not stale_done and batch:
            trace.append(f"stale-retry:{batch[0][0]}:{batch[0][1]}")
            stale_done = True
        assert len({arm for arm, _year in batch}) == len(batch)
        for arm, year in batch:
            row = rows[(arm, year)]
            row["status"] = "done"
            row["verdict"] = "MEASURED"
            trace.append(f"done:{arm}:{year}")
            if arm != "baseline" and row["trades"] < fixture["activity_floor"]:
                skipped = []
                for later in years:
                    if later > year and rows[(arm, later)]["status"] == "pending":
                        rows[(arm, later)]["status"] = "done"
                        rows[(arm, later)]["verdict"] = "SKIPPED_EXCLUDED"
                        skipped.append(later)
                receipt = {"trigger": [arm, year], "skipped": skipped}
                receipt["receipt_sha256"] = _digest(receipt)
                receipts.append(receipt)

    cells = {
        f"{arm}:{year}": {
            "status": row["status"],
            "verdict": row["verdict"],
            "evidence_sha256": _digest([arm, year, row["status"], row["verdict"]]),
        }
        for (arm, year), row in sorted(rows.items())
    }
    eligible = [
        arm for arm in fixture["arms"]
        if arm["arm"] != "baseline"
        and all(rows[(arm["arm"], year)]["verdict"] == "MEASURED" for year in years)
    ]
    selected = {
        direction: min(
            (
                arm for arm in eligible if arm["direction"] == direction
            ),
            key=lambda arm: (-arm["score"], arm["predicate_id"]),
        )["arm"]
        for direction in ("BUY", "SELL")
    }
    artifact = {
        "cells": cells,
        "pruning_receipts": receipts,
        "annual_matrix_sha256": _digest(cells),
        "wf_selections": [selected for _ in range(4)],
        "final_selection": selected,
        "stability": "PASS",
        "declared_trial_count": fixture["declared_trial_count"],
        "amendment_sha256": fixture["amendment_sha256"],
        "selection_sha256": fixture["selection_sha256"],
    }
    return {"trace": trace, "artifact_bytes": json.dumps(artifact, sort_keys=True)}


def _frontier_fixture() -> tuple[dict, list[dict]]:
    fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
    cells = []
    rows = []
    for arm in fixture["arms"]:
        for year in fixture["years"]:
            item_id = f"{arm['arm']}-{year}"
            cell = {
                "work_item_id": item_id,
                "cell_key": item_id,
                "arm": arm["arm"],
                "year": year,
                "direction": arm["direction"],
                "predicate_id": arm["predicate_id"],
                "setfile_path": f"{item_id}.set",
            }
            cells.append(cell)
            rows.append({
                "id": item_id,
                "phase": "OPT_CENSUS",
                "ea_id": "QM5_REPLAY",
                "symbol": "EURUSD.DWX",
                "setfile_path": cell["setfile_path"],
                "status": "pending",
                "verdict": None,
                "payload": {
                    "program_id": fixture["program_id"],
                    "cell_key": item_id,
                    "arm": arm["arm"],
                    "year": year,
                    "direction": arm["direction"],
                    "predicate_id": arm["predicate_id"],
                },
            })
    ledger = {
        "program_id": fixture["program_id"],
        "years": fixture["years"],
        "cells": cells,
    }
    return ledger, rows


def test_serial_parallel_and_stale_retry_are_artifact_equivalent() -> None:
    serial = _logical_replay(1, reverse=False)
    parallel = _logical_replay(2, reverse=True)
    stale = _logical_replay(2, reverse=True, stale_retry=True)
    assert serial["trace"] != parallel["trace"]
    assert parallel["trace"] != stale["trace"]
    assert serial["artifact_bytes"] == parallel["artifact_bytes"] == stale["artifact_bytes"]


def test_arm_frontier_rejects_later_nonterminal_after_skip() -> None:
    ledger, rows = _frontier_fixture()
    frontier = scheduling.arm_frontier(rows, ledger)
    assert len(frontier) == 5
    assert all(int(row["payload"]["year"]) == 2019 for row in frontier.values())
    rows[7]["status"] = "done"
    rows[7]["verdict"] = "SKIPPED_EXCLUDED"
    try:
        scheduling.arm_frontier(rows, ledger)
    except scheduling.SchedulingError as exc:
        assert "later nonterminal" in str(exc)
    else:
        raise AssertionError("skipped predecessor admitted a later year")


def test_duplicate_exception_is_exact_program_and_default_off() -> None:
    candidate = {"phase": "OPT_CENSUS", "ea_id": "QM5_REPLAY", "symbol": "EURUSD.DWX"}
    payload = {"program_id": "p", "arm": "buy_002"}
    active = [{
        "phase": "OPT_CENSUS",
        "ea_id": "QM5_REPLAY",
        "symbol": "EURUSD.DWX",
        "payload": {"program_id": "p", "arm": "buy_001"},
    }]
    with patch.dict("os.environ", {}, clear=True):
        assert not scheduling.duplicate_pair_exception_allowed(
            candidate=candidate,
            candidate_payload=payload,
            active_duplicates=active,
            l_eff=2,
            candidate_is_multisymbol=False,
        )
    with patch.dict(
        "os.environ",
        {"DL089_SAME_PROGRAM_PARALLEL_ALLOWLIST": "p"},
        clear=True,
    ):
        assert scheduling.duplicate_pair_exception_allowed(
            candidate=candidate,
            candidate_payload=payload,
            active_duplicates=active,
            l_eff=2,
            candidate_is_multisymbol=False,
        )
        active[0]["payload"]["program_id"] = "other"
        assert not scheduling.duplicate_pair_exception_allowed(
            candidate=candidate,
            candidate_payload=payload,
            active_duplicates=active,
            l_eff=2,
            candidate_is_multisymbol=False,
        )


def test_frontier_boost_and_rollback_deboost_are_exact(tmp_path: Path) -> None:
    ledger, rows = _frontier_fixture()
    ledger_path = tmp_path / "ledger.json"
    db_path = tmp_path / "farm.sqlite"
    ledger_path.write_text(json.dumps(ledger), encoding="utf-8")
    with sqlite3.connect(db_path) as conn:
        conn.execute(
            "CREATE TABLE work_items (id TEXT PRIMARY KEY,status TEXT,verdict TEXT,"
            "claimed_by TEXT,setfile_path TEXT,payload_json TEXT,updated_at TEXT)"
        )
        for row in rows:
            conn.execute(
                "INSERT INTO work_items VALUES (?,?,?,?,?,?,?)",
                (
                    row["id"], row["status"], row["verdict"], None,
                    row["setfile_path"], json.dumps(row["payload"]), "old",
                ),
            )
        conn.commit()
    first = opt_census.boost(
        ledger_path=ledger_path,
        db_path=db_path,
        window=8,
        lane_limit=2,
        cell_limit=6,
    )
    assert first["boosted_now"] == 2
    assert len(first["boosted_lane_ids"]) == 2
    rollback = opt_census.boost(
        ledger_path=ledger_path,
        db_path=db_path,
        window=8,
        lane_limit=1,
        cell_limit=6,
    )
    assert rollback["deboosted_now"] == 1
    assert rollback["target_priority_rows"] == 1


def test_pruning_lock_identity_serializes_only_one_arm() -> None:
    first = scheduling.pruning_lock_filename("program-a", "buy-001")
    assert first == scheduling.pruning_lock_filename("program-a", "buy-001")
    assert first != scheduling.pruning_lock_filename("program-a", "sell-001")
    assert first != scheduling.pruning_lock_filename("program-b", "buy-001")
