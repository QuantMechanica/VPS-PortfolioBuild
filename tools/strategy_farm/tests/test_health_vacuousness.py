"""WS-F standing vacuousness audit — synthetic fixtures per detector.

Positive (vacuous) fixtures must fire; negative (healthy / legitimately-identical)
fixtures must stay quiet. Every fixture is built in a temp DB / temp filesystem and the
module constants are patched, so no test touches the live factory DB or T_Live.

Covers the five WS-F detectors added to health.py (ULTRACODE 2026-07-26):
  (a) chk_q05_q06_stress_identity   (b) chk_q07_zero_variance
  (c) chk_phase_invalid_rate_7d     (d) chk_ks_baseline_dormancy
  (e) chk_seed_auth_failure_rate
plus the read-only _connect() contract.
"""

from __future__ import annotations

import hashlib
import json
import sqlite3
import sys
import time
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import health  # noqa: E402

NOW = time.time()
IN_WINDOW = NOW - 1 * 86400          # inside every detector window
OUT_WINDOW = NOW - 100 * 86400       # outside every detector window

_EA_METRICS_COLS = (
    "ea_id", "symbol", "phase", "verdict", "profit_factor", "trades",
    "drawdown_money", "evidence_path", "evidence_mtime", "detail_json",
)


def _make_db(path: Path, rows: list[dict]) -> None:
    con = sqlite3.connect(str(path))
    con.execute(
        "CREATE TABLE ea_metrics ("
        "ea_id TEXT, symbol TEXT, phase TEXT, verdict TEXT, profit_factor REAL, "
        "trades INTEGER, drawdown_money REAL, evidence_path TEXT, "
        "evidence_mtime REAL, detail_json TEXT)"
    )
    con.executemany(
        "INSERT INTO ea_metrics (" + ",".join(_EA_METRICS_COLS) + ") VALUES ("
        + ",".join("?" for _ in _EA_METRICS_COLS) + ")",
        [tuple(r.get(c) for c in _EA_METRICS_COLS) for r in rows],
    )
    con.commit()
    con.close()


def _write_json(path: Path, obj: dict) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj), encoding="utf-8")
    return str(path)


def _seed_detail(seed: int, pf: float, summary_path: str, invalid_reason=None) -> dict:
    return {
        "seed": seed, "pf": pf, "dd_money": 5000.0, "dd_pct": 5.0, "trades": 100,
        "exit_code": 0, "summary_path": summary_path, "report_path": None,
        "invalid_reason": invalid_reason,
    }


class ReadOnlyConnectTest(unittest.TestCase):
    def test_connect_is_read_only(self):
        tmp = Path(self.enterContext(_tmpdir())) / "farm.sqlite"
        _make_db(tmp, [])
        with mock.patch.object(health, "DB", tmp):
            con = health._connect()
            try:
                # PRAGMA query_only must be ON, and a write must raise.
                self.assertEqual(con.execute("PRAGMA query_only").fetchone()[0], 1)
                with self.assertRaises(sqlite3.OperationalError):
                    con.execute("CREATE TABLE _x(a)")
            finally:
                con.close()


class HelperTest(unittest.TestCase):
    def test_ea_id_int_strips_qm5_prefix(self):
        # the 'QM5_' prefix must not leak its 5 into the parsed id
        self.assertEqual(health._ea_id_int("QM5_13140"), 13140)
        self.assertEqual(health._ea_id_int("QM5_1567"), 1567)
        self.assertEqual(health._ea_id_int("QM5_13036"), 13036)
        self.assertEqual(health._ea_id_int(10403), 10403)
        self.assertEqual(health._ea_id_int("10403"), 10403)
        self.assertIsNone(health._ea_id_int(None))
        self.assertIsNone(health._ea_id_int("nope"))

    def test_norm_symbol(self):
        self.assertEqual(health._norm_symbol("XAUUSD.DWX"), "XAUUSD")
        self.assertEqual(health._norm_symbol("xauusd"), "XAUUSD")
        self.assertEqual(health._norm_symbol("XNGUSD.DWX"), "XNGUSD")


def _sha(tag: str) -> str:
    """Deterministic, realistic 64-hex-lowercase sha256 digest for a fixture tag.
    Real digests (not repeated placeholder letters) prove the AUTHENTICATED tier is
    reachable ONLY via valid provenance — Codex round-3 WSF2."""
    return hashlib.sha256(tag.encode("utf-8")).hexdigest()


# One deployed identity (EA source, set-file, compiled binary) shared by a genuine
# Q05/Q06 pair; each run carries its OWN distinct native report hash. These are the
# realistic distinct 64-hex values the reachability fixtures use.
_ID_EA = _sha("QM5_9301-ea-source-v1")
_ID_SET = _sha("QM5_9301-setfile-v1")
_ID_EX5 = _sha("QM5_9301-ex5-binary-v1")
_RPT_Q05 = _sha("QM5_9301-q05-native-report")
_RPT_Q06 = _sha("QM5_9301-q06-native-report")

