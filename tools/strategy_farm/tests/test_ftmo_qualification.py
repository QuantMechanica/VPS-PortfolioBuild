import csv
import json
import os
import sqlite3
import sys
import time
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

from portfolio import ftmo_qualification  # noqa: E402


def _fixture(tmp_path: Path, *, q08_verdict: str = "PASS", fresh_mae: bool = True):
    repo = tmp_path / "repo"
    common = tmp_path / "common"
    db = tmp_path / "farm.sqlite"
    ea_dir = repo / "framework" / "EAs" / "QM5_9001_demo"
    ea_dir.mkdir(parents=True)
    (ea_dir / "QM5_9001_demo.ex5").write_bytes(b"compiled")
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    registry.parent.mkdir(parents=True)
    with registry.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["ea_id", "symbol", "status"])
        writer.writeheader()
        writer.writerow({"ea_id": "9001", "symbol": "NDX.DWX", "status": "active"})

    durable_stream = tmp_path / "durable" / "QM" / "q08_trades" / "9001_NDX_DWX.jsonl"
    durable_stream.parent.mkdir(parents=True)
    with durable_stream.open("w", encoding="utf-8") as handle:
        for index in range(50):
            row = {"event": "TRADE_CLOSED", "net": 10.0, "time": index + 10}
            if fresh_mae:
                row.update({"entry_time": index + 1, "mae_acct": -5.0})
            handle.write(json.dumps(row) + "\n")

    with sqlite3.connect(db) as conn:
        conn.execute(
            """
            CREATE TABLE work_items (
                id TEXT, phase TEXT, ea_id TEXT, symbol TEXT, status TEXT,
                verdict TEXT, evidence_path TEXT, created_at TEXT, updated_at TEXT
            )
            """
        )
        for phase in ftmo_qualification.STRICT_PHASES:
            evidence = tmp_path / f"{phase}.json"
            payload = {}
            if phase == "Q08":
                payload["portfolio_stream"] = {
                    "persisted": True,
                    "path": str(durable_stream),
                }
            evidence.write_text(json.dumps(payload), encoding="utf-8")
            verdict = q08_verdict if phase == "Q08" else "PASS"
            conn.execute(
                "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?)",
                (
                    f"wi-{phase}", phase, "QM5_9001", "NDX.DWX", "done",
                    verdict, str(evidence), "2026-01-01", "2026-01-01",
                ),
            )
        conn.commit()

    # Deliberately invalid volatile output proves qualification uses the
    # evidence-linked baseline, not the last Q08.5 perturbation workspace.
    stream = common / "QM" / "q08_trades" / "9001_NDX_DWX.jsonl"
    stream.parent.mkdir(parents=True)
    stream.write_text('{"event":"TRADE_CLOSED"}\n', encoding="utf-8")
    return repo, common, db


def test_candidate_is_ready_only_with_complete_strict_evidence(tmp_path: Path) -> None:
    repo, common, db = _fixture(tmp_path)

    artifact = ftmo_qualification.build_inventory(
        db,
        keys=[("QM5_9001", "NDX.DWX")],
        repo_root=repo,
        common_dir=common,
    )

    assert artifact["challenge_ready_count"] == 1
    assert artifact["candidates"][0]["state"] == "CHALLENGE_READY"
    assert artifact["candidates"][0]["blockers"] == []


def test_q08_soft_fail_never_becomes_challenge_ready(tmp_path: Path) -> None:
    repo, common, db = _fixture(tmp_path, q08_verdict="FAIL_SOFT")

    artifact = ftmo_qualification.build_inventory(
        db,
        keys=[("QM5_9001", "NDX.DWX")],
        repo_root=repo,
        common_dir=common,
    )

    candidate = artifact["candidates"][0]
    assert candidate["challenge_ready"] is False
    assert candidate["state"] == "RESEARCH_LEAD"
    assert "q08_not_pass:FAIL_SOFT" in candidate["blockers"]


def test_missing_intraday_mae_blocks_candidate(tmp_path: Path) -> None:
    repo, common, db = _fixture(tmp_path, fresh_mae=False)

    artifact = ftmo_qualification.build_inventory(
        db,
        keys=[("QM5_9001", "NDX.DWX")],
        repo_root=repo,
        common_dir=common,
    )

    candidate = artifact["candidates"][0]
    assert candidate["challenge_ready"] is False
    assert "fresh_intraday_mae_stream_missing" in candidate["blockers"]


