#!/usr/bin/env python3
"""Tests for the live-deployment POINTER binding in verify_live_deployment_contract
(WS-E3 G5).

verify's --manifest carries no expected_server / expected_phase / deployment_epoch
/ binary fingerprint, so those read UNKNOWN. An OWNER-SIGNED runtime deploy pointer
carries them. These tests prove the pointer resolves those fields to VERIFIED ONLY
when it authenticates against THIS manifest under exactly morning_brief.py's rules,
and that an unsigned / mismatching / missing pointer never turns a run green.

Scenarios:
  signed_verified   -> fields VERIFIED, UNKNOWN warnings suppressed, overall GREEN
  unsigned          -> fields UNKNOWN (reason: signed not true), warnings stay, AMBER
  sha_mismatch      -> fields MISMATCH, POINTER_MANIFEST_MISMATCH (WARN), AMBER not GREEN
  missing_pointer   -> pointer ABSENT, unchanged old behaviour
  not_applicable    -> pointer binds a different manifest, ignored, old behaviour

Plus a PARITY test asserting the shared authenticator (live_deployment_pointer_auth)
decides identically to morning_brief._authenticate_deploy across representative
inputs -- the guard that keeps the two implementations from drifting.

The profile / runtime / common.ini scaffolding reuses the primitives from
test_verify_live_deployment_contract (the same real PowerShell .chr parser).
"""

from __future__ import annotations

import datetime as _dt
import hashlib
import importlib.util
import json
import os
import sys

_THIS = os.path.dirname(os.path.abspath(__file__))
_MODDIR = os.path.dirname(_THIS)
if _MODDIR not in sys.path:
    sys.path.insert(0, _MODDIR)
if _THIS not in sys.path:
    sys.path.insert(0, _THIS)

import verify_live_deployment_contract as V  # noqa: E402
import live_deployment_pointer_auth as LPA  # noqa: E402
import test_verify_live_deployment_contract as T  # noqa: E402


