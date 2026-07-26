#!/usr/bin/env python3
"""Fixtures + tests for verify_live_deployment_contract (WS-E3, ULTRACODE).

Self-contained: every fixture is generated on the fly (synthetic profile dir,
event-log dir, account snapshot, common.ini, signed manifest). No live paths are
touched. The `.chr`/common.ini grammar is parsed by the SHARED module
``tools/strategy_farm/liveops_profile_contract.ps1`` (the same one the two
PowerShell verifiers dot-source), so these tests exercise the real parser, not a
Python copy. Each scenario asserts the overall verdict and the presence/absence
of specific finding categories, exercising both truth layers independently.

Scenarios (Codex WS-E3 acceptance list + defect/identity mirrors):
  exact                        -> GREEN  (fully-bound SIGNED manifest)
  stale_profile                -> AMBER  (disk ok, all runtime stale)
  wrong_magic                  -> RED    (WRONG_MAGIC)
  wrong_binary                 -> RED    (WRONG_BINARY)
  duplicate_chart              -> RED    (DUPLICATE_CHART)
  orphan_chart                 -> RED    (ORPHAN_CHART)
  missing_monitor              -> RED    (MISSING_MONITOR)
  duplicate_monitor            -> RED    (DUPLICATE_MONITOR)
  profile_correct_runtime_stale-> RED    (disk GREEN, one sleeve RUNTIME_DETACHED)
  missing_chart                -> RED    (MISSING_CHART + UNPARSEABLE_CHART; mirrors 12778)
  identity_unknown             -> AMBER  (DRAFT/unsigned manifest with no server/epoch/
                                          ex5_sha256 -> explicit UNKNOWN, never a silent pass)

Run as a test:      python -m pytest tools/strategy_farm/tests/test_verify_live_deployment_contract.py
Materialize evidence: python tools/strategy_farm/tests/test_verify_live_deployment_contract.py --materialize <outdir>
"""

from __future__ import annotations

import datetime as _dt
import hashlib
import json
import os
import sys

_THIS = os.path.dirname(os.path.abspath(__file__))
_MODDIR = os.path.dirname(_THIS)
if _MODDIR not in sys.path:
    sys.path.insert(0, _MODDIR)

import verify_live_deployment_contract as V  # noqa: E402


