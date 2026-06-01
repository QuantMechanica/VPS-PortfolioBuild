"""Tests for agent_scopes — fail-closed enforcement + audit (DL-065 Task G)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

SF = Path(__file__).resolve().parents[1]
if str(SF) not in sys.path:
    sys.path.insert(0, str(SF))

import agent_scopes as sc  # noqa: E402


# ---- is_allowed against the real policy -----------------------------------

def test_unknown_agent_denied_everything():
    assert sc.is_allowed("nobody", "repo.read") is False
    assert sc.is_allowed("nobody", "git.push.main") is False


def test_unknown_scope_denied():
    assert sc.is_allowed("claude", "totally.made.up") is False


def test_codex_branch_only_denied_main_push():
    assert sc.is_allowed("codex", "git.push.main") is False
    assert sc.is_allowed("codex", "ea.compile") is True


def test_gemini_research_only():
    assert sc.is_allowed("gemini", "mt5.backtest.dispatch") is False
    assert sc.is_allowed("gemini", "research.web") is True


def test_live_autotrade_denied_for_all():
    for agent in ("claude", "codex", "gemini"):
        assert sc.is_allowed(agent, "live.autotrade") is False


def test_claude_broadest():
    assert sc.is_allowed("claude", "git.push.main") is True
    assert sc.is_allowed("claude", "fleet.recompile") is True
    assert sc.is_allowed("claude", "external.send") is False  # explicit deny


# ---- deny_explicit beats grants (synthetic policy) ------------------------

def test_deny_explicit_beats_grants():
    pol = sc.Policy({"agents": {"x": {"grants": ["a.b"], "deny_explicit": ["a.b"]}}})
    assert sc.is_allowed("x", "a.b", pol) is False


# ---- broken policy -> fail-closed except repo.read ------------------------

def test_broken_policy_fail_closed(tmp_path):
    bad = tmp_path / "missing.json"
    pol = sc.load_policy(bad)
    assert pol.broken is True
    assert sc.is_allowed("claude", "repo.read", pol) is True
    assert sc.is_allowed("claude", "git.push.main", pol) is False
    assert sc.is_allowed("codex", "ea.compile", pol) is False


# ---- require audits exactly one event with the right decision -------------

def _patch_event(monkeypatch):
    import farmctl
    calls: list[tuple] = []
    monkeypatch.setattr(farmctl, "event",
                        lambda conn, et, eid, name, detail: calls.append((et, eid, name, detail)))
    return calls


def test_require_allow_audits_once(monkeypatch):
    calls = _patch_event(monkeypatch)
    sc.require("claude", "git.push.main", tool="git_push", args_summary="HEAD:main", conn=object())
    assert len(calls) == 1
    et, eid, name, detail = calls[0]
    assert et == "agent_audit" and eid == "claude" and name == "git.push.main"
    assert detail["decision"] == "ALLOW"


def test_require_deny_audits_and_raises(monkeypatch):
    calls = _patch_event(monkeypatch)
    with pytest.raises(sc.ScopeDenied):
        sc.require("codex", "git.push.main", tool="git_push", args_summary="HEAD:main", conn=object())
    assert len(calls) == 1
    assert calls[0][3]["decision"] == "DENY"


def test_require_unknown_identity_defaults_fail_closed(monkeypatch):
    calls = _patch_event(monkeypatch)
    monkeypatch.delenv("QM_AGENT_ID", raising=False)
    with pytest.raises(sc.ScopeDenied):
        sc.require(None, "ea.compile", tool="compile", conn=object())
    assert calls[0][1] == "unknown" and calls[0][3]["decision"] == "DENY"


# ---- guard(): controller-safe choke point ---------------------------------

def test_guard_trusted_base_passes(monkeypatch):
    calls = _patch_event(monkeypatch)
    monkeypatch.setenv("QM_AGENT_ID", "controller")
    sc.guard("git.push.main", tool="push", args_summary="HEAD:main", conn=object())  # no raise
    assert calls[0][1] == "controller" and calls[0][3]["decision"] == "ALLOW"


def test_guard_unset_identity_fails_closed(monkeypatch):
    calls = _patch_event(monkeypatch)
    monkeypatch.delenv("QM_AGENT_ID", raising=False)
    with pytest.raises(sc.ScopeDenied):
        sc.guard("git.push.main", tool="push", args_summary="HEAD:main", conn=object())
    assert calls[0][1] == "unknown" and calls[0][3]["decision"] == "DENY"


def test_guard_enforces_spawned_codex(monkeypatch):
    calls = _patch_event(monkeypatch)
    monkeypatch.setenv("QM_AGENT_ID", "codex")
    with pytest.raises(sc.ScopeDenied):
        sc.guard("git.push.main", tool="push", conn=object())  # codex denied main push
    assert calls[0][3]["decision"] == "DENY"


def test_guard_allows_spawned_codex_in_scope(monkeypatch):
    calls = _patch_event(monkeypatch)
    monkeypatch.setenv("QM_AGENT_ID", "codex")
    sc.guard("ea.compile", tool="compile", conn=object())  # codex allowed
    assert calls[0][3]["decision"] == "ALLOW"


# ---- guarded_db_delete (DL-065 follow-up) ---------------------------------

def test_guarded_db_delete_controller_executes(monkeypatch):
    import sqlite3
    _patch_event(monkeypatch); monkeypatch.setenv("QM_AGENT_ID", "controller")
    c = sqlite3.connect(":memory:")
    c.execute("CREATE TABLE t(x)"); c.executemany("INSERT INTO t VALUES(?)", [(1,), (2,)])
    n = sc.guarded_db_delete(c, "DELETE FROM t WHERE x=?", (1,), tool="test")
    assert n == 1 and c.execute("SELECT COUNT(*) FROM t").fetchone()[0] == 1


def test_guarded_db_delete_codex_denied(monkeypatch):
    import sqlite3
    _patch_event(monkeypatch); monkeypatch.setenv("QM_AGENT_ID", "codex")
    c = sqlite3.connect(":memory:")
    c.execute("CREATE TABLE t(x)"); c.execute("INSERT INTO t VALUES(1)")
    with pytest.raises(sc.ScopeDenied):
        sc.guarded_db_delete(c, "DELETE FROM t", (), tool="test")
    assert c.execute("SELECT COUNT(*) FROM t").fetchone()[0] == 1  # delete never ran


# ---- spawn lease (R-065-3) ------------------------------------------------

def test_spawn_lease_prevents_duplicate():
    import sqlite3
    c = sqlite3.connect(":memory:")
    assert sc.acquire_spawn_lease(c, "taskA", "codex", "2026-06-01T10:00:00", "2026-06-01T10:30:00") is True
    # a second spawn path sees a live lease -> blocked (the Task-E dup guard)
    assert sc.acquire_spawn_lease(c, "taskA", "orchestration", "2026-06-01T10:05:00", "2026-06-01T10:35:00") is False
    # after expiry it is reclaimable
    assert sc.acquire_spawn_lease(c, "taskA", "codex", "2026-06-01T10:31:00", "2026-06-01T11:00:00") is True
    sc.release_spawn_lease(c, "taskA")
    assert sc.acquire_spawn_lease(c, "taskA", "codex", "2026-06-01T11:01:00", "2026-06-01T11:30:00") is True


def test_spawn_lease_error_fails_open(monkeypatch):
    class BadConn:
        def execute(self, *_args, **_kwargs):
            raise RuntimeError("boom")

    calls = _patch_event(monkeypatch)
    assert sc.acquire_spawn_lease(
        BadConn(), "taskA", "codex", "2026-06-01T10:00:00", "2026-06-01T10:30:00"
    ) is True
    assert calls[0][0] == "agent_audit"
    assert calls[0][2] == "spawn.lease"
    assert calls[0][3]["decision"] == "ALLOW"
