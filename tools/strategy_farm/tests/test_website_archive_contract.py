"""Redaction + contract-shape tests for the public Strategy-Archive generator.

Every forbidden leak class named in QM-TODO-20260820-003 has a fixture that MUST
be stripped or refused, and unknown field classes MUST be dropped by default.
The contract-shape tests build the tree from a synthetic farm DB (no live DB
dependency) and assert the four files + index manifest have the pinned shape and
carry no absolute paths.
"""
from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import website_archive_contract as wac  # noqa: E402


# ---------------------------------------------------------------------------
# scrub_text — free-text forbidden classes
# ---------------------------------------------------------------------------

@pytest.mark.parametrize("raw", [
    r"see D:\QM\reports\work_items\abc\summary.json for detail",
    r"C:\QM\repo\framework\EAs\QM5_10000\sets\x.set",
    r"G:\My Drive\capfree_scalper_spec.md",
])
def test_scrub_absolute_windows_path(raw):
    out = wac.scrub_text(raw)
    assert wac.REDACTED in out
    assert ":\\" not in out
    assert "QM5_10000" not in out or "\\" not in out


@pytest.mark.parametrize("raw, forbidden_tail", [
    (r"G:\My Drive\QuantMechanica - Company Reference\secret.md", "My Drive"),
    ("C:/QM/reports/private/report.json", "QM/reports"),
])
def test_scrub_windows_path_variants(raw, forbidden_tail):
    out = wac.scrub_text(raw)
    assert forbidden_tail not in out
    assert wac.REDACTED in out


@pytest.mark.parametrize("raw, endpoint", [
    ("host: qm-vps-01", "qm-vps-01"),
    ("hostname=worker.internal", "worker.internal"),
    ("server: darwinex-prod", "darwinex-prod"),
    ("vps=qm-runner-2", "qm-runner-2"),
])
def test_scrub_labelled_host_details(raw, endpoint):
    out = wac.scrub_text(raw)
    assert endpoint not in out
    assert wac.REDACTED in out


def test_scrub_file_uri():
    out = wac.scrub_text("open file:///D:/QM/strategy_farm/dashboards/x.html now")
    assert "file://" not in out
    assert wac.REDACTED in out


def test_scrub_unc_path():
    out = wac.scrub_text(r"copied from \\VPS-HOST\share\secret\a.txt today")
    assert "\\\\VPS-HOST" not in out
    assert wac.REDACTED in out


def test_scrub_ipv4():
    out = wac.scrub_text("terminal reachable at 10.4.221.7 on lan")
    assert "10.4.221.7" not in out
    assert wac.REDACTED in out


@pytest.mark.parametrize("raw", [
    "source: C:/Users/Administrator/Dropbox/Finanzen/Forex/strategy.pdf",
    "matrix at C:/QM/repo/framework/registry/dwx_symbol_matrix.csv",
    "export dir D:/QM/mt5/T_Export/MQL5/Files holds it",
])
def test_scrub_forward_slash_drive_path(raw):
    out = wac.scrub_text(raw)
    assert wac.REDACTED in out
    for tail in ("Administrator", "Dropbox", "dwx_symbol_matrix", "T_Export"):
        assert tail not in out


@pytest.mark.parametrize("raw", [
    "author prbain@tradingsmart.com published it",
    "contact: sam86@live.com / fxextract@yahoo.com",
])
def test_scrub_email_addresses(raw):
    out = wac.scrub_text(raw)
    assert "@" not in out
    assert wac.REDACTED in out


@pytest.mark.parametrize("raw, tail", [
    ("CROWN JEWEL of the Hyonix 5-agent audit", "Hyonix"),
    ("URL/local PDF lineage: Dropbox Forex PDF archive", "Dropbox"),
])
def test_scrub_sensitive_infrastructure_names(raw, tail):
    out = wac.scrub_text(raw)
    assert tail.lower() not in out.lower()
    assert wac.REDACTED in out