# Full provenance tuple (EA/set/binary/report sha256) shaped like a real, AUTHENTICATED
# aggregate — realistic distinct 64-hex digests, not placeholder letters. Supports both
# the flat *_sha256 form and the pipeline's nested {path,sha256} block form
# (q03_plateau_runner). Proves the AUTHENTICATED tier is genuinely reachable and is not a
# blanket CANDIDATE relabel — and that it is reachable ONLY via valid provenance.
_FULL_HASHES_FLAT = {
    "ea_sha256": _ID_EA, "set_sha256": _ID_SET,
    "ex5_sha256": _ID_EX5, "report_sha256": _RPT_Q05,
}
_FULL_HASHES_NESTED = {
    "mq5": {"path": "x.mq5", "sha256": _ID_EA},
    "baseline_setfile": {"path": "x.set", "sha256": _ID_SET},
    "ex5": {"path": "x.ex5", "sha256": _ID_EX5},
    "report": {"path": "x.htm", "sha256": _RPT_Q05},
}


class ProvenanceTierTest(unittest.TestCase):
    def test_extract_hash_flat_and_nested(self):
        self.assertEqual(health._extract_hash({"ex5_sha256": "c" * 64},
                                              health.PROVENANCE_HASH_ALIASES["binary"]), "c" * 64)
        self.assertEqual(health._extract_hash({"ex5": {"sha256": "c" * 64}},
                                              health.PROVENANCE_HASH_ALIASES["binary"]), "c" * 64)
        self.assertIsNone(health._extract_hash({}, health.PROVENANCE_HASH_ALIASES["binary"]))
        self.assertIsNone(health._extract_hash(None, health.PROVENANCE_HASH_ALIASES["binary"]))

    def test_candidate_when_hashes_absent(self):
        # heuristic evidence with unrounded KPIs + telemetry but NO deployment hashes
        ev = {"pf": 1.2, "dd_money": 5000.0, "trades": 100, "rejection_probability": 0.10}
        tier, missing = health._provenance_tier(ev, unrounded_ok=True, telemetry_ok=True)
        self.assertEqual(tier, health.TIER_CANDIDATE)
        self.assertIn("ea_hash", missing)
        self.assertIn("binary_hash", missing)

    def test_authenticated_when_full_tuple_bound_flat(self):
        ev = dict(_FULL_HASHES_FLAT, pf=1.2, dd_money=5000.0, trades=100)
        tier, missing = health._provenance_tier(ev, unrounded_ok=True, telemetry_ok=True)
        self.assertEqual(tier, health.TIER_AUTHENTICATED, missing)
        self.assertEqual(missing, [])

    def test_authenticated_when_full_tuple_bound_nested(self):
        ev = dict(_FULL_HASHES_NESTED, pf=1.2)
        tier, missing = health._provenance_tier(ev, unrounded_ok=True, telemetry_ok=True)
        self.assertEqual(tier, health.TIER_AUTHENTICATED, missing)

    def test_missing_unrounded_or_telemetry_downgrades(self):
        ev = dict(_FULL_HASHES_FLAT)
        tier, missing = health._provenance_tier(ev, unrounded_ok=False, telemetry_ok=True)
        self.assertEqual(tier, health.TIER_CANDIDATE)
        self.assertIn("unrounded_kpis", missing)
        tier2, missing2 = health._provenance_tier(ev, unrounded_ok=True, telemetry_ok=False)
        self.assertEqual(tier2, health.TIER_CANDIDATE)
        self.assertIn("telemetry", missing2)

    def test_multi_payload_all_must_bind(self):
        good = dict(_FULL_HASHES_FLAT)
        bad = {"ea_sha256": _ID_EA}  # only one facet bound
        tier, _ = health._provenance_tier((good, bad), unrounded_ok=True, telemetry_ok=True)
        self.assertEqual(tier, health.TIER_CANDIDATE)

    # --- Codex round-3 WSF2 hostile cases (verbatim) + stricter boundary --------
    # These are the exact two direct calls that previously returned ('AUTHENTICATED', [])
    # in the review. Under the real validation boundary they must both be CANDIDATE.
    def test_hostile_malformed_hash_returns_candidate(self):
        # Codex hostile case (a): ea_sha256=set_sha256=ex5_sha256=report_sha256="x".
        # A one-character "hash" is not a 64-hex sha256 -> malformed_hash / CANDIDATE.
        ev = {"ea_sha256": "x", "set_sha256": "x", "ex5_sha256": "x", "report_sha256": "x"}
        tier, missing = health._provenance_tier(ev, unrounded_ok=True, telemetry_ok=True)
        self.assertEqual(tier, health.TIER_CANDIDATE)
        self.assertIn("malformed_hash", missing)

    def test_hostile_mismatched_identity_pair_returns_candidate(self):
        # Codex hostile case (b): two individually-64-hex but mutually inconsistent
        # EA/set/binary/report tuples across the paired Q05/Q06 runs. Same *shape*,
        # different identity -> identity_mismatch / CANDIDATE (never AUTHENTICATED).
        ev5 = {"ea_sha256": _sha("ea-A"), "set_sha256": _sha("set-A"),
               "ex5_sha256": _sha("ex5-A"), "report_sha256": _sha("rpt-A")}
        ev6 = {"ea_sha256": _sha("ea-B"), "set_sha256": _sha("set-B"),
               "ex5_sha256": _sha("ex5-B"), "report_sha256": _sha("rpt-B")}
        tier, missing = health._provenance_tier((ev5, ev6), unrounded_ok=True, telemetry_ok=True)
        self.assertEqual(tier, health.TIER_CANDIDATE)
        self.assertIn("identity_mismatch", missing)

    def test_report_hash_not_distinct_returns_candidate(self):
        # Boundary (3): identical EA/set/binary identity but the SAME report hash on both
        # runs is one run re-read, not a genuine pair -> report_hash_not_distinct.
        shared = {"ea_sha256": _ID_EA, "set_sha256": _ID_SET,
                  "ex5_sha256": _ID_EX5, "report_sha256": _RPT_Q05}
        tier, missing = health._provenance_tier(
            (dict(shared), dict(shared)), unrounded_ok=True, telemetry_ok=True)
        self.assertEqual(tier, health.TIER_CANDIDATE)
        self.assertIn("report_hash_not_distinct", missing)

    def test_uppercase_hash_is_malformed(self):
        # Boundary (1) is lowercase-canonical: an uppercase hex char fails the 64-hex
        # lowercase floor -> malformed_hash / CANDIDATE.
        upper = "F" + _ID_EA[1:]  # guarantees an uppercase hex char at position 0
        ev = {"ea_sha256": upper, "set_sha256": _ID_SET,
              "ex5_sha256": _ID_EX5, "report_sha256": _RPT_Q05}
        tier, missing = health._provenance_tier(ev, unrounded_ok=True, telemetry_ok=True)
        self.assertEqual(tier, health.TIER_CANDIDATE)
        self.assertIn("malformed_hash", missing)

    def test_paired_authenticated_requires_shared_identity_distinct_report(self):
        # The ONLY paired path to AUTHENTICATED: identical EA/set/binary identity across
        # both runs AND a distinct, valid report hash for each run.
        ev5 = {"ea_sha256": _ID_EA, "set_sha256": _ID_SET,
               "ex5_sha256": _ID_EX5, "report_sha256": _RPT_Q05}
        ev6 = {"ea_sha256": _ID_EA, "set_sha256": _ID_SET,
               "ex5_sha256": _ID_EX5, "report_sha256": _RPT_Q06}
        tier, missing = health._provenance_tier((ev5, ev6), unrounded_ok=True, telemetry_ok=True)
        self.assertEqual(tier, health.TIER_AUTHENTICATED, missing)
        self.assertEqual(missing, [])


