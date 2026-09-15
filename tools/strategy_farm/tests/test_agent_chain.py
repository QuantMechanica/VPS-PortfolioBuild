"""Creator -> Critic -> Formatter chain (agent_chain.py): seat resolution, gates, receipts, critique sweep."""
from __future__ import annotations

import json
import sqlite3
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import agent_chain as ac  # noqa: E402


@pytest.fixture()
def cfg(tmp_path: Path) -> dict:
    cfg = ac.load_config()
    cfg["paths"] = {
        "artifact_root": str(tmp_path / "art"),
        "receipt_root": str(tmp_path / "rcpt"),
        "lane_log_dir": str(tmp_path / "logs"),
        "farm_db": str(tmp_path / "farm.sqlite"),
    }
    cfg["gates"] = {
        "codex_budget_line": False,
        "claude_disabled_flag": str(tmp_path / "CLAUDE_DISABLED.flag"),
        "codex_low_tokens_flag": str(tmp_path / "CODEX_LOW_TOKENS.flag"),
        "agy_low_quota_flag": str(tmp_path / "AGY_LOW_QUOTA.flag"),
    }
    return cfg


@pytest.fixture()
def fake_env() -> dict[str, str]:
    return {"QM_AGENT_CHAIN_FAKE": "1", "QM_AGENT_CHAIN": "1"}


def _open_gate(vendor: str) -> str | None:
    return None


def test_config_loads_with_cross_vendor_tables() -> None:
    cfg = ac.load_config()
    table = cfg["roles"]["critic"]["by_creator_vendor"]
    assert set(table) >= {"claude", "codex", "agy", "unknown"}
    for creator, candidates in table.items():
        first = ac.normalize_vendor(candidates[0]["vendor"])
        if creator != "unknown":
            assert first != creator, f"first critic candidate for {creator} must be cross-vendor"


def test_resolve_critic_prefers_cross_vendor_and_records_trace() -> None:
    cfg = ac.load_config()
    seat, cross, trace = ac.resolve_critic("claude", cfg, _open_gate)
    assert seat.vendor == "codex" and cross is True
    assert trace[-1]["selected"] is True
    seat, cross, _ = ac.resolve_critic("codex", cfg, _open_gate)
    assert seat.vendor == "claude" and cross is True


def test_resolve_critic_falls_back_same_vendor_only_last_and_flags_it() -> None:
    cfg = ac.load_config()

    def gate(vendor: str) -> str | None:
        return "closed" if vendor in {"codex", "agy"} else None

    seat, cross, trace = ac.resolve_critic("claude", cfg, gate)
    assert seat.vendor == "claude" and seat.model == "opus"
    assert cross is False
    assert [t.get("skipped") for t in trace[:2]] == ["closed", "closed"]


def test_resolve_critic_respects_no_agy() -> None:
    cfg = ac.load_config()

    def gate(vendor: str) -> str | None:
        return "closed" if vendor == "codex" else None

    seat, cross, trace = ac.resolve_critic("claude", cfg, gate, allow_agy=False)
    assert seat.vendor == "claude" and cross is False
    assert any(t.get("skipped") == "agy_not_allowed_for_this_spec" for t in trace)


def test_resolve_critic_raises_when_everything_gated() -> None:
    cfg = ac.load_config()
    with pytest.raises(ac.ChainGated):
        ac.resolve_critic("claude", cfg, lambda v: "closed")


def test_vendor_gate_kill_switch_and_flags(cfg: dict, tmp_path: Path) -> None:
    assert ac.vendor_gate("claude", cfg, {"QM_AGENT_CHAIN": "0"}) == "kill_switch_QM_AGENT_CHAIN=0"
    assert ac.vendor_gate("claude", cfg, {}) is None
    (tmp_path / "CLAUDE_DISABLED.flag").write_text("x")
    assert ac.vendor_gate("claude", cfg, {}) == "claude_disabled_flag"
    (tmp_path / "CODEX_LOW_TOKENS.flag").write_text("x")
    assert ac.vendor_gate("codex", cfg, {}) == "codex_low_tokens_flag"


