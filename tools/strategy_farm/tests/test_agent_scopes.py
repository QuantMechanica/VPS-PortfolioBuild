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