# ---------------------------------------------------------------------------
# Fixture primitives.
# ---------------------------------------------------------------------------
def _iso(dt: _dt.datetime) -> str:
    return dt.astimezone(_dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")


_TF_PERIOD = {"H1": ("1", "1"), "H4": ("1", "4"), "D1": ("1", "24"),
              "M5": ("0", "5"), "M30": ("0", "30")}


def _base_symbol(sym: str) -> str:
    for suf in (".DWX", ".cash"):
        if sym.upper().endswith(suf.upper()):
            return sym[: -len(suf)]
    return sym


def write_chart(path: str, *, symbol: str, tf: str, ea_id: int, slot: int,
                ea_name: str, risk_percent: float, risk_fixed: str = "0",
                expertmode: str = "1", encoding: str = "utf-16-le") -> None:
    pt, ps = _TF_PERIOD[tf]
    lines = [
        "<chart>",
        "id=133029748223610000",
        "symbol=%s" % _base_symbol(symbol),
        "description=fixture",
        "period_type=%s" % pt,
        "period_size=%s" % ps,
        "<expert>",
        "name=%s" % ea_name,
        "path=Experts\\Live EAs\\%s.ex5" % ea_name,
        "expertmode=%s" % expertmode,
        "<inputs>",
        "qm_ea_id=%d" % ea_id,
        "qm_magic_slot_offset=%d" % slot,
        "RISK_PERCENT=%s" % risk_percent,
        "RISK_FIXED=%s" % risk_fixed,
        "PORTFOLIO_WEIGHT=1.0",
        "qm_risk_cap_pct=1.0",
        "</inputs>",
        "</expert>",
        "</chart>",
        "",
    ]
    text = "\r\n".join(lines)
    _write_encoded(path, text, encoding)


def write_monitor_chart(path: str, monitor_name: str = "QM_AccountMonitor",
                        encoding: str = "utf-16-le") -> None:
    lines = [
        "<chart>", "id=999", "symbol=EURUSD", "period_type=1", "period_size=1",
        "<expert>",
        "name=%s" % monitor_name,
        "path=Experts\\%s.ex5" % monitor_name,
        "expertmode=1",
        "<inputs>",
        "InpTimerSeconds=60",
        "</inputs>",
        "</expert>", "</chart>", "",
    ]
    _write_encoded(path, "\r\n".join(lines), encoding)


def _write_encoded(path: str, text: str, encoding: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if encoding == "utf-16-le":
        data = b"\xff\xfe" + text.encode("utf-16-le")
    elif encoding == "utf-8-sig":
        data = text.encode("utf-8-sig")
    else:
        data = text.encode(encoding)
    with open(path, "wb") as fh:
        fh.write(data)


def write_binary(path: str, content: bytes) -> str:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(content)
    return hashlib.sha256(content).hexdigest().upper()


def write_event_log(path: str, *, ea_id: int, magic: int, symbol: str, tf: str,
                    init_ok_dt, deinit_dt=None) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    base = _base_symbol(symbol)
    rows = []

    def row(dt, ev, payload=None):
        return json.dumps({"ts_utc": _iso(dt), "ea_id": ea_id, "slug": "ea-%d" % ea_id,
                           "symbol": base, "tf": tf, "magic": magic, "event": ev,
                           "payload": payload or {}})
    if init_ok_dt is not None:
        rows.append(row(init_ok_dt - _dt.timedelta(seconds=1), "INIT",
                        {"magic": magic, "symbol": base}))
        rows.append(row(init_ok_dt, "INIT_OK"))
    if deinit_dt is not None:
        rows.append(row(deinit_dt, "DEINIT", {"reason": 9}))
    mode = "a" if os.path.exists(path) else "w"
    with open(path, mode, encoding="utf-8") as fh:
        for r in rows:
            fh.write(r + "\n")


def write_account_snapshot(path: str, account: int, hb_dt) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        json.dump({"account_login": account, "currency": "USD", "time_utc": _iso(hb_dt),
                   "equity": 100000.0, "balance": 100000.0, "write_ok": True}, fh)


def write_common_ini(path: str, login: str, server: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    text = "\r\n[Common]\r\nLogin=%s\r\nServer=%s\r\n" % (login, server)
    with open(path, "wb") as fh:
        fh.write(b"\xff\xfe" + text.encode("utf-16-le"))


# ---------------------------------------------------------------------------
# The 3-sleeve reference book used by every fixture.
# ---------------------------------------------------------------------------
BOOK = [
    dict(ea_id=101, slot=0, magic=1010000, symbol="EURUSD.DWX", ea_name="QM5_101_alpha",
         tf="H1", risk=0.5, binary=b"binaryAAA"),
    dict(ea_id=202, slot=1, magic=2020001, symbol="XAUUSD.DWX", ea_name="QM5_202_beta",
         tf="D1", risk=1.0, binary=b"binaryBBB"),
    dict(ea_id=303, slot=2, magic=3030002, symbol="GDAXI.DWX", ea_name="QM5_303_gamma",
         tf="M5", risk=0.25, binary=b"binaryCCC"),
]
ACCOUNT = "4000090541"
SERVER = "Darwinex-Live"


def build_fixture(case: str, root: str) -> list:
    """Materialize one fixture under `root` and return the argv list for the tool."""
    now = _dt.datetime.now(_dt.timezone.utc)
    fresh = now - _dt.timedelta(minutes=2)
    stale = now - _dt.timedelta(hours=48)
    yesterday_deinit = now - _dt.timedelta(hours=6)
    # deployment epoch: older than a fresh attach, newer than a stale one.
    epoch = now - _dt.timedelta(hours=3)

    prof = os.path.join(root, "MQL5", "Profiles", "Charts", "LiveOps")
    experts = os.path.join(root, "MQL5", "Experts", "Live EAs")
    events = os.path.join(root, "MQL5", "Files", "QM")
    snap = os.path.join(events, "journal", "account_snapshot.json")
    common = os.path.join(root, "config", "common.ini")
    manifest_path = os.path.join(root, "manifest.json")

    os.makedirs(prof, exist_ok=True)
    # deployed binaries + true SHAs
    sha = {}
    for s in BOOK:
        content = s["binary"]
        if case == "wrong_binary" and s["ea_id"] == 101:
            deployed = content + b"_TAMPERED"
        else:
            deployed = content
        write_binary(os.path.join(experts, "%s.ex5" % s["ea_name"]), deployed)
        sha[s["ea_id"]] = hashlib.sha256(content).hexdigest().upper()  # manifest pins ORIGINAL

    # Default manifest: FULLY BOUND + SIGNED (so `exact` is GREEN). The
    # identity_unknown case deliberately strips the binding fields below.
    sleeves = [dict(ea_id=s["ea_id"], ea_label=s["ea_name"], symbol=s["symbol"],
                    magic_number=s["magic"], risk_percent=s["risk"], timeframe=s["tf"],
                    ex5_path=os.path.join(experts, "%s.ex5" % s["ea_name"]),
                    ex5_sha256=sha[s["ea_id"]]) for s in BOOK]
    if case == "identity_unknown":
        # DRAFT/unsigned; no expected_server, no deployment_epoch, no per-sleeve
        # ex5_sha256 -> each must surface as an explicit UNKNOWN, never a silent pass.
        for sl in sleeves:
            sl.pop("ex5_sha256", None)
        manifest = {
            "book": "FIXTURE_%s" % ACCOUNT,  # account still derivable from book digits
            "status": "DRAFT",
            "sleeves": sleeves,
        }
    else:
        manifest = {
            "book": "FIXTURE_%s" % ACCOUNT,
            "status": "LIVE",
            "signed": True,
            "approved_by": "OWNER (fixture) 2026-07-26",
            "expected_account": ACCOUNT,
            "expected_server": SERVER,
            "deployment_epoch": _iso(epoch),
            "sleeves": sleeves,
        }
    with open(manifest_path, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)

    write_common_ini(common, ACCOUNT, SERVER)
    write_account_snapshot(snap, int(ACCOUNT), fresh)

    def chart_path(idx):
        return os.path.join(prof, "chart%02d.chr" % idx)

    for i, s in enumerate(BOOK, start=1):
        write_chart(chart_path(i), symbol=s["symbol"], tf=s["tf"], ea_id=s["ea_id"],
                    slot=s["slot"], ea_name=s["ea_name"], risk_percent=s["risk"])
    write_monitor_chart(chart_path(len(BOOK) + 1))  # chart04 = monitor

    def emit_runtime(s, init_ok, deinit=None):
        write_event_log(os.path.join(events, "QM5_%d_ea-%d.log" % (s["ea_id"], s["ea_id"])),
                        ea_id=s["ea_id"], magic=s["magic"], symbol=s["symbol"], tf=s["tf"],
                        init_ok_dt=init_ok, deinit_dt=deinit)

    runtime_plan = {s["ea_id"]: (fresh, None) for s in BOOK}

    # ---- case mutations ----
    if case in ("exact", "identity_unknown"):
        pass
    elif case == "stale_profile":
        runtime_plan = {s["ea_id"]: (stale, None) for s in BOOK}  # all attached-stale
    elif case == "wrong_magic":
        write_chart(chart_path(2), symbol=BOOK[1]["symbol"], tf=BOOK[1]["tf"],
                    ea_id=202, slot=9, ea_name=BOOK[1]["ea_name"], risk_percent=BOOK[1]["risk"])
    elif case == "wrong_binary":
        pass  # deployed 101 binary already tampered above
    elif case == "duplicate_chart":
        write_chart(chart_path(5), symbol=BOOK[2]["symbol"], tf=BOOK[2]["tf"],
                    ea_id=303, slot=2, ea_name=BOOK[2]["ea_name"], risk_percent=BOOK[2]["risk"])
    elif case == "orphan_chart":
        write_chart(chart_path(5), symbol="NZDUSD.DWX", tf="H1", ea_id=999, slot=0,
                    ea_name="QM5_999_orphan", risk_percent=0.3)
    elif case == "missing_monitor":
        os.remove(chart_path(len(BOOK) + 1))
    elif case == "duplicate_monitor":
        write_monitor_chart(chart_path(len(BOOK) + 2))  # second monitor
    elif case == "profile_correct_runtime_stale":
        runtime_plan[303] = (now - _dt.timedelta(hours=8), yesterday_deinit)
    elif case == "missing_chart":
        open(chart_path(3), "wb").close()  # 0-byte truncation, mirrors live 12778
        runtime_plan[303] = (now - _dt.timedelta(hours=8), yesterday_deinit)
    else:
        raise ValueError("unknown case %s" % case)

    for s in BOOK:
        io, de = runtime_plan[s["ea_id"]]
        emit_runtime(s, io, de)

    return [
        "--manifest", manifest_path,
        "--profile-dir", prof,
        "--event-log-dir", events,
        "--account-snapshot", snap,
        "--common-ini", common,
        "--monitor-name", "QM_AccountMonitor",
        "--freshness-hours", "24",
        "--trigger", "post_recovery",
    ]


EXPECT = {
    "exact": ("GREEN", {"present": [], "absent": ["MISSING_CHART", "DUPLICATE_CHART",
                                                  "ORPHAN_CHART", "WRONG_BINARY", "WRONG_MAGIC",
                                                  "RUNTIME_DETACHED", "MISSING_MONITOR",
                                                  "SERVER_EXPECTATION_UNKNOWN",
                                                  "DEPLOYMENT_EPOCH_UNKNOWN",
                                                  "BINARY_IDENTITY_UNKNOWN", "MANIFEST_UNSIGNED"]}),
    "stale_profile": ("AMBER", {"present": ["RUNTIME_STALE"], "absent": ["MISSING_CHART"]}),
    "wrong_magic": ("RED", {"present": ["WRONG_MAGIC", "MISSING_CHART"], "absent": []}),
    "wrong_binary": ("RED", {"present": ["WRONG_BINARY"], "absent": []}),
    "duplicate_chart": ("RED", {"present": ["DUPLICATE_CHART"], "absent": []}),
    "orphan_chart": ("RED", {"present": ["ORPHAN_CHART"], "absent": []}),
    "missing_monitor": ("RED", {"present": ["MISSING_MONITOR"], "absent": []}),
    "duplicate_monitor": ("RED", {"present": ["DUPLICATE_MONITOR"], "absent": []}),
    "profile_correct_runtime_stale": ("RED", {"present": ["RUNTIME_DETACHED"], "absent": []}),
    "missing_chart": ("RED", {"present": ["MISSING_CHART", "UNPARSEABLE_CHART", "RUNTIME_DETACHED"],
                              "absent": []}),
    "identity_unknown": ("AMBER", {"present": ["SERVER_EXPECTATION_UNKNOWN",
                                               "DEPLOYMENT_EPOCH_UNKNOWN",
                                               "BINARY_IDENTITY_UNKNOWN", "MANIFEST_UNSIGNED"],
                                   "absent": ["MISSING_CHART", "WRONG_BINARY", "RUNTIME_DETACHED",
                                              "ACCOUNT_MISMATCH", "SERVER_MISMATCH"]}),
}


def run_case(case: str, root: str) -> dict:
    argv = build_fixture(case, root)
    args = V.build_arg_parser().parse_args(argv)
    return V.verify(args)


def _categories(state: dict):
    return {f["category"] for f in state["findings"]}


# ---------------------------------------------------------------------------
# pytest entry points (works with or without pytest installed).
# ---------------------------------------------------------------------------
def _check(case: str, tmp: str):
    state = run_case(case, tmp)
    exp_status, exp = EXPECT[case]
    cats = _categories(state)
    assert state["overall_status"] == exp_status, (
        "%s: expected %s got %s (findings=%s)" % (case, exp_status, state["overall_status"], sorted(cats)))
    for c in exp["present"]:
        assert c in cats, "%s: expected finding %s missing (got %s)" % (case, c, sorted(cats))
    for c in exp["absent"]:
        assert c not in cats, "%s: unexpected finding %s (got %s)" % (case, c, sorted(cats))
    return state


try:
    import pytest

    @pytest.mark.parametrize("case", list(EXPECT.keys()))
    def test_case(case, tmp_path):
        _check(case, str(tmp_path))

    def test_disk_and_runtime_layers_are_separate(tmp_path):
        state = run_case("profile_correct_runtime_stale", str(tmp_path))
        assert state["disk_profile"]["status"] == "GREEN"
        assert state["runtime"]["status"] == "RED"
        assert state["overall_status"] == "RED"

    def test_missing_chart_flagged_in_both_layers(tmp_path):
        state = run_case("missing_chart", str(tmp_path))
        cats = _categories(state)
        assert {"MISSING_CHART", "UNPARSEABLE_CHART", "RUNTIME_DETACHED"} <= cats
        missing = [f for f in state["findings"] if f["category"] == "MISSING_CHART"][0]
        detached = [f for f in state["findings"] if f["category"] == "RUNTIME_DETACHED"][0]
        assert missing["magic"] == detached["magic"] == 3030002

    def test_exact_is_fully_bound(tmp_path):
        state = run_case("exact", str(tmp_path))
        ib = state["identity_binding"]
        assert ib["fully_bound"] is True
        assert ib["account"]["known"] and ib["server"]["known"] and ib["deployment_epoch"]["known"]
        assert ib["per_sleeve"]["ea_binary_sha256"]["known_count"] == 3
        assert ib["missing_fields"] == []

    def test_identity_unknown_is_explicit_not_silent(tmp_path):
        # Absent server/epoch/binary-sha and unsigned manifest must be UNKNOWN, and
        # must NOT masquerade as a match or a signed PASS.
        state = run_case("identity_unknown", str(tmp_path))
        ib = state["identity_binding"]
        assert ib["fully_bound"] is False
        assert ib["server"]["known"] is False
        assert ib["deployment_epoch"]["known"] is False
        assert state["identity"]["config_server_match"] is None  # UNKNOWN, not True
        want = {"expected_server", "deployment_epoch", "ex5_sha256", "signed/approved_by/signature"}
        assert want <= {m["field"] for m in ib["missing_fields"]}

    def test_e2_consumer_schema_present(tmp_path):
        # WS-E2 live_chart_inventory.json contract fields must exist and be sane.
        state = run_case("exact", str(tmp_path))
        for k in ("checked_at_utc", "status", "expected_charts", "matched", "mismatches",
                  "schema_version"):
            assert k in state, "missing WS-E2 consumer key %s" % k
        assert state["status"] == "ok"
        assert state["expected_charts"] == 3
        assert state["matched"] == 3
        assert state["mismatches"] == []

    def test_deploy_stamp_contract_lists_missing_fields(tmp_path):
        state = run_case("identity_unknown", str(tmp_path))
        md = V.render_deploy_stamp_contract(state)
        assert "Fields tonight's deploy stamp MUST add" in md
        assert "expected_server" in md and "deployment_epoch" in md and "ex5_sha256" in md

except ImportError:  # pragma: no cover - pytest not available
    pass


# ---------------------------------------------------------------------------
# CLI: run all checks (returns nonzero on failure) and optionally materialize
# fixtures + reports to an evidence dir.
# ---------------------------------------------------------------------------
def _main(argv=None):
    import argparse
    import tempfile
    p = argparse.ArgumentParser()
    p.add_argument("--materialize", default=None,
                   help="write fixtures + per-case reports under this dir (evidence)")
    a = p.parse_args(argv)

    failures = []
    lines = []
    outroot = a.materialize
    for case in EXPECT:
        if outroot:
            croot = os.path.join(outroot, case)
            os.makedirs(croot, exist_ok=True)
        else:
            croot = tempfile.mkdtemp(prefix="wse3_%s_" % case)
        try:
            state = _check(case, croot)
            status = state["overall_status"]
            cats = sorted(_categories(state))
            lines.append("PASS  %-30s -> %-5s  findings=%s" % (case, status, cats))
            if outroot:
                with open(os.path.join(croot, "state.json"), "w", encoding="utf-8") as fh:
                    json.dump(state, fh, indent=2)
                with open(os.path.join(croot, "report.md"), "w", encoding="utf-8") as fh:
                    fh.write(V.render_report(state))
        except AssertionError as exc:
            failures.append(str(exc))
            lines.append("FAIL  %-30s -> %s" % (case, exc))
    out = "\n".join(lines)
    print(out)
    print("\n%d/%d cases passed" % (len(EXPECT) - len(failures), len(EXPECT)))
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(_main())