def test_vendor_gate_codex_budget_line_denies_and_fails_closed(cfg: dict) -> None:
    cfg["gates"]["codex_budget_line"] = True
    assert ac.vendor_gate("codex", cfg, {}, budget_eval=lambda: {"allowed": False, "reason": "over_line"}) == "codex_budget_line:over_line"
    assert ac.vendor_gate("codex", cfg, {}, budget_eval=lambda: {"allowed": True}) is None

    def boom() -> dict:
        raise OSError("state unreadable")

    assert ac.vendor_gate("codex", cfg, {}, budget_eval=boom) == "codex_budget_line_unreadable:OSError"


def test_parse_critic_json_takes_last_schema_block_and_verdict_rules() -> None:
    text = (
        "notes\n```json\n{\"schema\": \"other\"}\n```\n"
        "```json\n{\"schema\": \"qm.agent-chain.critic.v1\", \"verdict\": \"PASS\", \"findings\": ["
        "{\"id\": \"F1\", \"severity\": \"blocking\"}]}\n```\n"
    )
    data = ac.parse_critic_json(text)
    assert data is not None and data["findings"][0]["id"] == "F1"
    assert ac.critic_verdict(data) == "REJECT"  # blocking overrides the declared PASS
    assert ac.critic_verdict({"schema": ac.CRITIC_SCHEMA, "verdict": "PASS", "findings": []}) == "PASS"
    assert ac.critic_verdict(None) == "UNPARSED"
    assert ac.parse_critic_json("no json here") is None


def test_render_refuses_unbound_placeholder() -> None:
    with pytest.raises(ac.ChainError):
        ac.render("creator", {"task": "t"})
    text = ac.render("creator", {"task": "T", "language": "English", "inputs": "I"})
    assert "{{" not in text and "T" in text


def test_dry_run_spends_nothing_and_writes_plan(cfg: dict, fake_env: dict, tmp_path: Path) -> None:
    spec = {"kind": "run", "task": "t", "input_paths": [], "input_texts": {"a": "b"}}
    receipt = ac.run_chain(spec, apply=False, cfg=cfg, environ=fake_env)
    assert receipt["status"] == "dry_run"
    assert receipt["stages"] == []
    assert receipt["plan"]["critic"]["cross_vendor"] is True
    assert (Path(receipt["out_dir"]) / "chain_plan.json").exists()


def test_apply_runs_three_stages_and_binds_receipt(cfg: dict, fake_env: dict, tmp_path: Path) -> None:
    src = tmp_path / "in.md"
    src.write_text("# in\n", encoding="utf-8")
    spec = {"kind": "run", "task": "t", "input_paths": [str(src), str(tmp_path / "missing.md")]}
    receipt = ac.run_chain(spec, apply=True, cfg=cfg, environ=fake_env)
    assert receipt["status"] == "ok"
    assert [s["role"] for s in receipt["stages"]] == ["creator", "critic", "formatter"]
    assert receipt["stages"][1]["cross_vendor"] is True
    assert receipt["critic_verdict"] == "GAPS" and receipt["finding_counts"] == {"major": 1}
    exists = {b["path"]: b["exists"] for b in receipt["input_bindings"]}
    assert exists[str(src)] is True and exists[str(tmp_path / "missing.md")] is False
    final = Path(receipt["final_path"]).read_text(encoding="utf-8")
    assert "## A. Zusammenfassung" in final and "## C. Bindings" in final
    assert Path(receipt["receipt_path"]).exists()
    for stage in receipt["stages"]:
        assert Path(stage["output_path"]).exists() and Path(stage["prompt_path"]).exists()


def test_revision_round_is_bounded(cfg: dict, fake_env: dict) -> None:
    spec = {"kind": "run", "task": "t", "max_rounds": 3}
    receipt = ac.run_chain(spec, apply=True, cfg=cfg, environ=fake_env)
    roles = [s["role"] for s in receipt["stages"]]
    # fake critic always returns GAPS -> creator/critic alternate, bounded by max_rounds, then formatter
    assert roles == ["creator", "critic", "creator", "critic", "creator", "critic", "formatter"]


def test_gated_chain_writes_gated_receipt(cfg: dict, tmp_path: Path) -> None:
    receipt = ac.run_chain({"kind": "run", "task": "t"}, apply=True, cfg=cfg, environ={"QM_AGENT_CHAIN": "0"})
    assert receipt["status"] == "gated" and "kill_switch" in receipt["reason"]
    assert Path(receipt["receipt_path"]).exists()