# ---------------------------------------------------------------------------
# Fixture: a 3-sleeve signed book + a configurable manifest + a deploy pointer.
# ---------------------------------------------------------------------------
def _sha_of_file(path: str) -> str:
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def build(root: str, *, manifest_bound: bool, pointer: dict = None,
          pointer_disabled: bool = False, pointer_missing: bool = False) -> list:
    """Materialize the fixture and return the verify argv.

    manifest_bound=False -> LIVE+signed manifest that OMITS expected_server,
    deployment_epoch and per-sleeve ex5_sha256 (so those read UNKNOWN unless a
    pointer resolves them). manifest_bound=True -> fully-bound (server/epoch/ex5).

    `pointer` (dict) is written to a pointer file and passed via --pointer. Its
    `manifest_path` / `manifest_sha256` may be filled with sentinels resolved here:
      "__MANIFEST_PATH__" -> the fixture manifest path
      "__MANIFEST_SHA__"  -> the real sha256 of the fixture manifest
    """
    now = _dt.datetime.now(_dt.timezone.utc)
    fresh = now - _dt.timedelta(minutes=2)
    epoch = now - _dt.timedelta(hours=3)

    prof = os.path.join(root, "MQL5", "Profiles", "Charts", "LiveOps")
    experts = os.path.join(root, "MQL5", "Experts", "Live EAs")
    events = os.path.join(root, "MQL5", "Files", "QM")
    snap = os.path.join(events, "journal", "account_snapshot.json")
    common = os.path.join(root, "config", "common.ini")
    manifest_path = os.path.join(root, "manifest.json")
    os.makedirs(prof, exist_ok=True)

    sha = {}
    for s in T.BOOK:
        sha[s["ea_id"]] = T.write_binary(
            os.path.join(experts, "%s.ex5" % s["ea_name"]), s["binary"])

    sleeves = []
    for s in T.BOOK:
        sl = dict(ea_id=s["ea_id"], ea_label=s["ea_name"], symbol=s["symbol"],
                  magic_number=s["magic"], risk_percent=s["risk"], timeframe=s["tf"],
                  ex5_path=os.path.join(experts, "%s.ex5" % s["ea_name"]))
        if manifest_bound:
            sl["ex5_sha256"] = sha[s["ea_id"]]
        sleeves.append(sl)

    manifest = {
        "book": "FIXTURE_%s" % T.ACCOUNT,
        "status": "LIVE",
        "signed": True,
        "approved_by": "OWNER (fixture) 2026-07-26",
        "expected_account": T.ACCOUNT,
        "sleeves": sleeves,
    }
    if manifest_bound:
        manifest["expected_server"] = T.SERVER
        manifest["deployment_epoch"] = T._iso(epoch)
    with open(manifest_path, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2)

    T.write_common_ini(common, T.ACCOUNT, T.SERVER)
    T.write_account_snapshot(snap, int(T.ACCOUNT), fresh)

    for i, s in enumerate(T.BOOK, start=1):
        T.write_chart(os.path.join(prof, "chart%02d.chr" % i), symbol=s["symbol"],
                      tf=s["tf"], ea_id=s["ea_id"], slot=s["slot"], ea_name=s["ea_name"],
                      risk_percent=s["risk"])
    T.write_monitor_chart(os.path.join(prof, "chart%02d.chr" % (len(T.BOOK) + 1)))
    for s in T.BOOK:
        T.write_event_log(os.path.join(events, "QM5_%d_ea-%d.log" % (s["ea_id"], s["ea_id"])),
                          ea_id=s["ea_id"], magic=s["magic"], symbol=s["symbol"],
                          tf=s["tf"], init_ok_dt=fresh, deinit_dt=None)

    if pointer_missing:
        pointer_arg = os.path.join(root, "no_such_pointer.json")
    elif pointer_disabled:
        pointer_arg = ""
    elif pointer is not None:
        resolved = json.loads(json.dumps(pointer))  # deep copy
        if resolved.get("manifest_path") == "__MANIFEST_PATH__":
            resolved["manifest_path"] = manifest_path
        if resolved.get("manifest_sha256") == "__MANIFEST_SHA__":
            resolved["manifest_sha256"] = _sha_of_file(manifest_path)
        pointer_arg = os.path.join(root, "pointer.json")
        with open(pointer_arg, "w", encoding="utf-8") as fh:
            json.dump(resolved, fh, indent=2)
    else:
        pointer_arg = os.path.join(root, "no_such_pointer.json")

    return [
        "--manifest", manifest_path,
        "--profile-dir", prof,
        "--event-log-dir", events,
        "--account-snapshot", snap,
        "--common-ini", common,
        "--monitor-name", "QM_AccountMonitor",
        "--freshness-hours", "24",
        "--pointer", pointer_arg,
        "--trigger", "post_recovery",
    ]


def _run(argv):
    return V.verify(V.build_arg_parser().parse_args(argv))


def _cats(state):
    return {f["category"] for f in state["findings"]}


def _signed_pointer():
    return {
        "signed": True,
        "approved_by": "OWNER (Fabian) 2026-07-24",
        "manifest_path": "__MANIFEST_PATH__",
        "manifest_sha256": "__MANIFEST_SHA__",
        "deployment_epoch_utc": "2026-07-24T06:42:00+00:00",
        "expected_account": T.ACCOUNT,
        "expected_server": T.SERVER,
        "expected_phase": "DXZ_LIVE",
        "binary_setfile_fingerprint": {
            "fingerprint_sha256": "8e476e5b807450cbaea92f12b92fcaa285e372a47533b5071996d114a3116035",
            "n_binary_missing": 0, "n_sleeves": 3},
    }