class Q05Q06StressIdentityTest(unittest.TestCase):
    def _build(self, tmp: Path):
        rows = []

        def pair(ea, pf5, tr5, ev5, pf6, tr6, ev6):
            rows.append(dict(ea_id=ea, symbol="EURUSD.DWX", phase="Q05", verdict="PASS",
                             profit_factor=pf5, trades=tr5, drawdown_money=5000.0,
                             evidence_path=ev5, evidence_mtime=IN_WINDOW, detail_json="{}"))
            rows.append(dict(ea_id=ea, symbol="EURUSD.DWX", phase="Q06", verdict="PASS",
                             profit_factor=pf6, trades=tr6, drawdown_money=5000.0,
                             evidence_path=ev6, evidence_mtime=IN_WINDOW, detail_json="{}"))

        def ev(name, pf, dd, tr, rp=None, summ=None):
            obj = {"pf": pf, "dd_money": dd, "trades": tr, "summary_path": summ or f"D:/x/{name}/summary.json"}
            if rp is not None:
                obj["rejection_probability"] = rp
                obj["stress_level"] = "HARSH"
            return _write_json(tmp / f"{name}.json", obj)

        # (1) vacuous: identical raw KPIs, distinct runs, HARSH reject 0.10, big cohort -> FLAG
        pair("QM5_9001", 1.23, 200, ev("q05_9001", 1.23, 5000.0, 200),
             1.23, 200, ev("q06_9001", 1.23, 5000.0, 200, rp=0.10))
        # (2) distinct KPIs -> benign (DB pre-filter)
        pair("QM5_9002", 1.30, 200, ev("q05_9002", 1.30, 5000.0, 200),
             1.10, 180, ev("q06_9002", 1.10, 4000.0, 180, rp=0.10))
        # (3) rounded-only equal: DB pf/trades equal but raw pf differs -> benign
        pair("QM5_9003", 1.20, 150, ev("q05_9003", 1.201, 5000.0, 150),
             1.20, 150, ev("q06_9003", 1.199, 4900.0, 150, rp=0.10))
        # (4) below cohort: identical but only 20 trades -> benign
        pair("QM5_9004", 1.15, 20, ev("q05_9004", 1.15, 5000.0, 20),
             1.15, 20, ev("q06_9004", 1.15, 5000.0, 20, rp=0.10))
        # (5) stress not configured: identical but Q06 reject 0.0 -> benign
        pair("QM5_9005", 1.15, 100, ev("q05_9005", 1.15, 5000.0, 100),
             1.15, 100, ev("q06_9005", 1.15, 5000.0, 100, rp=0.0))
        # (6) shared evidence: identical, same summary_path in Q05 and Q06 -> FLAG
        shared = ev("shared_9006", 1.40, 5000.0, 100, summ="D:/x/shared/summary.json")
        rows.append(dict(ea_id="QM5_9006", symbol="EURUSD.DWX", phase="Q05", verdict="PASS",
                         profit_factor=1.40, trades=100, drawdown_money=5000.0,
                         evidence_path=shared, evidence_mtime=IN_WINDOW, detail_json="{}"))
        ev6 = _write_json(tmp / "q06_9006.json", {"pf": 1.40, "dd_money": 5000.0, "trades": 100,
                                                  "rejection_probability": 0.10, "stress_level": "HARSH",
                                                  "summary_path": "D:/x/shared/summary.json"})
        rows.append(dict(ea_id="QM5_9006", symbol="EURUSD.DWX", phase="Q06", verdict="PASS",
                         profit_factor=1.40, trades=100, drawdown_money=5000.0,
                         evidence_path=ev6, evidence_mtime=IN_WINDOW, detail_json="{}"))
        # (7) old vacuous pair OUT of window -> ignored
        pair("QM5_9007", 1.23, 200, ev("q05_9007", 1.23, 5000.0, 200),
             1.23, 200, ev("q06_9007", 1.23, 5000.0, 200, rp=0.10))
        rows[-1]["evidence_mtime"] = OUT_WINDOW
        rows[-2]["evidence_mtime"] = OUT_WINDOW
        return rows

    def test_positive_and_negative(self):
        tmp = Path(self.enterContext(_tmpdir()))
        db = tmp / "farm.sqlite"
        _make_db(db, self._build(tmp))
        with mock.patch.object(health, "DB", db):
            con = health._connect()
            try:
                res = health.chk_q05_q06_stress_identity(con)
            finally:
                con.close()
        # Two vacuous sleeves flagged (9001 harsh_reject_no_effect + 9006 shared_evidence),
        # all others benign, the out-of-window pair ignored.
        self.assertEqual(res["value"], 2, res["detail"])
        self.assertIn("distinct_kpis=1", res["detail"])
        self.assertIn("rounded_equality=1", res["detail"])
        self.assertIn("below_cohort=1", res["detail"])
        self.assertIn("stress_not_configured=1", res["detail"])
        self.assertIn("harsh_reject_no_effect", res["detail"])
        self.assertIn("shared_evidence", res["detail"])
        # Two-tier: no aggregate hashes in the fixtures => both publish as CANDIDATES,
        # zero AUTHENTICATED. This is the exact claim boundary Codex round-2 requires.
        self.assertIn("candidates=2", res["detail"])
        self.assertIn("authenticated=0", res["detail"])
        self.assertIn("tier=CANDIDATE", res["detail"])
        # default FAIL threshold (20) -> WARN; DB path printed
        self.assertEqual(res["status"], "WARN")
        self.assertIn(str(db), res["detail"])
        # a low FAIL threshold escalates
        with mock.patch.object(health, "STRESS_IDENTITY_FAIL_COUNT", 2), \
                mock.patch.object(health, "DB", db):
            con = health._connect()
            try:
                res2 = health.chk_q05_q06_stress_identity(con)
            finally:
                con.close()
        self.assertEqual(res2["status"], "FAIL")

    def test_authenticated_tier_when_hashes_bound(self):
        # A vacuous pair whose evidence binds the SAME EA/set/binary identity across both
        # runs AND a DISTINCT native report hash for each is promoted to AUTHENTICATED —
        # proving the two-tier split is real, and reachable ONLY via valid provenance.
        tmp = Path(self.enterContext(_tmpdir()))
        db = tmp / "farm.sqlite"

        def ev(name, report_hash, rp=None):
            obj = {"ea_sha256": _ID_EA, "set_sha256": _ID_SET, "ex5_sha256": _ID_EX5,
                   "report_sha256": report_hash, "pf": 1.23, "dd_money": 5000.0, "trades": 200,
                   "summary_path": f"D:/x/{name}/summary.json"}
            if rp is not None:
                obj["rejection_probability"] = rp
                obj["stress_level"] = "HARSH"
            return _write_json(tmp / f"{name}.json", obj)

        rows = [
            dict(ea_id="QM5_9301", symbol="EURUSD.DWX", phase="Q05", verdict="PASS",
                 profit_factor=1.23, trades=200, drawdown_money=5000.0,
                 evidence_path=ev("q05_9301", _RPT_Q05), evidence_mtime=IN_WINDOW, detail_json="{}"),
            dict(ea_id="QM5_9301", symbol="EURUSD.DWX", phase="Q06", verdict="PASS",
                 profit_factor=1.23, trades=200, drawdown_money=5000.0,
                 evidence_path=ev("q06_9301", _RPT_Q06, rp=0.10), evidence_mtime=IN_WINDOW, detail_json="{}"),
        ]
        _make_db(db, rows)
        with mock.patch.object(health, "DB", db):
            con = health._connect()
            try:
                res = health.chk_q05_q06_stress_identity(con)
            finally:
                con.close()
        self.assertEqual(res["value"], 1, res["detail"])
        self.assertIn("authenticated=1", res["detail"])
        self.assertIn("candidates=0", res["detail"])
        self.assertIn("tier=AUTHENTICATED", res["detail"])

    def test_all_healthy_is_ok(self):
        tmp = Path(self.enterContext(_tmpdir()))
        db = tmp / "farm.sqlite"

        def ev(name, pf, dd, tr, rp=None):
            obj = {"pf": pf, "dd_money": dd, "trades": tr, "summary_path": f"D:/x/{name}.json"}
            if rp is not None:
                obj["rejection_probability"] = rp
            return _write_json(tmp / f"{name}.json", obj)

        rows = [
            dict(ea_id="QM5_8001", symbol="EURUSD.DWX", phase="Q05", verdict="PASS",
                 profit_factor=1.30, trades=200, drawdown_money=5000.0,
                 evidence_path=ev("q05", 1.30, 5000.0, 200), evidence_mtime=IN_WINDOW, detail_json="{}"),
            dict(ea_id="QM5_8001", symbol="EURUSD.DWX", phase="Q06", verdict="PASS",
                 profit_factor=1.10, trades=170, drawdown_money=4200.0,
                 evidence_path=ev("q06", 1.10, 4200.0, 170, rp=0.10), evidence_mtime=IN_WINDOW, detail_json="{}"),
        ]
        _make_db(db, rows)
        with mock.patch.object(health, "DB", db):
            con = health._connect()
            try:
                res = health.chk_q05_q06_stress_identity(con)
            finally:
                con.close()
        self.assertEqual(res["status"], "OK")
        self.assertEqual(res["value"], 0)


