"""WS-E2 — morning briefing live-truth-first status lamp.

Proves that morning_brief.live_status():
  * consumes the schemas the producers ACTUALLY emit — the WS-E1 alarm state
    (watchdog_status/any_alarm/sessions/generated_utc) and the WS-E3 deployment
    contract state (overall_status/generated_utc/summary) — so a FRESH VALID
    producer file renders GREEN/RED by its own content (never UNKNOWN-on-valid);
  * is derived ONLY from injected state-file paths (no MT5 process probe, no file
    under C:\\QM\\mt5\\T_Live is ever in the default source set);
  * is deterministic given (paths, now);
  * fails visible — missing/stale/malformed sources become UNBEKANNT/RED, never
    green-by-absence, and a red live condition reaches the subject line;
  * authenticates the SIGNED deploy-stamp (signed + manifest SHA-256 + deployment
    epoch + expected account/phase) — status==LIVE alone is insufficient;
  * derives the expected sleeve count from the manifest, never a constant;
  * generates FTMO trial-dead/alive prose from account state, not retained text.

Fixtures: tests/fixtures/morning_brief_live/scenarios.json (schema-conformant),
plus tests/fixtures/morning_brief_live/producer_samples/*.json (verbatim producer
bytes) exercised by test_producer_samples_conformance.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[3]
MODULE_PATH = ROOT / "tools" / "strategy_farm" / "morning_brief.py"
FX = Path(__file__).resolve().parent / "fixtures" / "morning_brief_live"
FIXTURES = FX / "scenarios.json"
SAMPLES = FX / "producer_samples"

_SPEC = importlib.util.spec_from_file_location("morning_brief_under_test", MODULE_PATH)
assert _SPEC and _SPEC.loader
mb = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(mb)

_DATA = json.loads(FIXTURES.read_text(encoding="utf-8"))
_FIXED_NOW = mb._parse_utc(_DATA["fixed_now"])
_SCENARIOS = _DATA["scenarios"]

# All source keys morning_brief._resolve_paths understands.
_SRC_KEYS = ("alarm", "watchdog", "supervisor", "maintenance", "ftmo", "ddguard",
             "contract", "news", "deploy_pointer", "deploy_default", "manifest")

# GREEN, fresh, authenticated baseline — every scenario overrides only what it
# tests. Timestamps are ~30s before fixed_now (2026-07-26T08:00:00Z) => fresh.
_BASELINE = {
    "alarm": {"schema_version": 1, "generated_utc": "2026-07-26T07:59:30Z", "author": "T_Live_Watchdog",
              "watchdog_status": "healthy", "maintenance": False, "reboot_suppressed": False, "any_alarm": False,
              "sessions": {
                  "T_LIVE": {"session": "T_LIVE", "condition": "ok", "detail": "terminal_running", "alarm": False, "since_utc": "2026-07-26T07:00:00Z", "last_change": "2026-07-26T07:00:00Z", "transitions": 0, "previous_condition": None},
                  "FTMO": {"session": "FTMO", "condition": "ok", "detail": "terminal_running", "alarm": False, "since_utc": "2026-07-26T07:00:00Z", "last_change": "2026-07-26T07:00:00Z", "transitions": 0, "previous_condition": None}}},
    "ddguard": {"blind_runs": 90, "breached": False, "halt_dd_pct": 10.0, "hwm_equity": 101871.44,
                "last_dd_pct": 0.18, "last_equity": 101683.41, "last_run_utc": "2026-07-26T07:59:00+00:00"},
    "ftmo": {"checked_at_utc": "2026-07-26T07:59:00Z", "verdict": "OK", "terminal_up": True,
             "total_dd_pct": 3.0, "day_loss_pct": 0.4, "equity": 105000.0},
    "contract": {"tool": "verify_live_deployment_contract", "version": "1.0",
                 "generated_utc": "2026-07-26T07:59:00+00:00", "trigger": "periodic", "overall_status": "GREEN",
                 "disk_profile": {"status": "GREEN", "chart_files_total": 25, "trading_parseable": 24, "unparseable": 0,
                                  "monitor_count": 1, "monitor_status": "OK", "expected_present_ok": 24,
                                  "expected_missing": 0, "expected_field_mismatch": 0, "duplicates": 0, "orphans": 0, "sleeves": []},
                 "runtime": {"status": "GREEN", "n_logs_indexed": 24, "sleeves": []},
                 "findings": [], "summary": {"critical": 0, "warn": 0, "info": 1, "headline": "GREEN; disk 24/24 ok"}},
    "manifest_file": {"book": "DXZ_4000090541", "status": "LIVE", "n_sleeves": 24, "sleeves": []},
    "deploy_pointer": {"manifest_path": "__manifest__", "manifest_sha256": "__manifest_sha256__", "signed": True,
                       "approved_by": "OWNER (Fabian) 2026-07-25", "deployment_epoch_utc": "2026-07-25T20:00:00Z",
                       "expected_account": "4000090541", "expected_phase": "DXZ_LIVE"},
    "news_age_sec": 3600,
}

_ABSENT = ("__absent__", None)


def _write_json(fp: Path, content) -> None:
    if isinstance(content, dict) and "__raw__" in content:
        fp.write_text(content["__raw__"], encoding="utf-8")
    else:
        fp.write_text(json.dumps(content), encoding="utf-8")


def _resolve_stamp_sentinels(stamp: dict, manifest_path: Path) -> dict:
    """Substitute deploy-stamp sentinels against the materialized manifest."""
    out = dict(stamp)
    if out.get("manifest_path") == "__manifest__":
        out["manifest_path"] = str(manifest_path)
    if out.get("manifest_sha256") == "__manifest_sha256__":
        h = hashlib.sha256(manifest_path.read_bytes()).hexdigest()
        out["manifest_sha256"] = h
    return out


def _materialize(name: str, tmp: Path) -> dict:
    """Build a scenario's state files by overriding the GREEN baseline, and
    return the `paths` override for live_status(). Absent sources point at a
    guaranteed-nonexistent path so the reader exercises its real missing branch."""
    scn = _SCENARIOS[name]
    tmp.mkdir(parents=True, exist_ok=True)
    files = scn.get("files", {})
    nonexist = tmp / "__absent__"

    # Effective content = baseline merged with the scenario's overrides.
    eff = dict(_BASELINE)
    for k, v in files.items():
        eff[k] = v
    # news age: scenario key wins; else baseline.
    news_age = scn["news_age_sec"] if "news_age_sec" in scn else _BASELINE["news_age_sec"]

    paths = {k: nonexist for k in _SRC_KEYS}
    paths["manifest"] = None  # use the stamp path, not the direct override

    # ── producer state files ────────────────────────────────────────────
    for key in ("alarm", "watchdog", "supervisor", "ftmo", "ddguard", "contract"):
        content = eff.get(key)
        if content in _ABSENT or key not in eff:
            paths[key] = tmp / f"absent_{key}.json"
            continue
        fp = tmp / f"{key}.json"
        _write_json(fp, content)
        paths[key] = fp

    # ── manifest + deploy stamp ─────────────────────────────────────────
    manifest_content = eff.get("manifest_file")
    manifest_path = None
    if manifest_content not in _ABSENT:
        manifest_path = tmp / "manifest.json"
        _write_json(manifest_path, manifest_content)

    # direct manifest override (only if the scenario asks for it)
    if "manifest" in files and files["manifest"] not in _ABSENT:
        mo = tmp / "manifest_override.json"
        _write_json(mo, files["manifest"])
        paths["manifest"] = mo

    for pkey in ("deploy_pointer", "deploy_default"):
        content = eff.get(pkey)
        if content in _ABSENT:
            paths[pkey] = tmp / f"absent_{pkey}.json"
            continue
        if isinstance(content, dict) and manifest_path is not None:
            content = _resolve_stamp_sentinels(content, manifest_path)
        elif isinstance(content, dict) and content.get("manifest_path") == "__manifest__":
            # no manifest materialized => leave pointer effectively broken
            content = dict(content)
            content["manifest_path"] = str(tmp / "absent_manifest.json")
        fp = tmp / f"{pkey}.json"
        _write_json(fp, content)
        paths[pkey] = fp

    # ── news (mtime-based) ──────────────────────────────────────────────
    if news_age is not None:
        nf = tmp / "news.csv"
        nf.write_text("date,event\n", encoding="utf-8")
        mt = _FIXED_NOW.timestamp() - news_age
        os.utime(nf, (mt, mt))
        paths["news"] = nf
    else:
        paths["news"] = tmp / "absent_news.csv"
    return paths


def _lamp(status: dict, key: str) -> dict:
    return next(l for l in status["lamps"] if l["key"] == key)


@pytest.mark.parametrize("name", list(_SCENARIOS))
def test_scenario_outcomes(name, tmp_path):
    paths = _materialize(name, tmp_path)
    st = mb.live_status(paths=paths, now=_FIXED_NOW)
    exp = _SCENARIOS[name]["expect"]

    if "overall" in exp:
        assert st["overall"] == exp["overall"], f"{name}: overall {st['overall']}"
    if "overall_in" in exp:
        assert st["overall"] in exp["overall_in"], f"{name}: overall {st['overall']}"
    if "overall_not" in exp:
        assert st["overall"] != exp["overall_not"], f"{name}: overall must not be {exp['overall_not']}"

    if "expected_sleeves" in exp:
        assert st["expected_sleeves"] == exp["expected_sleeves"], f"{name}: sleeves {st['expected_sleeves']}"
    if exp.get("expected_sleeves_null"):
        assert st["expected_sleeves"] is None, f"{name}: sleeves {st['expected_sleeves']}"
    if "account" in exp:
        assert st["account"] == exp["account"]

    for lamp_key, level_key in (("watchdog", "watchdog_level"), ("ftmo", "ftmo_level"),
                                ("contract", "contract_level"), ("news", "news_level"),
                                ("deploy", "deploy_level")):
        if level_key in exp:
            assert _lamp(st, lamp_key)["level"] == exp[level_key], \
                f"{name}:{lamp_key} = {_lamp(st, lamp_key)['level']} (detail: {_lamp(st, lamp_key)['detail']})"
    if "watchdog_value" in exp:
        assert _lamp(st, "watchdog")["value"] == exp["watchdog_value"], f"{name}: {_lamp(st, 'watchdog')['value']}"
    if "contract_value" in exp:
        assert _lamp(st, "contract")["value"] == exp["contract_value"]

    if "ftmo_prose_has" in exp:
        assert exp["ftmo_prose_has"] in st["ftmo_prose"], f"{name}: {st['ftmo_prose']}"
    if "ftmo_prose_hasnot" in exp:
        assert exp["ftmo_prose_hasnot"] not in st["ftmo_prose"]
    if "subject_reason_has" in exp:
        assert exp["subject_reason_has"] in st["subject_reason"], f"{name}: {st['subject_reason']}"

    # subject wiring — a non-green live condition must reach the subject line.
    data = _full_data(st)
    subject = mb.build_subject(data)
    if "subject_has" in exp:
        assert exp["subject_has"] in subject, subject
    if st["overall"] != mb.L_GREEN:
        assert f"LIVE {st['overall']}" in subject


# ── verbatim producer-output conformance ────────────────────────────────
# These load the ACTUAL bytes the producers emit (WS-E1 samples copied verbatim
# from wse1/samples/*; WS-E3 states derived from wse3/live_run_state.json with
# the exact producer schema). `now` is set relative to each file's own stamp so
# the file is fresh, proving a valid producer file renders GREEN/RED by content.

# (filename, path_key to inject the producer file, lamp_key to assert, expected level)
_PRODUCER_CASES = [
    ("wse1_alarm_all_ok.json", "alarm", "watchdog", mb.L_GREEN),
    ("wse1_alarm_tlive_missing.json", "alarm", "watchdog", mb.L_RED),
    ("wse1_alarm_both_missing.json", "alarm", "watchdog", mb.L_RED),
    ("wse1_alarm_maintenance.json", "alarm", "watchdog", mb.L_AMBER),
    ("wse3_deployment_contract_red.json", "contract", "contract", mb.L_RED),
    ("wse3_deployment_contract_green.json", "contract", "contract", mb.L_GREEN),
]


def _now_for_sample(obj: dict) -> dt.datetime:
    ts = obj.get("generated_utc") or obj.get("ts") or obj.get("checked_at_utc")
    d = mb._parse_utc(ts)
    return d + dt.timedelta(seconds=45)  # 45s later => fresh for every SLA


@pytest.mark.parametrize("fname,path_key,lamp_key,expect_level", _PRODUCER_CASES)
def test_producer_samples_conformance(fname, path_key, lamp_key, expect_level, tmp_path):
    """A verbatim producer file renders its lamp GREEN/RED by content."""
    src = SAMPLES / fname
    obj = json.loads(src.read_text(encoding="utf-8"))
    now = _now_for_sample(obj)
    # inject the real producer file at its OWN source key; everything else absent
    # (so we assert on that lamp specifically, not the aggregate).
    nonexist = tmp_path / "nope"
    paths = {k: nonexist for k in _SRC_KEYS}
    paths["manifest"] = None
    paths[path_key] = src
    st = mb.live_status(paths=paths, now=now)
    got = _lamp(st, lamp_key)
    assert got["level"] == expect_level, \
        f"{fname}: {lamp_key} level={got['level']} detail={got['detail']}"


def test_e1_alarm_preferred_over_fallback(tmp_path):
    """When both the E1 alarm file and the shipped watchdog file exist, the E1
    alarm contract wins (label mentions E1)."""
    alarm = json.loads((SAMPLES / "wse1_alarm_all_ok.json").read_text(encoding="utf-8"))
    now = _now_for_sample(alarm)
    af = tmp_path / "alarm.json"
    af.write_text(json.dumps(alarm), encoding="utf-8")
    wf = tmp_path / "wd.json"
    wf.write_text(json.dumps({"ts": alarm["generated_utc"], "status": "critical",
                              "dxz_running": False, "ftmo_running": False}), encoding="utf-8")
    nonexist = tmp_path / "nope"
    paths = {k: nonexist for k in _SRC_KEYS}
    paths["manifest"] = None
    paths["alarm"] = af
    paths["watchdog"] = wf
    st = mb.live_status(paths=paths, now=now)
    wd = _lamp(st, "watchdog")
    assert "E1" in wd["label"], wd["label"]
    assert wd["level"] == mb.L_GREEN  # alarm says healthy; the critical fallback is ignored


def test_never_green_by_absence(tmp_path):
    """Every source missing => the lamp cannot be green."""
    nonexist = tmp_path / "nothing"
    paths = {k: nonexist for k in _SRC_KEYS}
    paths["manifest"] = None
    st = mb.live_status(paths=paths, now=_FIXED_NOW)
    assert st["overall"] != mb.L_GREEN
    assert st["expected_sleeves"] is None
    assert _lamp(st, "news")["level"] == mb.L_RED  # news missing = hard RED


def test_determinism(tmp_path):
    """Same (paths, now) => byte-identical status + subject + HTML + text."""
    paths = _materialize("green", tmp_path)
    a = mb.live_status(paths=paths, now=_FIXED_NOW)
    b = mb.live_status(paths=paths, now=_FIXED_NOW)
    assert json.dumps(a, sort_keys=True) == json.dumps(b, sort_keys=True)
    da, db = _full_data(a), _full_data(b)
    assert mb.build_subject(da) == mb.build_subject(db)
    assert mb.render_html(da) == mb.render_html(db)
    assert mb.render_text(da) == mb.render_text(db)


def test_default_sources_never_touch_tlive():
    """Structural guard: no default live-status source resolves under T_Live,
    and none is an MT5 process handle — the lamp is state-file only."""
    defaults = mb._resolve_paths(None)
    for key, p in defaults.items():
        if p is None:
            continue
        s = str(p).lower()
        assert "t_live" not in s, f"{key} -> {p} points under T_Live"
        assert "terminal64" not in s


def test_full_render_red_reaches_top_summary(tmp_path):
    """A red live condition is present in the rendered HTML + text bodies."""
    paths = _materialize("red_ddguard", tmp_path)
    st = mb.live_status(paths=paths, now=_FIXED_NOW)
    data = _full_data(st)
    html = mb.render_html(data)
    text = mb.render_text(data)
    assert "Live-Ampel" in html
    assert "ROT" in html and "DD-Guard" in html
    assert "0) LIVE-AMPEL: ROT" in text
    assert "DD-Guard" in text


def test_deploy_authenticated_flag(tmp_path):
    """The green baseline authenticates the signed stamp; unsigned does not."""
    st_ok = mb.live_status(paths=_materialize("green", tmp_path / "a"), now=_FIXED_NOW)
    assert st_ok["deploy_authenticated"] is True
    st_bad = mb.live_status(paths=_materialize("deploy_unsigned_amber", tmp_path / "b"), now=_FIXED_NOW)
    assert st_bad["deploy_authenticated"] is False


# ── fail-closed contract: Codex round-3 hostile semantic-invalid cases ──────
# These reproduce the THREE hostile inputs from
# docs/ops/evidence/2026-07-26_codex_review_round3.md ("WSE22 — fail-closed
# contract is still violated") VERBATIM. Round-2 rendered all three green; each
# must now be non-green (UNKNOWN/RED), because a producer file that does not carry
# its REQUIRED schema cannot be interpreted as a healthy live money book.

def _inject(tmp_path, **overrides):
    """Build a paths dict with every source ABSENT, then apply overrides
    (path_key -> filesystem path)."""
    nonexist = tmp_path / "nope"
    paths = {k: nonexist for k in _SRC_KEYS}
    paths["manifest"] = None
    paths.update(overrides)
    return paths


def test_hostile_e1_schema_incomplete_is_not_green(tmp_path):
    """Codex case 1 VERBATIM: {"watchdog_status":"healthy","sessions":{}} — no
    generated_utc, no required session blocks. Must render UNKNOWN, never GRÜN."""
    f = tmp_path / "alarm.json"
    f.write_text(json.dumps({"watchdog_status": "healthy", "sessions": {}}), encoding="utf-8")
    st = mb.live_status(paths=_inject(tmp_path, alarm=f), now=_FIXED_NOW)
    wd = _lamp(st, "watchdog")
    assert wd["level"] in (mb.L_UNKNOWN, mb.L_RED), f"watchdog={wd['level']} detail={wd['detail']}"
    assert wd["level"] != mb.L_GREEN
    assert st["overall"] != mb.L_GREEN


def test_hostile_e3_schema_incomplete_is_not_green(tmp_path):
    """Codex case 2 VERBATIM: {"overall_status":"GREEN","disk_profile":{...}} — no
    generated_utc/summary/runtime/findings. Must render UNKNOWN, never GRÜN 24/24."""
    f = tmp_path / "contract.json"
    f.write_text(json.dumps({"overall_status": "GREEN",
                             "disk_profile": {"expected_present_ok": 24, "expected_missing": 0}}),
                 encoding="utf-8")
    st = mb.live_status(paths=_inject(tmp_path, contract=f), now=_FIXED_NOW)
    ct = _lamp(st, "contract")
    assert ct["level"] in (mb.L_UNKNOWN, mb.L_RED), f"contract={ct['level']} detail={ct['detail']}"
    assert ct["level"] != mb.L_GREEN
    assert ct["value"] != "24/24"
    assert st["overall"] != mb.L_GREEN


def test_hostile_unbindable_account_never_authenticates_green(tmp_path):
    """Codex case 3 VERBATIM: a signed stamp with matching manifest SHA, but a
    manifest whose book is just "DXZ" (no bindable account). Must NOT authenticate
    green — the expected_account cannot be corroborated against the manifest."""
    man = tmp_path / "manifest.json"
    man.write_text(json.dumps({"book": "DXZ", "status": "LIVE", "n_sleeves": 24, "sleeves": []}),
                   encoding="utf-8")
    sha = hashlib.sha256(man.read_bytes()).hexdigest()
    ptr = tmp_path / "pointer.json"
    ptr.write_text(json.dumps({
        "manifest_path": str(man), "manifest_sha256": sha, "signed": True,
        "approved_by": "OWNER (Fabian) 2026-07-25", "deployment_epoch_utc": "2026-07-25T20:00:00Z",
        "expected_account": "4000090541", "expected_phase": "DXZ_LIVE"}), encoding="utf-8")
    st = mb.live_status(paths=_inject(tmp_path, deploy_pointer=ptr), now=_FIXED_NOW)
    dep = _lamp(st, "deploy")
    assert dep["level"] != mb.L_GREEN, f"deploy={dep['level']} detail={dep['detail']}"
    assert dep["level"] in (mb.L_UNKNOWN, mb.L_RED)
    assert st["deploy_authenticated"] is False
    assert st["account"] is None  # manifest carried no bindable account
    assert st["overall"] != mb.L_GREEN


# ── schema-required-field negative tests ────────────────────────────────────
# Systematically drop each REQUIRED field from an otherwise-valid, otherwise-GREEN
# producer object; the corresponding lamp must never stay green. Proves the
# validation is field-complete, not just tuned to the three hostile examples.

_VALID_E1 = {
    "schema_version": 1, "generated_utc": "2026-07-26T07:59:30Z", "author": "T_Live_Watchdog",
    "watchdog_status": "healthy", "maintenance": False, "reboot_suppressed": False, "any_alarm": False,
    "sessions": {
        "T_LIVE": {"session": "T_LIVE", "condition": "ok", "detail": "terminal_running", "alarm": False},
        "FTMO": {"session": "FTMO", "condition": "ok", "detail": "terminal_running", "alarm": False}}}

# (mutation label, mutator) — each makes _VALID_E1 schema-invalid.
_E1_NEG = [
    ("no_generated_utc", lambda d: d.pop("generated_utc")),
    ("empty_generated_utc", lambda d: d.update(generated_utc="")),
    ("bad_generated_utc", lambda d: d.update(generated_utc="not-a-timestamp")),
    ("no_watchdog_status", lambda d: d.pop("watchdog_status")),
    ("no_sessions", lambda d: d.pop("sessions")),
    ("sessions_not_dict", lambda d: d.update(sessions=[])),
    ("empty_sessions", lambda d: d.update(sessions={})),
    ("missing_tlive_session", lambda d: d["sessions"].pop("T_LIVE")),
    ("missing_ftmo_session", lambda d: d["sessions"].pop("FTMO")),
    ("tlive_no_condition", lambda d: d["sessions"]["T_LIVE"].pop("condition")),
    ("ftmo_empty_condition", lambda d: d["sessions"]["FTMO"].update(condition="")),
]


@pytest.mark.parametrize("label,mut", _E1_NEG, ids=[x[0] for x in _E1_NEG])
def test_e1_required_field_negative(label, mut, tmp_path):
    import copy
    obj = copy.deepcopy(_VALID_E1)
    mut(obj)
    f = tmp_path / "alarm.json"
    f.write_text(json.dumps(obj), encoding="utf-8")
    st = mb.live_status(paths=_inject(tmp_path, alarm=f), now=_FIXED_NOW)
    wd = _lamp(st, "watchdog")
    assert wd["level"] != mb.L_GREEN, f"{label}: watchdog stayed green ({wd['detail']})"


def test_e1_required_field_positive(tmp_path):
    """Control: the unmutated _VALID_E1 renders GRÜN by content (schema is not
    over-strict — it only rejects genuinely incomplete producers)."""
    f = tmp_path / "alarm.json"
    f.write_text(json.dumps(_VALID_E1), encoding="utf-8")
    now = mb._parse_utc("2026-07-26T08:00:00Z")
    st = mb.live_status(paths=_inject(tmp_path, alarm=f), now=now)
    assert _lamp(st, "watchdog")["level"] == mb.L_GREEN


_VALID_E3 = {
    "tool": "verify_live_deployment_contract", "version": "1.0",
    "generated_utc": "2026-07-26T07:59:00+00:00", "trigger": "periodic", "overall_status": "GREEN",
    "disk_profile": {"status": "GREEN", "expected_present_ok": 24, "expected_missing": 0},
    "runtime": {"status": "GREEN", "n_logs_indexed": 24, "sleeves": []},
    "findings": [], "summary": {"critical": 0, "warn": 0, "info": 0, "headline": "GREEN; disk 24/24 ok"}}

_E3_NEG = [
    ("no_generated_utc", lambda d: d.pop("generated_utc")),
    ("bad_generated_utc", lambda d: d.update(generated_utc="nope")),
    ("no_overall_status", lambda d: d.pop("overall_status")),
    ("empty_overall_status", lambda d: d.update(overall_status="")),
    ("no_summary", lambda d: d.pop("summary")),
    ("summary_not_dict", lambda d: d.update(summary="green")),
    ("no_disk_profile", lambda d: d.pop("disk_profile")),
    ("no_runtime", lambda d: d.pop("runtime")),
    ("no_findings", lambda d: d.pop("findings")),
    ("findings_not_list", lambda d: d.update(findings={})),
]


@pytest.mark.parametrize("label,mut", _E3_NEG, ids=[x[0] for x in _E3_NEG])
def test_e3_required_field_negative(label, mut, tmp_path):
    import copy
    obj = copy.deepcopy(_VALID_E3)
    mut(obj)
    f = tmp_path / "contract.json"
    f.write_text(json.dumps(obj), encoding="utf-8")
    st = mb.live_status(paths=_inject(tmp_path, contract=f), now=_FIXED_NOW)
    ct = _lamp(st, "contract")
    assert ct["level"] != mb.L_GREEN, f"{label}: contract stayed green ({ct['detail']})"


def test_e3_required_field_positive(tmp_path):
    """Control: the unmutated _VALID_E3 renders GRÜN by content."""
    f = tmp_path / "contract.json"
    f.write_text(json.dumps(_VALID_E3), encoding="utf-8")
    now = mb._parse_utc("2026-07-26T08:00:00Z")
    st = mb.live_status(paths=_inject(tmp_path, contract=f), now=now)
    assert _lamp(st, "contract")["level"] == mb.L_GREEN


def test_deploy_unbindable_account_direct_authenticate():
    """Unit-level guard on _authenticate_deploy: a signed, SHA-matched stamp over
    a manifest with no bindable account must not return GREEN."""
    # book with digits binds; book without digits does not.
    man_ok = {"book": "DXZ_4000090541", "status": "LIVE"}
    man_bad = {"book": "DXZ", "status": "LIVE"}
    stamp = {"signed": True, "approved_by": "OWNER", "manifest_sha256": None,
             "deployment_epoch_utc": "2026-07-25T20:00:00Z",
             "expected_account": "4000090541", "expected_phase": "DXZ_LIVE"}
    # Unbindable manifest => never green (UNKNOWN), regardless of the stamp.
    lvl_bad, notes_bad = mb._authenticate_deploy(stamp, "runtime_stamp", None, man_bad)
    assert lvl_bad != mb.L_GREEN
    assert any("bindbaren Account" in n for n in notes_bad), notes_bad
    # Bindable + matching account is not blocked by the account check specifically
    # (other missing fields like the SHA still degrade it, but not to UNKNOWN-for-
    # account): the account note must be absent.
    _, notes_ok = mb._authenticate_deploy(stamp, "runtime_stamp", None, man_ok)
    assert not any("bindbaren Account" in n for n in notes_ok), notes_ok


# ── minimal full-data stub so the renderers exercise real code paths ────────

def _full_data(live: dict) -> dict:
    return {
        "live": live,
        "night": {"equity": 100000.0, "equity_ts": "2026-07-26T00:00:00",
                  "delta_prev": 0.0, "ea_logs_today": 24, "ea_logs_total": 24,
                  "deals": 0, "err_lines": 0, "journal_date": "20260726",
                  "journal_age_sec": 3600},
        "since": "2026-07-25T18:00",
        "frontier": {"fresh_pass": [], "in_flight": [], "fresh_count": 0, "inflight_count": 0},
        "factory": {"color": mb.EMERALD, "label": "GRÜN", "workers": 10,
                    "d_free": 200.0, "infra": 0.0, "reason": "10/10 Worker."},
        "actions": [],
        "quota": {"claude": {"week_pct": 40}, "codex": {"week_pct": 50}},
        "heartbeats": [],
        "now_local": "2026-07-26 06:00",
        "tz": "W. Europe",
        "date_h": "So 26.07.2026",
        "date_iso": "2026-07-26",
    }