def test_scrub_non_web_uri_scheme():
    out = wac.scrub_text("tracked as l://OWNER-FTMO-SURVIVORS-20260711 internally")
    assert "l://" not in out
    assert wac.REDACTED in out


def test_scrub_keeps_public_http_links():
    src = "paper at https://ssrn.com/abstract=123456 (public)"
    assert wac.scrub_text(src) == src


@pytest.mark.parametrize("raw", [
    "account: 12345678 mapped to slot 1",
    "magic=100390001 for this EA",
    "broker login 9987654 configured",
])
def test_scrub_labelled_account_and_magic(raw):
    out = wac.scrub_text(raw)
    assert wac.REDACTED in out
    # the numeric id itself must be gone
    for tok in ("12345678", "100390001", "9987654"):
        assert tok not in out


@pytest.mark.parametrize("raw", [
    "password: hunter2",
    "api_key = sk-live-abcdef123456",
    "bearer: eyJhbGciOi",
])
def test_scrub_credentials(raw):
    out = wac.scrub_text(raw)
    assert wac.REDACTED in out


def test_scrub_preserves_benign_numbers():
    # trade counts / PF must survive — they are safe public metrics
    out = wac.scrub_text("206 trades, PF 1.22, net 49991")
    assert "206 trades" in out
    assert "1.22" in out


# ---------------------------------------------------------------------------
# redact_record — allowlist + forbidden keys
# ---------------------------------------------------------------------------

def test_unknown_fields_dropped_by_default():
    rec = {"ea_id": "QM5_1", "surprise_field": "leak", "another": 3}
    out = wac.redact_record(rec, {"ea_id"})
    assert out == {"ea_id": "QM5_1"}


@pytest.mark.parametrize("key", [
    "evidence_path", "setfile_path", "magic", "magic_number", "account_login",
    "broker_server", "hostname", "claimed_by", "worker_id", "vps_ip",
    "terminal_dir", "secret_token",
])
def test_forbidden_key_refused_even_if_allowlisted(key):
    # Defence in depth: even if a forbidden key is mistakenly allowlisted, the
    # value must never survive.
    rec = {key: "SENSITIVE"}
    out = wac.redact_record(rec, {key})
    assert key not in out


def test_allowlisted_value_still_scrubbed():
    rec = {"note": r"ran from D:\QM\reports\x.json ok"}
    out = wac.redact_record(rec, {"note"})
    assert ":\\" not in out["note"]
    assert wac.REDACTED in out["note"]


def test_nested_dict_forbidden_key_dropped():
    rec = {"metrics": {"net_profit": 100.0, "magic": 100390001}}
    out = wac.redact_record(rec, {"metrics"})
    assert "magic" not in out["metrics"]
    assert out["metrics"]["net_profit"] == 100.0


def test_redact_value_list_scrubbed():
    out = wac.redact_value("targets", [r"C:\QM\x", "EURUSD.DWX"])
    assert wac.REDACTED in out[0]
    assert out[1] == "EURUSD.DWX"


# ---------------------------------------------------------------------------
# card projection
# ---------------------------------------------------------------------------

def test_project_card_redacts_and_grades(tmp_path):
    card = tmp_path / "QM5_9001_demo.md"
    card.write_text(
        "---\n"
        "ea_id: QM5_9001\n"
        "slug: demo\n"
        "source_citation: \"Author, Title, 2011, https://example.com/x\"\n"
        "indicators: [cci, atr]\n"
        "target_symbols: [EURUSD.DWX, XAUUSD.DWX]\n"
        "period: H1\n"
        "r4_ml_forbidden: PASS\n"
        "g0_status: APPROVED\n"
        "secret_login: 12345678\n"
        "---\n"
        "Mechanical rules. Spec saved to G:\\My Drive\\demo_spec.md here.\n",
        encoding="utf-8",
    )
    proj = wac.project_card(card)
    assert proj is not None
    assert proj["ea_id"] == "QM5_9001"
    assert proj["grade"] == "A"
    assert proj["card_id"].startswith("card_")
    # forbidden frontmatter key dropped
    assert "secret_login" not in proj["frontmatter"]
    # absolute path scrubbed from excerpt
    assert ":\\" not in proj["excerpt_redacted"]
    assert wac.REDACTED in proj["excerpt_redacted"]