def _seed_db(path: Path, artifact: Path) -> None:
    conn = sqlite3.connect(path)
    conn.execute(
        "create table agent_tasks(id text, task_type text, state text, priority int, required_capabilities_json text, "
        "assigned_agent text, budget_class text, parent_id text, artifact_path text, verdict text, payload_json text, "
        "created_at text, updated_at text, required_skills_json text)"
    )
    rows = [
        ("aaaa1111-1", "ops_issue", "REVIEW", 70, "[]", "claude", None, None, str(artifact), "PASS: x",
         json.dumps({"title": "T", "acceptance": ["a1"], "hard_limits": ["h1"]}), "2026-09-15T00:00:00+00:00", "2026-09-15T01:00:00+00:00", "[]"),
        ("bbbb2222-1", "review_ea", "REVIEW", 90, "[]", "codex", None, None, str(artifact), "PASS", "{}",
         "2026-09-15T00:00:00+00:00", "2026-09-15T01:00:00+00:00", "[]"),
        ("cccc3333-1", "ops_issue", "REVIEW", 60, "[]", None, None, None, str(artifact), "PASS",
         json.dumps({"decision_bound_agent": "codex", "title": "U"}), "2026-09-15T00:00:00+00:00", "2026-09-15T01:00:00+00:00", "[]"),
        ("dddd4444-1", "ops_issue", "APPROVED", 99, "[]", "claude", None, None, str(artifact), "PASS", "{}",
         "2026-09-15T00:00:00+00:00", "2026-09-15T01:00:00+00:00", "[]"),
    ]
    conn.executemany("insert into agent_tasks values(?,?,?,?,?,?,?,?,?,?,?,?,?,?)", rows)
    conn.commit()
    conn.close()


def test_critique_sweep_selects_review_rows_skips_review_ea_and_receipted(cfg: dict, fake_env: dict, tmp_path: Path) -> None:
    artifact = tmp_path / "deliv.md"
    artifact.write_text("RESULT verdict=PASS\n", encoding="utf-8")
    db = Path(cfg["paths"]["farm_db"])
    _seed_db(db, artifact)
    conn = ac._connect_ro(db)
    try:
        rows = ac.pending_review_tasks(cfg, conn, limit=10)
        assert [r["id"] for r in rows] == ["aaaa1111-1", "cccc3333-1"]  # priority desc, review_ea + APPROVED skipped
        spec = ac.build_critique_spec("aaaa1111", cfg, conn)
        assert spec["existing_artifact"]["vendor"] == "claude"
        assert spec["existing_artifact"]["executor_source"] == "assigned_agent"
        receipt = ac.run_chain(spec, apply=True, cfg=cfg, environ=fake_env)
        assert receipt["status"] == "ok"
        assert receipt["stages"][0]["status"] == "reused"
        assert receipt["stages"][1]["seat"]["vendor"] == "codex" and receipt["stages"][1]["cross_vendor"] is True
        assert (Path(cfg["paths"]["receipt_root"]) / "tasks" / "aaaa1111-1.json").exists()
        assert [r["id"] for r in ac.pending_review_tasks(cfg, conn, limit=10)] == ["cccc3333-1"]
        spec_c = ac.build_critique_spec("cccc3333", cfg, conn)
        assert spec_c["existing_artifact"]["vendor"] == "codex"
        assert spec_c["existing_artifact"]["executor_source"] == "decision_bound_agent"
        plan = ac.run_chain(spec_c, apply=False, cfg=cfg, environ=fake_env)
        assert plan["plan"]["critic"]["vendor"] == "claude" and plan["plan"]["critic"]["cross_vendor"] is True
    finally:
        conn.close()


def test_critique_never_touches_agent_tasks(cfg: dict, fake_env: dict, tmp_path: Path) -> None:
    artifact = tmp_path / "deliv.md"
    artifact.write_text("RESULT\n", encoding="utf-8")
    db = Path(cfg["paths"]["farm_db"])
    _seed_db(db, artifact)
    before = sqlite3.connect(db).execute("select id, state, verdict, artifact_path, payload_json from agent_tasks order by id").fetchall()
    conn = ac._connect_ro(db)
    try:
        for row in ac.pending_review_tasks(cfg, conn, limit=10):
            ac.run_chain(ac.build_critique_spec(str(row["id"]), cfg, conn), apply=True, cfg=cfg, environ=fake_env)
    finally:
        conn.close()
    after = sqlite3.connect(db).execute("select id, state, verdict, artifact_path, payload_json from agent_tasks order by id").fetchall()
    assert before == after
