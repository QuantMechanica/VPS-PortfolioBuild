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
    assert wac._public_gate("Q10", "v3") == "Q11"
    assert wac._public_gate("Q10", "v4") == "Q10"
    assert wac._public_gate("Q10_NEWS", "v4") == "Q10"
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


# ---------------------------------------------------------------------------
# Numeric-free public snapshot blocks
# ---------------------------------------------------------------------------

def _make_public_blocks_fixture(path: Path) -> None:
    with sqlite3.connect(path) as con:
        con.execute("""
            CREATE TABLE work_items (
                id TEXT, kind TEXT, phase TEXT, ea_id TEXT, symbol TEXT,
                setfile_path TEXT, status TEXT, verdict TEXT, attempt_count INTEGER,
                parent_task_id TEXT, evidence_path TEXT, claimed_by TEXT,
                payload_json TEXT, created_at TEXT, updated_at TEXT,
                gate_contract_version TEXT
            )""")

        def add(
            row_id: str,
            ea_id: str,
            phase: str,
            verdict: str | None,
            *,
            version: str,
            status: str = "done",
            symbol: str = "EURUSD.DWX",
        ) -> None:
            con.execute(
                "INSERT INTO work_items VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
                (
                    row_id, "backtest", phase, ea_id, symbol, None, status,
                    verdict, 0, None, None, None, "{}", "2026-08-23T00:00:00Z",
                    "2026-08-23T00:00:00Z", version,
                ),
            )

        # Historical v3 incumbent evidence resolves to v4 Q11, but cannot jump
        # the missing v4 Q09/Q10 prerequisites. Public progress stops at Q08.
        for phase in ("Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08"):
            add(f"a-{phase}", "QM5_9001", phase, "PASS", version="v3")
        add("a-incumbent", "QM5_9001", "Q10", "PASS", version="v3")

        add("b-q02", "QM5_9002", "Q02", "PASS", version="v4")
        add("b-q03", "QM5_9002", "Q03", "FAIL", version="v4")
        add("c-q02", "QM5_9003", "Q02", None, version="v4", status="pending")

        # A complete v4 phase-two chain with contiguous phase-three evidence.
        for phase in tuple(f"Q{i:02d}" for i in range(2, 14)):
            add(f"d-{phase}", "QM5_9004", phase, "PASS", version="v4")
        add("d-q14", "QM5_9004", "Q14", "KEEP_INCUMBENT", version="v4")
        add("d-q15", "QM5_9004", "Q15_DXZ", "PASS_PORTFOLIO", version="v4")
        add("d-q16", "QM5_9004", "Q16", None, version="v4", status="active")
        # Isolated later evidence must not leap over the active Q16 frontier.
        add("d-q17", "QM5_9004", "Q17", "PASS", version="v4")


def _make_public_card(root: Path, ea_id: str, *, public_summary: str | None = None) -> None:
    cards = root / "artifacts" / "cards_approved"
    cards.mkdir(parents=True, exist_ok=True)
    summary = f"public_summary: \"{public_summary}\"\n" if public_summary else ""
    (cards / f"{ea_id}_demo.md").write_text(
        "---\n"
        f"ea_id: {ea_id}\n"
        "slug: demo\n"
        f"{summary}"
        "g0_status: APPROVED\n"
        "---\n"
        "# Internal card body\n",
        encoding="utf-8",
    )


def _public_card_for_ea(block: dict, farm_root: Path, ea_id: str) -> dict:
    card_path = next((farm_root / "artifacts" / "cards_approved").glob(f"{ea_id}_*.md"))
    public_id = wac.project_card(card_path)["card_id"]
    return next(item for item in block["cards"] if item["public_id"] == public_id)


def test_public_snapshot_archive_is_version_aware_contiguous_and_number_free(
    tmp_path: Path,
) -> None:
    db = tmp_path / "farm.sqlite"
    _make_public_blocks_fixture(db)
    farm_root = tmp_path / "farm"
    for ea_id in ("QM5_9001", "QM5_9002", "QM5_9003", "QM5_9004", "QM5_9005"):
        _make_public_card(
            farm_root,
            ea_id,
            public_summary=(
                "A trend-following mechanism based on persistent directional movement."
                if ea_id == "QM5_9001" else None
            ),
        )
    repo_root = tmp_path / "repo"
    repo_root.mkdir()

    blocks = wac.build_public_snapshot_blocks(db, farm_root, repo_root)
    archive = blocks["public_archive"]
    historical = _public_card_for_ea(archive, farm_root, "QM5_9001")
    failed = _public_card_for_ea(archive, farm_root, "QM5_9002")
    running = _public_card_for_ea(archive, farm_root, "QM5_9003")
    complete = _public_card_for_ea(archive, farm_root, "QM5_9004")
    card_only = _public_card_for_ea(archive, farm_root, "QM5_9005")

    assert historical["mechanism_class"].startswith("A trend-following mechanism")
    assert all(historical["gates"][f"Q{i:02d}"] == "PASS" for i in range(9))
    assert all(historical["gates"][f"Q{i:02d}"] == "UNTESTED" for i in range(9, 18))
    assert failed["gates"]["Q02"] == "PASS"
    assert failed["gates"]["Q03"] == "FAIL"
    assert running["gates"]["Q02"] == "IN_PROGRESS"
    assert complete["gates"]["Q15"] == "PASS"
    assert complete["gates"]["Q16"] == "IN_PROGRESS"
    assert complete["gates"]["Q17"] == "UNTESTED"
    assert card_only["gates"]["Q00"] == "PASS"
    assert card_only["gates"]["Q01"] == "UNTESTED"
    serialized = json.dumps(blocks)
    assert "QM5_" not in serialized
    assert ":\\" not in serialized
    assert "work_item_id" not in serialized
    assert "symbol" not in serialized
    assert "@" not in serialized
    wac.assert_public_snapshot_blocks_safe(blocks)


