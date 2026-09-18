"""Roster-driven FTMO demo tooling (GAPS 2026-09-18 G1/G3/G4/G7).

Synthetic dirs only: no MT5, no real terminal, no farm DB write.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
from pathlib import Path
import sqlite3

import pytest

from tools.strategy_farm.ftmo import demo_cycle, demo_install, governor_rebind
from tools.strategy_farm.ftmo import trial_setpath as s

ROOT = Path(__file__).resolve().parents[3]

REAL_TERMINALS = (
    Path(r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal"),
    Path(r"C:\QM\mt5"),
    Path(r"D:\QM\mt5"),
)


@pytest.fixture(autouse=True)
def never_touch_a_real_terminal(tmp_path, monkeypatch):
    """Structural guard: point every terminal constant at tmp before each test.

    A default-argument capture once let a planned destination escape a
    monkeypatched TARGET and write into the live FTMO demo terminal. This makes
    that class of accident impossible: the module constants are redirected, and
    any path that still resolves under a real terminal root fails the test.
    """
    sentinel = tmp_path / "_forbidden_terminal_sentinel"
    monkeypatch.setattr(demo_install, "TARGET", sentinel)
    monkeypatch.setattr(demo_install, "TRIAL_REPORT_ROOT", tmp_path / "_reports")
    yield
    for constant in (demo_install.TARGET, demo_install.TRIAL_REPORT_ROOT):
        assert tmp_path in Path(constant).parents or Path(constant) == tmp_path, constant
        for root in REAL_TERMINALS:
            assert root not in Path(constant).parents, f"constant escaped to a real terminal: {constant}"

BASE = (
    b"; environment: backtest\n"
    b"qm_ea_id=13213\nqm_magic_slot_offset=0\n"
    b"RISK_FIXED=1000\nRISK_PERCENT=0\nLookback=17\n"
)
SYMBOL_BASE = BASE + b"strategy_host_symbol=USDJPY.DWX\n"


def _sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _pin(data: bytes) -> str:
    """The binding's pin basis: sha256 of the LINE-ENDING-NORMALIZED bytes.

    Ticket a5cf99d0 (2026-09-18): raw-byte pins are not portable, because
    core.autocrlf gives one committed content two different digests. These
    CRLF fixtures must therefore be pinned the way the real binding is.
    """
    return hashlib.sha256(data.replace(b"\r\n", b"\n")).hexdigest()


def _row(**over) -> dict:
    row = {
        "ea_id": 13213, "ea_label": "QM5_13213_balke-gmt3-range-breakout",
        "dxz_symbol": "USDJPY", "ftmo_symbol": "USDJPY", "timeframe": "H1",
        "slot": 0, "magic": 132130000, "risk_percent": 0.3125,
    }
    row.update(over)
    return row


def _roster(tmp_path: Path, rows: list[dict], name: str = "roster.json") -> Path:
    path = tmp_path / name
    path.write_text(json.dumps(
        {"schema": s.ROSTER_SCHEMA, "label": "R2_test", "candidates": rows}), encoding="utf-8")
    return path


# --------------------------------------------------------------------------- #
# 1. trial_setpath --roster
# --------------------------------------------------------------------------- #
def test_roster_loads_and_validates(tmp_path):
    roster = s.load_roster(_roster(tmp_path, [_row(), _row(ea_id=10706, dxz_symbol="GBPUSD",
                                                    ftmo_symbol="GBPUSD", slot=1, magic=107060001,
                                                    ea_label="QM5_10706_tv-mon-ls")]))
    assert [r["magic"] for r in roster["candidates"]] == [132130000, 107060001]


@pytest.mark.parametrize("rows,match", [
    ([_row(magic=132130007)], "roster_magic_formula_violation"),
    ([_row(), _row(ea_label="dup")], "roster_magic_collision"),
    ([_row(ftmo_symbol="USDJPY.DWX")], "roster_ftmo_symbol_is_factory_name"),
    ([_row(timeframe="H")], "roster_timeframe_invalid"),
    ([_row(risk_percent=0)], "roster_risk_percent_outside_cap"),
    ([_row(risk_percent=2)], "roster_risk_percent_outside_cap"),
    ([{"ea_id": 1}], "roster_row_incomplete"),
    ([], "empty_roster"),
])
def test_roster_refusals(tmp_path, rows, match):
    with pytest.raises(s.Refusal, match=match):
        s.load_roster(_roster(tmp_path, rows))


def test_roster_schema_must_be_v1(tmp_path):
    path = tmp_path / "bad.json"
    path.write_text(json.dumps({"schema": "other/v9", "candidates": [_row()]}), encoding="utf-8")
    with pytest.raises(s.Refusal, match="invalid_roster_schema"):
        s.load_roster(path)


def test_symbol_slot_rebound_to_bare_venue_name():
    out, proof = s.derive_for_roster(SYMBOL_BASE, 0.3125, "USDJPY", "USDJPY")
    values = s.values(s.decode(out))
    assert values["strategy_host_symbol"] == "USDJPY"
    assert values["RISK_FIXED"] == "0" and values["RISK_PERCENT"] == "0.3125"
    assert values["qm_news_temporal"] == "3" and values["qm_friday_close_enabled"] == "true"
    assert proof["symbol_slot_changes"]["strategy_host_symbol"] == {
        "before": "USDJPY.DWX", "after": "USDJPY"}
    assert proof["factory_symbol"] == "USDJPY.DWX"


def test_index_slot_rebound_to_venue_alias():
    source = BASE + b"strategy_symbol_slot0=NDX.DWX\n"
    out, proof = s.derive_for_roster(source, 0.3125, "NDX", "US100.cash")
    assert s.values(s.decode(out))["strategy_symbol_slot0"] == "US100.cash"
    assert proof["venue_symbol"] == "US100.cash"


def test_foreign_symbol_slot_is_refused_not_left_dark():
    source = SYMBOL_BASE + b"strategy_partner_symbol=GBPUSD.DWX\n"
    with pytest.raises(s.Refusal, match="unmapped_symbol_slot_input"):
        s.derive_for_roster(source, 0.3125, "USDJPY", "USDJPY")


def test_literal_free_preset_is_untouched_by_the_rebind():
    plain, _ = s.derive(BASE, 0.3125)
    rebound, proof = s.derive_for_roster(BASE, 0.3125, "USDJPY", "USDJPY")
    assert rebound == plain and proof["symbol_slot_changes"] == {}


FAKE_RULE = {
    "rulepack_id": "FTMO_2S_100K_STANDARD_V2", "profile_version": 2, "as_of": "2026-09-04",
    "official_rules": [
        {"rule_id": "ftmo_2s_max_daily_loss", "parameters": {"percent_of_initial_simulated_capital": "5"}},
        {"rule_id": "ftmo_2s_maximum_loss", "parameters": {"percent_of_initial_simulated_capital": "10"}},
    ],
}
FAKE_BINDING = {
    "binding_id": "FTMO_M13_STANDARD_DEMO_V1",
    "account": {"observed_leverage": "1:100"},
    "rulepack": {"canonical_sha256": "c" * 64},
}


def _stub_binding(monkeypatch):
    """The pinned-sha binding check is exercised by test_ftmo_trial_setpath.py.

    Here it is stubbed so a roster test reports a roster defect, not the repo's
    line-ending-sensitive sha pins.
    """
    monkeypatch.setattr(s, "load_binding",
                        lambda path=s.BINDING: (FAKE_BINDING, FAKE_RULE, Path(path), b"{}"))


def _fake_seal(tmp_path, monkeypatch, source_bytes=BASE, timeframe="H1"):
    source = tmp_path / f"src_USDJPY.DWX_{timeframe}_backtest.set"
    source.write_bytes(source_bytes)

    def fake(_conn, ea, symbol):
        return source_bytes, {
            "ea_id": ea, "symbol": symbol, "timeframe": timeframe,
            "seal_work_item_id": f"seal-{ea}", "source_path": str(source),
            "source_sha256": _sha(source_bytes), "seal_path": str(tmp_path / "seal.json"),
            "seal_sha256": "1" * 64, "source_role": "SEALED_BASELINE_STRATEGY_PARAMETERS",
            "original_selected_news_config": {}, "ex5_sha256": "2" * 64,
        }

    monkeypatch.setattr(s, "sealed_source_raw", fake)
    return source


def test_generate_from_roster_writes_v2_manifest(tmp_path, monkeypatch):
    _stub_binding(monkeypatch)
    _fake_seal(tmp_path, monkeypatch, SYMBOL_BASE)
    database = tmp_path / "farm.sqlite"
    sqlite3.connect(database).close()
    out = s.generate_from_roster(
        "roster-run", _roster(tmp_path, [_row()]), database=database,
        trial_root=tmp_path / "review")
    assert out["schema"] == "qm.ftmo-trial-setpath/v2"
    assert out["ENV"] == "live" and out["installed"] is False and out["installable"] is False
    assert out["risk_percent"] == 0.3125 and out["book_risk_percent"] == 0.3125
    assert out["roster_schema"] == s.ROSTER_SCHEMA
    assert out["constraints"]["calendar_binding"].startswith("NATIVE_MT5_CALENDAR_LIVE")
    assert out["constraints"]["qm_weekend_flat"].startswith("FRIDAY_CLOSE_21")
    assert len(out["candidates"]) == 1
    candidate = out["candidates"][0]
    assert candidate["venue_symbol"] == "USDJPY" and candidate["magic"] == 132130000
    written = Path(out["directory"]) / candidate["output_path"]
    assert _sha(written.read_bytes()) == candidate["output_sha256"]
    assert s.values(s.decode(written.read_bytes()))["strategy_host_symbol"] == "USDJPY"


def test_generate_from_roster_refuses_timeframe_drift(tmp_path, monkeypatch):
    _stub_binding(monkeypatch)
    _fake_seal(tmp_path, monkeypatch, BASE, timeframe="D1")
    database = tmp_path / "farm.sqlite"
    sqlite3.connect(database).close()
    with pytest.raises(s.Refusal, match="roster_timeframe_mismatch"):
        s.generate_from_roster("tf-drift", _roster(tmp_path, [_row(timeframe="H1")]),
                               database=database, trial_root=tmp_path / "review")


def test_generate_from_roster_refuses_slot_drift(tmp_path, monkeypatch):
    _stub_binding(monkeypatch)
    _fake_seal(tmp_path, monkeypatch, BASE)
    database = tmp_path / "farm.sqlite"
    sqlite3.connect(database).close()
    rows = [_row(slot=4, magic=132130004)]
    with pytest.raises(s.Refusal, match="roster_slot_mismatch"):
        s.generate_from_roster("slot-drift", _roster(tmp_path, rows),
                               database=database, trial_root=tmp_path / "review")


def test_legacy_path_still_uses_lanes_and_v3(tmp_path, monkeypatch):
    """The hard-bound path is unchanged: LANES-derived venue, v3 manifest."""
    _stub_binding(monkeypatch)
    _fake_seal(tmp_path, monkeypatch, BASE)
    monkeypatch.setattr(s, "CANDIDATES", ((10706, "GBPUSD"),))
    monkeypatch.setattr(s, "TRIAL_ROOT", tmp_path / "legacy")
    s.TRIAL_ROOT.mkdir()
    database = tmp_path / "farm.sqlite"
    sqlite3.connect(database).close()
    out = s.generate("legacy-run", 0.3125, database=database)
    assert out["schema"] == "qm.ftmo-trial-setpath/v3"
    assert out["candidates"][0]["native_symbol"] == s.LANES["GBPUSD"]


def test_cli_requires_exactly_one_input_mode():
    with pytest.raises(SystemExit):
        s.main.__wrapped__ if False else _cli(["--run-name", "x", "--dry-run"])
    with pytest.raises(SystemExit):
        _cli(["--run-name", "x", "--dry-run", "--roster", "r.json", "--risk-percent", "0.3"])


def _cli(argv):
    import sys as _sys
    old = _sys.argv
    _sys.argv = ["trial_setpath"] + argv
    try:
        return s.main()
    finally:
        _sys.argv = old


# --------------------------------------------------------------------------- #
# 2. demo_install --package / --dry-run
# --------------------------------------------------------------------------- #
def _package(tmp_path: Path, monkeypatch, *, rows=None, cycle_id="2026-09-18") -> Path:
    rows = rows or [_row()]
    pkg = tmp_path / "package"
    (pkg / "sets").mkdir(parents=True)
    (pkg / "collector").mkdir()
    (pkg / "bin").mkdir()
    _roster(pkg, rows)

    ea_dir = tmp_path / "EAs" / "QM5_13213_x"
    (ea_dir / "sets").mkdir(parents=True)
    ex5 = ea_dir / "QM5_13213_x.ex5"
    ex5.write_bytes(b"EX5-BINARY")

    candidates = []
    for row in rows:
        preset_bytes, _ = s.derive_for_roster(BASE, row["risk_percent"], row["dxz_symbol"], row["ftmo_symbol"])
        name = f"QM5_{row['ea_id']}_{row['ftmo_symbol']}_{row['timeframe']}_live_trial.set"
        (pkg / "sets" / name).write_bytes(preset_bytes)
        candidates.append({
            "ea_id": row["ea_id"], "native_symbol": row["ftmo_symbol"],
            "timeframe": row["timeframe"], "qm_magic_slot_offset": str(row["slot"]),
            "output_path": name, "output_sha256": _sha(preset_bytes),
            "source_path": str(ea_dir / "sets" / "src.set"), "ex5_sha256": _sha(b"EX5-BINARY"),
        })
    (pkg / "sets" / "manifest.json").write_text(json.dumps({
        "schema": "qm.ftmo-trial-setpath/v2",
        "account_variant": "STANDARD_2STEP_100K_FREE_TRIAL",
        "candidates": candidates}), encoding="utf-8")

    collector_binary = pkg / "bin" / "QM_FTMO_TrialTelemetry.ex5"
    collector_binary.write_bytes(b"COLLECTOR")
    collector_preset = pkg / "collector" / "QM_FTMO_TrialTelemetry_1514536732.set"
    collector_preset.write_text(
        "InpTimerSeconds=1\n"
        f"InpOutputDir=QM\\ftmo_trial\\{cycle_id}\n"
        "InpExpectedLogin=1514536732\nInpExpectedServer=FTMO-Demo\n"
        f"InpTrialId=M13_{cycle_id}\n", encoding="utf-8")

    receipt = tmp_path / "fable_receipt.md"
    receipt.write_text("OWNER receipt", encoding="utf-8")
    (pkg / "authority.json").write_text(json.dumps({
        "schema": demo_install.AUTHORITY_SCHEMA,
        "decision_id": "OWNER-DEC-FTMO-R2-20260918",
        "receipt_path": str(receipt),
        "cycle_id": cycle_id,
        "label": "R2_capped",
        "collector": {"binary_path": "bin/QM_FTMO_TrialTelemetry.ex5",
                      "preset_path": "collector/QM_FTMO_TrialTelemetry_1514536732.set",
                      "binary_sha256": _sha(b"COLLECTOR"),
                      "trial_id": f"M13_{cycle_id}"},
    }), encoding="utf-8")
    return pkg


def _fake_terminal(tmp_path: Path, monkeypatch) -> Path:
    target = tmp_path / "Terminal" / "ABC"
    (target / "config").mkdir(parents=True)
    program = tmp_path / "Program"
    program.mkdir()
    (target / "origin.txt").write_text(str(program), encoding="utf-16")
    (target / "config" / "common.ini").write_text(
        "[Common]\nLogin=1514536732\nServer=FTMO-Demo\n\n[Experts]\nEnabled=0\n", encoding="utf-16")
    monkeypatch.setattr(demo_install, "TARGET", target)
    monkeypatch.setattr(demo_install, "PROGRAM", program)
    monkeypatch.setattr(demo_install, "TRIAL_REPORT_ROOT", tmp_path / "reports")
    return target


def test_package_dry_run_prints_full_copy_plan_with_hashes(tmp_path, monkeypatch):
    target = _fake_terminal(tmp_path, monkeypatch)
    pkg = _package(tmp_path, monkeypatch)
    plan = demo_install.plan(demo_install.load_package(pkg))
    assert plan["mode"] == "DRY_RUN"
    assert plan["decision_id"] == "OWNER-DEC-FTMO-R2-20260918"
    assert plan["cycle_id"] == "2026-09-18"
    assert plan["autotrading_changed"] is False and plan["charts_changed"] is False
    assert plan["copy_count"] == 4  # 1 ex5 + 1 preset + collector binary + collector preset
    assert all(len(c["source_sha256"]) == 64 for c in plan["copies"])
    assert all(c["action"] == "CREATE" for c in plan["copies"])
    assert plan["backup_dir"].endswith("_pre_2026-09-18")
    # dry-run must not have written anything into the terminal
    assert not (target / "MQL5").exists()


def test_package_install_stages_only_binaries_and_presets(tmp_path, monkeypatch):
    target = _fake_terminal(tmp_path, monkeypatch)
    pkg = _package(tmp_path, monkeypatch)
    receipt = demo_install.install(demo_install.load_package(pkg))
    assert receipt["status"] == "INSTALLED_UNATTACHED_PARKED"
    assert receipt["authority"]["mode"] == "OWNER_DECISION_RECEIPT"
    assert receipt["charts_changed"] is False and receipt["tlive_written"] is False
    assert len(receipt["installed"]) == 4
    experts = target / "MQL5" / "Experts" / "QM_FTMO"
    presets = target / "MQL5" / "Profiles" / "Presets" / "QM_FTMO_M13"
    assert (experts / "QM5_13213_x.ex5").is_file()
    assert (presets / "QM5_13213_USDJPY_H1_live_trial.set").is_file()
    assert (target / "MQL5" / "Files" / "QM" / "ftmo_trial" / "2026-09-18").is_dir()
    # no chart profile and no AutoTrading edit
    assert not (target / "MQL5" / "Profiles" / "Charts").exists()
    common = (target / "config" / "common.ini").read_text(encoding="utf-16")
    assert "Enabled=0" in common
    assert (pkg / "install_receipt.json").is_file()
    with pytest.raises(demo_install.Refusal, match="receipt_exists_refusing_overwrite"):
        demo_install.install(demo_install.load_package(pkg))


@pytest.mark.parametrize("key,value,match", [
    ("Login", "9999999", "login_mismatch"),
    ("Server", "FTMO-Live", "server_mismatch"),
])
def test_target_identity_is_still_fail_closed(tmp_path, monkeypatch, key, value, match):
    target = _fake_terminal(tmp_path, monkeypatch)
    text = (target / "config" / "common.ini").read_text(encoding="utf-16")
    original = {"Login": "1514536732", "Server": "FTMO-Demo"}[key]
    (target / "config" / "common.ini").write_text(
        text.replace(f"{key}={original}", f"{key}={value}"), encoding="utf-16")
    pkg = _package(tmp_path, monkeypatch)
    with pytest.raises(demo_install.Refusal, match=match):
        demo_install.plan(demo_install.load_package(pkg))


def test_autotrading_enabled_target_is_refused(tmp_path, monkeypatch):
    target = _fake_terminal(tmp_path, monkeypatch)
    (target / "config" / "common.ini").write_text(
        "[Common]\nLogin=1514536732\nServer=FTMO-Demo\n\n[Experts]\nEnabled=1\n", encoding="utf-16")
    pkg = _package(tmp_path, monkeypatch)
    with pytest.raises(demo_install.Refusal, match="autotrading_must_be_disabled"):
        demo_install.plan(demo_install.load_package(pkg))


def test_forbidden_terminal_targets_are_still_listed():
    source = Path(demo_install.__file__).read_text(encoding="utf-8")
    assert r"C:\QM\mt5\T_Live" in source
    assert 'D:/QM/mt5/T{i}' in source and "range(1, 11)" in source


def test_collector_contract_is_cycle_bound(tmp_path, monkeypatch):
    _fake_terminal(tmp_path, monkeypatch)
    pkg = _package(tmp_path, monkeypatch, cycle_id="2026-09-18")
    preset = pkg / "collector" / "QM_FTMO_TrialTelemetry_1514536732.set"
    preset.write_text(preset.read_text(encoding="utf-8").replace("2026-09-18", "2026-09-06"), encoding="utf-8")
    with pytest.raises(demo_install.Refusal, match="collector_preset_contract_mismatch"):
        demo_install.plan(demo_install.load_package(pkg))


def test_collector_binary_sha_is_enforced(tmp_path, monkeypatch):
    _fake_terminal(tmp_path, monkeypatch)
    pkg = _package(tmp_path, monkeypatch)
    (pkg / "bin" / "QM_FTMO_TrialTelemetry.ex5").write_bytes(b"TAMPERED")
    with pytest.raises(demo_install.Refusal, match="collector_binary_hash_mismatch"):
        demo_install.plan(demo_install.load_package(pkg))


def test_manifest_must_match_the_roster(tmp_path, monkeypatch):
    _fake_terminal(tmp_path, monkeypatch)
    pkg = _package(tmp_path, monkeypatch)
    manifest = json.loads((pkg / "sets" / "manifest.json").read_text(encoding="utf-8"))
    manifest["candidates"][0]["native_symbol"] = "EURUSD"
    (pkg / "sets" / "manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    with pytest.raises(demo_install.Refusal, match="roster_manifest_binding_mismatch"):
        demo_install.plan(demo_install.load_package(pkg))


def test_authority_is_required(tmp_path, monkeypatch):
    pkg = _package(tmp_path, monkeypatch)
    (pkg / "authority.json").unlink()
    with pytest.raises(demo_install.Refusal, match="package_authority_missing"):
        demo_install.load_package(pkg)


def test_authority_receipt_must_exist(tmp_path, monkeypatch):
    pkg = _package(tmp_path, monkeypatch)
    authority = json.loads((pkg / "authority.json").read_text(encoding="utf-8"))
    authority["receipt_path"] = str(tmp_path / "gone.md")
    (pkg / "authority.json").write_text(json.dumps(authority), encoding="utf-8")
    with pytest.raises(demo_install.Refusal, match="package_authority_receipt_missing"):
        demo_install.load_package(pkg)


def test_package_paths_cannot_escape_the_package(tmp_path, monkeypatch):
    pkg = _package(tmp_path, monkeypatch)
    authority = json.loads((pkg / "authority.json").read_text(encoding="utf-8"))
    authority["collector"]["binary_path"] = "../outside.ex5"
    (pkg / "authority.json").write_text(json.dumps(authority), encoding="utf-8")
    with pytest.raises(demo_install.Refusal, match="package_path_escape"):
        demo_install.load_package(pkg)


def test_legacy_constants_are_preserved():
    assert demo_install.TASK_ID == "35eac0e9-8568-4114-b68f-45258ad7189b"
    legacy = demo_install.legacy_package()
    assert legacy.cycle_id == "2026-09-06"
    assert legacy.backup_dir_name == "_pre_m13_20260906"
    assert legacy.collector_output_dir == r"QM\ftmo_trial\2026-09-06"
    assert legacy.trial_id == "M13_OPTION_B_20260906_1514536732"
    assert legacy.expected_agent == "codex"
    assert legacy.collector_sha == demo_install.EXPECTED_COLLECTOR_SHA


# --------------------------------------------------------------------------- #
# 3. governor rebind
# --------------------------------------------------------------------------- #
GOV_PRESET = (
    "qm_ea_id=13206||13206||1||999999||N\r\n"
    "signed_policy_id=FTMO_2S_P1_100K_V2\r\n"
    "governed_symbols_csv=GBPUSD,EURUSD\r\n"
    "challenge_id=M13_20260906_1514536732\r\n"
    "challenge_start_utc=2026.09.06 06:17:00\r\n"
    "allowed_magics_csv=107060001,114210000\r\n"
    "governed_ea_ids_csv=10706,11421\r\n"
    "governor_dry_run=false||false||0||true||N\r\n\r\n"
)


def _registry(tmp_path: Path, rows: list[tuple]) -> Path:
    path = tmp_path / "magic_numbers.csv"
    lines = ["ea_id,ea_slug,symbol_slot,symbol,magic,reserved_at,reserved_by,status"]
    lines += [f"{e},slug,{sl},{sym},{m},2026-01-01,Dev,{st}" for e, sl, sym, m, st in rows]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return path


def _gov_fixture(tmp_path: Path):
    sets = tmp_path / "gov_sets"
    sets.mkdir()
    paths = {}
    for role in ("bootstrap", "active"):
        p = sets / f"gov_{role}.set"
        p.write_bytes(GOV_PRESET.encode("utf-8"))
        paths[role] = p
    binding = tmp_path / "binding.json"
    binding.write_text(json.dumps({"governor": {
        "ea_id": 13206, "policy_id": "FTMO_2S_P1_100K_V2",
        "bootstrap_preset_path": str(paths["bootstrap"].relative_to(tmp_path)),
        "active_preset_path": str(paths["active"].relative_to(tmp_path)),
        "bootstrap_preset_sha256": _pin(GOV_PRESET.encode("utf-8")),
        "active_preset_sha256": _pin(GOV_PRESET.encode("utf-8")),
    }}, indent=2), encoding="utf-8")
    return binding, paths


def test_rebind_derives_csvs_and_repins_shas_atomically(tmp_path, monkeypatch):
    monkeypatch.setattr(governor_rebind, "REPO_ROOT", tmp_path)
    binding, paths = _gov_fixture(tmp_path)
    rows = [_row(), _row(ea_id=11660, ea_label="QM5_11660_pp-wedge", dxz_symbol="NDX",
                         ftmo_symbol="US100.cash", timeframe="H4", slot=4, magic=116600004)]
    registry = _registry(tmp_path, [
        (13213, 0, "USDJPY.DWX", 132130000, "active"),
        (11660, 4, "NDX.DWX", 116600004, "active"),
    ])
    receipt_path = tmp_path / "receipt.json"
    result = governor_rebind.rebind(
        _roster(tmp_path, rows), binding_path=binding, registry_path=registry,
        challenge_id="M13_20260918_1514536732", challenge_start_utc="2026.09.18 06:17:00",
        apply=True, receipt_path=receipt_path, verify=lambda _p: None)

    assert result["applied"] is True
    assert result["updates"]["allowed_magics_csv"] == "116600004,132130000"
    assert result["updates"]["governed_ea_ids_csv"] == "11660,13213"
    assert result["updates"]["governed_symbols_csv"] == "US100.cash,USDJPY"
    assert result["terminal_written"] is False
    new_binding = json.loads(binding.read_text(encoding="utf-8"))
    for role in ("bootstrap", "active"):
        raw = paths[role].read_bytes()
        assert new_binding["governor"][f"{role}_preset_sha256"] == _pin(raw)
        # ... and that re-pin is line-ending-invariant: the identical content
        # written with LF carries the same pin (ticket a5cf99d0).
        assert _pin(raw.replace(b"\r\n", b"\n")) == _pin(raw)
        text = raw.decode("utf-8")
        assert "\r\n" in text  # CRLF preserved
        assert "allowed_magics_csv=116600004,132130000" in text
        assert "challenge_id=M13_20260918_1514536732" in text
        assert "qm_ea_id=13206||13206||1||999999||N" in text  # untouched key kept verbatim
        assert "governor_dry_run=false||false||0||true||N" in text
    assert json.loads(receipt_path.read_text(encoding="utf-8"))["schema"] == governor_rebind.RECEIPT_SCHEMA


def test_rebind_refuses_magic_absent_from_registry(tmp_path, monkeypatch):
    monkeypatch.setattr(governor_rebind, "REPO_ROOT", tmp_path)
    binding, _ = _gov_fixture(tmp_path)
    registry = _registry(tmp_path, [(13213, 0, "USDJPY.DWX", 132130000, "active")])
    rows = [_row(), _row(ea_id=99999, ea_label="ghost", dxz_symbol="EURUSD",
                         ftmo_symbol="EURUSD", slot=0, magic=999990000)]
    with pytest.raises(governor_rebind.Refusal, match="magic_not_in_registry:999990000"):
        governor_rebind.rebind(_roster(tmp_path, rows), binding_path=binding, registry_path=registry)


def test_rebind_refuses_retired_registry_row(tmp_path, monkeypatch):
    monkeypatch.setattr(governor_rebind, "REPO_ROOT", tmp_path)
    binding, _ = _gov_fixture(tmp_path)
    registry = _registry(tmp_path, [(13213, 0, "USDJPY.DWX", 132130000, "retired")])
    with pytest.raises(governor_rebind.Refusal, match="magic_not_in_registry"):
        governor_rebind.rebind(_roster(tmp_path, [_row()]), binding_path=binding, registry_path=registry)


def test_rebind_refuses_registry_symbol_mismatch(tmp_path, monkeypatch):
    monkeypatch.setattr(governor_rebind, "REPO_ROOT", tmp_path)
    binding, _ = _gov_fixture(tmp_path)
    registry = _registry(tmp_path, [(13213, 0, "EURUSD.DWX", 132130000, "active")])
    with pytest.raises(governor_rebind.Refusal, match="registry_symbol_mismatch"):
        governor_rebind.rebind(_roster(tmp_path, [_row()]), binding_path=binding, registry_path=registry)


def test_rebind_refuses_colliding_roster_magics(tmp_path, monkeypatch):
    monkeypatch.setattr(governor_rebind, "REPO_ROOT", tmp_path)
    binding, _ = _gov_fixture(tmp_path)
    registry = _registry(tmp_path, [(13213, 0, "USDJPY.DWX", 132130000, "active")])
    path = tmp_path / "dup.json"
    path.write_text(json.dumps({"schema": s.ROSTER_SCHEMA,
                                "candidates": [_row(), _row(ea_label="dup")]}), encoding="utf-8")
    with pytest.raises(s.Refusal, match="roster_magic_collision"):
        governor_rebind.rebind(path, binding_path=binding, registry_path=registry)


def test_rebind_rolls_back_when_the_binding_becomes_incoherent(tmp_path, monkeypatch):
    monkeypatch.setattr(governor_rebind, "REPO_ROOT", tmp_path)
    binding, paths = _gov_fixture(tmp_path)
    before_binding = binding.read_bytes()
    before_preset = paths["active"].read_bytes()
    registry = _registry(tmp_path, [(13213, 0, "USDJPY.DWX", 132130000, "active")])

    def boom(_path):
        raise ValueError("active_preset_binding_mismatch")

    with pytest.raises(governor_rebind.Refusal, match="rebind_binding_incoherent"):
        governor_rebind.rebind(_roster(tmp_path, [_row()]), binding_path=binding,
                               registry_path=registry, apply=True, verify=boom)
    assert binding.read_bytes() == before_binding
    assert paths["active"].read_bytes() == before_preset


def test_rebind_dry_run_changes_nothing(tmp_path, monkeypatch):
    monkeypatch.setattr(governor_rebind, "REPO_ROOT", tmp_path)
    binding, paths = _gov_fixture(tmp_path)
    before = {p: p.read_bytes() for p in list(paths.values()) + [binding]}
    registry = _registry(tmp_path, [(13213, 0, "USDJPY.DWX", 132130000, "active")])
    result = governor_rebind.rebind(_roster(tmp_path, [_row()]), binding_path=binding,
                                    registry_path=registry)
    assert result["applied"] is False
    assert result["binding"]["sha256_after"] != result["binding"]["sha256_before"]
    assert all(p.read_bytes() == data for p, data in before.items())


def test_rebind_refuses_preset_that_drifted_from_its_pin(tmp_path, monkeypatch):
    monkeypatch.setattr(governor_rebind, "REPO_ROOT", tmp_path)
    binding, paths = _gov_fixture(tmp_path)
    paths["active"].write_bytes(GOV_PRESET.replace("13206", "13207").encode("utf-8"))
    registry = _registry(tmp_path, [(13213, 0, "USDJPY.DWX", 132130000, "active")])
    with pytest.raises(governor_rebind.Refusal, match="active_preset_hash_drift_before_rebind"):
        governor_rebind.rebind(_roster(tmp_path, [_row()]), binding_path=binding, registry_path=registry)


def test_rebind_refuses_preset_missing_a_governed_key(tmp_path, monkeypatch):
    monkeypatch.setattr(governor_rebind, "REPO_ROOT", tmp_path)
    stripped = GOV_PRESET.replace("governed_symbols_csv=GBPUSD,EURUSD\r\n", "")
    sets = tmp_path / "gov_sets"
    sets.mkdir()
    for role in ("bootstrap", "active"):
        (sets / f"gov_{role}.set").write_bytes(stripped.encode("utf-8"))
    binding = tmp_path / "binding.json"
    binding.write_text(json.dumps({"governor": {
        "ea_id": 13206,
        "bootstrap_preset_path": "gov_sets/gov_bootstrap.set",
        "active_preset_path": "gov_sets/gov_active.set",
        "bootstrap_preset_sha256": _pin(stripped.encode("utf-8")),
        "active_preset_sha256": _pin(stripped.encode("utf-8")),
    }}), encoding="utf-8")
    registry = _registry(tmp_path, [(13213, 0, "USDJPY.DWX", 132130000, "active")])
    with pytest.raises(governor_rebind.Refusal, match="governor_key_missing:governed_symbols_csv"):
        governor_rebind.rebind(_roster(tmp_path, [_row()]), binding_path=binding, registry_path=registry)


def test_shipped_governor_presets_keep_their_policy_values():
    """A rebind must never be able to disturb the policy keys load_binding() checks.

    Asserted on the shipped presets directly; the sha-pin half of that contract is
    covered by test_ftmo_trial_setpath.py.
    """
    binding = json.loads((ROOT / "tools/strategy_farm/config/ftmo_m13_standard_demo.v1.json")
                         .read_text(encoding="utf-8"))
    governor = binding["governor"]
    assert governor["ea_id"] == 13206 and governor["policy_id"] == "FTMO_2S_P1_100K_V2"
    protected = {
        "signed_policy_id": "FTMO_2S_P1_100K_V2", "qm_news_temporal": "3",
        "qm_news_compliance": "2", "qm_news_stale_max_hours": "336",
        "qm_friday_close_enabled": "true", "qm_friday_close_hour_broker": "21",
        "qm_friday_flat_lead_minutes": "5", "expected_account_login": "1514536732",
        "expected_account_server": "FTMO-Demo",
    }
    for role in ("bootstrap", "active"):
        raw = (ROOT / governor[f"{role}_preset_path"]).read_bytes()
        values = s._preset_values(s.decode(raw))
        for key, value in protected.items():
            assert values[key] == value, (role, key)
        # every key the rebind touches is present, so a rebind cannot silently no-op
        for key in governor_rebind.REBOUND_KEYS:
            assert key in values, (role, key)
        # and the rebind leaves the protected keys untouched
        rebound = governor_rebind.rewrite_preset(raw, {k: "X" for k in governor_rebind.REBOUND_KEYS})
        after = s._preset_values(s.decode(rebound))
        assert {k: after[k] for k in protected} == protected


# --------------------------------------------------------------------------- #
# 4. QM_MagicSymbolCanonical US100 -> NDX
# --------------------------------------------------------------------------- #
def test_ndx_alias_present_in_resolver_and_generator():
    resolver = (ROOT / "framework/include/QM/QM_MagicResolver.mqh").read_text(encoding="utf-8-sig")
    generator = (ROOT / "framework/scripts/update_magic_resolver.py").read_text(encoding="utf-8-sig")
    for source in (resolver, generator):
        assert 'base == "USOIL"' in source and 'return "XTIUSD"' in source
        assert 'base == "US100"' in source and 'return "NDX"' in source
        assert "compile lane must rebuild" in source


def test_resolver_alias_block_matches_the_generator_template():
    resolver = (ROOT / "framework/include/QM/QM_MagicResolver.mqh").read_text(encoding="utf-8-sig")
    generator = (ROOT / "framework/scripts/update_magic_resolver.py").read_text(encoding="utf-8-sig")
    block = resolver.split("string QM_MagicSymbolCanonical", 1)[1].split("bool QM_Magic", 1)[0]
    assert block.replace("{", "{{").replace("}", "}}") in generator


# --------------------------------------------------------------------------- #
# 5. demo_cycle attached_dark
# --------------------------------------------------------------------------- #
def _sleeve(magic, ea_id, symbol, risk=0.3125):
    return {"ea_id": ea_id, "ea_name": f"QM5_{ea_id}_x", "symbol": symbol,
            "slot": magic % 10000, "magic": magic, "risk_pct": risk, "ex5_sha": "a" * 64}


def _observation(roster, placements=None, dark_after=5):
    obs = {"roster": roster, "roster_source": "chart_profile",
           "product": "P", "compliance": {"r": 1}, "dark_after_trading_days": dark_after}
    if placements is not None:
        obs["placements"] = placements
        obs["placements_source"] = "synthetic"
    return obs


def test_attached_dark_flags_zero_placement_sleeves():
    roster = [_sleeve(107060001, 10706, "GBPUSD"), _sleeve(200480000, 20048, "USOIL.cash")]
    start = dt.datetime(2026, 9, 7, tzinfo=dt.timezone.utc)   # Monday
    obs = _observation(roster, {10706: 6, 20048: 0})
    prev = {"roster_hash": demo_cycle.roster_hash(roster), "roster": roster,
            "cycle_start_utc": "2026-09-07T00:00:00Z", "state": "RUNNING",
            "product": "P", "compliance": {"r": 1}}
    ledger = demo_cycle.build_demo_cycle(obs, prev, start + dt.timedelta(days=9))
    by_magic = {s["magic"]: s for s in ledger["roster"]}
    assert by_magic[107060001]["attached_dark"] is False
    assert by_magic[200480000]["attached_dark"] is True
    assert ledger["attached_dark_magics"] == [200480000]
    assert ledger["attached_dark_count"] == 1
    assert ledger["total_book_risk_pct"] == 0.625
    assert ledger["attached_dark_risk_pct"] == 0.3125
    assert ledger["realised_book_risk_pct"] == 0.3125


def test_attached_dark_waits_for_n_trading_days():
    roster = [_sleeve(200480000, 20048, "USOIL.cash")]
    start = dt.datetime(2026, 9, 7, tzinfo=dt.timezone.utc)
    prev = {"roster_hash": demo_cycle.roster_hash(roster), "roster": roster,
            "cycle_start_utc": "2026-09-07T00:00:00Z", "state": "RUNNING",
            "product": "P", "compliance": {"r": 1}}
    early = demo_cycle.build_demo_cycle(_observation(roster, {20048: 0}), prev, start + dt.timedelta(days=2))
    assert early["trading_days_observed"] == 2
    assert early["roster"][0]["attached_dark"] is False
    late = demo_cycle.build_demo_cycle(_observation(roster, {20048: 0}), prev, start + dt.timedelta(days=7))
    assert late["roster"][0]["attached_dark"] is True


def test_attached_dark_is_not_a_material_change_and_does_not_reset_the_cycle():
    roster = [_sleeve(200480000, 20048, "USOIL.cash")]
    start = dt.datetime(2026, 9, 1, tzinfo=dt.timezone.utc)
    prev = {"roster_hash": demo_cycle.roster_hash(roster), "roster": roster,
            "cycle_start_utc": "2026-09-01T00:00:00Z", "state": "RUNNING",
            "product": "P", "compliance": {"r": 1}, "material_changes": []}
    ledger = demo_cycle.build_demo_cycle(_observation(roster, {20048: 0}), prev, start + dt.timedelta(days=20))
    assert ledger["roster"][0]["attached_dark"] is True
    assert ledger["is_new_cycle_this_observation"] is False
    assert ledger["cycle_start_utc"] == "2026-09-01T00:00:00Z"
    assert ledger["material_changes"] == []
    assert ledger["latest_change_assessment"]["material"] is False
    assert ledger["state"] == "REPRESENTATIVE" and ledger["representative"] is True
    # identity is unaffected by the annotation
    assert demo_cycle.roster_hash(ledger["roster"]) == demo_cycle.roster_hash(roster)


def test_missing_placement_evidence_never_calls_a_sleeve_dark():
    roster = [_sleeve(200480000, 20048, "USOIL.cash")]
    start = dt.datetime(2026, 9, 1, tzinfo=dt.timezone.utc)
    prev = {"roster_hash": demo_cycle.roster_hash(roster), "roster": roster,
            "cycle_start_utc": "2026-09-01T00:00:00Z", "state": "RUNNING",
            "product": "P", "compliance": {"r": 1}}
    obs = {"roster": roster, "roster_source": "chart_profile", "product": "P", "compliance": {"r": 1}}
    ledger = demo_cycle.build_demo_cycle(obs, prev, start + dt.timedelta(days=30))
    assert ledger["roster"][0]["placements_observed"] == "EVIDENCE_MISSING"
    assert ledger["roster"][0]["attached_dark"] is False
    assert ledger["attached_dark_count"] == 0
    assert ledger["placements_source"] == "EVIDENCE_MISSING"


def test_observe_placements_counts_tm_open_from_ea_logs(tmp_path):
    (tmp_path / "QM5_10706_ea-10706.log").write_text(
        "INIT_OK\nTM_OPEN ticket=1\nENTRY_ACCEPTED x\nnoise\n", encoding="utf-8")
    (tmp_path / "QM5_20048_ea-20048.log").write_text("INIT_OK\nINIT_OK\n", encoding="utf-8")
    counts = demo_cycle.observe_placements(tmp_path)
    assert counts == {10706: 2, 20048: 0}
    assert demo_cycle.observe_placements(tmp_path / "nope") == {}


@pytest.mark.parametrize("days,expected", [(0, 0), (1, 1), (5, 4), (7, 5), (14, 10)])
def test_trading_day_counter_skips_weekends(days, expected):
    start = dt.datetime(2026, 9, 7, tzinfo=dt.timezone.utc)  # Monday
    assert demo_cycle._trading_days_between(start, start + dt.timedelta(days=days)) == expected