class Q07ZeroVarianceTest(unittest.TestCase):
    def test_deterministic_benign_and_seed_alias_flag(self):
        tmp = Path(self.enterContext(_tmpdir()))
        db = tmp / "farm.sqlite"
        # deterministic-by-design: zero variance, all seeds authenticated, distinct summaries
        det_ev = _write_json(tmp / "det.json", {"per_seed_detail": [
            _seed_detail(s, 1.20, f"D:/det/run_{s}/summary.json") for s in (42, 17, 99, 7, 2026)]})
        # seed_alias: zero variance but a seed carries effective_seed_mismatch
        alias_psd = [_seed_detail(s, 1.20, f"D:/al/run_{s}/summary.json") for s in (42, 17, 99, 7, 2026)]
        alias_psd[1]["invalid_reason"] = "effective_seed_mismatch:requested=17:report=42"
        alias_ev = _write_json(tmp / "alias.json", {"per_seed_detail": alias_psd})
        rows = [
            dict(ea_id="QM5_9101", symbol="EURUSD.DWX", phase="Q07", verdict="PASS",
                 profit_factor=1.20, trades=100, drawdown_money=None, evidence_path=det_ev,
                 evidence_mtime=IN_WINDOW, detail_json=json.dumps({"metrics": {"variance_pct": 0.0, "spread": 0.0}})),
            dict(ea_id="QM5_9102", symbol="GBPUSD.DWX", phase="Q07", verdict="INVALID",
                 profit_factor=1.20, trades=100, drawdown_money=None, evidence_path=alias_ev,
                 evidence_mtime=IN_WINDOW, detail_json=json.dumps({"metrics": {"variance_pct": 0.0, "spread": 0.0},
                                                                   "reason": "seeds_invalid_evidence"})),
            # non-zero variance -> not a candidate
            dict(ea_id="QM5_9103", symbol="USDJPY.DWX", phase="Q07", verdict="PASS",
                 profit_factor=1.30, trades=100, drawdown_money=None,
                 evidence_path=_write_json(tmp / "hv.json", {"per_seed_detail": []}),
                 evidence_mtime=IN_WINDOW, detail_json=json.dumps({"metrics": {"variance_pct": 12.0, "spread": 0.3}})),
        ]
        _make_db(db, rows)
        with mock.patch.object(health, "DB", db):
            con = health._connect()
            try:
                res = health.chk_q07_zero_variance(con)
            finally:
                con.close()
        self.assertEqual(res["value"], 1, res["detail"])            # only seed_alias flagged
        self.assertIn("deterministic_by_design=1", res["detail"])   # benign, reported
        self.assertIn("seed_alias=1", res["detail"])
        # Two-tier: seed-auth telemetry present but no deployment hashes => CANDIDATE.
        self.assertIn("candidates=1", res["detail"])
        self.assertIn("authenticated=0", res["detail"])
        self.assertIn("tier=CANDIDATE", res["detail"])
        self.assertEqual(res["status"], "WARN")
        with mock.patch.object(health, "Q07_ZERO_VARIANCE_FAIL_COUNT", 1), \
                mock.patch.object(health, "DB", db):
            con = health._connect()
            try:
                res2 = health.chk_q07_zero_variance(con)
            finally:
                con.close()
        self.assertEqual(res2["status"], "FAIL")

    def test_all_deterministic_is_ok(self):
        tmp = Path(self.enterContext(_tmpdir()))
        db = tmp / "farm.sqlite"
        det_ev = _write_json(tmp / "det.json", {"per_seed_detail": [
            _seed_detail(s, 1.20, f"D:/det/run_{s}/summary.json") for s in (42, 17, 99, 7, 2026)]})
        rows = [dict(ea_id="QM5_9201", symbol="EURUSD.DWX", phase="Q07", verdict="PASS",
                     profit_factor=1.20, trades=100, drawdown_money=None, evidence_path=det_ev,
                     evidence_mtime=IN_WINDOW,
                     detail_json=json.dumps({"metrics": {"variance_pct": 0.0, "spread": 0.0}}))]
        _make_db(db, rows)
        with mock.patch.object(health, "DB", db):
            con = health._connect()
            try:
                res = health.chk_q07_zero_variance(con)
            finally:
                con.close()
        self.assertEqual(res["status"], "OK")
        self.assertEqual(res["value"], 0)