def test_evidence_and_stream_older_than_binary_block_candidate(tmp_path: Path) -> None:
    repo, common, db = _fixture(tmp_path)
    ex5 = repo / "framework" / "EAs" / "QM5_9001_demo" / "QM5_9001_demo.ex5"
    rebuilt_at = time.time() + 60
    os.utime(ex5, (rebuilt_at, rebuilt_at))

    artifact = ftmo_qualification.build_inventory(
        db,
        keys=[("QM5_9001", "NDX.DWX")],
        repo_root=repo,
        common_dir=common,
    )

    candidate = artifact["candidates"][0]
    assert candidate["challenge_ready"] is False
    assert "q02_evidence_predates_build" in candidate["blockers"]
    assert "q03_evidence_predates_build" in candidate["blockers"]
    assert "q04_evidence_predates_build" in candidate["blockers"]
    assert "q10_evidence_predates_build" in candidate["blockers"]
    assert "intraday_mae_stream_predates_build" in candidate["blockers"]
    assert candidate["phases"]["Q04"]["evidence_predates_build"] is True
    assert candidate["stream"]["predates_build"] is True


def test_unlinked_q08_stream_cannot_qualify_volatile_common_output(tmp_path: Path) -> None:
    repo, common, db = _fixture(tmp_path)
    q08_evidence = tmp_path / "Q08.json"
    q08_evidence.write_text("{}", encoding="utf-8")

    artifact = ftmo_qualification.build_inventory(
        db,
        keys=[("QM5_9001", "NDX.DWX")],
        repo_root=repo,
        common_dir=common,
    )

    candidate = artifact["candidates"][0]
    assert candidate["challenge_ready"] is False
    assert "q08_baseline_stream_unlinked:portfolio_stream_missing" in candidate["blockers"]
    assert candidate["stream"]["source"] == "common_volatile_fallback"


def test_parse_keys_accepts_qm5_and_numeric_labels() -> None:
    assert ftmo_qualification.parse_keys("QM5_12969:USDJPY.DWX,13036:NDX.DWX") == [
        ("QM5_12969", "USDJPY.DWX"),
        ("QM5_13036", "NDX.DWX"),
    ]


# --- basket-magic contract (logical-symbol resolution) ------------------------


def _magic_repo(
    tmp_path: Path,
    *,
    ea_id: str,
    ea_slug: str,
    rows: list[tuple[str, str]],
    manifest: dict | None = None,
) -> Path:
    """Build a minimal repo tree: magic_numbers.csv + optional basket manifest.

    ``rows`` is a list of (symbol, status) pairs for the given EA id.
    """
    repo = tmp_path / "repo"
    ea_dir = repo / "framework" / "EAs" / f"{ea_slug}"
    ea_dir.mkdir(parents=True)
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    registry.parent.mkdir(parents=True)
    with registry.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=["ea_id", "symbol", "status"])
        writer.writeheader()
        for symbol, status in rows:
            writer.writerow({"ea_id": ea_id, "symbol": symbol, "status": status})
    if manifest is not None:
        (ea_dir / "basket_manifest.json").write_text(
            json.dumps(manifest), encoding="utf-8"
        )
    return repo


def test_plain_symbol_registered_is_unchanged(tmp_path: Path) -> None:
    repo = _magic_repo(
        tmp_path, ea_id="9001", ea_slug="QM5_9001_demo",
        rows=[("NDX.DWX", "active")],
    )
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    ok, reason = ftmo_qualification._active_magic_registered(
        registry, "QM5_9001", "NDX.DWX", repo_root=repo
    )
    assert ok is True
    assert reason is None


def test_plain_symbol_unregistered_keeps_original_blocker(tmp_path: Path) -> None:
    repo = _magic_repo(
        tmp_path, ea_id="9001", ea_slug="QM5_9001_demo",
        rows=[("NDX.DWX", "active")],
    )
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    ok, reason = ftmo_qualification._active_magic_registered(
        registry, "QM5_9001", "WS30.DWX", repo_root=repo
    )
    assert ok is False
    assert reason == "active_magic_missing"


def test_basket_with_declared_traded_legs_all_registered(tmp_path: Path) -> None:
    logical = "QM5_13140_XTI_XNG_ALIQ_D1"
    repo = _magic_repo(
        tmp_path, ea_id="13140", ea_slug="QM5_13140_energy-aliq-rank",
        rows=[("XTIUSD.DWX", "active"), ("XNGUSD.DWX", "active")],
        manifest={
            "logical_symbol": logical,
            "host_symbol": "XTIUSD.DWX",
            "host_timeframe": "D1",
            "basket_symbols": ["XTIUSD.DWX", "XNGUSD.DWX"],
            "traded_symbols": ["XTIUSD.DWX", "XNGUSD.DWX"],
        },
    )
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    ok, reason = ftmo_qualification._active_magic_registered(
        registry, "QM5_13140", logical, repo_root=repo
    )
    assert ok is True
    assert reason is None