def test_project_card_reconciles_bare_frontmatter_id(tmp_path):
    # Filename is canonical; a bare frontmatter id must not become the join key.
    card = tmp_path / "QM5_1143_carver.md"
    card.write_text(
        "---\nea_id: 1143\nslug: carver\nindicators: [ewmac]\n"
        "target_symbols: [SPX500.DWX]\nperiod: D1\nr4_ml_forbidden: PASS\n---\nx\n",
        encoding="utf-8",
    )
    proj = wac.project_card(card)
    assert proj["ea_id"] == "QM5_1143"
    assert proj["frontmatter"]["ea_id"] == "QM5_1143"
    assert proj["id_reconciled_from_frontmatter"] is True


def test_project_card_rejects_non_ea(tmp_path):
    card = tmp_path / "QM5_note.md"
    card.write_text("# just a prompt, no frontmatter ea_id\n", encoding="utf-8")
    assert wac.project_card(card) is None


def test_card_grade_ml_violation_blocks():
    grade, missing = wac._card_grade({
        "source_citation": "x", "indicators": ["a"], "target_symbols": ["EURUSD"],
        "period": "H1", "r4_ml_forbidden": "FAIL",
    })
    assert grade == "Blocked"


# ---------------------------------------------------------------------------
# id helpers
# ---------------------------------------------------------------------------

def test_report_id_is_path_free_and_stable():
    p = r"D:\QM\reports\work_items\abc\summary.json"
    rid = wac.report_id_for(p)
    assert rid.startswith("rpt_")
    assert "QM" not in rid and "\\" not in rid
    assert rid == wac.report_id_for(p)  # stable


def test_public_gate_maps_legacy_and_drops_internal():
    assert wac._public_gate("P2") == "Q02"
    assert wac._public_gate("Q06") == "Q06"
    assert wac._public_gate("HARNESS_PP_FIXTURE") is None


def test_era_labels_legacy():
    assert wac._era_for("P2") == "legacy"
    assert wac._era_for("Q06") == "current"


# ---------------------------------------------------------------------------
# contract-shape integration on a synthetic DB
# ---------------------------------------------------------------------------

def _make_farm_db(path: Path) -> None:
    """Minimal work_items + ea_metrics matching the real column names the
    clean-view module and generator read."""
    con = sqlite3.connect(str(path))
    con.execute("""
        CREATE TABLE work_items (
            id TEXT, kind TEXT, phase TEXT, ea_id TEXT, symbol TEXT,
            setfile_path TEXT, status TEXT, verdict TEXT, attempt_count INTEGER,
            parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT,
            payload_json TEXT, created_at TEXT, updated_at TEXT
        )""")
    rows = [
        ("w1", "backtest", "Q02", "QM5_9001", "EURUSD.DWX",
         r"C:\QM\x_EURUSD.set", "done", "PASS", 1, None,
         r"D:\QM\reports\work_items\w1\summary.json", "T3",
         "{}", "2026-08-01T00:00:00", "2026-08-01T00:00:00"),
        ("w2", "backtest", "P2", "QM5_9001", "GBPUSD.DWX",
         r"C:\QM\x_GBPUSD.set", "failed", "FAIL", 1, None,
         r"D:\QM\reports\work_items\w2\summary.json", "T4",
         "{}", "2026-08-15T00:00:00", "2026-08-15T00:00:00"),
        ("w3", "harness", "HARNESS_PP_FIXTURE", "QM5_9001", "",
         None, "done", "PASS", 1, None, None, "T1",
         "{}", "2026-08-01T00:00:00", "2026-08-01T00:00:00"),
    ]
    con.executemany(
        "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)", rows)
    con.execute("""
        CREATE TABLE ea_metrics (
            work_item_id TEXT, ea_id TEXT, phase TEXT, symbol TEXT,
            verdict TEXT, status TEXT, net_profit REAL, profit_factor REAL,
            trades INTEGER, drawdown_money REAL, drawdown_pct REAL, sharpe REAL,
            detail_json TEXT, source TEXT, evidence_path TEXT,
            evidence_mtime REAL, extracted_at TEXT, is_ablation INTEGER,
            parent_work_item_id TEXT
        )""")
    con.execute(
        "INSERT INTO ea_metrics VALUES "
        "('w1','QM5_9001','Q02','EURUSD.DWX','PASS','done',49991.0,1.22,206,"
        "-3200.0,-8.1,0.9,'{}','summary',"
        r"'D:\QM\reports\work_items\w1\summary.json',0,'2026-08-01',0,NULL)")
    con.commit()
    con.close()