class PhaseInvalidRateTest(unittest.TestCase):
    def _rows(self, phase, n_invalid, n_other, mtime=IN_WINDOW):
        rows = []
        for i in range(n_invalid):
            rows.append(dict(ea_id=f"QM5_{i}", symbol="X", phase=phase, verdict="INVALID",
                             profit_factor=None, trades=0, drawdown_money=None,
                             evidence_path=None, evidence_mtime=mtime, detail_json="{}"))
        for i in range(n_other):
            rows.append(dict(ea_id=f"QM5_{1000+i}", symbol="X", phase=phase, verdict="PASS",
                             profit_factor=1.2, trades=100, drawdown_money=None,
                             evidence_path=None, evidence_mtime=mtime, detail_json="{}"))
        return rows

    def _run(self, rows):
        tmp = Path(self.enterContext(_tmpdir()))
        db = tmp / "farm.sqlite"
        _make_db(db, rows)
        with mock.patch.object(health, "DB", db):
            con = health._connect()
            try:
                return health.chk_phase_invalid_rate_7d(con)
            finally:
                con.close()

    def test_high_invalid_rate_fails(self):
        res = self._run(self._rows("Q99", n_invalid=10, n_other=20))  # 33.3%
        self.assertEqual(res["status"], "FAIL")
        self.assertIn("Q99", res["detail"])

    def test_low_invalid_rate_ok(self):
        res = self._run(self._rows("Q99", n_invalid=1, n_other=29))   # 3.3%
        self.assertEqual(res["status"], "OK")

    def test_below_min_sample_ignored(self):
        # 5/5 INVALID but only 10 rows (< min sample 20) -> not judged
        res = self._run(self._rows("Q99", n_invalid=5, n_other=5))
        self.assertEqual(res["status"], "OK")

    def test_out_of_window_ignored(self):
        res = self._run(self._rows("Q99", n_invalid=10, n_other=20, mtime=OUT_WINDOW))
        self.assertEqual(res["status"], "OK")


