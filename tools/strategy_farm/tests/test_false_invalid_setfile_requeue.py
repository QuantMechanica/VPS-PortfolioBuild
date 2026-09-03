"""Coverage for the guarded false-INVALID universe-expansion setfile requeue.

Class T2_SETFILE_PATH_PROVENANCE_FALSE_INVALID
(docs/ops/evidence/2026-09-03_vein1_false_invalid_requeue_packet.md, 2.4).

The pure precondition checker is exercised in isolation, and the enqueue
function is exercised against a hermetic tmp DB / tmp repo: happy-path insert,
every refusal reason, and the read-only dry run that inserts nothing.
"""

import json
import sqlite3
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import farmctl  # noqa: E402


EA_ID = "QM5_9971"
EA_DIR_NAME = "QM5_9971_falseinv-demo"
SYMBOL = "EURUSD.DWX"
NATIVE_PASS_ID = "native-pass-row"
SOURCE_ID = "false-invalid-source"
DEAD_SETFILE = (
    "C:\\QM\\worktrees\\rb-universe-expansion\\framework\\EAs\\"
    f"{EA_DIR_NAME}\\sets\\{EA_DIR_NAME}_{SYMBOL}_H1_backtest.set"
)
# A canonical-shaped path (no "worktrees" segment) for the provenance guard.
NON_WORKTREE_SETFILE = (
    "C:\\QM\\repo\\framework\\EAs\\"
    f"{EA_DIR_NAME}\\sets\\{EA_DIR_NAME}_{SYMBOL}_H1_backtest.set"
)
REQUAL_REASON = (
    "era audit vein 1: false INVALID from purged worktree setfile path "
    "(OWNER-DEC-13036-XAU)"
)


def _artifacts(tmp_path, monkeypatch, *, risk_percent="0", magic_rows=1):
    root = tmp_path / "farm"
    repo_root = tmp_path / "repo"
    ea_dir = repo_root / "framework" / "EAs" / EA_DIR_NAME
    sets_dir = ea_dir / "sets"
    sets_dir.mkdir(parents=True)
    mq5 = ea_dir / f"{EA_DIR_NAME}.mq5"
    ex5 = ea_dir / f"{EA_DIR_NAME}.ex5"
    setfile = sets_dir / f"{EA_DIR_NAME}_{SYMBOL}_H1_backtest.set"
    mq5.write_text("// current source\n", encoding="utf-8")
    ex5.write_bytes(b"current compiled binary")
    setfile.write_text(
        f"RISK_FIXED=1000\nRISK_PERCENT={risk_percent}\n", encoding="utf-8"
    )
    registry = repo_root / "framework" / "registry"
    registry.mkdir(parents=True)
    header = "ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status\n"
    lines = [header]
    for slot in range(magic_rows):
        lines.append(
            f"9971,falseinv-demo,{slot},{SYMBOL},9971000{slot},2026-08-23,Codex,active\n"
        )
    (registry / "magic_numbers.csv").write_text("".join(lines), encoding="utf-8")
    monkeypatch.setattr(farmctl, "REPO_ROOT", repo_root)
    farmctl.init_db(root)
    return {
        "root": root,
        "repo_root": repo_root,
        "ea_dir": ea_dir,
        "mq5": mq5,
        "ex5": ex5,
        "setfile": setfile,
        "ex5_sha": farmctl._sha256_file(ex5),
        "mq5_sha": farmctl._sha256_file(mq5),
        "setfile_sha": farmctl._sha256_file(setfile),
    }


def _source_payload(art, **overrides):
    payload = {
        "expected_ex5_sha256": art["ex5_sha"],
        "expected_mq5_sha256": art["mq5_sha"],
        "expected_setfile_sha256": art["setfile_sha"],
        "expected_symbol": SYMBOL,
        "expected_period": "H1",
        "expected_expert": f"QM\\{EA_DIR_NAME}",
        "native_q02_pass_work_item_id": NATIVE_PASS_ID,
        "universe_expansion": True,
        "universe_expansion_owner_decision": "OWNER-DEC-13036-XAU",
        "universe_expansion_priority": "BELOW_ALL_REBASELINE_BACKFILL",
        "priority_track": False,
        "recovery_class": "UNIVERSE_EXPANSION_LOW_PRIORITY",
        "verdict_reason": "setfile_missing",
        "target_symbols": [SYMBOL],
        "target_timeframe": "H1",
        "from_year": 2017,
        "to_year": 2022,
    }
    payload.update(overrides)
    return payload