try:
    import pytest

    def test_signed_pointer_resolves_fields_verified(tmp_path):
        state = _run(build(str(tmp_path), manifest_bound=False, pointer=_signed_pointer()))
        pb = state["pointer_binding"]
        assert pb["auth_status"] == "VERIFIED", pb
        assert pb["applicable"] is True and pb["read_status"] == "ok"
        for f in ("server", "phase", "deployment_epoch", "binary_fingerprint"):
            assert pb["resolved"][f]["status"] == "VERIFIED", (f, pb["resolved"][f])
        ib = state["identity_binding"]
        assert ib["server"]["known"] and ib["server"]["source"] == "authenticated_pointer"
        assert ib["deployment_epoch"]["known"] and ib["deployment_epoch"]["source"] == "authenticated_pointer"
        assert ib["phase"]["known"] and ib["phase"]["value"] == "DXZ_LIVE"
        assert ib["binary_fingerprint"]["known"]
        assert ib["fully_bound"] is True
        cats = _cats(state)
        # The previously-UNKNOWN identity warnings are SUPPRESSED once resolved.
        assert "SERVER_EXPECTATION_UNKNOWN" not in cats
        assert "DEPLOYMENT_EPOCH_UNKNOWN" not in cats
        assert "BINARY_IDENTITY_UNKNOWN" not in cats
        assert "POINTER_AUTHENTICATED" in cats
        # Signing over a matching manifest with a clean profile/runtime is a PASS.
        assert state["overall_status"] == "GREEN", sorted(cats)

    def test_unsigned_pointer_leaves_fields_unknown_with_reason(tmp_path):
        ptr = _signed_pointer()
        ptr["signed"] = False
        state = _run(build(str(tmp_path), manifest_bound=False, pointer=ptr))
        pb = state["pointer_binding"]
        assert pb["auth_status"] == "UNKNOWN", pb
        for f in ("server", "phase", "deployment_epoch", "binary_fingerprint"):
            assert pb["resolved"][f]["status"] == "UNKNOWN", (f, pb["resolved"][f])
        assert "signed is not true" in pb["resolved"]["server"]["reason"]
        assert "SIGNED_NOT_TRUE" in {r["code"] for r in pb["auth_reasons"]}
        ib = state["identity_binding"]
        assert ib["server"]["known"] is False and ib["deployment_epoch"]["known"] is False
        assert ib["phase"]["known"] is False
        cats = _cats(state)
        # Unresolved -> the manifest-driven UNKNOWN warnings still fire.
        assert {"SERVER_EXPECTATION_UNKNOWN", "DEPLOYMENT_EPOCH_UNKNOWN",
                "BINARY_IDENTITY_UNKNOWN"} <= cats
        assert "POINTER_NOT_AUTHENTICATED" in cats
        assert state["overall_status"] == "AMBER"

    def test_manifest_sha_mismatch_is_mismatch_and_never_green(tmp_path):
        # A fully-bound signed manifest would be GREEN on its own; a pointer that
        # targets it by path but declares the WRONG manifest sha is a tamper signal:
        # fields MISMATCH, overall downgraded to AMBER, never GREEN.
        ptr = _signed_pointer()
        ptr["manifest_sha256"] = "b" * 64  # deliberately wrong; path still matches
        state = _run(build(str(tmp_path), manifest_bound=True, pointer=ptr))
        pb = state["pointer_binding"]
        assert pb["auth_status"] == "MISMATCH", pb
        for f in ("server", "phase", "deployment_epoch", "binary_fingerprint"):
            assert pb["resolved"][f]["status"] == "MISMATCH", (f, pb["resolved"][f])
        assert "MANIFEST_SHA_MISMATCH" in {r["code"] for r in pb["auth_reasons"]}
        cats = _cats(state)
        assert "POINTER_MANIFEST_MISMATCH" in cats
        assert state["overall_status"] == "AMBER", sorted(cats)
        assert state["overall_status"] != "GREEN"

    def test_account_mismatch_is_mismatch(tmp_path):
        ptr = _signed_pointer()
        ptr["expected_account"] = "9999999999"  # != manifest book account
        state = _run(build(str(tmp_path), manifest_bound=True, pointer=ptr))
        pb = state["pointer_binding"]
        assert pb["auth_status"] == "MISMATCH", pb
        assert "ACCOUNT_MISMATCH" in {r["code"] for r in pb["auth_reasons"]}
        assert state["overall_status"] == "AMBER"

    def test_missing_pointer_unchanged_old_behaviour_bound(tmp_path):
        # Fully-bound signed manifest + NO pointer -> GREEN, pointer ABSENT, no
        # POINTER_* findings. Identical to the pre-pointer behaviour.
        state = _run(build(str(tmp_path), manifest_bound=True, pointer_missing=True))
        pb = state["pointer_binding"]
        assert pb["auth_status"] == "ABSENT" and pb["read_status"] == "missing"
        assert not any(c.startswith("POINTER_") for c in _cats(state))
        ib = state["identity_binding"]
        assert ib["server"]["known"] and ib["server"].get("source") != "authenticated_pointer"
        assert ib["phase"]["known"] is False
        assert state["overall_status"] == "GREEN"

    def test_missing_pointer_unchanged_old_behaviour_unbound(tmp_path):
        # Unbound manifest + NO pointer -> the three UNKNOWN warnings fire, AMBER.
        state = _run(build(str(tmp_path), manifest_bound=False, pointer_missing=True))
        assert state["pointer_binding"]["auth_status"] == "ABSENT"
        cats = _cats(state)
        assert {"SERVER_EXPECTATION_UNKNOWN", "DEPLOYMENT_EPOCH_UNKNOWN",
                "BINARY_IDENTITY_UNKNOWN"} <= cats
        assert not any(c.startswith("POINTER_") for c in cats)
        assert state["overall_status"] == "AMBER"

    def test_pointer_binding_different_manifest_not_applicable(tmp_path):
        # A signed pointer that binds a DIFFERENT manifest is ignored; old behaviour.
        ptr = _signed_pointer()
        ptr["manifest_path"] = os.path.join(str(tmp_path), "some_other_manifest.json")
        ptr["manifest_sha256"] = "c" * 64
        state = _run(build(str(tmp_path), manifest_bound=False, pointer=ptr))
        pb = state["pointer_binding"]
        assert pb["auth_status"] == "NOT_APPLICABLE", pb
        assert pb["applicable"] is False
        cats = _cats(state)
        assert {"SERVER_EXPECTATION_UNKNOWN", "DEPLOYMENT_EPOCH_UNKNOWN",
                "BINARY_IDENTITY_UNKNOWN"} <= cats
        assert "POINTER_NOT_APPLICABLE" in cats
        assert state["overall_status"] == "AMBER"

    def test_disabled_pointer_reads_nothing(tmp_path):
        state = _run(build(str(tmp_path), manifest_bound=True, pointer_disabled=True))
        pb = state["pointer_binding"]
        assert pb["read_status"] == "disabled" and pb["auth_status"] == "ABSENT"
        assert pb["pointer_path"] is None
        assert state["overall_status"] == "GREEN"

    def test_shared_auth_matches_morning_brief(tmp_path):
        # PARITY GUARD: the shared authenticator must decide identically to
        # morning_brief._authenticate_deploy (rank <-> lamp level) for every case.
        mb_path = os.path.join(_MODDIR, "morning_brief.py")
        spec = importlib.util.spec_from_file_location("mb_parity", mb_path)
        mb = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mb)
        rank2lvl = {LPA.RANK_OK: mb.L_GREEN, LPA.RANK_DEGRADED: mb.L_AMBER,
                    LPA.RANK_UNCORROBORATED: mb.L_UNKNOWN, LPA.RANK_CONFLICT: mb.L_RED}

        manp = str(tmp_path / "man.json")
        man = {"book": "DXZ_4000090541", "status": "LIVE"}
        with open(manp, "w", encoding="utf-8") as fh:
            json.dump(man, fh)
        good_sha = _sha_of_file(manp)

        base = {"signed": True, "approved_by": "OWNER", "manifest_sha256": good_sha,
                "deployment_epoch_utc": "2026-07-25T20:00:00Z",
                "expected_account": "4000090541", "expected_phase": "DXZ_LIVE"}
        cases = [
            (dict(base), "runtime_stamp", man),
            ({**base, "signed": False}, "runtime_stamp", man),
            ({**base, "approved_by": ""}, "runtime_stamp", man),
            ({**base, "manifest_sha256": "a" * 64}, "runtime_stamp", man),
            ({**base, "expected_account": "9999999999"}, "runtime_stamp", man),
            ({**base, "manifest_sha256": None}, "runtime_stamp", {"status": "LIVE", "book": "DXZ"}),
            ({**base, "expected_phase": ""}, "runtime_stamp", man),
            (dict(base), "runtime_stamp", {"status": "DRAFT", "book": "DXZ_4000090541"}),
            (dict(base), "override", man),
            (dict(base), "repo_default", man),
        ]
        for stamp, src, manobj in cases:
            lvl_mb, _ = mb._authenticate_deploy(stamp, src, manp, manobj)
            res = LPA.authenticate_deploy_stamp(
                stamp, src, manifest_sha_actual=(lambda: (mb._sha256_file(manp) or "")),
                manifest_status=(manobj or {}).get("status"),
                manifest_book=(manobj or {}).get("book"))
            assert rank2lvl[res.rank] == lvl_mb, (src, stamp, res.codes(), lvl_mb)

except ImportError:  # pragma: no cover - pytest not available
    pass
