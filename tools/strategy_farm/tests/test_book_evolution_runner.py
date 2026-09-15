"""Regression tests for the weekly book-evolution ceremony runner (Phase H).

Directive OWNER-DEC-CBE-20260915 sections 6, 61, 64, 68H, 70 + follow-up section 12.
Covered:
* end-to-end dry run (friday-cut -> saturday-analysis -> sunday-recommendation) that
  concludes KEEP for an unchanged fixture and CHANGE for a clearly superior challenger,
* byte-identical outputs on re-run (evaluate is a pure function of the frozen cut),
* NO candidate-count condition anywhere in the runner (grep the source for '25'),
* OWNER decision-card idempotency (created -> unchanged; a DECIDED card is kept),
* refusal to overwrite a CLOSED cut without --force-new-cut,
* runtime-verify never writes outside its own report.

The runner's orchestration is what this slice owns; the recompose ENGINE has its own
tests (test_recompose_engine.py), so freeze/evaluate/chain are injected as deterministic
fakes here to keep the suite hermetic (no MT5, no tokens, no Vault, no farm DB).
"""
from __future__ import annotations

import datetime as dt
import json
import re
import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import book_evolution_runner as ber  # noqa: E402
from tools.strategy_farm import owner_decision_store as ods  # noqa: E402

WEEK = "2026-W38"
FROZEN_AT = ber.friday_close_instant(WEEK).isoformat()


# ---------------------------------------------------------------------------
# Deterministic fakes for the E1 engine + the critic chain.
# ---------------------------------------------------------------------------
def _fake_manifest(venue: str, iso_week: str) -> dict:
    return {
        "schema": "qm.recompose-frozen-inputs/v1",
        "venue": venue,
        "iso_week": iso_week,
        "frozen_at_utc": FROZEN_AT,
        "seed": 20260918,
        "qualified_pool": {"count": 3, "definition": "test", "pairs": ["1:AUDUSD", "2:EURUSD", "3:XAUUSD"]},
        "incumbents": [{"label": "live-24"}],
        "streams": {"count_present": 3, "count_missing": 0, "missing": []},
    }