def test_basket_with_one_declared_leg_missing_names_the_leg(tmp_path: Path) -> None:
    logical = "QM5_13140_XTI_XNG_ALIQ_D1"
    repo = _magic_repo(
        tmp_path, ea_id="13140", ea_slug="QM5_13140_energy-aliq-rank",
        rows=[("XTIUSD.DWX", "active")],  # XNGUSD leg unregistered
        manifest={
            "logical_symbol": logical,
            "host_symbol": "XTIUSD.DWX",
            "host_timeframe": "D1",
            "basket_symbols": ["XTIUSD.DWX", "XNGUSD.DWX"],
            "traded_symbols": ["XTIUSD.DWX", "XNGUSD.DWX"],
        },
    )
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    ok, reason = ftmo_qualification._active_magic_registered(
        registry, "QM5_13140", logical, repo_root=repo
    )
    assert ok is False
    assert reason == "active_magic_missing_legs:XNGUSD.DWX"


def test_basket_without_authoritative_legs_second_leg_removed_is_rejected(tmp_path: Path) -> None:
    # Codex counterexample (adversarial review 2026-07-26): a fallback basket with
    # neither traded_symbols nor conversion_symbols, whose host row is active but
    # whose genuinely traded second leg's registry row is REMOVED, and with no
    # contradictory inactive rows. basket_symbols cannot name the missing leg, so
    # the old host + registry-consistency heuristic silently passed. The traded
    # set is undeclared, so fail-closed now rejects it as unknown-legs.
    logical = "QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1"
    repo = _magic_repo(
        tmp_path, ea_id="12778", ea_slug="QM5_12778_edgelab",
        rows=[("AUDUSD.DWX", "active")],  # host active; traded EURJPY row removed
        manifest={
            "logical_symbol": logical,
            "host_symbol": "AUDUSD.DWX",
            "host_timeframe": "D1",
            "basket_symbols": ["AUDUSD.DWX", "EURJPY.DWX"],
        },
    )
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    ok, reason = ftmo_qualification._active_magic_registered(
        registry, "QM5_12778", logical, repo_root=repo
    )
    assert ok is False
    assert reason == "active_magic_unknown_legs:" + logical + ":traded_symbols_undeclared"


def test_basket_without_authoritative_legs_rejected_even_when_consistent(tmp_path: Path) -> None:
    # The fail-closed contract holds even when the registry looks fully
    # consistent: host active, every declared leg active, no inactive rows. Absent
    # an authoritative traded set (traded_symbols or a complete basket_symbols -
    # conversion_symbols derivation), host + consistency is never sufficient on
    # its own -- the basket is rejected, and the fix is to declare traded_symbols.
    logical = "QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1"
    repo = _magic_repo(
        tmp_path, ea_id="12778", ea_slug="QM5_12778_edgelab",
        rows=[("AUDUSD.DWX", "active"), ("EURJPY.DWX", "active")],
        manifest={
            "logical_symbol": logical,
            "host_symbol": "AUDUSD.DWX",
            "host_timeframe": "D1",
            "basket_symbols": ["AUDUSD.DWX", "EURJPY.DWX"],
        },
    )
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    ok, reason = ftmo_qualification._active_magic_registered(
        registry, "QM5_12778", logical, repo_root=repo
    )
    assert ok is False
    assert reason == "active_magic_unknown_legs:" + logical + ":traded_symbols_undeclared"


def test_basket_conversion_symbols_key_excludes_conversion_legs(tmp_path: Path) -> None:
    logical = "QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1"
    repo = _magic_repo(
        tmp_path, ea_id="12778", ea_slug="QM5_12778_edgelab",
        rows=[("AUDUSD.DWX", "active"), ("EURJPY.DWX", "active")],
        manifest={
            "logical_symbol": logical,
            "host_symbol": "AUDUSD.DWX",
            "host_timeframe": "D1",
            "basket_symbols": [
                "AUDUSD.DWX", "EURJPY.DWX", "EURUSD.DWX", "EURAUD.DWX",
            ],
            "conversion_symbols": ["EURUSD.DWX", "EURAUD.DWX"],
        },
    )
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    ok, reason = ftmo_qualification._active_magic_registered(
        registry, "QM5_12778", logical, repo_root=repo
    )
    assert ok is True
    assert reason is None


def test_basket_logical_symbol_without_manifest_is_flagged(tmp_path: Path) -> None:
    logical = "QM5_13140_XTI_XNG_ALIQ_D1"
    repo = _magic_repo(
        tmp_path, ea_id="13140", ea_slug="QM5_13140_energy-aliq-rank",
        rows=[("XTIUSD.DWX", "active"), ("XNGUSD.DWX", "active")],
        manifest=None,
    )
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    ok, reason = ftmo_qualification._active_magic_registered(
        registry, "QM5_13140", logical, repo_root=repo
    )
    assert ok is False
    assert reason == "active_magic_missing:basket_manifest_unavailable"


