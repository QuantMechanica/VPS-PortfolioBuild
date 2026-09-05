"""Family identity, evidence semantics and disclosure boundary fixtures."""
import json
import sqlite3
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import website_archive_v31 as archive
from test_website_archive_contract import _make_public_blocks_fixture


def fixture(tmp_path):
    db = tmp_path / "farm.sqlite"
    _make_public_blocks_fixture(db)
    farm, repo = tmp_path / "farm", tmp_path / "repo"
    cards = farm / "artifacts/cards_approved"
    cards.mkdir(parents=True)
    for ea in ("QM5_9001", "QM5_9002", "QM5_9003", "QM5_9004", "QM5_9005"):
        (cards / (ea + "_demo.md")).write_text(
            f"---\nea_id: {ea}\nslug: moving-average-pullback\nsource_id: {ea}\ng0_status: APPROVED\n"
            "target_symbols: [EURUSD.DWX]\nlast_updated: 2026-09-04\n---\n"
            "## 1. Summary\nLooks for a pullback within a directional trend.\n\n"
            "## 2. Secret\nRISK_FIXED=123456 private parameter\n", encoding="utf-8")
        folder = repo / "framework/EAs" / (ea + "_demo")
        (folder / "sets").mkdir(parents=True)
        (folder / "SPEC.md").write_text(
            "## 1. Strategy Logic\n\nDaily price pullbacks form the entry context.\n\n"
            "## 2. Parameters\nsecret_parameter=321 C:/QM/private\n", encoding="utf-8")
        (folder / "sets" / (ea + "_demo_EURUSD.DWX_H1_backtest.set")).write_text("RISK_FIXED=1000\n", encoding="utf-8")
    return db, farm, repo


def build(tmp_path):
    return archive.build(*fixture(tmp_path), generated_at="2026-09-05T00:00:00Z")


def test_family_merge_uses_lineage_and_keeps_unrelated_sources_separate():
    cards = [
        {"ea": "QM5_1", "fm": {"source_id": "a", "slug": "squeeze"}},
        {"ea": "QM5_2", "fm": {"source_id": "a", "slug": "squeeze-r2-recovery"}},
        {"ea": "QM5_3", "fm": {"source_id": "b", "slug": "squeeze"}},
        {"ea": "QM5_4", "fm": {"parent_ea_id": "QM5_2", "slug": "fresh-name-opt"}},
        {"ea": "QM5_1", "fm": {"source_id": "a", "slug": "squeeze"}},
    ]
    families = archive.families(cards)
    assert set(families) == {"QM5_1", "QM5_3"}
    assert {c["ea"] for c in families["QM5_1"]} == {"QM5_1", "QM5_2", "QM5_4"}


def test_revision_identity_dates_and_copy_provenance(tmp_path):
    db, farm, repo = fixture(tmp_path)
    cards = farm / "artifacts/cards_approved"
    original = cards / "QM5_9001_demo.md"
    (cards / "QM5_9001_demo_r2.md").write_text(original.read_text().replace("2026-09-04", "2026-09-05"))
    result, ledger, _ = archive.build(db, farm, repo, generated_at="2026-09-05T00:00:00Z")
    item = next(x for x in result["items"] if len(x["revision_history"]) == 2)
    assert result["total"] == 5
    assert item["display_name"] == "Daily Trend Pullback"
    assert ledger["entries"][item["public_id"]]["provenance"]["spec_sha256"]
    encoded = json.dumps(result)
    for forbidden in ("secret_parameter", "C:/QM", "QM5_", "RISK_FIXED", "source_id"):
        assert forbidden not in encoded
    assert not __import__("re").search(r"\d", item["tagline"] + item["display_name"])
    again = archive.build(db, farm, repo, generated_at="2026-09-05T00:00:00Z", previous_ledger=ledger)
    assert result == again[0] and ledger == again[1]


def test_setfile_timeframe_resolution_and_multi(tmp_path):
    db, farm, repo = fixture(tmp_path)
    folder = repo / "framework/EAs/QM5_9001_demo/sets"
    (folder / "QM5_9001_demo_EURUSD.DWX_H4_backtest.set").write_text("RISK_FIXED=1000\n")
    result, _, audit = archive.build(db, farm, repo)
    assert not any(x["unknown_markets"] for x in audit if x["set_files"])
    item = next(x for x in result["items"] if x["markets"][0]["timeframe"] == "multi")
    assert item["markets"] == [{"symbol_public": "EURUSD", "timeframe": "multi"}]
    assert archive.timeframes(["PERIOD_H1", "D1", "UNKNOWN"]) == {"H1", "D1"}
    p = tmp_path / "plain.set"
    p.write_text("; timeframe: H4\nsecret_value=16385", encoding="utf-16")
    assert archive.read_set_timeframes(p) == {"H4"}


