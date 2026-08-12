"""E4' repaired live-vs-book comparator — sampling-contract tests.

Covers Codex WS-E4 acceptance (round-1 + round-2 closure):
  1. filter live data to one signed manifest SHA, deployment epoch, account, EA/magic, symbol;
  2. match observation window (ts_utc, NOT day_key), capital, weights, cost basis, and a
     SUM-of-sleeves Monte-Carlo bound to the book — no placeholder;
  3. atomic/idempotent output; incomplete inputs -> UNKNOWN, never a silent green.

Round-2 closure adds:
  * THREE INDEPENDENT per-sleeve states (ATTACHMENT / TELEMETRY / ACTIVITY), never collapsed
    into one heartbeat: a DETACHED sleeve is an attachment defect; an ATTACHED-but-silent
    sleeve is a telemetry gap, NOT an unattached sleeve;
  * signed-manifest contract: a DRAFT bound only by SHA is UNSIGNED and cannot bind/PASS;
  * cost basis correction: the book streams DO carry swap.
"""
import json
import sys
import tempfile
import unittest
import datetime as dt
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

from portfolio import portfolio_live_forward_from_logs as lf  # noqa: E402

CONFIG = {"pass_tolerances": {"dd_tolerance": 1.5, "sharpe_band": 1.0}, "burnin_window_days": 42}


def _manifest(sleeves, *, starting_capital=100_000.0, total_risk_pct=9.75, sharpe=2.4,
              status="DRAFT", approved_by=None, signed=None):
    m = {
        "book": "DXZ",
        "status": status,
        "starting_capital": starting_capital,
        "total_risk_pct": total_risk_pct,
        "n_sleeves": len(sleeves),
        "kpis": {"sharpe": sharpe, "max_drawdown_pct": 3.0},
        "sleeves": [
            {
                "ea_id": ea,
                "symbol": sym,
                "magic_number": magic,
                "weight": rp,
                "risk_percent": rp,
            }
            for (ea, sym, magic, rp) in sleeves
        ],
    }
    if approved_by is not None:
        m["approved_by"] = approved_by
    if signed is not None:
        m["signed"] = signed
    return m


def _signed_manifest(sleeves, **kw):
    """A SIGNED manifest: approved live status + approver (mirrors the OWNER-approved book)."""
    kw.setdefault("status", "LIVE")
    kw.setdefault("approved_by", "OWNER (Fabian) 2026-07-24 - countersigned")
    return _manifest(sleeves, **kw)


def _write_manifest(path: Path, manifest) -> Path:
    path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return path


def _snapshot(ea_id, symbol, magic, ts_utc, day_key, equity):
    return {
        "ts_utc": ts_utc,
        "ea_id": ea_id,
        "slug": f"ea-{ea_id}",
        "symbol": symbol,
        "tf": "D1",
        "magic": magic,
        "event": "EQUITY_SNAPSHOT",
        "payload": {"day_key": day_key, "equity": equity, "symbol": symbol},
    }


def _lifecycle(magic, ts_utc, event, ea_id=None):
    """INIT_OK / DEINIT lifecycle line (attachment state)."""
    return {"ts_utc": ts_utc, "magic": magic, "event": event, "ea_id": ea_id}


def _trade(magic, ts_utc, event, ea_id=None):
    """TM_OPEN / ENTRY_ACCEPTED / TM_CLOSE activity line."""
    return {"ts_utc": ts_utc, "magic": magic, "event": event, "ea_id": ea_id}


def _write_log(path: Path, records) -> None:
    path.write_text(
        "\n".join(json.dumps(r, separators=(",", ":")) for r in records) + "\n",
        encoding="utf-8",
    )


def _epoch(s):
    return lf._parse_epoch(s)


# Two-sleeve reference book (base symbols XAUUSD / GDAXI).
SLEEVES = [(10403, "XAUUSD.DWX", 104030002, 0.6), (10911, "GDAXI.DWX", 109110003, 0.4)]