@pytest.mark.parametrize(
    "unsafe",
    [
        r"A mechanism documented at D:\QM\private\card.md.",
        "A mechanism maintained by analyst@example.com.",
        "A mechanism with a threshold of twelve percent and PF 1.2.",
    ],
)
def test_public_snapshot_redaction_guard_fails_closed_on_public_summary(
    tmp_path: Path, unsafe: str
) -> None:
    db = tmp_path / "farm.sqlite"
    _make_public_blocks_fixture(db)
    farm_root = tmp_path / "farm"
    _make_public_card(farm_root, "QM5_9001", public_summary=unsafe)
    repo_root = tmp_path / "repo"
    repo_root.mkdir()

    with pytest.raises(wac.PublicSnapshotContractError):
        wac.build_public_snapshot_blocks(db, farm_root, repo_root)


def test_public_gate_copy_is_active_v4_three_phase_and_has_no_threshold_numbers() -> None:
    block = wac.build_pipeline_gates_block()
    assert [gate["id"] for gate in block["gates"]] == list(wac.PUBLIC_GATE_IDS)
    assert len(block["macro_phases"]) == 3
    assert len({gate["macro_phase"] for gate in block["gates"]}) == 3
    for gate in block["gates"]:
        assert not any(ch.isdigit() for ch in gate["name"])
        assert not any(ch.isdigit() for ch in gate["purpose"])
        assert gate["purpose"].endswith(".")


def test_public_snapshot_schema_pins_archive_and_gate_copy_contracts() -> None:
    schema = json.loads(
        (REPO / "public-data" / "public-snapshot.schema.v2.json").read_text(
            encoding="utf-8"
        )
    )
    assert {"public_archive", "pipeline_gates"} <= set(schema["required"])
    archive = schema["properties"]["public_archive"]
    gates = schema["properties"]["pipeline_gates"]
    assert archive["additionalProperties"] is False
    assert gates["additionalProperties"] is False
    assert schema["$defs"]["gate_state"]["enum"] == [
        "PASS", "FAIL", "UNTESTED", "IN_PROGRESS"
    ]


def test_strategy_archive_v2_exposes_terminal_binary_coverage_only() -> None:
    states = {gate: "UNTESTED" for gate in wac.PUBLIC_GATE_IDS}
    states.update(Q00="PASS", Q02="FAIL", Q03="IN_PROGRESS")
    public = {
        "gate_contract_version": "v4",
        "progress_metric": wac.PUBLIC_PROGRESS_METRIC,
        "gates": list(wac.PUBLIC_GATE_IDS),
        "cards": [{
            "public_id": "card_0123456789abcdef",
            "mechanism_class": "A mechanical trend continuation method.",
            "gates": states,
        }],
    }
    archive = wac.build_strategy_archive_v2(
        public, generated_at="2026-09-02T15:00:00+00:00"
    )
    assert archive["schema_version"] == 2
    assert archive["disclosure"] == "terminal_pass_fail_without_metrics"
    assert archive["items"][0]["gate_coverage"] == {"Q00": "PASS", "Q02": "FAIL"}
    serialized = json.dumps(archive)
    for forbidden in ("UNTESTED", "IN_PROGRESS", "symbol", "QM5_"):
        assert forbidden not in serialized
    assert '"metrics":' not in serialized


def test_strategy_archive_v2_schema_is_closed_and_metric_free() -> None:
    schema = json.loads(
        (REPO / "public-data" / "strategy-archive.schema.v2.json").read_text()
    )
    assert schema["properties"]["schema_version"]["enum"] == [2]
    item = schema["properties"]["items"]["items"]
    assert item["additionalProperties"] is False
    assert set(item["properties"]) == {
        "public_id", "mechanism_class", "gate_coverage"
    }
    assert item["properties"]["gate_coverage"]["additionalProperties"]["enum"] == [
        "PASS", "FAIL"
    ]


def test_exporter_invokes_fail_closed_public_projection() -> None:
    source = (REPO / "scripts" / "export_public_snapshot.ps1").read_text(
        encoding="utf-8-sig"
    )
    generator = source.index("--public-bundle")
    archive_assignment = source.index("public_archive = $publicBlocks.public_archive")
    schema_validation = source.index(
        "Validate-JsonAgainstSchema -Object $publicSnapshot"
    )
    assert generator < archive_assignment < schema_validation
    assert "Public archive redaction grep guard refused generated blocks" in source
    assert "pipeline_gates = $publicBlocks.pipeline_gates" in source
    assert "$strategyArchive = $publicBlocks.strategy_archive_v2" in source