def _fake_freeze(venue, out, *, as_of=None, seed=None):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    manifest = _fake_manifest(venue, WEEK)
    (out / "manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return manifest


def _read_model(venue: str, outcome: str) -> dict:
    change = outcome not in ber.KEEP_OUTCOMES
    return {
        "schema": "qm.book-evolution-venue/v1",
        "venue": venue,
        "iso_week": WEEK,
        "generated_at_utc": FROZEN_AT,
        "incumbent": {"label": "live-24", "sleeve_count": 24, "total_risk_pct": 9.75, "sleeves": []},
        "evidence": {"live_equity": 100000.0},
        "qualified_pool": {"count": 3, "definition": "test", "csv_path": "x"},
        "challengers": [{"ea_id": 10700, "symbol": "XAUUSD", "highest_gate": "Q14"}],
        "proposal": {
            "outcome": outcome,
            "changes": ([{"outcome": "ADD_SLEEVE", "add": [[10700, "XAUUSD"]]}] if change else []),
            "expected_metrics": {"sharpe": 2.4, "max_drawdown_pct": 3.1},
            "materiality": {"material": bool(change), "reasons": (["delta_objective>0"] if change else ["noise"])},
            "confidence": 0.82,
            "operational_risk": "low",
            "risk_diagnostics": {"status": "PRESENT", "cap_warnings": [], "hard_guards_passed": True},
        },
        "recommendation_text": f"{venue.upper()} weekly recomposition ({WEEK}): {outcome}.",
        "owner_action": ("NONE" if not change else "REVIEW_PROPOSED_CHANGE (prepared artifacts; OWNER-only live)"),
    }


def _make_evaluate(outcomes: dict):
    def _fake_evaluate(venue, snapshot, out, *, book_evolution_root=None, **kwargs):
        rm = _read_model(venue, outcomes[venue])
        out = Path(out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(rm, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        eval_dir = Path(book_evolution_root) / WEEK / venue
        eval_dir.mkdir(parents=True, exist_ok=True)
        evaluation = {"schema": "qm.recompose-evaluation/v1", "venue": venue, "iso_week": WEEK,
                      "generated_at_utc": FROZEN_AT, "proposal": rm["proposal"], "read_model": rm}
        (eval_dir / "evaluation.json").write_text(
            json.dumps(evaluation, indent=2, sort_keys=True) + "\n", encoding="utf-8")
        (eval_dir / "evidence.md").write_text(
            f"# Book evolution evidence - {venue.upper()} {WEEK}\n\nOutcome: {outcomes[venue]}\n", encoding="utf-8")
        return rm
    return _fake_evaluate


def _fake_chain(spec, *, apply):  # deterministic cross-vendor critic (creator=claude -> critic=codex)
    return {
        "status": "dry_run" if not apply else "complete",
        "plan": {"critic": {"vendor": "codex", "model": "gpt-x", "cross_vendor": True}},
        "stages": [{"role": "critic", "status": "ok", "artifact_path": str(Path(spec["out_dir"]) / "critic.md")}],
        "receipt_path": str(Path(spec["out_dir"]) / "chain_receipt.json"),
    }


def _fake_chain_gated(spec, *, apply):
    return {"status": "gated", "reason": "no critic seat available (quota)"}


# ---------------------------------------------------------------------------
# Fixtures on disk
# ---------------------------------------------------------------------------
def _seed_state_inputs(state_dir: Path) -> None:
    state_dir.mkdir(parents=True, exist_ok=True)
    (state_dir / "ftmo_demo_cycle.json").write_text(json.dumps({
        "schema": "qm.ftmo-demo-cycle/v1", "sleeve_count": 8, "roster_hash": "abc123def456",
        "total_book_risk_pct": 2.5, "representative": False, "validation_days": 0,
        "validation_min_days": 14, "state": "OBSERVING",
    }), encoding="utf-8")
    (state_dir / "ftmo_challenge_readiness.json").write_text(json.dumps({
        "schema": "qm.ftmo-challenge-readiness/v1", "recommendation": "NOT_READY",
        "rationale": "no representative demo", "strongest_failure_mode": "daily_loss",
        "would_fable_buy_today": False,
    }), encoding="utf-8")
    (state_dir / "research_state.json").write_text(json.dumps({
        "schema": "qm.research-state/v1", "counts": {"survived": 1, "failed": 2},
        "hypotheses": {"total": 3}, "most_important_failed_lesson": "seasonality overfit",
        "kimi_campaigns": [{"id": "CAMP-2026-0001"}],
    }), encoding="utf-8")
    (state_dir / "factory_bottleneck.json").write_text(json.dumps({
        "schema": "qm.factory-bottleneck/v1", "bottlenecks": [{"name": "opt_census", "cost": "high"}],
        "frontier": {"Q14": 26}, "degraded_reasons": [],
    }), encoding="utf-8")
    (state_dir / "kimi_quota_state.json").write_text(json.dumps({
        "schema": "qm.kimi-quota/v1", "fetch_status": "auth_error", "source": "oauth",
        "monthly": {"used": 0}, "rolling_5h": {}, "rolling_7d": {}, "plan_status": "NORMAL",
        "extra_quota_active": False,
    }), encoding="utf-8")


class BookEvolutionRunnerTest(unittest.TestCase):
    def setUp(self):
        self._tmp = Path(self.enterContext(__import__("tempfile").TemporaryDirectory()))
        self.root = self._tmp / "book_evolution"
        self.state = self._tmp / "state"
        self.vault = self._tmp / "vault"
        _seed_state_inputs(self.state)
        # never touch the production log during tests
        ber.LOG_PATH = self._tmp / "book_evolution.log"

    # -- helpers ----------------------------------------------------------
    def _friday(self, **kw):
        return ber.friday_cut(iso_week=WEEK, root=self.root, freeze_fn=_fake_freeze,
                              run_state_builds=False, state_dir=self.state, **kw)

    def _saturday(self, outcomes, chain=_fake_chain, **kw):
        return ber.saturday_analysis(iso_week=WEEK, root=self.root,
                                     evaluate_fn=_make_evaluate(outcomes), chain_fn=chain,
                                     cross_review_apply=False, **kw)

    def _sunday(self, **kw):
        kw.setdefault("no_owner_card", True)
        kw.setdefault("no_vault", True)
        return ber.sunday_recommendation(iso_week=WEEK, root=self.root, **kw)

    # -- tests ------------------------------------------------------------
    def test_end_to_end_keep(self):
        self._friday()
        self._saturday({"dxz": "KEEP", "ftmo": "CONTINUE_OBSERVATION"})
        res = self._sunday()
        self.assertFalse(res["owner_action_required"])
        pkg = Path(res["package_path"]).read_text(encoding="utf-8")
        self.assertIn("outcome: **KEEP**", pkg)
        self.assertIn("owner_action NONE", pkg)
        self.assertEqual(res["per_venue"]["dxz"]["owner_action"], "NONE")
        self.assertEqual(res["cards"], [])

    def test_end_to_end_change(self):
        self._friday()
        self._saturday({"dxz": "ADD_SLEEVE", "ftmo": "CONTINUE_OBSERVATION"})
        res = self._sunday()
        self.assertTrue(res["owner_action_required"])
        self.assertEqual(res["per_venue"]["dxz"]["card_id"], "BOOK-EVOLUTION-2026-W38-DXZ")
        pkg = Path(res["package_path"]).read_text(encoding="utf-8")
        self.assertIn("outcome: **ADD_SLEEVE**", pkg)
        self.assertIn("Section 9 answers", pkg)
        self.assertIn("DRY-RUN commands", pkg)
        # the dry-run artifact commands must never be executed here
        self.assertIn("stage_tlive_presets_risk.py", pkg)

    def test_byte_identical_on_rerun(self):
        self._friday()
        outcomes = {"dxz": "ADD_SLEEVE", "ftmo": "CONTINUE_OBSERVATION"}
        self._saturday(outcomes)
        r1 = self._sunday()
        pkg1 = Path(r1["package_path"]).read_bytes()
        eval1 = (ber.cut_dir(self.root, WEEK, "c1") / "analysis" / WEEK / "dxz" / "evaluation.json").read_bytes()
        # re-run both weekend phases
        self._saturday(outcomes)
        r2 = self._sunday()
        pkg2 = Path(r2["package_path"]).read_bytes()
        eval2 = (ber.cut_dir(self.root, WEEK, "c1") / "analysis" / WEEK / "dxz" / "evaluation.json").read_bytes()
        self.assertEqual(pkg1, pkg2)
        self.assertEqual(eval1, eval2)

    def test_no_count_condition_in_source(self):
        # No bare "25" count threshold anywhere (WAY-TO-25 abolished). A bare 25 is one
        # not embedded in a longer number (so sha256 / 2026 do not count).
        src = Path(ber.__file__).read_text(encoding="utf-8")
        self.assertFalse(
            re.search(r"(?<!\d)25(?!\d)", src),
            "runner must carry no candidate-count condition (WAY-TO-25 abolished)",
        )

    def test_refuse_overwrite_closed_cut(self):
        self._friday()
        with self.assertRaises(ber.BookEvolutionError):
            self._friday()  # same week + default cut, already CLOSED
        # --force-new-cut mints a NEW cut id, never overwrites
        m2 = self._friday(force_new_cut=True)
        self.assertEqual(m2["cut_id"], "c2")
        self.assertTrue((ber.cut_dir(self.root, WEEK, "c1") / "cut_manifest.json").is_file())
        self.assertTrue((ber.cut_dir(self.root, WEEK, "c2") / "cut_manifest.json").is_file())

    def test_runtime_verify_writes_only_its_report(self):
        self._friday()
        self._saturday({"dxz": "KEEP", "ftmo": "CONTINUE_OBSERVATION"})
        self._sunday()
        cut = ber.cut_dir(self.root, WEEK, "c1")
        before = {p for p in cut.rglob("*") if p.is_file()}
        rep = ber.runtime_verify(
            iso_week=WEEK, root=self.root,
            live_profile_dir=self._tmp / "no_such_profile",
            ftmo_demo_state=self._tmp / "no_such_demo.json",
            verify_profile_fn=lambda *a, **k: {"status": "OK", "mismatches": [], "charts_found": 0},
        )
        after = {p for p in cut.rglob("*") if p.is_file()}
        new_files = after - before
        self.assertEqual(new_files, {cut / "verify.json"})
        self.assertEqual(rep["overall"], "INCOMPLETE")  # missing profile + demo -> incomplete, never crash

    def test_cross_review_gated_never_blocks(self):
        self._friday()
        res = self._saturday({"dxz": "KEEP", "ftmo": "CONTINUE_OBSERVATION"}, chain=_fake_chain_gated)
        cr = ber._read_json(ber._cross_review_path(ber.cut_dir(self.root, WEEK, "c1"), "dxz"))
        self.assertEqual(cr["chain_status"], "gated")
        self.assertTrue(cr["blocked_on_quota"])
        self.assertIsNone(cr["cross_vendor"])
        # analysis still completes with an outcome
        self.assertEqual(res["venues"]["dxz"]["outcome"], "KEEP")


# ---------------------------------------------------------------------------
# OWNER decision-card idempotency (owner_decision_store.upsert_open_item)
# ---------------------------------------------------------------------------
class OwnerCardIdempotencyTest(unittest.TestCase):
    def setUp(self):
        self._tmp = Path(self.enterContext(__import__("tempfile").TemporaryDirectory()))
        self.feed = self._tmp / "owner_decisions.json"
        self._write_feed([])

    def _write_feed(self, items):
        self.feed.write_text(json.dumps({
            "schema_version": ods.FEED_SCHEMA, "revision": 0,
            "updated_at_utc": "2026-09-15T00:00:00Z", "items": items,
        }, indent=2), encoding="utf-8")

    def _card(self):
        return {
            "id": "BOOK-EVOLUTION-2026-W38-DXZ", "status": "OPEN", "category": "Book evolution",
            "severity": "action", "question": "Apply the proposed ADD_SLEEVE?",
            "recommendation": "Review.", "yes_effect": "Prepare artifacts.",
            "no_effect": "Keep the book.", "cost_of_wait": "Defers a material improvement.",
            "evidence": ["D:/QM/reports/book_evolution/2026-W38/OWNER_DECISION_PACKAGE.md"],
            "created_at_utc": "2026-09-18T21:15:00+00:00",
        }

    def test_created_then_unchanged(self):
        r1 = ods.upsert_open_item(self._card(), feed_path=self.feed, sync_vault=False)
        self.assertEqual(r1["action"], "created")
        rev1 = json.loads(self.feed.read_text(encoding="utf-8"))["revision"]
        r2 = ods.upsert_open_item(self._card(), feed_path=self.feed, sync_vault=False)
        self.assertEqual(r2["action"], "unchanged")
        rev2 = json.loads(self.feed.read_text(encoding="utf-8"))["revision"]
        self.assertEqual(rev1, rev2, "an idempotent re-run must not move the revision")

    def test_terminal_card_kept(self):
        item = self._card()
        item["status"] = "DECIDED"
        item["last_decision"] = "NO"
        self._write_feed([item])
        r = ods.upsert_open_item(self._card(), feed_path=self.feed, sync_vault=False)
        self.assertEqual(r["action"], "terminal_kept")
        self.assertEqual(r["item"]["status"], "DECIDED")


if __name__ == "__main__":
    unittest.main()