def test_build_and_write_contract_shape(tmp_path):
    db = tmp_path / "farm_state.sqlite"
    _make_farm_db(db)
    farm_root = tmp_path / "farm"
    (farm_root / "artifacts" / "cards_approved").mkdir(parents=True)
    (farm_root / "artifacts" / "cards_approved" / "QM5_9001_demo.md").write_text(
        "---\nea_id: QM5_9001\nslug: demo\nindicators: [cci]\n"
        "target_symbols: [EURUSD.DWX]\nperiod: H1\nr4_ml_forbidden: PASS\n"
        "source_citation: \"x, https://ex.com\"\ng0_status: APPROVED\n---\nbody\n",
        encoding="utf-8",
    )
    repo_root = tmp_path / "repo"
    (repo_root / "framework" / "EAs" / "QM5_9001_demo").mkdir(parents=True)

    contract = wac.build_contract(db, farm_root, repo_root, verbose=False)

    # gate results: Q02 (from w1) and Q02 (from P2 legacy w2); fixture dropped
    gates = {(g["ea_id"], g["symbol_id"], g["gate_id"], g["era"])
             for g in contract["gate_results"]}
    assert ("QM5_9001", "EURUSD.DWX", "Q02", "current") in gates
    assert ("QM5_9001", "GBPUSD.DWX", "Q02", "legacy") in gates
    assert all(g["gate_id"] != "HARNESS_PP_FIXTURE"
               for g in contract["gate_results"])
    # metrics survived, forbidden fields absent
    q02 = next(g for g in contract["gate_results"]
               if g["symbol_id"] == "EURUSD.DWX")
    assert q02["metrics"]["net_profit"] == 49991.0
    assert q02["metrics"]["trades"] == 206
    assert "evidence_path" not in q02
    assert q02["report_id"].startswith("rpt_")
    assert q02["report_published"] is False

    # write + reload; assert NO absolute path anywhere in the serialized tree
    written = wac.write_contract(contract, tmp_path / "out")
    assert set(written) >= {
        "strategy_summaries.json", "strategy_cards_public.json",
        "gate_results.json", "report_manifest.json", "index.json"}
    for path in written.values():
        blob = Path(path).read_text(encoding="utf-8")
        assert ":\\" not in blob, f"absolute path leaked in {path}"
        assert "file://" not in blob
        assert "claimed_by" not in blob
    index = json.loads(Path(written["index.json"]).read_text(encoding="utf-8"))
    assert index["staging_only"] is True
    assert index["counts"]["eas"] == 1
    assert index["contract_version"] == wac.CONTRACT_VERSION

    legacy_summary = next(s for s in contract["summaries"]
                          if s["ea_id"] == "QM5_9001")
    assert legacy_summary["era"] == "legacy"


def test_write_refuses_public_data_dir(tmp_path):
    contract = {"summaries": [], "cards": [], "gate_results": [],
                "report_manifest": [], "counts": {}, "generated_at": "x",
                "gate_contract_version": "v"}
    target = wac.PUBLIC_DATA_DIR / "website_preview"
    with pytest.raises(SystemExit):
        wac.write_contract(contract, target)