class LegacyBackwardCompat(unittest.TestCase):
    def test_no_epoch_keeps_daykey_median_path(self):
        """Dashboard call site: (log_dir, manifest) with no epoch -> unchanged behavior."""
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            _write_log(d / "QM5_1001_ea-1001.log", [
                {"event": "EQUITY_SNAPSHOT", "payload": {"day_key": 20260718, "equity": 100_001.0}},
                {"event": "EQUITY_SNAPSHOT", "payload": {"day_key": 20260719, "equity": 100_011.0}},
            ])
            _write_log(d / "QM5_1002_ea-1002.log", [
                {"event": "EQUITY_SNAPSHOT", "payload": {"day_key": 20260718, "equity": 100_003.0}},
                {"event": "EQUITY_SNAPSHOT", "payload": {"day_key": 20260719, "equity": 100_013.0}},
            ])
            res = lf.collect_forward_equity_from_logs(d, {"starting_capital": 100_000.0})
        self.assertEqual(res["equity_curve"], [100_002.0, 100_012.0])  # median, never summed
        self.assertEqual(res["daily_pnl"], [10.0])
        self.assertEqual(res["sleeves"], {})


class IdentityAndWindow(unittest.TestCase):
    def _logs(self, d: Path):
        # 10403 + 10911 are manifest sleeves; 99999/104039999 is a FOREIGN magic.
        _write_log(d / "QM5_10403_ea-10403.log", [
            _lifecycle(104030002, "2026-07-16T21:00:00Z", "INIT_OK"),
            _snapshot(10403, "XAUUSD", 104030002, "2026-07-16T22:00:00Z", 20260716, 100_000.0),
            # day_key PINS to Friday 20260717 but ts_utc is 07-19 -> must be IN a 07-19 epoch window
            _snapshot(10403, "XAUUSD", 104030002, "2026-07-19T22:00:00Z", 20260717, 100_500.0),
            _snapshot(10403, "XAUUSD", 104030002, "2026-07-20T22:00:00Z", 20260720, 100_800.0),
        ])
        _write_log(d / "QM5_10911_ea-10911.log", [
            _lifecycle(109110003, "2026-07-16T21:00:00Z", "INIT_OK"),
            _snapshot(10911, "GDAXI", 109110003, "2026-07-16T22:00:00Z", 20260716, 100_000.0),
            _snapshot(10911, "GDAXI", 109110003, "2026-07-19T22:00:00Z", 20260717, 100_500.0),
            _snapshot(10911, "GDAXI", 109110003, "2026-07-20T22:00:00Z", 20260720, 100_800.0),
        ])
        # foreign EA emitting an account snapshot — must be excluded + flagged unexpected.
        _write_log(d / "QM5_99999_ea-99999.log", [
            _snapshot(99999, "USDJPY", 999990000, "2026-07-20T22:00:00Z", 20260720, 55_555.0),
        ])

    def test_window_uses_ts_utc_not_daykey_and_filters_identity(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            self._logs(d)
            man = _manifest(SLEEVES)
            ids = lf.manifest_identities(man)
            res = lf.collect_forward_equity_from_logs(
                d, man, deployment_epoch="2026-07-19", identities=ids)
        # 07-16 (ts before epoch) excluded despite valid day_key; 07-19 (pinned day_key) INCLUDED.
        self.assertEqual(res["dates"], ["2026-07-19", "2026-07-20"])
        self.assertEqual(res["n_days"], 2)
        # account-wide equity: median across the two manifest sleeves (identical here).
        self.assertEqual(res["equity_curve"], [100_500.0, 100_800.0])
        self.assertEqual(res["daily_pnl"], [300.0])
        cov = res["three_state_coverage"]
        self.assertIn(999990000, cov["foreign_emitting_in_window"])  # foreign flagged
        self.assertEqual(cov["attachment"]["detached"], [])  # both book sleeves attached
        # foreign 55_555 equity never leaked into the curve.
        self.assertNotIn(55_555.0, res["equity_curve"])

    def test_future_epoch_yields_empty_window(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            self._logs(d)
            man = _manifest(SLEEVES)
            res = lf.collect_forward_equity_from_logs(d, man, deployment_epoch="2026-08-01")
        self.assertEqual(res["n_days"], 0)
        self.assertEqual(res["dates"], [])
        # foreign 07-20 emit is BEFORE the future epoch -> not flagged in-window.
        self.assertEqual(res["three_state_coverage"]["foreign_emitting_in_window"], [])

    def test_prewindow_foreign_ea_not_flagged_unexpected(self):
        """Coverage is window-scoped: an EA that emitted only BEFORE the epoch is not flagged."""
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            _write_log(d / "QM5_10403_ea-10403.log", [
                _lifecycle(104030002, "2026-07-18T21:00:00Z", "INIT_OK"),
                _snapshot(10403, "XAUUSD", 104030002, "2026-07-20T22:00:00Z", 20260720, 100_800.0),
            ])
            _write_log(d / "QM5_10911_ea-10911.log", [
                _lifecycle(109110003, "2026-07-18T21:00:00Z", "INIT_OK"),
                _snapshot(10911, "GDAXI", 109110003, "2026-07-20T22:00:00Z", 20260720, 100_800.0),
            ])
            # foreign EA emitted ONLY before the epoch -> must NOT appear as unexpected.
            _write_log(d / "QM5_88888_ea-88888.log", [
                _snapshot(88888, "USDJPY", 888880000, "2026-07-10T22:00:00Z", 20260710, 99_000.0),
            ])
            man = _manifest(SLEEVES)
            res = lf.collect_forward_equity_from_logs(d, man, deployment_epoch="2026-07-19")
        cov = res["three_state_coverage"]
        self.assertNotIn(888880000, cov["foreign_emitting_in_window"])
        self.assertEqual(res["identity_coverage"]["identities_match"], True)  # attached + no foreign


class ThreeIndependentStates(unittest.TestCase):
    """Codex WS-E4 round-2: ATTACHMENT / TELEMETRY / ACTIVITY are three SEPARATE states."""

    def test_attached_but_silent_is_telemetry_gap_not_detachment(self):
        """The 1567/12969/13117 shape: healthy INIT_OK, zero EQUITY_SNAPSHOT."""
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            # 10403: attached + emitting + trading (the healthy control).
            _write_log(d / "QM5_10403_ea-10403.log", [
                _lifecycle(104030002, "2026-07-19T05:00:00Z", "INIT_OK"),
                _snapshot(10403, "XAUUSD", 104030002, "2026-07-19T22:00:00Z", 20260717, 100_100.0),
                _snapshot(10403, "XAUUSD", 104030002, "2026-07-20T22:00:00Z", 20260720, 100_300.0),
                _trade(104030002, "2026-07-20T09:00:00Z", "TM_OPEN"),
            ])
            # 10911: ATTACHED (last event INIT_OK) but NEVER emits an EQUITY_SNAPSHOT.
            _write_log(d / "QM5_10911_ea-10911.log", [
                _lifecycle(109110003, "2026-07-19T05:00:00Z", "INIT_OK"),
                _lifecycle(109110003, "2026-07-20T05:00:00Z", "INIT_OK"),
            ])
            man = _manifest(SLEEVES)
            res = lf.collect_forward_equity_from_logs(d, man, deployment_epoch="2026-07-19")
        cov = res["three_state_coverage"]
        # 10911 IS attached (not a detachment/attachment defect) ...
        self.assertIn(109110003, cov["attachment"]["attached"])
        self.assertNotIn(109110003, cov["attachment"]["detached"])
        self.assertNotIn(109110003, cov["attachment"]["no_lifecycle"])
        # ... but its telemetry IS silent (never emitted).
        self.assertIn(109110003, cov["telemetry"]["silent"])
        self.assertIn(109110003, cov["telemetry"]["silent_never_emitted"])
        self.assertIn(104030002, cov["telemetry"]["emitting"])
        # identity_coverage attachment_defect must NOT contain the silent-but-attached sleeve.
        self.assertNotIn(109110003, res["identity_coverage"]["attachment_defect"])
        # account equity curve still built from the emitting sleeve.
        self.assertEqual(res["n_days"], 2)

    def test_detached_sleeve_is_attachment_defect(self):
        """The 12778 shape: last lifecycle event is DEINIT -> DETACHED."""
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            _write_log(d / "QM5_10403_ea-10403.log", [
                _lifecycle(104030002, "2026-07-19T05:00:00Z", "INIT_OK"),
                _snapshot(10403, "XAUUSD", 104030002, "2026-07-19T22:00:00Z", 20260717, 100_100.0),
            ])
            # 10911: INIT_OK then DEINIT (never re-inits) -> DETACHED.
            _write_log(d / "QM5_10911_ea-10911.log", [
                _lifecycle(109110003, "2026-07-19T05:00:00Z", "INIT_OK"),
                _lifecycle(109110003, "2026-07-20T22:24:09Z", "DEINIT"),
            ])
            man = _manifest(SLEEVES)
            res = lf.collect_forward_equity_from_logs(d, man, deployment_epoch="2026-07-19")
        cov = res["three_state_coverage"]
        self.assertIn(109110003, cov["attachment"]["detached"])
        self.assertNotIn(109110003, cov["attachment"]["attached"])
        self.assertIn(109110003, res["identity_coverage"]["attachment_defect"])
        # a detached sleeve is NOT identities_match.
        self.assertFalse(res["identity_coverage"]["identities_match"])

    def test_no_lifecycle_when_no_init_or_deinit(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            _write_log(d / "QM5_10403_ea-10403.log", [
                _lifecycle(104030002, "2026-07-19T05:00:00Z", "INIT_OK"),
                _snapshot(10403, "XAUUSD", 104030002, "2026-07-19T22:00:00Z", 20260717, 100_100.0),
            ])
            # 10911 emits only a non-lifecycle event -> NO_LIFECYCLE.
            _write_log(d / "QM5_10911_ea-10911.log", [
                {"event": "SYMBOL_GUARD_INIT", "magic": 109110003, "ts_utc": "2026-07-19T05:00:00Z"},
            ])
            man = _manifest(SLEEVES)
            res = lf.collect_forward_equity_from_logs(d, man, deployment_epoch="2026-07-19")
        cov = res["three_state_coverage"]
        self.assertIn(109110003, cov["attachment"]["no_lifecycle"])
        self.assertIn(109110003, res["identity_coverage"]["attachment_defect"])

    def test_states_are_not_collapsed_per_sleeve(self):
        """One sleeve can be ATTACHED + SILENT + FLAT at once; each state stands alone."""
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp)
            _write_log(d / "QM5_10403_ea-10403.log", [
                _lifecycle(104030002, "2026-07-19T05:00:00Z", "INIT_OK"),
                _snapshot(10403, "XAUUSD", 104030002, "2026-07-19T22:00:00Z", 20260717, 100_100.0),
            ])
            _write_log(d / "QM5_10911_ea-10911.log", [
                _lifecycle(109110003, "2026-07-19T05:00:00Z", "INIT_OK"),  # attached, no snap, no trade
            ])
            man = _manifest(SLEEVES)
            res = lf.collect_forward_equity_from_logs(d, man, deployment_epoch="2026-07-19")
        by_magic = {s["magic"]: s for s in res["sleeve_states"]}
        s = by_magic[109110003]
        self.assertEqual(s["attachment"]["state"], "ATTACHED")
        self.assertEqual(s["telemetry"]["state"], "SILENT")
        self.assertEqual(s["telemetry"]["detail"], "never_emitted")
        self.assertEqual(s["activity"]["state"], "FLAT")
        # the emitting/trading control is independently classified.
        c = by_magic[104030002]
        self.assertEqual(c["attachment"]["state"], "ATTACHED")
        self.assertEqual(c["telemetry"]["state"], "EMITTING")


class ManifestBinding(unittest.TestCase):
    def test_sha_and_fingerprint_present_and_stable(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = _write_manifest(Path(tmp) / "m.json", _manifest(SLEEVES))
            ids1 = lf.manifest_identities(_manifest(SLEEVES), path)
            ids2 = lf.manifest_identities(_manifest(SLEEVES), path)
        self.assertEqual(len(ids1["manifest_sha256"]), 64)
        self.assertEqual(ids1["book_fingerprint"], ids2["book_fingerprint"])

    def test_fingerprint_changes_on_reweight(self):
        base = lf.manifest_identities(_manifest(SLEEVES))
        reweighted = lf.manifest_identities(
            _manifest([(10403, "XAUUSD.DWX", 104030002, 0.7),
                       (10911, "GDAXI.DWX", 109110003, 0.4)]))
        self.assertNotEqual(base["book_fingerprint"], reweighted["book_fingerprint"])

    def test_duplicate_magic_rejected(self):
        with self.assertRaises(ValueError):
            lf.manifest_identities(_manifest(
                [(10403, "XAUUSD.DWX", 104030002, 0.5),
                 (10403, "GDAXI.DWX", 104030002, 0.5)]))


class ManifestSignature(unittest.TestCase):
    """Codex WS-E4 round-2: a DRAFT bound only by SHA is NOT signed."""

    def test_draft_is_unsigned(self):
        sig = lf.manifest_signature_status(_manifest(SLEEVES, status="DRAFT"))
        self.assertEqual(sig["signature_label"], "DRAFT")
        self.assertFalse(sig["signed"])

    def test_live_with_approver_is_signed(self):
        sig = lf.manifest_signature_status(_signed_manifest(SLEEVES))
        self.assertEqual(sig["signature_label"], "SIGNED")
        self.assertTrue(sig["signed"])

    def test_live_without_approver_is_unsigned(self):
        sig = lf.manifest_signature_status(_manifest(SLEEVES, status="LIVE"))
        self.assertEqual(sig["signature_label"], "UNSIGNED")
        self.assertFalse(sig["signed"])

    def test_draft_with_signed_flag_still_unsigned(self):
        # signed=true but status DRAFT: status gate fails -> not signed.
        sig = lf.manifest_signature_status(_manifest(SLEEVES, status="DRAFT", signed=True))
        self.assertFalse(sig["signed"])

    def test_identities_carry_signature(self):
        ids = lf.manifest_identities(_signed_manifest(SLEEVES))
        self.assertTrue(ids["signature"]["signed"])

    def test_unsigned_manifest_cannot_bind_or_pass(self):
        ids = lf.manifest_identities(_manifest(SLEEVES, status="DRAFT"))
        rep = lf.build_report(
            manifest=_manifest(SLEEVES, status="DRAFT"), identities=ids,
            forward_equity=VerdictContract._clean_forward([-100.0, 50.0]),
            mc_artifact=VerdictContract._bound_mc_static(ids, 6.0), mc_reason="bound_by_fingerprint",
            account_expected=None, account_observed=None,
            deployment_epoch=_epoch("2026-07-19"), config=CONFIG,
            generated_at_utc="2026-07-26T00:00:00Z")
        self.assertEqual(rep["verdict"]["checks"]["manifest_signature"]["status"], "UNKNOWN")
        self.assertNotEqual(rep["verdict"]["verdict"], "PASS")
        self.assertFalse(rep["verdict"]["binding"])

    def test_signed_vs_unsigned_binding_gate(self):
        """Identical clean+mature inputs: SIGNED -> binding; UNSIGNED -> UNKNOWN, not binding."""
        daily = [80.0, -30.0, 60.0, -20.0, 50.0] * 9  # 45 days, small swings
        for status, approver, expect_bind in [("DRAFT", None, False),
                                              ("LIVE", "OWNER approved", True)]:
            man = _manifest(SLEEVES, status=status, approved_by=approver)
            ids = lf.manifest_identities(man)
            rep = lf.build_report(
                manifest=man, identities=ids,
                forward_equity=VerdictContract._clean_forward(daily, n_days=45),
                mc_artifact=VerdictContract._bound_mc_static(ids, 6.0),
                mc_reason="bound_by_fingerprint",
                account_expected=4000090541, account_observed=4000090541,
                deployment_epoch=_epoch("2026-07-19"), config=CONFIG,
                generated_at_utc="2026-07-26T00:00:00Z")
            self.assertEqual(rep["verdict"]["binding"], expect_bind,
                             f"binding for status={status}")
            if not expect_bind:
                self.assertEqual(rep["verdict"]["verdict"], "UNKNOWN")
            else:
                self.assertIn(rep["verdict"]["verdict"], {"PASS", "HOLD"})


class MonteCarloBinding(unittest.TestCase):
    def _ids(self):
        return lf.manifest_identities(_manifest(SLEEVES))

    def test_wrong_basis_refused(self):
        ids = self._ids()
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "mc.json"
            p.write_text(json.dumps({
                "_basis": "manifest_weighted_avg_placeholder",
                "max_drawdown_pct": {"p95": 0.92},
            }), encoding="utf-8")
            art, reason = lf.load_bound_mc(p, ids)
        self.assertIsNone(art)
        self.assertIn("not a SUM-of-sleeves", reason)

    def test_wrong_fingerprint_refused(self):
        ids = self._ids()
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "mc.json"
            p.write_text(json.dumps({
                "_basis": "sum_of_sleeves_flat_risk_calendar_daily",
                "max_drawdown_pct": {"p95": 6.0},
                "_provenance": {"book_fingerprint": "deadbeef"},
            }), encoding="utf-8")
            art, reason = lf.load_bound_mc(p, ids)
        self.assertIsNone(art)
        self.assertIn("not bound to this book", reason)

    def test_correct_binding_accepted(self):
        ids = self._ids()
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "mc.json"
            p.write_text(json.dumps({
                "_basis": lf.SUM_MC_BASIS,
                "max_drawdown_pct": {"p95": 6.0},
                "block_bootstrap": {"max_drawdown_pct": {"p95": 6.0}},
                "_provenance": {"book_fingerprint": ids["book_fingerprint"]},
            }), encoding="utf-8")
            art, reason = lf.load_bound_mc(p, ids)
        self.assertIsNotNone(art)
        self.assertEqual(reason, "bound_by_fingerprint")

    def test_build_sum_of_sleeves_from_streams_binds(self):
        ids = self._ids()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            q = root / "QM" / "q08_trades"
            q.mkdir(parents=True)
            # minimal valid TRADE_CLOSED streams for both sleeves.
            for (ea, sym, _magic, _rp) in SLEEVES:
                fname = f"{ea}_{sym.replace('.', '_')}.jsonl"
                rows = [
                    {"event": "TRADE_CLOSED", "time": 1520024400 + i * 86400,
                     "entry_time": 1520024400 + i * 86400 - 3600, "net": (-500.0 if i % 3 else 400.0),
                     "profit": (-500.0 if i % 3 else 400.0), "swap": 0.0, "commission": 0.0,
                     "volume": 0.3, "notional": 40000.0, "symbol": sym}
                    for i in range(60)
                ]
                (q / fname).write_text(
                    "\n".join(json.dumps(r) for r in rows) + "\n", encoding="utf-8")
            art, reason = lf.build_sum_of_sleeves_mc(
                ids, root, window_days=42, runs=500, seed=1,
                generated_at_utc="2026-07-26T00:00:00Z")
        self.assertIsNotNone(art)
        self.assertTrue(str(art["_basis"]).startswith("sum_of_sleeves"))
        self.assertEqual(art["_provenance"]["book_fingerprint"], ids["book_fingerprint"])
        self.assertGreaterEqual(art["max_drawdown_pct"]["p95"], 0.0)
        # cost-basis note must NOT claim swap=$0 (round-2 correction).
        note = art["_provenance"]["note"]
        self.assertIn("swap is NOT $0", note)
        self.assertNotIn("swap=$0", note)

    def test_build_refuses_missing_stream(self):
        ids = self._ids()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "QM" / "q08_trades").mkdir(parents=True)  # empty
            art, reason = lf.build_sum_of_sleeves_mc(
                ids, root, window_days=42, runs=10, seed=1,
                generated_at_utc="2026-07-26T00:00:00Z")
        self.assertIsNone(art)
        self.assertIn("absent", reason)


class VerdictContract(unittest.TestCase):
    @staticmethod
    def _clean_forward(daily_pnl, *, n_days=None, attached=None, detached=None,
                       telem_emitting=None, telem_silent=None, foreign=None):
        magics = [s[2] for s in SLEEVES]
        att = magics if attached is None else attached
        emit = magics if telem_emitting is None else telem_emitting
        return {
            "source": "t_live_per_ea_logs",
            "n_days": len(daily_pnl) + 1 if n_days is None else n_days,
            "daily_pnl": daily_pnl,
            "three_state_coverage": {
                "attachment": {"attached": att, "detached": detached or [], "no_lifecycle": []},
                "telemetry": {"emitting": emit, "silent": telem_silent or [],
                              "silent_never_emitted": telem_silent or []},
                "activity": {"trading": magics, "flat": []},
                "foreign_emitting_in_window": foreign or [],
            },
        }

    @staticmethod
    def _bound_mc_static(ids, p95):
        return {
            "_basis": lf.SUM_MC_BASIS,
            "max_drawdown_pct": {"p95": p95},
            "block_bootstrap": {"max_drawdown_pct": {"p95": p95}},
            "_provenance": {"book_fingerprint": ids["book_fingerprint"]},
        }

    def _bound_mc(self, ids, p95):
        return self._bound_mc_static(ids, p95)

    def test_no_mc_is_unknown_never_green(self):
        ids = lf.manifest_identities(_signed_manifest(SLEEVES))
        rep = lf.build_report(
            manifest=_signed_manifest(SLEEVES), identities=ids,
            forward_equity=self._clean_forward([-100.0, 50.0]),
            mc_artifact=None, mc_reason="no reference supplied",
            account_expected=None, account_observed=None,
            deployment_epoch=_epoch("2026-07-19"), config=CONFIG,
            generated_at_utc="2026-07-26T00:00:00Z")
        self.assertEqual(rep["verdict"]["checks"]["drawdown_vs_mc"]["status"], "UNKNOWN")
        self.assertNotEqual(rep["verdict"]["verdict"], "PASS")
        self.assertFalse(rep["verdict"]["binding"])

    def test_dd_fail_surfaces_even_when_immature(self):
        ids = lf.manifest_identities(_signed_manifest(SLEEVES))
        # -8000 on 100k = 8.0% DD; MC p95 6.0 + tol 1.5 = 7.5 limit -> FAIL.
        rep = lf.build_report(
            manifest=_signed_manifest(SLEEVES), identities=ids,
            forward_equity=self._clean_forward([-8000.0]),
            mc_artifact=self._bound_mc(ids, 6.0), mc_reason="bound_by_fingerprint",
            account_expected=None, account_observed=None,
            deployment_epoch=_epoch("2026-07-19"), config=CONFIG,
            generated_at_utc="2026-07-26T00:00:00Z")
        self.assertEqual(rep["verdict"]["checks"]["drawdown_vs_mc"]["status"], "FAIL")
        self.assertEqual(rep["verdict"]["verdict"], "FAIL")
        self.assertTrue(rep["maturity"]["immature"])  # short window, but FAIL still dominates

    def test_dd_pass_with_bound_reference(self):
        ids = lf.manifest_identities(_signed_manifest(SLEEVES))
        rep = lf.build_report(
            manifest=_signed_manifest(SLEEVES), identities=ids,
            forward_equity=self._clean_forward([-1000.0, 200.0]),
            mc_artifact=self._bound_mc(ids, 6.0), mc_reason="bound_by_fingerprint",
            account_expected=None, account_observed=None,
            deployment_epoch=_epoch("2026-07-19"), config=CONFIG,
            generated_at_utc="2026-07-26T00:00:00Z")
        self.assertEqual(rep["verdict"]["checks"]["drawdown_vs_mc"]["status"], "PASS")

    def test_attachment_defect_forces_unknown(self):
        """A detached sleeve (attachment defect) forces UNKNOWN even with a clean DD."""
        ids = lf.manifest_identities(_signed_manifest(SLEEVES))
        rep = lf.build_report(
            manifest=_signed_manifest(SLEEVES), identities=ids,
            forward_equity=self._clean_forward([-100.0, 50.0], detached=[109110003]),
            mc_artifact=self._bound_mc(ids, 6.0), mc_reason="bound_by_fingerprint",
            account_expected=None, account_observed=None,
            deployment_epoch=_epoch("2026-07-19"), config=CONFIG,
            generated_at_utc="2026-07-26T00:00:00Z")
        self.assertEqual(rep["verdict"]["checks"]["attachment_coverage"]["status"], "UNKNOWN")
        self.assertIn(109110003, rep["verdict"]["checks"]["attachment_coverage"]["detached"])
        self.assertEqual(rep["verdict"]["verdict"], "UNKNOWN")

    def test_telemetry_gap_is_warn_and_separate_from_attachment(self):
        """An attached-but-silent sleeve is a telemetry WARN, NOT an attachment defect."""
        ids = lf.manifest_identities(_signed_manifest(SLEEVES))
        rep = lf.build_report(
            manifest=_signed_manifest(SLEEVES), identities=ids,
            forward_equity=self._clean_forward(
                [-100.0, 50.0], telem_emitting=[104030002], telem_silent=[109110003]),
            mc_artifact=self._bound_mc(ids, 6.0), mc_reason="bound_by_fingerprint",
            account_expected=None, account_observed=None,
            deployment_epoch=_epoch("2026-07-19"), config=CONFIG,
            generated_at_utc="2026-07-26T00:00:00Z")
        checks = rep["verdict"]["checks"]
        self.assertEqual(checks["telemetry_coverage"]["status"], "WARN")
        self.assertIn(109110003, checks["telemetry_coverage"]["silent"])
        # attachment stays clean — the silent sleeve is NOT reported as detached.
        self.assertEqual(checks["attachment_coverage"]["status"], "PASS")
        self.assertNotIn(109110003, checks["attachment_coverage"]["detached"])
        # WARN is an incomplete input -> UNKNOWN, never a silent green.
        self.assertEqual(rep["verdict"]["verdict"], "UNKNOWN")
        self.assertFalse(rep["verdict"]["binding"])

    def test_empty_window_is_unknown(self):
        ids = lf.manifest_identities(_signed_manifest(SLEEVES))
        rep = lf.build_report(
            manifest=_signed_manifest(SLEEVES), identities=ids,
            forward_equity={"n_days": 0, "daily_pnl": [],
                            "three_state_coverage": {
                                "attachment": {"attached": [], "detached": [], "no_lifecycle": []},
                                "telemetry": {"emitting": [], "silent": [], "silent_never_emitted": []},
                                "activity": {"trading": [], "flat": []},
                                "foreign_emitting_in_window": []}},
            mc_artifact=None, mc_reason="no window",
            account_expected=None, account_observed=None,
            deployment_epoch=_epoch("2026-07-26"), config=CONFIG,
            generated_at_utc="2026-07-26T00:00:00Z")
        self.assertEqual(rep["verdict"]["verdict"], "UNKNOWN")

    def test_account_mismatch_flagged_not_green(self):
        ids = lf.manifest_identities(_signed_manifest(SLEEVES))
        rep = lf.build_report(
            manifest=_signed_manifest(SLEEVES), identities=ids,
            forward_equity=self._clean_forward([-100.0, 50.0]),
            mc_artifact=self._bound_mc(ids, 6.0), mc_reason="bound_by_fingerprint",
            account_expected=4000090541, account_observed=1234567,
            deployment_epoch=_epoch("2026-07-19"), config=CONFIG,
            generated_at_utc="2026-07-26T00:00:00Z")
        self.assertEqual(rep["verdict"]["checks"]["account_identity"]["status"], "MISMATCH")
        self.assertNotEqual(rep["verdict"]["verdict"], "PASS")

    def test_binding_records_sha_fingerprint_and_signature(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = _write_manifest(Path(tmp) / "m.json", _signed_manifest(SLEEVES))
            ids = lf.manifest_identities(_signed_manifest(SLEEVES), path)
            rep = lf.build_report(
                manifest=_signed_manifest(SLEEVES), identities=ids,
                forward_equity=self._clean_forward([-100.0, 50.0]),
                mc_artifact=None, mc_reason="n/a",
                account_expected=None, account_observed=None,
                deployment_epoch=_epoch("2026-07-19"), config=CONFIG,
                generated_at_utc="2026-07-26T00:00:00Z")
        self.assertEqual(len(rep["manifest_binding"]["manifest_sha256"]), 64)
        self.assertEqual(rep["manifest_binding"]["book_fingerprint"], ids["book_fingerprint"])
        self.assertEqual(rep["manifest_binding"]["signature"]["signature_label"], "SIGNED")


class CostBasis(unittest.TestCase):
    def test_cost_basis_declares_streams_carry_swap(self):
        cb = lf._cost_basis_block()
        self.assertIn("swap", cb["book_side"].lower())
        self.assertIn("NOT $0", cb["book_side"])
        self.assertNotIn("$0 (deferred", cb["book_side"])
        self.assertIn("profit + swap + commission", cb["book_side"])


class AtomicWrite(unittest.TestCase):
    def test_atomic_idempotent_and_no_temp_left(self):
        obj = {"b": 2, "a": 1, "nested": {"y": 2, "x": 1}}
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "sub" / "report.json"
            lf._atomic_write_json(obj, out)
            first = out.read_bytes()
            lf._atomic_write_json(obj, out)
            second = out.read_bytes()
            leftovers = [p.name for p in out.parent.iterdir() if ".tmp." in p.name]
        self.assertEqual(first, second)  # idempotent, sort_keys deterministic
        self.assertEqual(leftovers, [])  # temp cleaned up


if __name__ == "__main__":
    unittest.main()