def test_gate_labels_use_version_mapping_and_do_not_promote_isolated_live_pass(tmp_path):
    result, _, audit = build(tmp_path)
    ids = {x["members"][0]: x["public_id"] for x in audit}
    items = {x["public_id"]: x for x in result["items"]}
    historical = items[ids["QM5_9001"]]
    later = [g for p in historical["gate_journey"] for g in p["gates"] if g["gate"] == "Q11"]
    assert later and "locked configuration" in later[0]["purpose"]
    assert historical["terminal_status"] == "optimization"
    completed = items[ids["QM5_9004"]]
    assert completed["terminal_status"] == "book candidate"
    assert completed["gate_journey"][2]["name"] == "Book build and live readiness"
    assert all(x["terminal_status"] != "live" for x in result["items"])


def test_historical_pass_and_fail_are_both_visible_without_inventing_aggregate_pass(tmp_path):
    db, farm, repo = fixture(tmp_path)
    with sqlite3.connect(db) as con:
        con.execute("INSERT INTO work_items SELECT 'new-fail',kind,phase,ea_id,'GBPUSD.DWX',setfile_path,status,'FAIL',attempt_count,parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at,gate_contract_version FROM work_items WHERE id='b-q02'")
    result, _, audit = archive.build(db, farm, repo)
    pid = next(x["public_id"] for x in audit if x["members"] == ["QM5_9002"])
    item = next(x for x in result["items"] if x["public_id"] == pid)
    gate = item["gate_journey"][0]["gates"][0]
    assert gate["outcome"] == "mixed"
    assert gate["passed_symbols"] == ["EURUSD"] and gate["failed_symbols"] == ["GBPUSD"]


@pytest.mark.parametrize("field", ["parameters", "source", "profit_factor", "drawdown", "return", "work_item_id", "magic", "trade_count"])
def test_forbidden_fields_at_each_public_boundary(tmp_path, field):
    result, _, _ = build(tmp_path)
    for target in (result, result["items"][0], result["items"][0]["revision_history"][0], result["items"][0]["markets"][0], result["items"][0]["gate_journey"][0]):
        target[field] = "secret"
        with pytest.raises(archive.legacy.PublicSnapshotContractError):
            archive.validate(result)
        del target[field]


@pytest.mark.parametrize("value", ["C:/QM/private", "profit factor 1.5", "risk twelve percent", "qm_value", "foo@example.com", "https://private.example"])
def test_forbidden_prose(tmp_path, value):
    result, _, _ = build(tmp_path)
    result["items"][0]["tagline"] = value
    with pytest.raises(archive.legacy.PublicSnapshotContractError):
        archive.validate(result)


def test_preview_refuses_public_data_directory(tmp_path):
    with pytest.raises(SystemExit, match="STAGING ONLY"):
        archive.main(["--out-dir", str(archive.legacy.PUBLIC_DATA_DIR / "v31")])


def test_parameter_only_untested_sets_do_not_invent_market_contract(tmp_path):
    db, farm, repo = fixture(tmp_path)
    p = farm / "artifacts/cards_approved/QM5_9010_rubber.md"
    p.write_text("---\nea_id: QM5_9010\nname: Rubber Band\n---\n# Rubber Band\n\nMean reversion using Bollinger Bands.\n## Rules\nsecret=777\n")
    folder = repo / "framework/EAs/QM5_9010_rubber/sets"
    folder.mkdir(parents=True)
    (folder / "QM5_9010_EURUSD.DWX_baseline.set").write_text("RISK_FIXED=100\n")
    result, _, audit = archive.build(db, farm, repo)
    pid = next(x["public_id"] for x in audit if x["members"] == ["QM5_9010"])
    item = next(x for x in result["items"] if x["public_id"] == pid)
    assert item["markets"] == []
    assert item["display_name"] == "Volatility Envelope"
    assert item["terminal_status"] == "research frontier"


def test_schema_and_runtime_whitelist_have_same_public_fields():
    schema = json.loads((Path(__file__).resolve().parents[3] / "public-data/strategy-archive.schema.v31.json").read_text())
    assert schema["additionalProperties"] is False
    assert schema["properties"]["schema_version"]["const"] == "3.1"
    assert schema["properties"]["items"]["items"]["additionalProperties"] is False
    assert "revision_history" in schema["properties"]["items"]["items"]["required"]


def test_ordinary_prose_cannot_be_misread_as_a_rotation_code():
    entry = archive.name_entry("Price acts as a reference in a FOMC cycle drift strategy.")
    assert entry["name"] == "Policy Cycle Drift"
