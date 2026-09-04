"""OOS-2026 explicit window contract: spawn, dispatcher and repair.

Postmortem (Astra task e544e3b8, 2026-09-04): the oos-2026-confirmation-v1
campaign declared 2026-01-01..2026-04-06 in its campaign plan but never wrote
the window into the work-item payloads.  farmctl's spawn builder found no
window and terminal_worker._resolved_evidence_window silently substituted
DEFAULT_RUN_SMOKE_YEAR (2024): every completed row measured 2024 while being
labelled 2026 out-of-sample evidence.
"""

from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path
from typing import Any

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402

from tools.strategy_farm import oos_2026_confirmation as subject  # noqa: E402
from tools.strategy_farm import q09_news_runner as q09  # noqa: E402


CAMPAIGN_ID = subject.CAMPAIGN_ID
FROM_DATE = "2026.01.01"
TO_DATE = "2026.04.06"
FROM_UTC = "2026-01-01T00:00:00Z"
TO_UTC = "2026-04-06T23:59:59Z"


def _campaign_plan(directory: Path, name: str = "campaign_plan.json") -> Path:
    path = directory / name
    path.write_text(
        json.dumps(
            {
                "campaign_id": CAMPAIGN_ID,
                "full_from_utc": FROM_UTC,
                "full_to_utc": TO_UTC,
                "run_count": 4,
            },
            sort_keys=True,
        ),
        encoding="utf-8",
    )
    return path


# ---------------------------------------------------------------------------
# 1. farmctl spawn builder: explicit window contract
# ---------------------------------------------------------------------------


def _diagnostic_payload(**overrides: Any) -> dict[str, Any]:
    payload: dict[str, Any] = {
        "window_source": "oos_2026",
        "diagnostic_single_window": True,
        "diagnostic_non_admission": True,
        "diagnostic_campaign_id": CAMPAIGN_ID,
        "host_symbol": "USDJPY.DWX",
        "host_timeframe": "H1",
        "timeout_min": 90,
    }
    payload.update(overrides)
    return payload


def _bound_payload(plan_path: Path, **overrides: Any) -> dict[str, Any]:
    """A campaign payload that also names the plan file the spawn re-verifies."""
    payload = _diagnostic_payload(
        from_date=FROM_DATE,
        to_date=TO_DATE,
        diagnostic_campaign_plan_path=str(plan_path),
        diagnostic_campaign_plan_sha256=subject.sha(plan_path),
    )
    payload.update(overrides)
    return payload


def _dispatch(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    payload: dict[str, Any],
    *,
    make_artifacts: bool = True,
) -> tuple[dict[str, Any], list[list[str]]]:
    root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    ea_id = "QM5_13213"
    ea_dir = repo_root / "framework" / "EAs" / f"{ea_id}_demo"
    sets_dir = ea_dir / "sets"
    sets_dir.mkdir(parents=True)
    setfile = sets_dir / f"{ea_id}_demo_USDJPY.DWX_H1_backtest.set"
    if make_artifacts:
        (ea_dir / f"{ea_id}_demo.ex5").write_bytes(b"test-ex5")
        setfile.write_text("RISK_FIXED=1000\n", encoding="utf-8")

    item = {
        "id": "oos-2026-window-contract-test",
        "kind": "backtest",
        "ea_id": ea_id,
        "symbol": "USDJPY.DWX",
        "setfile_path": str(setfile.resolve()),
        "phase": "Q09_NEWS",
        "payload_json": json.dumps(payload, sort_keys=True),
    }
    commands: list[list[str]] = []

    class FakeProc:
        pid = 13213

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

    result = farmctl._spawn_run_smoke_for_work_item(root, item, "T1")
    return result, commands


