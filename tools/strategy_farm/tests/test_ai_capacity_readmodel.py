"""Hermetic tests for the AI factory capacity read-model (qm.ai-capacity/v1).

Every input is a temp fixture (governor/quota state files, flag dir, agent-chain
receipt dir); the registry + agent_chain/quota-gate config are the live seams.
The determinism test pins ``now`` so the output is a pure function of the
fixtures + the fixed clock.
"""
from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import pytest

from tools.strategy_farm import ai_capacity_readmodel as ac


NOW = dt.datetime(2026, 9, 15, 18, 0, 0, tzinfo=dt.timezone.utc)


@pytest.fixture()
def state_dir(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    """Point every module-level path at temp fixtures with a known posture:

    claude exhausted (100% weekly, throttled), codex ahead (80%, throttled),
    agy spare (85.5% remaining, fast reset), kimi fresh (0% used).
    """
    reports = tmp_path / "reports"
    flags = tmp_path / "flags"
    receipts = tmp_path / "receipts"
    reports.mkdir()
    flags.mkdir()
    receipts.mkdir()

    def w(path: Path, obj: dict) -> None:
        path.write_text(json.dumps(obj), encoding="utf-8")

    w(reports / "quota_governor_state.json", {
        "ts": "2026-09-15T17:42:36Z",
        "agents": {
            "claude": {"used_pct": 100.0, "elapsed_pct": 68.9, "projected_eow_pct": 145.0,
                       "five_hour_used_pct": 48.0, "week_reset": "2026-09-17T22:00:00Z",
                       "action": "hold"},
            "codex": {"used_pct": 80.0, "elapsed_pct": 48.3, "projected_eow_pct": 166.0,
                      "week_reset": "2026-09-19T08:29:07Z", "action": "hold"},
        },
    })
    w(reports / "codex_budget_line.json", {"anchor_used": 80.0, "target_at_reset": 92.0,
                                           "reset_ts": "2026-09-19T08:29:07+00:00"})
    w(reports / "agy_quota.json", {"ok": True, "token_expired": False,
                                   "binding_remaining_pct": 85.5,
                                   "binding_reset": "2026-09-15T21:34:00Z",
                                   "checked_at": "2026-09-15T17:40:09Z"})
    w(reports / "agy_governor_state.json", {"flag_owned": False})
    w(reports / "kimi_governor_state.json", {
        "state": "NORMAL", "quota_fetch_status": "ok", "counts": {"day": 6, "week": 6},
        "caps": {"day": 120, "week": 600}, "computed_at": "2026-09-15T17:41:06Z",
        "real_quota": {
            "rolling_7d": {"used_ratio": 0.0, "reset_at": "2026-09-22T09:31:53Z"},
            "rolling_5h": {"used_ratio": 0.0, "reset_at": "2026-09-15T19:31:53Z"},
            "source_timestamp": "2026-09-15T15:41:01Z"},
    })
    # A governor log with two claude samples so burn rate is derivable.
    (reports / "quota_governor.log").write_text(
        "2026-09-15T16:42:36Z claude: used=95.0% elapsed=68.0%\n"
        "2026-09-15T17:42:36Z claude: used=100.0% elapsed=68.9%\n"
        "2026-09-15T16:42:36Z codex: used=79.0% elapsed=48.0%\n"
        "2026-09-15T17:42:36Z codex: used=80.0% elapsed=48.3%\n",
        encoding="utf-8")
    # Throttle flags present.
    (flags / "CLAUDE_DISABLED.flag").write_text("MANAGED_BY=quota_governor\n", encoding="utf-8")
    (flags / "CODEX_LOW_TOKENS.flag").write_text("MANAGED_BY=quota_governor\n", encoding="utf-8")
    # One completed cross-vendor critic receipt.
    (receipts / "chain1.json").write_text(json.dumps({
        "chain_id": "chain1", "status": "ok",
        "plan": {"creator": {"vendor": "claude"}, "critic": {"vendor": "codex", "cross_vendor": True}},
        "stages": [{"role": "critic", "cross_vendor": True}],
        "generated_at_utc": "2026-09-15T12:00:00Z"}), encoding="utf-8")

    monkeypatch.setattr(ac, "REPORTS_STATE", reports)
    monkeypatch.setattr(ac, "QUOTA_GOVERNOR_STATE", reports / "quota_governor_state.json")
    monkeypatch.setattr(ac, "QUOTA_GOVERNOR_LOG", reports / "quota_governor.log")
    monkeypatch.setattr(ac, "CODEX_BUDGET_LINE", reports / "codex_budget_line.json")
    monkeypatch.setattr(ac, "AGY_QUOTA", reports / "agy_quota.json")
    monkeypatch.setattr(ac, "AGY_GOVERNOR_STATE", reports / "agy_governor_state.json")
    monkeypatch.setattr(ac, "KIMI_GOVERNOR_STATE", reports / "kimi_governor_state.json")
    monkeypatch.setattr(ac, "FLAG_DIR", flags)
    monkeypatch.setattr(ac, "AGENT_CHAIN_RECEIPT_DIR", receipts)
    return tmp_path


def test_schema_and_providers(state_dir: Path) -> None:
    st = ac.build_ai_capacity(now=NOW)
    assert st["schema"] == "qm.ai-capacity/v1"
    assert st["generated_at_utc"] == "2026-09-15T18:00:00Z"
    names = [p["provider"] for p in st["providers"]]
    assert names == ["claude", "codex", "agy", "kimi", "owner"]


def test_quota_and_pacing(state_dir: Path) -> None:
    by = {p["provider"]: p for p in ac.build_ai_capacity(now=NOW)["providers"]}
    assert by["claude"]["quota"]["remaining_pct"] == 0.0
    assert by["claude"]["pacing_gated"] is True
    assert by["claude"]["routable_now"] is False
    assert by["codex"]["quota"]["remaining_pct"] == 20.0
    assert by["agy"]["quota"]["remaining_pct"] == 85.5
    assert by["agy"]["routable_now"] is True
    assert by["kimi"]["quota"]["remaining_pct"] == 100.0
    assert by["kimi"]["routable_now"] is True
    assert by["owner"]["quota"] is None


def test_shadow_price_orders_scarce_above_spare(state_dir: Path) -> None:
    by = {p["provider"]: p for p in ac.build_ai_capacity(now=NOW)["providers"]}
    # Exhausted claude is far scarcer than spare agy/kimi.
    assert by["claude"]["shadow_price"] == ac.SHADOW_PRICE_CAP
    assert by["agy"]["shadow_price"] < 1.0
    assert by["kimi"]["shadow_price"] < by["codex"]["shadow_price"]
    assert by["owner"]["shadow_price"] == "NOT_EVALUATED"


def test_offload_and_review(state_dir: Path) -> None:
    fleet = ac.build_ai_capacity(now=NOW)["fleet"]
    # research: saturated claude+codex -> spare agy AND kimi, actionable in-contract.
    research = [o for o in fleet["offload_opportunities"]
               if o["capability"] == "research" and o["saturated_provider"] == "claude"]
    assert research and set(research[0]["spare_in_contract"]) == {"agy", "kimi"}
    assert research[0]["actionable_now"] is True
    # code: expansion capability -> benchmark-gated.
    code = [o for o in fleet["offload_opportunities"]
            if o["capability"] == "code" and o["saturated_provider"] == "claude"]
    assert code and code[0]["benchmark_gated"] is True and code[0]["actionable_now"] is False
    rev = fleet["review_independence"]
    assert rev["present"] is True and rev["completed"] == 1 and rev["same_vendor_share"] == 0.0


def test_burn_rate_from_log(state_dir: Path) -> None:
    by = {p["provider"]: p for p in ac.build_ai_capacity(now=NOW)["providers"]}
    assert by["claude"]["burn_rate_per_hour"]["value"] == 5.0  # 95 -> 100 over 1h
    assert by["agy"]["burn_rate_per_hour"]["value"] == "NOT_EVALUATED"


def test_independent_review_flags(state_dir: Path) -> None:
    by = {p["provider"]: p for p in ac.build_ai_capacity(now=NOW)["providers"]}
    # agy/kimi routable + listed as cross-vendor critics -> available.
    assert by["agy"]["independent_review_available"] is True
    assert by["kimi"]["independent_review_available"] is True
    # claude throttled (not routable) -> not currently available as critic.
    assert by["claude"]["independent_review_available"] is False


def test_last_benchmark_evidence_missing(state_dir: Path) -> None:
    for p in ac.build_ai_capacity(now=NOW)["providers"]:
        assert p["last_benchmark_utc"] == "EVIDENCE_MISSING"


def test_deterministic(state_dir: Path) -> None:
    a = json.dumps(ac.build_ai_capacity(now=NOW), sort_keys=True)
    b = json.dumps(ac.build_ai_capacity(now=NOW), sort_keys=True)
    assert a == b


def test_render_idempotent(state_dir: Path, tmp_path: Path) -> None:
    st = ac.build_ai_capacity(now=NOW)
    page = tmp_path / "page.md"
    page.write_text(
        "# X\n\n## CONTRACT\nhand-written stays.\n\n## RUNTIME\n"
        f"{ac.BLOCK_BEGIN}\nold\n{ac.BLOCK_END}\n", encoding="utf-8")
    block = ac.render_runtime_markdown(st)
    r1 = ac.update_marked_block(page, block)
    assert r1["changed"] is True
    text1 = page.read_text(encoding="utf-8")
    assert "hand-written stays." in text1
    assert "\nold\n" not in text1  # the stale block body is replaced
    # Second identical render is a no-op.
    r2 = ac.update_marked_block(page, block)
    assert r2["changed"] is False
    assert page.read_text(encoding="utf-8") == text1


def test_render_appends_when_no_markers(tmp_path: Path, state_dir: Path) -> None:
    page = tmp_path / "nomarkers.md"
    page.write_text("# Doc\n\nbody\n", encoding="utf-8")
    block = ac.render_runtime_markdown(ac.build_ai_capacity(now=NOW))
    res = ac.update_marked_block(page, block)
    assert res["changed"] is True
    txt = page.read_text(encoding="utf-8")
    assert "body" in txt and ac.BLOCK_BEGIN in txt and ac.BLOCK_END in txt