class KsBaselineDormancyTest(unittest.TestCase):
    def _fixture(self, tmp: Path, *, with_mismatch=True, with_dormant=True):
        baseline_dir = tmp / "baselines"
        baseline_dir.mkdir(parents=True)
        _write_json(baseline_dir / "QM5_9401_EURUSD.json", {"hash": "AAA"})
        _write_json(baseline_dir / "QM5_9402_XAUUSD.json", {"hash": "BBB"})
        _write_json(baseline_dir / "QM5_9403_GBPUSD.json", {"hash": "CCC"})
        # 9404 has NO baseline file
        log_dir = tmp / "logs"
        log_dir.mkdir(parents=True)

        def line(ea, sym, event, ts, h=None):
            rec = {"ts_utc": ts, "ea_id": ea, "symbol": sym, "magic": ea * 10000, "event": event}
            if event == "KS_BASELINE_LOADED":
                rec["payload"] = {"path": f"QM/baselines/QM5_{ea}_{sym}.json", "hash": h}
            else:
                rec["payload"] = {"expected_path": f"QM/baselines/QM5_{ea}_{sym}.json"}
            return json.dumps(rec)

        lines = [
            # 9401: ABSENT then LOADED matching -> loaded_ok (latest wins)
            line(9401, "EURUSD", "KS_BASELINE_ABSENT", "2026-07-10T00:00:00Z"),
            line(9401, "EURUSD", "KS_BASELINE_LOADED", "2026-07-25T00:00:00Z", h="AAA"),
        ]
        if with_dormant:
            # 9402: LOADED then ABSENT -> dormant (latest is ABSENT)
            lines += [
                line(9402, "XAUUSD", "KS_BASELINE_LOADED", "2026-07-10T00:00:00Z", h="BBB"),
                line(9402, "XAUUSD", "KS_BASELINE_ABSENT", "2026-07-25T00:00:00Z"),
            ]
        else:
            lines += [line(9402, "XAUUSD", "KS_BASELINE_LOADED", "2026-07-25T00:00:00Z", h="BBB")]
        if with_mismatch:
            # 9403: LOADED with WRONG hash -> hash_mismatch
            lines += [line(9403, "GBPUSD", "KS_BASELINE_LOADED", "2026-07-25T00:00:00Z", h="WRONG")]
        else:
            lines += [line(9403, "GBPUSD", "KS_BASELINE_LOADED", "2026-07-25T00:00:00Z", h="CCC")]
        (log_dir / "QM5_book.log").write_text("\n".join(lines) + "\n", encoding="utf-8")

        manifest = tmp / "manifest.json"
        _write_json(manifest, {"sleeves": [
            {"ea_id": 9401, "symbol": "EURUSD.DWX"},
            {"ea_id": 9402, "symbol": "XAUUSD.DWX"},
            {"ea_id": 9403, "symbol": "GBPUSD.DWX"},
            {"ea_id": 9404, "symbol": "EURGBP.DWX"},
        ]})
        return baseline_dir, log_dir, manifest

    def test_mismatch_fails_and_classification(self):
        tmp = Path(self.enterContext(_tmpdir()))
        bdir, ldir, manifest = self._fixture(tmp, with_mismatch=True, with_dormant=True)
        with mock.patch.object(health, "LIVE_TERMINAL_BASELINE_DIR", tmp / "no_local"), \
                mock.patch.object(health, "LIVE_COMMON_BASELINE_DIR", bdir), \
                mock.patch.object(health, "LIVE_QM_LOG_DIR", ldir), \
                mock.patch.object(health, "DXZ_BOOK_MANIFEST", manifest):
            res = health.chk_ks_baseline_dormancy()
        self.assertEqual(res["status"], "FAIL")            # a hash_mismatch present
        self.assertIn("loaded_ok=1", res["detail"])
        self.assertIn("dormant=1", res["detail"])
        self.assertIn("no_baseline_file=1", res["detail"])
        self.assertIn("hash_mismatch=1", res["detail"])

    def test_dormant_only_warns(self):
        tmp = Path(self.enterContext(_tmpdir()))
        bdir, ldir, manifest = self._fixture(tmp, with_mismatch=False, with_dormant=True)
        with mock.patch.object(health, "LIVE_TERMINAL_BASELINE_DIR", tmp / "no_local"), \
                mock.patch.object(health, "LIVE_COMMON_BASELINE_DIR", bdir), \
                mock.patch.object(health, "LIVE_QM_LOG_DIR", ldir), \
                mock.patch.object(health, "DXZ_BOOK_MANIFEST", manifest):
            res = health.chk_ks_baseline_dormancy()
        self.assertEqual(res["status"], "WARN")            # dormant + no_file, no mismatch
        self.assertIn("hash_mismatch=0", res["detail"])

    def test_all_loaded_ok(self):
        tmp = Path(self.enterContext(_tmpdir()))
        bdir, ldir, manifest = self._fixture(tmp, with_mismatch=False, with_dormant=False)
        # give 9404 a baseline + LOADED so everything is clean
        _write_json(bdir / "QM5_9404_EURGBP.json", {"hash": "DDD"})
        rec = json.dumps({"ts_utc": "2026-07-25T00:00:00Z", "ea_id": 9404, "symbol": "EURGBP",
                          "event": "KS_BASELINE_LOADED", "payload": {"hash": "DDD"}})
        with (ldir / "QM5_book.log").open("a", encoding="utf-8") as fh:
            fh.write(rec + "\n")
        with mock.patch.object(health, "LIVE_TERMINAL_BASELINE_DIR", tmp / "no_local"), \
                mock.patch.object(health, "LIVE_COMMON_BASELINE_DIR", bdir), \
                mock.patch.object(health, "LIVE_QM_LOG_DIR", ldir), \
                mock.patch.object(health, "DXZ_BOOK_MANIFEST", manifest):
            res = health.chk_ks_baseline_dormancy()
        self.assertEqual(res["status"], "OK", res["detail"])
        self.assertIn("loaded_ok=4", res["detail"])

    def test_loaded_event_without_hash_is_intentional_mismatch(self):
        tmp = Path(self.enterContext(_tmpdir()))
        bdir, ldir, manifest = self._fixture(tmp, with_mismatch=False, with_dormant=False)
        _write_json(bdir / "QM5_9404_EURGBP.json", {"hash": "DDD"})
        records = [
            {"ts_utc": "2026-07-25T00:00:00Z", "ea_id": 9404, "symbol": "EURGBP",
             "event": "KS_BASELINE_LOADED", "payload": {"hash": "DDD"}},
            {"ts_utc": "2026-07-26T00:00:00Z", "ea_id": 9401, "symbol": "EURUSD",
             "event": "KS_BASELINE_LOADED", "payload": {"path": "QM/baselines/QM5_9401_EURUSD.json"}},
        ]
        with (ldir / "QM5_book.log").open("a", encoding="utf-8") as fh:
            for record in records:
                fh.write(json.dumps(record) + "\n")

        with mock.patch.object(health, "LIVE_TERMINAL_BASELINE_DIR", tmp / "no_local"), \
                mock.patch.object(health, "LIVE_COMMON_BASELINE_DIR", bdir), \
                mock.patch.object(health, "LIVE_QM_LOG_DIR", ldir), \
                mock.patch.object(health, "DXZ_BOOK_MANIFEST", manifest):
            res = health.chk_ks_baseline_dormancy()

        self.assertEqual(res["status"], "FAIL")
        self.assertIn("hash_mismatch=1", res["detail"])

    def test_missing_logs_is_unknown_not_green(self):
        tmp = Path(self.enterContext(_tmpdir()))
        bdir, _ldir, manifest = self._fixture(tmp)
        with mock.patch.object(health, "LIVE_TERMINAL_BASELINE_DIR", tmp / "no_local"), \
                mock.patch.object(health, "LIVE_COMMON_BASELINE_DIR", bdir), \
                mock.patch.object(health, "LIVE_QM_LOG_DIR", tmp / "does_not_exist"), \
                mock.patch.object(health, "DXZ_BOOK_MANIFEST", manifest):
            res = health.chk_ks_baseline_dormancy()
        self.assertEqual(res["status"], "WARN")
        self.assertIn("log_dir_missing", res["detail"])

    def test_divergent_terminal_local_and_common_mirrors_fail(self):
        tmp = Path(self.enterContext(_tmpdir()))
        common, ldir, manifest = self._fixture(tmp, with_mismatch=False, with_dormant=False)
        _write_json(common / "QM5_9404_EURGBP.json", {"hash": "DDD"})
        rec = json.dumps({"ts_utc": "2026-07-25T00:00:00Z", "ea_id": 9404, "symbol": "EURGBP",
                          "event": "KS_BASELINE_LOADED", "payload": {"hash": "DDD"}})
        with (ldir / "QM5_book.log").open("a", encoding="utf-8") as fh:
            fh.write(rec + "\n")
        local = tmp / "terminal" / "baselines"
        local.mkdir(parents=True)
        for path in common.glob("*.json"):
            (local / path.name).write_bytes(path.read_bytes())
        _write_json(local / "QM5_9401_EURUSD.json", {"hash": "LOCAL-DIFFERENT"})

        with mock.patch.object(health, "LIVE_TERMINAL_BASELINE_DIR", local), \
                mock.patch.object(health, "LIVE_COMMON_BASELINE_DIR", common), \
                mock.patch.object(health, "LIVE_QM_LOG_DIR", ldir), \
                mock.patch.object(health, "DXZ_BOOK_MANIFEST", manifest):
            res = health.chk_ks_baseline_dormancy()

        self.assertEqual(res["status"], "FAIL")
        self.assertIn("mirror_divergent=1", res["detail"])

    def test_missing_manifest_is_unknown_not_green(self):
        tmp = Path(self.enterContext(_tmpdir()))
        with mock.patch.object(health, "DXZ_BOOK_MANIFEST", tmp / "nope.json"):
            res = health.chk_ks_baseline_dormancy()
        self.assertEqual(res["status"], "WARN")
        self.assertIn("manifest_unavailable", str(res["value"]))