def _insert_row(
    art,
    *,
    item_id,
    status,
    verdict,
    payload,
    phase="Q02",
    symbol=SYMBOL,
    setfile_path=DEAD_SETFILE,
    claimed_by=None,
    updated_at="2026-08-25T00:00:00+00:00",
):
    root = art["root"]
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
                id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,
                created_at,updated_at
            ) VALUES(?, 'backtest', ?, ?, ?, ?, ?, ?, 0, NULL, NULL, ?, ?, ?, ?)
            """,
            (
                item_id,
                phase,
                EA_ID,
                symbol,
                setfile_path,
                status,
                verdict,
                claimed_by,
                json.dumps(payload, sort_keys=True),
                updated_at,
                updated_at,
            ),
        )
        conn.commit()


def _seed(art, *, source_payload=None, source_verdict="INVALID", source_status="failed"):
    """Insert the valid native PASS parent and the false-INVALID source row."""
    _insert_row(
        art,
        item_id=NATIVE_PASS_ID,
        status="done",
        verdict="PASS",
        symbol="GBPUSD.DWX",
        setfile_path=str(art["setfile"]),
        payload={"native": True},
        updated_at="2026-08-23T00:00:00+00:00",
    )
    _insert_row(
        art,
        item_id=SOURCE_ID,
        status=source_status,
        verdict=source_verdict,
        payload=source_payload if source_payload is not None else _source_payload(art),
    )


def _count(art):
    with sqlite3.connect(art["root"] / farmctl.DB_REL) as conn:
        return int(conn.execute("SELECT count(*) FROM work_items").fetchone()[0])


def _run(art, **overrides):
    kwargs = {
        "requal_reason": REQUAL_REASON,
        "expected_current_ex5_sha256": art["ex5_sha"],
        "apply": True,
    }
    kwargs.update(overrides)
    return farmctl.enqueue_false_invalid_setfile_requeue(
        art["root"], SOURCE_ID, **kwargs
    )


# --------------------------------------------------------------------------
# happy path
# --------------------------------------------------------------------------
def test_happy_path_inserts_exactly_one_successor(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    _seed(art)
    before = _count(art)

    result = _run(art)

    assert result["enqueued"] is True
    assert result["dry_run"] is False
    assert _count(art) == before + 1

    root = art["root"]
    new_id = result["id"]
    with sqlite3.connect(root / farmctl.DB_REL) as conn:
        conn.row_factory = sqlite3.Row
        row = conn.execute(
            "SELECT * FROM work_items WHERE id=?", (new_id,)
        ).fetchone()
        source = conn.execute(
            "SELECT status,verdict FROM work_items WHERE id=?", (SOURCE_ID,)
        ).fetchone()
    payload = json.loads(row["payload_json"])

    # the successor is a pending Q02 row bound to the CANONICAL setfile
    assert row["status"] == "pending"
    assert row["phase"] == "Q02"
    assert row["symbol"] == SYMBOL
    assert row["setfile_path"] == str(art["setfile"])
    # required payload markers
    assert payload["append_only_rerun"] is True
    assert payload["append_only_rerun_of"] == SOURCE_ID
    assert payload["requeue_class"] == "T2_SETFILE_PATH_PROVENANCE_FALSE_INVALID"
    assert payload["requalification_reason"] == REQUAL_REASON
    assert payload["priority_track"] is False
    # copied identity binding
    assert payload["expected_ex5_sha256"] == art["ex5_sha"]
    assert payload["expected_setfile_sha256"] == art["setfile_sha"]
    assert payload["expected_symbol"] == SYMBOL
    assert payload["expected_expert"] == f"QM\\{EA_DIR_NAME}"
    assert payload["expected_current_ex5_sha256"] == art["ex5_sha"]
    assert payload["risk_fixed"] == 1000.0
    assert payload["risk_percent"] == 0.0
    assert payload["requeue_canonical_setfile_sha256"] == art["setfile_sha"]
    assert payload["requeue_source_setfile_path"] == str(Path(DEAD_SETFILE))
    # the preserved terminal INVALID row is untouched
    assert (source["status"], source["verdict"]) == ("failed", "INVALID")


def test_dry_run_default_inserts_nothing(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    _seed(art)
    before = _count(art)

    result = farmctl.enqueue_false_invalid_setfile_requeue(
        art["root"],
        SOURCE_ID,
        requal_reason=REQUAL_REASON,
        expected_current_ex5_sha256=art["ex5_sha"],
        apply=False,
    )

    assert result["enqueued"] is False
    assert result["dry_run"] is True
    assert result["would_enqueue"] is True
    assert result["setfile_path"] == str(art["setfile"])
    assert _count(art) == before  # nothing inserted


# --------------------------------------------------------------------------
# refusals (enqueue function)
# --------------------------------------------------------------------------
def test_refuses_missing_source(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    result = _run(art)
    assert result["enqueued"] is False
    assert result["reason"] == "false_invalid_requeue_source_missing"
    assert _count(art) == 0


def test_refuses_source_not_q02_invalid_setfile_missing(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    _seed(art, source_verdict="FAIL")
    result = _run(art)
    assert result["enqueued"] is False
    assert (
        result["reason"]
        == "false_invalid_requeue_source_not_q02_invalid_setfile_missing"
    )
    assert _count(art) == 2


def test_refuses_non_setfile_missing_reason(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    _seed(art, source_payload=_source_payload(art, verdict_reason="zero_trades"))
    result = _run(art)
    assert (
        result["reason"]
        == "false_invalid_requeue_source_not_q02_invalid_setfile_missing"
    )
    assert _count(art) == 2


def test_refuses_setfile_path_not_removed_worktree(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    _insert_row(
        art,
        item_id=NATIVE_PASS_ID,
        status="done",
        verdict="PASS",
        symbol="GBPUSD.DWX",
        setfile_path=str(art["setfile"]),
        payload={"native": True},
    )
    # a canonical (non-worktree) setfile path is bound to the exact EA dir but
    # is not a removed worktree, so the provenance guard refuses it.
    _insert_row(
        art,
        item_id=SOURCE_ID,
        status="failed",
        verdict="INVALID",
        setfile_path=NON_WORKTREE_SETFILE,
        payload=_source_payload(art),
    )
    result = _run(art)
    assert (
        result["reason"] == "false_invalid_requeue_setfile_path_not_removed_worktree"
    )
    assert _count(art) == 2


def test_refuses_current_ex5_hash_mismatch(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    _seed(art)
    result = _run(art, expected_current_ex5_sha256="f" * 64)
    assert result["reason"] == "false_invalid_requeue_current_ex5_hash_mismatch"
    assert _count(art) == 2


def test_refuses_source_ex5_binding_mismatch(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    _seed(art, source_payload=_source_payload(art, expected_ex5_sha256="1" * 64))
    result = _run(art)
    assert result["reason"] == "false_invalid_requeue_source_ex5_binding_mismatch"
    assert _count(art) == 2


def test_refuses_canonical_setfile_missing(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    _seed(art)
    art["setfile"].unlink()
    result = _run(art)
    assert result["reason"] == "false_invalid_requeue_canonical_setfile_missing"
    assert _count(art) == 2


def test_refuses_canonical_setfile_sha_mismatch(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    _seed(art, source_payload=_source_payload(art, expected_setfile_sha256="3" * 64))
    result = _run(art)
    assert result["reason"] == "false_invalid_requeue_canonical_setfile_sha_mismatch"
    assert _count(art) == 2


def test_refuses_fixed_risk_contract_violation(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch, risk_percent="1")
    # recompute the setfile sha after the RISK_PERCENT=1 write
    payload = _source_payload(art, expected_setfile_sha256=art["setfile_sha"])
    _seed(art, source_payload=payload)
    result = _run(art)
    assert result["reason"] == "fixed_risk_contract_violation"
    assert _count(art) == 2


def test_refuses_native_pass_parent_invalid(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    # source row only; no native PASS parent exists
    _insert_row(
        art,
        item_id=SOURCE_ID,
        status="failed",
        verdict="INVALID",
        payload=_source_payload(art),
    )
    result = _run(art)
    assert result["reason"] == "false_invalid_requeue_native_pass_parent_invalid"
    assert _count(art) == 1


def test_refuses_active_magic_row_count_invalid(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch, magic_rows=2)
    _seed(art)
    result = _run(art)
    assert result["reason"] == "false_invalid_requeue_active_magic_row_count_invalid"
    assert result["active_magic_rows"] == 2
    assert _count(art) == 2


def test_refuses_newer_terminal_row_for_pair(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    _seed(art)
    _insert_row(
        art,
        item_id="newer-terminal",
        status="done",
        verdict="FAIL",
        setfile_path=str(art["setfile"]),
        payload={"later": True},
        updated_at="2026-08-30T00:00:00+00:00",
    )
    result = _run(art)
    assert result["reason"] == "false_invalid_requeue_pair_has_newer_terminal"
    assert result["existing_work_item_id"] == "newer-terminal"
    assert _count(art) == 3


def test_refuses_pending_active_row_for_pair(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    _seed(art)
    _insert_row(
        art,
        item_id="pending-row",
        status="pending",
        verdict=None,
        setfile_path=str(art["setfile"]),
        payload={"open": True},
        updated_at="2026-08-26T00:00:00+00:00",
    )
    result = _run(art)
    assert result["reason"] == "already_pending_or_active"
    assert result["existing_work_item_id"] == "pending-row"
    assert _count(art) == 3


def test_refuses_existing_successor_is_idempotent(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    _seed(art)
    first = _run(art)
    assert first["enqueued"] is True
    second = _run(art)
    assert second["enqueued"] is False
    assert second["reason"] == "false_invalid_requeue_successor_already_exists"
    assert second["existing_work_item_id"] == first["id"]
    # only one successor exists
    assert _count(art) == 3


def test_apply_refused_when_precondition_fails_inserts_nothing(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    _seed(art)
    result = _run(art, expected_current_ex5_sha256="e" * 64)
    assert result["enqueued"] is False
    assert result["dry_run"] is False
    assert result["reason"] == "false_invalid_requeue_current_ex5_hash_mismatch"
    assert _count(art) == 2


def test_requires_reason(tmp_path, monkeypatch):
    art = _artifacts(tmp_path, monkeypatch)
    _seed(art)
    result = _run(art, requal_reason="  ")
    assert result["reason"] == "false_invalid_requeue_requires_requal_reason"
    assert _count(art) == 2


# --------------------------------------------------------------------------
# pure precondition checker
# --------------------------------------------------------------------------
def _base_facts():
    ex5 = "a" * 64
    setfile = "b" * 64
    return {
        "source_exists": True,
        "kind": "backtest",
        "phase": "Q02",
        "status": "failed",
        "verdict": "INVALID",
        "verdict_reason": "setfile_missing",
        "universe_expansion": True,
        "claimed": False,
        "setfile_bound_to_ea_dir": True,
        "setfile_is_removed_worktree": True,
        "expected_current_ex5_valid": True,
        "expected_current_ex5_sha256": ex5,
        "canonical_ex5_present": True,
        "canonical_ex5_sha256": ex5,
        "source_expected_ex5_sha256": ex5,
        "canonical_setfile_present": True,
        "canonical_setfile_sha256": setfile,
        "source_expected_setfile_sha256": setfile,
        "risk_contract_ok": True,
        "risk_contract_detail": {"risk_fixed": 1000.0, "risk_percent": 0.0},
        "native_pass_valid": True,
        "active_magic_row_count": 1,
        "existing_successor_row": None,
        "pair_open_row": None,
        "pair_newer_terminal_row": None,
    }


def test_precondition_base_facts_pass():
    assert farmctl._false_invalid_setfile_requeue_precondition(_base_facts()) == {
        "ok": True
    }


def test_precondition_refusals_are_ordered_and_specific():
    cases = [
        ({"source_exists": False}, "false_invalid_requeue_source_missing"),
        ({"verdict": "PASS"},
         "false_invalid_requeue_source_not_q02_invalid_setfile_missing"),
        ({"verdict_reason": "other"},
         "false_invalid_requeue_source_not_q02_invalid_setfile_missing"),
        ({"universe_expansion": False},
         "false_invalid_requeue_source_not_q02_invalid_setfile_missing"),
        ({"claimed": True},
         "false_invalid_requeue_source_not_q02_invalid_setfile_missing"),
        ({"setfile_bound_to_ea_dir": False},
         "false_invalid_requeue_setfile_not_bound_to_exact_ea_directory"),
        ({"setfile_is_removed_worktree": False},
         "false_invalid_requeue_setfile_path_not_removed_worktree"),
        ({"expected_current_ex5_valid": False},
         "expected_current_ex5_sha256_required_or_invalid"),
        ({"canonical_ex5_present": False},
         "false_invalid_requeue_canonical_ex5_missing"),
        ({"canonical_ex5_sha256": "c" * 64},
         "false_invalid_requeue_current_ex5_hash_mismatch"),
        ({"source_expected_ex5_sha256": "d" * 64},
         "false_invalid_requeue_source_ex5_binding_mismatch"),
        ({"canonical_setfile_present": False},
         "false_invalid_requeue_canonical_setfile_missing"),
        ({"source_expected_setfile_sha256": "not-a-hash"},
         "false_invalid_requeue_source_setfile_binding_missing_or_invalid"),
        ({"canonical_setfile_sha256": "e" * 64},
         "false_invalid_requeue_canonical_setfile_sha_mismatch"),
        ({"risk_contract_ok": False,
          "risk_contract_detail": {"reason": "fixed_risk_contract_violation"}},
         "fixed_risk_contract_violation"),
        ({"native_pass_valid": False},
         "false_invalid_requeue_native_pass_parent_invalid"),
        ({"active_magic_row_count": 0},
         "false_invalid_requeue_active_magic_row_count_invalid"),
        ({"existing_successor_row": {"id": "succ"}},
         "false_invalid_requeue_successor_already_exists"),
        ({"pair_open_row": {"id": "open"}}, "already_pending_or_active"),
        ({"pair_newer_terminal_row": {"id": "newer"}},
         "false_invalid_requeue_pair_has_newer_terminal"),
    ]
    for override, expected in cases:
        facts = _base_facts()
        facts.update(override)
        decision = farmctl._false_invalid_setfile_requeue_precondition(facts)
        assert decision["ok"] is False, (override, decision)
        assert decision["reason"] == expected, (override, decision)