def test_basket_logical_symbol_active_row_does_not_bypass(tmp_path: Path) -> None:
    # Batch-3 counterexample (adversarial review 2026-07-26): an ACTIVE registry
    # row for the logical basket symbol itself must not short-circuit the check --
    # a logical row is not evidence that every real broker leg owns an active
    # magic row. Without an authoritative traded set the basket is still rejected.
    logical = "QM5_9001_A_B_D1"
    repo = _magic_repo(
        tmp_path, ea_id="9001", ea_slug="QM5_9001_synthetic",
        rows=[(logical, "active")],
        manifest={
            "logical_symbol": logical,
            "host_symbol": "A.DWX",
            "host_timeframe": "D1",
            "basket_symbols": ["A.DWX", "B.DWX"],
        },
    )
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    ok, reason = ftmo_qualification._active_magic_registered(
        registry, "QM5_9001", logical, repo_root=repo
    )
    assert ok is False
    assert reason == "active_magic_unknown_legs:" + logical + ":traded_symbols_undeclared"


def test_basket_blank_traded_symbols_rejected(tmp_path: Path) -> None:
    # A declared traded set that normalizes to nothing (blank/whitespace entries)
    # is malformed, not license to guess: fail-closed rejection, no fall-through
    # to the derivation (batch-3 review).
    logical = "QM5_9002_A_B_D1"
    repo = _magic_repo(
        tmp_path, ea_id="9002", ea_slug="QM5_9002_synthetic",
        rows=[("A.DWX", "active")],
        manifest={
            "logical_symbol": logical,
            "host_symbol": "A.DWX",
            "host_timeframe": "D1",
            "traded_symbols": ["  "],
        },
    )
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    ok, reason = ftmo_qualification._active_magic_registered(
        registry, "QM5_9002", logical, repo_root=repo
    )
    assert ok is False
    assert reason == "active_magic_unknown_legs:" + logical + ":traded_symbols_undeclared"


def test_basket_declared_empty_traded_symbols_no_derivation_fallthrough(tmp_path: Path) -> None:
    # Batch-4 probe: traded_symbols=[] DECLARED alongside an otherwise valid
    # derivation must reject — a declared key is always authoritative, malformed
    # values never fall through to basket_symbols - conversion_symbols.
    logical = "QM5_9004_A_B_D1"
    repo = _magic_repo(
        tmp_path, ea_id="9004", ea_slug="QM5_9004_synthetic",
        rows=[("A.DWX", "active"), ("B.DWX", "active")],
        manifest={
            "logical_symbol": logical,
            "host_symbol": "A.DWX",
            "host_timeframe": "D1",
            "traded_symbols": [],
            "basket_symbols": ["A.DWX", "B.DWX", "C.DWX"],
            "conversion_symbols": ["C.DWX"],
        },
    )
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    ok, reason = ftmo_qualification._active_magic_registered(
        registry, "QM5_9004", logical, repo_root=repo
    )
    assert ok is False
    assert reason == "active_magic_unknown_legs:" + logical + ":traded_symbols_undeclared"


def test_basket_non_list_traded_symbols_rejected(tmp_path: Path) -> None:
    # Same authority rule for a non-list declared value (e.g. a bare string).
    logical = "QM5_9005_A_B_D1"
    repo = _magic_repo(
        tmp_path, ea_id="9005", ea_slug="QM5_9005_synthetic",
        rows=[("A.DWX", "active"), ("B.DWX", "active")],
        manifest={
            "logical_symbol": logical,
            "host_symbol": "A.DWX",
            "host_timeframe": "D1",
            "traded_symbols": "A.DWX",
            "basket_symbols": ["A.DWX", "B.DWX"],
            "conversion_symbols": [],
        },
    )
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    ok, reason = ftmo_qualification._active_magic_registered(
        registry, "QM5_9005", logical, repo_root=repo
    )
    assert ok is False
    assert reason == "active_magic_unknown_legs:" + logical + ":traded_symbols_undeclared"


def test_basket_empty_derivation_rejected(tmp_path: Path) -> None:
    # basket_symbols - conversion_symbols == {} leaves the traded set unknowable:
    # same fail-closed rejection as an undeclared set (batch-3 review).
    logical = "QM5_9003_A_B_D1"
    repo = _magic_repo(
        tmp_path, ea_id="9003", ea_slug="QM5_9003_synthetic",
        rows=[("A.DWX", "active")],
        manifest={
            "logical_symbol": logical,
            "host_symbol": "A.DWX",
            "host_timeframe": "D1",
            "basket_symbols": ["A.DWX"],
            "conversion_symbols": ["A.DWX"],
        },
    )
    registry = repo / "framework" / "registry" / "magic_numbers.csv"
    ok, reason = ftmo_qualification._active_magic_registered(
        registry, "QM5_9003", logical, repo_root=repo
    )
    assert ok is False
    assert reason == "active_magic_unknown_legs:" + logical + ":traded_symbols_undeclared"