class SeedAuthFailureRateTest(unittest.TestCase):
    def _run(self, rows):
        tmp = Path(self.enterContext(_tmpdir()))
        db = tmp / "farm.sqlite"
        _make_db(db, rows)
        with mock.patch.object(health, "DB", db):
            con = health._connect()
            try:
                return health.chk_seed_auth_failure_rate(con)
            finally:
                con.close()

    def _q07(self, ea, reason, mtime=IN_WINDOW):
        return dict(ea_id=ea, symbol="EURUSD.DWX", phase="Q07", verdict="INVALID" if reason else "PASS",
                    profit_factor=1.2, trades=100, drawdown_money=None, evidence_path=None,
                    evidence_mtime=mtime, detail_json=json.dumps({"reason": reason or "variance_pct=1.0"}))

    def test_high_rate_fails(self):
        rows = [self._q07(f"QM5_{i}", "seeds_invalid_evidence:[(17,'effective_seed_mismatch:requested=17:report=42')]")
                for i in range(2)] + [self._q07(f"QM5_{100+i}", None) for i in range(2)]
        res = self._run(rows)  # 2/4 = 50%
        self.assertEqual(res["status"], "FAIL")
        self.assertIn("seed_auth_failures=2", res["detail"])

    def test_low_rate_warns(self):
        rows = [self._q07("QM5_1", "seeds_invalid_evidence:[(7,'seed_evidence_missing:requested=7:effective=None:harsh_label=7')]")]
        rows += [self._q07(f"QM5_{100+i}", None) for i in range(60)]  # 1/61 = 1.6% < 5%
        res = self._run(rows)
        self.assertEqual(res["status"], "WARN")

    def test_clean_is_ok(self):
        rows = [self._q07(f"QM5_{i}", None) for i in range(10)]
        res = self._run(rows)
        self.assertEqual(res["status"], "OK")
        self.assertIn("seed_auth_failures=0", res["detail"])

    def test_out_of_window_ignored(self):
        # The out-of-window failure must NOT be counted; in-window clean rows keep the
        # denominator non-zero so this stays an OK verdict (not the UNKNOWN path).
        rows = [self._q07("QM5_1", "effective_seed_mismatch:requested=17:report=42", mtime=OUT_WINDOW)]
        rows += [self._q07(f"QM5_{100+i}", None) for i in range(5)]
        res = self._run(rows)
        self.assertEqual(res["status"], "OK")
        self.assertIn("seed_auth_failures=0", res["detail"])

    def test_zero_denominator_is_unknown_not_ok(self):
        # No in-window Q07 runs at all: the failure RATE is undefined. Codex round-2 —
        # this must be UNKNOWN (surfaced as WARN), never a green OK by absence.
        rows = [self._q07("QM5_1", "effective_seed_mismatch:requested=17:report=42", mtime=OUT_WINDOW)]
        res = self._run(rows)
        self.assertEqual(res["status"], "WARN")
        self.assertEqual(res["value"], "UNKNOWN")
        self.assertIn("UNKNOWN", res["detail"])


# --- small helpers ---------------------------------------------------------
import contextlib
import tempfile


@contextlib.contextmanager
def _tmpdir():
    d = tempfile.mkdtemp(prefix="wsf_")
    try:
        yield d
    finally:
        import shutil
        shutil.rmtree(d, ignore_errors=True)


if __name__ == "__main__":
    unittest.main(verbosity=2)