def test_spawn_honours_the_declared_diagnostic_window(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    plan_path = _campaign_plan(tmp_path)
    result, commands = _dispatch(monkeypatch, tmp_path, _bound_payload(plan_path))

    assert result["spawned"] is True
    assert result["from_date"] == result["expected_from_date"] == FROM_DATE
    assert result["to_date"] == result["expected_to_date"] == TO_DATE
    command = commands[0]
    assert command[command.index("-FromDate") + 1] == FROM_DATE
    assert command[command.index("-ToDate") + 1] == TO_DATE


@pytest.mark.parametrize(
    ("from_date", "to_date"),
    [
        (None, None),
        (None, TO_DATE),
        (FROM_DATE, None),
        ("2026.13.01", TO_DATE),
        ("2026-01-01", TO_DATE),
        (TO_DATE, FROM_DATE),
    ],
)
def test_spawn_fails_closed_without_a_valid_declared_window(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
    from_date: str | None,
    to_date: str | None,
) -> None:
    payload = _diagnostic_payload()
    if from_date is not None:
        payload["from_date"] = from_date
    if to_date is not None:
        payload["to_date"] = to_date

    result, commands = _dispatch(monkeypatch, tmp_path, payload)

    assert result["spawned"] is False
    assert result["reason"] == farmctl.DIAGNOSTIC_SINGLE_WINDOW_INVALID_REASON
    assert result["window_source"] == "oos_2026"
    assert commands == []


def test_window_source_alone_also_selects_the_explicit_window_contract(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    payload = _diagnostic_payload()
    payload.pop("diagnostic_single_window")

    result, _commands = _dispatch(monkeypatch, tmp_path, payload)

    assert result["spawned"] is False
    assert result["reason"] == farmctl.DIAGNOSTIC_SINGLE_WINDOW_INVALID_REASON


def test_ordinary_rows_keep_the_pre_existing_no_window_behaviour(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """A non-diagnostic Q09_NEWS row is untouched by the new contract."""
    payload = _diagnostic_payload()
    payload.pop("diagnostic_single_window")
    payload.pop("window_source")

    result, commands = _dispatch(monkeypatch, tmp_path, payload)

    assert result["spawned"] is True
    assert result["from_date"] is None
    assert result["to_date"] is None
    assert "-FromDate" not in commands[0]
    assert "-SmokeMode" not in commands[0]


def test_declared_diagnostic_window_is_not_silently_clamped(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """No campaign id -> no plan binding required, and no start clamp either."""
    payload = _diagnostic_payload(from_date="2016.01.01", to_date="2016.12.31")
    payload.pop("diagnostic_campaign_id")

    result, _commands = _dispatch(monkeypatch, tmp_path, payload)

    assert result["spawned"] is True
    assert result["from_date"] == "2016.01.01"
    assert result["from_date"] < farmctl.DWX_MULTI_SYMBOL_FULL_HISTORY_FROM


# --- the corrected window is re-derived from the campaign plan at spawn time ---


def test_spawn_fails_closed_when_a_campaign_row_names_no_plan(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    payload = _diagnostic_payload(from_date=FROM_DATE, to_date=TO_DATE)

    result, commands = _dispatch(monkeypatch, tmp_path, payload)

    assert result["spawned"] is False
    assert result["reason"] == farmctl.DIAGNOSTIC_CAMPAIGN_WINDOW_BINDING_MISSING
    assert commands == []


def test_spawn_fails_closed_when_the_campaign_plan_was_edited(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    plan_path = _campaign_plan(tmp_path)
    payload = _bound_payload(plan_path)
    plan_path.write_text(
        json.dumps({"campaign_id": CAMPAIGN_ID, "full_from_utc": FROM_UTC,
                    "full_to_utc": TO_UTC, "run_count": 5}, sort_keys=True),
        encoding="utf-8",
    )

    result, commands = _dispatch(monkeypatch, tmp_path, payload)

    assert result["spawned"] is False
    assert result["reason"] == farmctl.DIAGNOSTIC_CAMPAIGN_PLAN_SHA256_MISMATCH
    assert commands == []


def test_spawn_fails_closed_when_the_payload_window_contradicts_the_plan(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """The tampering case: a plausible window edited into an otherwise valid row."""
    plan_path = _campaign_plan(tmp_path)
    payload = _bound_payload(plan_path, from_date="2024.01.01", to_date="2024.12.31")

    result, commands = _dispatch(monkeypatch, tmp_path, payload)

    assert result["spawned"] is False
    assert result["reason"] == farmctl.DIAGNOSTIC_CAMPAIGN_WINDOW_CONTRADICTION
    assert result["plan_from_date"] == FROM_DATE
    assert result["plan_to_date"] == TO_DATE
    assert commands == []


def test_spawn_accepts_the_repair_audit_block_as_the_plan_binding(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """A repaired row binds through oos_window_repair, not the dispatcher keys."""
    plan_path = _campaign_plan(tmp_path)
    payload = _diagnostic_payload(
        from_date=FROM_DATE,
        to_date=TO_DATE,
        oos_window_repair={
            "campaign_plan_path": str(plan_path),
            "campaign_plan_sha256": subject.sha(plan_path),
        },
    )

    result, commands = _dispatch(monkeypatch, tmp_path, payload)

    assert result["spawned"] is True
    assert commands[0][commands[0].index("-FromDate") + 1] == FROM_DATE


def test_spawn_fails_closed_when_the_named_plan_is_gone(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    plan_path = _campaign_plan(tmp_path)
    payload = _bound_payload(plan_path)
    plan_path.unlink()

    result, _commands = _dispatch(monkeypatch, tmp_path, payload)

    assert result["spawned"] is False
    assert result["reason"] == farmctl.DIAGNOSTIC_CAMPAIGN_PLAN_UNREADABLE


# --- the quarter-length window must not inherit the annual q02 trade floor ----


def test_declared_quarter_window_prorates_the_q02_trade_floor(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    """96 days may not be judged against a full year's 5-trade floor.

    ``_smoke_year_count`` counts calendar YEARS TOUCHED, so 2026.01.01..
    2026.04.06 yields years=1 and the annual floor 5.  run_smoke re-derives the
    same number and OVERRIDES ``-MinTrades`` with it unless ``-SmokeMode`` is
    passed, which is how the campaign's own evidence artifact would carry a
    spurious MIN_TRADES_NOT_MET for a deliberately quarter-length window.
    """
    plan_path = _campaign_plan(tmp_path)
    result, commands = _dispatch(monkeypatch, tmp_path, _bound_payload(plan_path))

    assert farmctl._effective_min_trades(
        tmp_path, "QM5_13213", FROM_DATE, TO_DATE, 2024
    )["effective_min_trades"] == 5
    assert farmctl._inclusive_window_days(FROM_DATE, TO_DATE) == 96
    assert result["effective_min_trades"] == 1
    assert result["min_trade_scope"] == "declared_diagnostic_window_prorated"
    assert result["declared_window_days"] == 96
    command = commands[0]
    assert command[command.index("-MinTrades") + 1] == "1"
    # Without -SmokeMode run_smoke.ps1 recomputes Max(5, 5*years) and discards
    # the number above (run_smoke.ps1:3348-3352).
    assert "-SmokeMode" in command


@pytest.mark.parametrize(
    ("from_date", "to_date", "expected"),
    [
        (FROM_DATE, TO_DATE, 1),          # 96 days
        ("2026.01.01", "2026.03.01", 1),  # 60 days
        ("2024.01.01", "2024.12.31", 5),  # a leap year is still the annual floor
        ("2025.01.01", "2025.12.31", 5),
        ("2024.01.01", "2025.12.31", 10),  # two years -> 2x the annual floor
        ("2026.01.01", "2026.01.01", 1),  # a single day never drops below 1
    ],
)
def test_prorated_floor_degenerates_to_the_annual_floor(
    from_date: str, to_date: str, expected: int
) -> None:
    assert farmctl._declared_window_min_trades(from_date, to_date) == expected


# ---------------------------------------------------------------------------
# 2. dispatcher: enqueue() carries the plan window
# ---------------------------------------------------------------------------


def test_inclusive_end_day_convention() -> None:
    assert subject.tester_date_from_utc(FROM_UTC, field="full_from_utc") == FROM_DATE
    # MT5 ToDate is the INCLUSIVE last calendar day: an end-of-day instant maps
    # to its own date, never to the following day.
    assert subject.tester_date_from_utc(TO_UTC, field="full_to_utc") == TO_DATE
    assert subject.FROM_DATE == FROM_DATE
    assert subject.TO_DATE == TO_DATE
    # farmctl re-derives the same window from the plan without importing this
    # module (that import would be circular), so the two must agree exactly.
    assert farmctl._campaign_plan_tester_window(
        {"full_from_utc": FROM_UTC, "full_to_utc": TO_UTC}
    ) == (FROM_DATE, TO_DATE)


def test_campaign_window_rejects_an_inverted_plan() -> None:
    with pytest.raises(subject.OOS2026Error, match="inverted"):
        subject.campaign_window({"full_from_utc": TO_UTC, "full_to_utc": FROM_UTC})


def _run_plan_file(tmp_path: Path) -> Path:
    path = tmp_path / "run_plan.json"
    path.write_text(
        json.dumps(
            {
                "plan_sha256": "a" * 64,
                "input_manifest_sha256": "b" * 64,
            }
        ),
        encoding="utf-8",
    )
    return path


def _enqueue_campaign(tmp_path: Path, plan_path: Path) -> dict[str, Any]:
    return {
        "campaign_id": CAMPAIGN_ID,
        "router_task_id": "router-task",
        "full_from_utc": FROM_UTC,
        "full_to_utc": TO_UTC,
        "campaign_plan_path": str(plan_path),
        "campaign_plan_sha256": subject.sha(plan_path),
        "runs": [
            {
                "rank": 1,
                "ea_id": "QM5_99999",
                "symbol": "USDJPY.DWX",
                "period": "H1",
                "work_item_id": "enqueue-window-test",
                "baseline_setfile_path": str(tmp_path / "inputs.set"),
                "staged_ex5_path": str(tmp_path / "demo.ex5"),
                "staged_ex5_sha256": "c" * 64,
                "anchor_path": str(tmp_path / "anchor.json"),
                "anchor_sha256": "d" * 64,
                "run_plan_path": str(_run_plan_file(tmp_path)),
                "run_plan_file_sha256": "e" * 64,
            }
        ],
    }


def test_enqueue_writes_the_plan_window_into_every_payload(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    db = tmp_path / "farm_state.sqlite"
    _make_db(db)
    campaign = _enqueue_campaign(tmp_path, _campaign_plan(tmp_path))

    class _Ctx:
        def __enter__(self):
            self.conn = sqlite3.connect(db)
            self.conn.row_factory = sqlite3.Row
            return self.conn

        def __exit__(self, *_exc):
            self.conn.close()
            return False

    monkeypatch.setattr(subject.farmctl, "connect", lambda _root: _Ctx())
    monkeypatch.setattr(subject, "ARTIFACT_ROOT", tmp_path / "artifacts")

    receipt = subject.enqueue(campaign)

    assert receipt["tester_window"]["from_date"] == FROM_DATE
    with sqlite3.connect(db) as conn:
        payload = json.loads(
            conn.execute(
                "SELECT payload_json FROM work_items WHERE id=?",
                ("enqueue-window-test",),
            ).fetchone()[0]
        )
    assert payload["from_date"] == FROM_DATE
    assert payload["to_date"] == TO_DATE
    assert payload["window_from_utc"] == FROM_UTC
    assert payload["window_to_utc"] == TO_UTC
    assert payload["diagnostic_campaign_plan_path"] == campaign["campaign_plan_path"]
    assert payload["diagnostic_campaign_plan_sha256"] == campaign["campaign_plan_sha256"]
    # The window must actually reach the spawn builder's contract, and the row
    # must satisfy the spawn-time plan re-derivation.
    assert farmctl._diagnostic_single_window(payload) == (FROM_DATE, TO_DATE)
    assert farmctl._diagnostic_campaign_window_refusal(
        payload, (FROM_DATE, TO_DATE)
    ) is None


def test_enqueue_refuses_a_campaign_without_a_plan_binding(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    campaign = _enqueue_campaign(tmp_path, _campaign_plan(tmp_path))
    campaign.pop("campaign_plan_sha256")
    monkeypatch.setattr(subject, "ARTIFACT_ROOT", tmp_path / "artifacts")

    with pytest.raises(subject.OOS2026Error, match="campaign_plan_path"):
        subject.enqueue(campaign)


# ---------------------------------------------------------------------------
# 3. repair mode
# ---------------------------------------------------------------------------


def _make_db(db: Path) -> None:
    db.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(db) as conn:
        conn.execute(
            "CREATE TABLE work_items("
            "id TEXT PRIMARY KEY,kind TEXT,phase TEXT,ea_id TEXT,symbol TEXT,"
            "setfile_path TEXT,status TEXT,verdict TEXT,attempt_count INTEGER,"
            "parent_task_id TEXT,claimed_by TEXT,payload_json TEXT,"
            "created_at TEXT,updated_at TEXT,gate_contract_version TEXT,"
            "data_window_start TEXT,data_window_end TEXT)"
        )
        conn.execute(
            "CREATE TABLE work_item_holds("
            "work_item_id TEXT PRIMARY KEY,hold_code TEXT NOT NULL,reason TEXT NOT NULL,"
            "active INTEGER NOT NULL DEFAULT 1,release_on_restart INTEGER NOT NULL DEFAULT 0,"
            "created_at TEXT NOT NULL,updated_at TEXT NOT NULL,released_at TEXT,"
            "release_note TEXT)"
        )
        conn.execute(
            "CREATE TABLE work_item_transition_ledger("
            "idempotency_key TEXT PRIMARY KEY,ts TEXT,work_item_id TEXT,action TEXT,"
            "from_status TEXT,to_status TEXT,from_verdict TEXT,to_verdict TEXT,"
            "reason TEXT,run_id TEXT,detail_json TEXT)"
        )
        conn.execute(
            "CREATE TABLE events("
            "id INTEGER PRIMARY KEY AUTOINCREMENT,ts TEXT,entity_type TEXT,"
            "entity_id TEXT,event TEXT,detail_json TEXT)"
        )


def _base_payload(rank: int) -> dict[str, Any]:
    payload = {
        "window_source": "oos_2026",
        "diagnostic_non_admission": True,
        "diagnostic_single_window": True,
        "diagnostic_campaign_id": CAMPAIGN_ID,
        "diagnostic_contract": q09.DIAGNOSTIC_CONTRACT,
        "diagnostic_queue_rank": 10000 + rank,
        "diagnostic_allowed_terminals": ["T1", "T2", "T3", "T4", "T5"],
        "avoid_terminals": ["T6", "T7", "T8", "T9", "T10"],
        "host_symbol": "USDJPY.DWX",
        "host_timeframe": "H1",
        "risk_fixed": 1000.0,
        "risk_percent": 0.0,
        "q09_activation_state": "RUNNABLE_BOUND",
        "q09_binding_version": "q09-news-dispatch-binding/v1",
        "q09_run_plan_path": r"D:\QM\plan.json",
        "q09_run_plan_file_sha256": "f" * 64,
        "q09_run_plan_sha256": "1" * 64,
        "q09_input_manifest_sha256": "2" * 64,
        "q09_cell_count": 1,
        "q09_cell_timeout_sec": 3600,
        "staged_ex5_path": r"C:\QM\demo.ex5",
        "staged_ex5_sha256": "3" * 64,
        "timeout_min": 90,
    }
    payload["q09_dispatch_binding_sha256"] = q09._dispatch_binding_sha256(payload)
    return payload


def _insert(
    db: Path,
    *,
    work_item_id: str,
    status: str,
    payload: dict[str, Any],
    verdict: str | None = None,
    claimed_by: str | None = None,
) -> None:
    with sqlite3.connect(db) as conn:
        conn.execute(
            "INSERT INTO work_items(id,kind,phase,ea_id,symbol,setfile_path,status,"
            "verdict,attempt_count,parent_task_id,claimed_by,payload_json,created_at,"
            "updated_at,gate_contract_version,data_window_start,data_window_end)"
            " VALUES(?,'backtest','Q09_NEWS','QM5_13213','USDJPY.DWX',?,?,?,0,NULL,?,?,"
            "'2026-09-02T10:00:00+00:00','2026-09-02T10:00:00+00:00','v4',NULL,NULL)",
            (
                work_item_id,
                rf"D:\QM\sets\{work_item_id}.set",
                status,
                verdict,
                claimed_by,
                json.dumps(payload, sort_keys=True),
            ),
        )


def _hold(db: Path, work_item_id: str, hold_code: str) -> None:
    with sqlite3.connect(db) as conn:
        conn.execute(
            "INSERT INTO work_item_holds(work_item_id,hold_code,reason,active,"
            "release_on_restart,created_at,updated_at) VALUES(?,?,?,1,0,?,?)",
            (
                work_item_id,
                hold_code,
                "fixture hold",
                "2026-09-04T00:00:00+00:00",
                "2026-09-04T00:00:00+00:00",
            ),
        )


# Rows that MUST be invisible to the repair.  The primary safety property of a
# one-off mutation is its blast radius, so the fixture carries the near misses:
# another campaign, a claimed row, an active row, and a campaign-id row that is
# not in the non-admission lane.
BYSTANDER_IDS = (
    "foreign-campaign-pending",
    "campaign-pending-claimed",
    "campaign-active",
    "campaign-not-non-admission",
    "no-campaign-diagnostic",
)


@pytest.fixture()
def fixture_db(tmp_path: Path) -> tuple[Path, Path, Path]:
    farm_root = tmp_path / "farm"
    db = farm_root / "state" / "farm_state.sqlite"
    _make_db(db)

    # (a) pending, held with OOS_WINDOW_MISMATCH, no window keys.
    _insert(db, work_item_id="pending-held", status="pending", payload=_base_payload(1))
    _hold(db, "pending-held", subject.WINDOW_HOLD_CODE)

    # (b) pending, no window keys, held for an UNRELATED reason.
    _insert(
        db, work_item_id="pending-foreign-hold", status="pending", payload=_base_payload(2)
    )
    _hold(db, "pending-foreign-hold", "Q09_AWAITING_SEALED_PLAN")

    # (c) done on the WRONG (default-year) window.
    wrong = _base_payload(3)
    wrong.update({
        "expected_from_date": "2024.01.01",
        "expected_to_date": "2024.12.31",
        "expected_symbol": "USDJPY.DWX",
        "expected_period": "H1",
        "terminal": "T1",
        "pid": 2512,
        "report_root": r"D:\QM\reports\work_items\done-wrong",
        "verdict_taxonomy": "review",
        "smoke_year_count": 1,
    })
    _insert(
        db,
        work_item_id="done-wrong",
        status="done",
        verdict="REVIEW_REQUIRED",
        payload=wrong,
    )

    # (d) done on the CORRECT window.
    right = _base_payload(4)
    right.update({"expected_from_date": FROM_DATE, "expected_to_date": TO_DATE})
    _insert(
        db,
        work_item_id="done-correct",
        status="done",
        verdict="REVIEW_REQUIRED",
        payload=right,
    )

    plan_path = _campaign_plan(tmp_path)

    # (e) pending, already repaired: window keys + a CURRENT plan binding, no hold.
    repaired = _base_payload(5)
    repaired.update({
        "from_date": FROM_DATE,
        "to_date": TO_DATE,
        "window_from_utc": FROM_UTC,
        "window_to_utc": TO_UTC,
        subject.WINDOW_REPAIR_MARKER: {
            "at_utc": "2026-09-04T00:00:00+00:00",
            "campaign_plan_path": str(plan_path),
            "campaign_plan_sha256": subject.sha(plan_path),
        },
    })
    _insert(db, work_item_id="pending-repaired", status="pending", payload=repaired)

    # --- bystanders: none of these may be read, patched, released or minted ---
    foreign = _base_payload(6)
    foreign["diagnostic_campaign_id"] = "q09-live-news-backfill-20260805-v1"
    _insert(db, work_item_id="foreign-campaign-pending", status="pending", payload=foreign)
    _hold(db, "foreign-campaign-pending", subject.WINDOW_HOLD_CODE)

    _insert(
        db,
        work_item_id="campaign-pending-claimed",
        status="pending",
        payload=_base_payload(7),
        claimed_by="T3",
    )
    _hold(db, "campaign-pending-claimed", subject.WINDOW_HOLD_CODE)

    _insert(
        db, work_item_id="campaign-active", status="active",
        payload=_base_payload(8), claimed_by="T4",
    )

    lax = _base_payload(9)
    lax.pop("diagnostic_non_admission")
    _insert(db, work_item_id="campaign-not-non-admission", status="pending", payload=lax)

    orphan = _base_payload(10)
    orphan.pop("diagnostic_campaign_id")
    _insert(db, work_item_id="no-campaign-diagnostic", status="pending", payload=orphan)

    return db, plan_path, farm_root


def _payload_of(db: Path, work_item_id: str) -> dict[str, Any]:
    with sqlite3.connect(db) as conn:
        return json.loads(
            conn.execute(
                "SELECT payload_json FROM work_items WHERE id=?", (work_item_id,)
            ).fetchone()[0]
        )


def _snapshot(db: Path, ids: tuple[str, ...] | None = None) -> list[tuple[Any, ...]]:
    where = ""
    params: tuple[Any, ...] = ()
    if ids is not None:
        placeholders = ",".join("?" for _ in ids)
        where = f" WHERE id IN ({placeholders})"
        params = ids
    with sqlite3.connect(db) as conn:
        items = conn.execute(
            "SELECT id,status,verdict,payload_json,updated_at,claimed_by "
            f"FROM work_items{where} ORDER BY id",
            params,
        ).fetchall()
        hold_where = where.replace(" WHERE id IN", " WHERE work_item_id IN")
        holds = conn.execute(
            "SELECT work_item_id,hold_code,active,released_at,release_note "
            f"FROM work_item_holds{hold_where} ORDER BY work_item_id",
            params,
        ).fetchall()
    return [*items, *holds]


def test_dry_run_reports_the_exact_changes_and_mutates_nothing(
    fixture_db: tuple[Path, Path, Path]
) -> None:
    db, plan_path, _farm_root = fixture_db
    before = _snapshot(db)

    result = subject.plan_oos_window_repair(db, campaign_plan_path=plan_path)

    assert result["mode"] == "DRY_RUN"
    assert result["window"]["from_date"] == FROM_DATE
    assert result["window"]["to_date"] == TO_DATE
    assert result["counts"] == {
        # the foreign campaign and the campaign-less row are not even selected
        "campaign_rows": 8,
        "pending_to_patch": 2,
        "holds_to_release": 1,
        "done_to_succeed": 1,
        "unchanged": 2,
        "skipped": 3,
    }

    patches = {entry["work_item_id"]: entry for entry in result["pending_patches"]}
    assert set(patches) == {"pending-held", "pending-foreign-hold"}
    held = patches["pending-held"]
    assert held["before"] == {key: None for key in subject.WINDOW_KEYS}
    assert held["after"] == {
        "from_date": FROM_DATE,
        "to_date": TO_DATE,
        "window_from_utc": FROM_UTC,
        "window_to_utc": TO_UTC,
    }
    assert held["hold_release"] is True
    assert held["hold_code"] == subject.WINDOW_HOLD_CODE
    assert patches["pending-foreign-hold"]["hold_release"] is False

    successor = result["successors"][0]
    assert successor["work_item_id"] == "done-wrong"
    assert successor["before"]["expected_from_date"] == "2024.01.01"
    assert successor["after"]["from_date"] == FROM_DATE
    assert "expected_from_date" in successor["dropped_keys"]
    assert "2024" in successor["rerun_reason"]
    assert "2026.01.01" in successor["rerun_reason"]
    assert subject.WINDOW_REPAIR_TASK_REF in successor["rerun_reason"]

    unchanged = {entry["work_item_id"]: entry["reason"] for entry in result["unchanged"]}
    assert unchanged == {
        "done-correct": "done_window_matches_plan",
        "pending-repaired": "already_repaired",
    }
    skipped = {entry["work_item_id"]: entry["reason"] for entry in result["skipped"]}
    assert skipped == {
        "campaign-pending-claimed": "pending_row_is_claimed",
        "campaign-active": "status_not_repairable:active",
        "campaign-not-non-admission": "outside_diagnostic_non_admission_lane",
    }
    assert _snapshot(db) == before


def test_a_stale_plan_binding_is_repaired_even_with_the_window_present(
    fixture_db: tuple[Path, Path, Path]
) -> None:
    """The window alone is not enough: an unbindable row cannot spawn."""
    db, plan_path, _farm_root = fixture_db
    payload = _base_payload(11)
    payload.update({
        "from_date": FROM_DATE,
        "to_date": TO_DATE,
        "window_from_utc": FROM_UTC,
        "window_to_utc": TO_UTC,
    })
    _insert(db, work_item_id="pending-unbound", status="pending", payload=payload)

    result = subject.plan_oos_window_repair(db, campaign_plan_path=plan_path)

    entry = next(
        e for e in result["pending_patches"] if e["work_item_id"] == "pending-unbound"
    )
    assert entry["payload_change"] is True
    assert entry["added_keys"] == [subject.WINDOW_REPAIR_MARKER]


def test_apply_patches_releases_and_mints_then_is_idempotent(
    fixture_db: tuple[Path, Path, Path], tmp_path: Path
) -> None:
    db, plan_path, farm_root = fixture_db
    lock = tmp_path / "FACTORY_MUTATION.lock"
    out = tmp_path / "receipt.json"
    bystanders_before = _snapshot(db, BYSTANDER_IDS)

    receipt = subject.apply_oos_window_repair(
        db, lock, out, campaign_plan_path=plan_path, farm_root=farm_root
    )

    assert receipt["mode"] == "APPLY"
    assert out.is_file()
    assert json.loads(out.read_text(encoding="utf-8"))["mode"] == "APPLY"
    assert not (tmp_path / "receipt.json.tmp").exists()
    assert sorted(receipt["patched_work_items"]) == [
        "pending-foreign-hold",
        "pending-held",
    ]
    assert receipt["released_holds"] == ["pending-held"]
    successor_id = receipt["minted_successors"][0]

    # (a) pending payloads carry the window and the audit block.
    patched = _payload_of(db, "pending-held")
    assert patched["from_date"] == FROM_DATE
    assert patched["to_date"] == TO_DATE
    assert patched["window_from_utc"] == FROM_UTC
    assert patched["window_to_utc"] == TO_UTC
    audit = patched[subject.WINDOW_REPAIR_MARKER]
    assert audit["from"] == FROM_DATE
    assert audit["to"] == TO_DATE
    assert audit["campaign_plan_sha256"] == subject.sha(plan_path)
    assert audit["campaign_plan_path"] == str(plan_path)
    assert audit["at_utc"]
    # The repaired row now satisfies the spawn-time re-derivation.
    assert farmctl._diagnostic_campaign_window_refusal(
        patched, (FROM_DATE, TO_DATE)
    ) is None
    # Q09 identity survives untouched.
    assert patched["q09_run_plan_sha256"] == "1" * 64
    assert patched["diagnostic_queue_rank"] == 10001

    # (b) only the OOS_WINDOW_MISMATCH hold of a campaign row is released.
    with sqlite3.connect(db) as conn:
        holds = {
            row[0]: row[1:]
            for row in conn.execute(
                "SELECT work_item_id,hold_code,active,released_at,release_note "
                "FROM work_item_holds"
            )
        }
    assert holds["pending-held"][1] == 0
    assert holds["pending-held"][2]  # released_at
    assert subject.WINDOW_REPAIR_TASK_REF in holds["pending-held"][3]
    assert holds["pending-foreign-hold"][0] == "Q09_AWAITING_SEALED_PLAN"
    assert holds["pending-foreign-hold"][1] == 1
    assert holds["pending-foreign-hold"][2] is None
    # the same hold_code on a foreign campaign / claimed row stays active
    assert holds["foreign-campaign-pending"][1] == 1
    assert holds["campaign-pending-claimed"][1] == 1

    # (c) the append-only successor.
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            "SELECT * FROM work_items WHERE id=?", (successor_id,)
        ).fetchone()
        source = conn.execute(
            "SELECT status,verdict,payload_json FROM work_items WHERE id=?",
            ("done-wrong",),
        ).fetchone()
    assert row["status"] == "pending"
    assert row["verdict"] is None
    assert row["phase"] == "Q09_NEWS"
    assert row["ea_id"] == "QM5_13213"
    assert row["symbol"] == "USDJPY.DWX"
    assert row["setfile_path"] == r"D:\QM\sets\done-wrong.set"
    assert row["gate_contract_version"] == "v4"
    successor_payload = json.loads(row["payload_json"])
    assert successor_payload["append_only_rerun"] is True
    assert successor_payload["append_only_rerun_of_work_item"] == "done-wrong"
    assert successor_payload["append_only_rerun_lineage_work_items"] == ["done-wrong"]
    assert successor_payload["historical_work_item_preserved"] is True
    assert successor_payload["from_date"] == FROM_DATE
    assert successor_payload["to_date"] == TO_DATE
    assert successor_payload["diagnostic_queue_rank"] == 10003
    assert successor_payload["q09_activation_state"] == "RUNNABLE_BOUND"
    assert successor_payload["q09_run_plan_path"] == r"D:\QM\plan.json"
    assert successor_payload["diagnostic_single_window"] is True
    assert farmctl._diagnostic_campaign_window_refusal(
        successor_payload, (FROM_DATE, TO_DATE)
    ) is None
    for residue in ("expected_from_date", "expected_to_date", "pid", "terminal",
                    "report_root", "verdict_taxonomy"):
        assert residue not in successor_payload

    # (d) the historical row is untouched but is now marked superseded.
    assert source["status"] == "done"
    assert source["verdict"] == "REVIEW_REQUIRED"
    assert json.loads(source["payload_json"])["expected_from_date"] == "2024.01.01"
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        supersedes = conn.execute("SELECT * FROM work_item_supersedes").fetchall()
    assert len(supersedes) == 1
    assert supersedes[0]["work_item_id"] == "done-wrong"
    assert supersedes[0]["superseded_by_work_item_id"] == successor_id
    assert supersedes[0]["source_encoding"] == subject.SUPERSEDES_SOURCE_ENCODING
    assert supersedes[0]["evidence_path"] == str(out)
    assert "2024.01.01" in supersedes[0]["reason"]
    assert receipt["superseded_work_items"] == [
        {"work_item_id": "done-wrong", "superseded_by_work_item_id": successor_id}
    ]

    # (e) governed evidence: state backup, ledger row, events rows.
    backup = receipt["state_backup"]
    assert Path(backup["path"]).is_file()
    assert len(backup["sha256"]) == 64
    assert Path(backup["path"]).parent == farm_root / "state" / "backups"
    release_entry = next(
        e for e in receipt["pending_patches"] if e["work_item_id"] == "pending-held"
    )
    assert release_entry["ledger_written"] is True
    with sqlite3.connect(db) as conn:
        conn.row_factory = sqlite3.Row
        ledger = conn.execute(
            "SELECT * FROM work_item_transition_ledger WHERE action='work_item_hold_released'"
        ).fetchall()
        events = conn.execute("SELECT * FROM events ORDER BY id").fetchall()
    assert len(ledger) == 1
    ledger_detail = json.loads(ledger[0]["detail_json"])
    assert ledger_detail["backup_path"] == backup["path"]
    assert ledger_detail["backup_sha256"] == backup["sha256"]
    assert ledger_detail["hold_code"] == subject.WINDOW_HOLD_CODE
    event_names = [e["event"] for e in events]
    assert event_names == ["work_item_hold_released", "work_item_superseded"]
    assert events[0]["entity_id"] == "pending-held"
    assert json.loads(events[0]["detail_json"])["backup_sha256"] == backup["sha256"]
    assert events[1]["entity_id"] == "done-wrong"
    assert json.loads(events[1]["detail_json"])[
        "superseded_by_work_item_id"
    ] == successor_id

    # (f) blast radius: every bystander row is byte-identical.
    assert _snapshot(db, BYSTANDER_IDS) == bystanders_before

    # (g) idempotence: a second run changes nothing.
    before = _snapshot(db)
    second = subject.plan_oos_window_repair(db, campaign_plan_path=plan_path)
    assert second["counts"]["pending_to_patch"] == 0
    assert second["counts"]["holds_to_release"] == 0
    assert second["counts"]["done_to_succeed"] == 0
    assert {e["work_item_id"]: e["reason"] for e in second["unchanged"]}[
        "done-wrong"
    ] == "supersession_already_recorded"
    out2 = tmp_path / "receipt2.json"
    applied2 = subject.apply_oos_window_repair(
        db, lock, out2, campaign_plan_path=plan_path, farm_root=farm_root
    )
    assert applied2["patched_work_items"] == []
    assert applied2["released_holds"] == []
    assert applied2["minted_successors"] == []
    # a no-op apply mints no backup and litters no directory
    assert applied2["state_backup"] == {"path": None, "sha256": None}
    assert _snapshot(db) == before


def test_apply_uses_the_short_mutation_lock_busy_envelope(
    fixture_db: tuple[Path, Path, Path], monkeypatch: pytest.MonkeyPatch
) -> None:
    """farmctl.py:1312-1324: a governed writer under the mutation lock never
    waits minutes for the SQLite write lock."""
    db, _plan_path, _farm_root = fixture_db
    seen: list[float] = []
    real_connect = sqlite3.connect

    def spy(target, *args, **kwargs):
        if str(target) == str(db):
            seen.append(float(kwargs.get("timeout", 5.0)))
        return real_connect(target, *args, **kwargs)

    monkeypatch.setattr(subject.sqlite3, "connect", spy)
    conn = subject._connect_under_mutation_lock(db)
    conn.close()
    assert seen == [farmctl.MUTATION_LOCK_DB_TIMEOUT_SECONDS]
    assert farmctl.MUTATION_LOCK_DB_TIMEOUT_SECONDS <= 3.0


def test_apply_writes_no_receipt_when_the_transaction_fails(
    fixture_db: tuple[Path, Path, Path], tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    """A rolled-back apply must not leave an artifact claiming the mutations."""
    db, plan_path, farm_root = fixture_db
    out = tmp_path / "receipt.json"

    def boom(*_args, **_kwargs):
        raise sqlite3.OperationalError("disk I/O error")

    monkeypatch.setattr(subject, "_apply_window_repair_locked", boom)
    with pytest.raises(sqlite3.OperationalError):
        subject.apply_oos_window_repair(
            db, tmp_path / "FACTORY_MUTATION.lock", out,
            campaign_plan_path=plan_path, farm_root=farm_root,
        )
    assert not out.exists()
    assert not (tmp_path / "receipt.json.tmp").exists()
    with sqlite3.connect(db) as conn:
        assert conn.execute(
            "SELECT active FROM work_item_holds WHERE work_item_id='pending-held'"
        ).fetchone()[0] == 1


def test_apply_refuses_to_overwrite_an_existing_receipt(
    fixture_db: tuple[Path, Path, Path], tmp_path: Path
) -> None:
    db, plan_path, farm_root = fixture_db
    out = tmp_path / "receipt.json"
    out.write_text("{}", encoding="utf-8")
    with pytest.raises(subject.OOS2026Error, match="refusing to overwrite"):
        subject.apply_oos_window_repair(
            db, tmp_path / "FACTORY_MUTATION.lock", out,
            campaign_plan_path=plan_path, farm_root=farm_root,
        )


def test_repair_skips_a_pending_row_whose_window_contradicts_the_plan(
    fixture_db: tuple[Path, Path, Path]
) -> None:
    db, plan_path, _farm_root = fixture_db
    payload = _base_payload(12)
    payload.update({"from_date": "2025.01.01", "to_date": "2025.12.31"})
    _insert(db, work_item_id="pending-contradiction", status="pending", payload=payload)

    result = subject.plan_oos_window_repair(db, campaign_plan_path=plan_path)

    skipped = {entry["work_item_id"]: entry for entry in result["skipped"]}
    assert skipped["pending-contradiction"]["reason"] == "pending_window_contradiction"
    assert skipped["pending-contradiction"]["contradictions"]["from_date"] == {
        "actual": "2025.01.01",
        "expected": FROM_DATE,
    }


def test_repair_rejects_a_foreign_campaign_plan(
    fixture_db: tuple[Path, Path, Path], tmp_path: Path
) -> None:
    db, _plan_path, _farm_root = fixture_db
    foreign = tmp_path / "foreign_plan.json"
    foreign.write_text(
        json.dumps({"campaign_id": "some-other-campaign"}), encoding="utf-8"
    )
    with pytest.raises(subject.OOS2026Error, match="campaign plan is not"):
        subject.plan_oos_window_repair(db, campaign_plan_path=foreign)
