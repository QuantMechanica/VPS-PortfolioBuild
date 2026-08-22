"""OWNER burn-authorization window in the quota governor (fail-closed)."""
from __future__ import annotations

import datetime as dt
from pathlib import Path

from tools.strategy_farm import quota_governor as gov

NOW = dt.datetime(2026, 8, 22, 9, 0, tzinfo=dt.timezone.utc)


def _with_flag(tmp_path: Path, monkeypatch, body: str | None) -> None:
    flag = tmp_path / "CODEX_BURN_AUTHORIZED.flag"
    if body is not None:
        flag.write_text(body, encoding="utf-8")
    monkeypatch.setitem(gov.BURN_FLAGS, "codex", flag)


def test_absent_flag_means_normal_pacing(tmp_path, monkeypatch):
    _with_flag(tmp_path, monkeypatch, None)
    assert gov._burn_authorized("codex", NOW) == (False, "")


def test_valid_future_expiry_suspends_pacing(tmp_path, monkeypatch):
    _with_flag(tmp_path, monkeypatch,
               "AUTHORIZED_BY=OWNER\nexpires_at=2026-08-25T00:00:00+00:00\n")
    burn, why = gov._burn_authorized("codex", NOW)
    assert burn is True and "2026-08-25" in why


def test_expired_flag_fails_closed(tmp_path, monkeypatch):
    _with_flag(tmp_path, monkeypatch,
               "AUTHORIZED_BY=OWNER\nexpires_at=2026-08-22T08:59:00+00:00\n")
    burn, why = gov._burn_authorized("codex", NOW)
    assert burn is False and "expired" in why


def test_malformed_flag_fails_closed(tmp_path, monkeypatch):
    for body in ("no expiry line\n", "expires_at=not-a-date\n", ""):
        _with_flag(tmp_path, monkeypatch, body)
        burn, why = gov._burn_authorized("codex", NOW)
        assert burn is False and "malformed" in why


def test_naive_expiry_treated_as_utc(tmp_path, monkeypatch):
    _with_flag(tmp_path, monkeypatch, "expires_at=2026-08-25T00:00:00\n")
    assert gov._burn_authorized("codex", NOW)[0] is True


def test_unknown_agent_has_no_burn(tmp_path, monkeypatch):
    assert gov._burn_authorized("gemini", NOW) == (False, "")


def test_spawn_gate_burn_bypasses_exhaustion(tmp_path, monkeypatch):
    """A valid burn flag lets evaluate_spawn allow even without usable state."""
    from tools.strategy_farm import quota_spawn_gate as gate
    _with_flag(tmp_path, monkeypatch,
               "AUTHORIZED_BY=OWNER\nexpires_at=2099-01-01T00:00:00+00:00\n")
    real_policy, err = gate.load_policy()
    assert err is None, f"live policy unreadable: {err}"
    result = gate.evaluate_spawn(
        "codex", "build_ea", 50,
        state_path=tmp_path / "missing_state.json",
        summary_path=tmp_path / "summary.json",
        now=NOW, write_summary=False)
    assert result["allowed"] is True
    assert result["reason"].startswith("owner_burn_authorization_active")


def test_spawn_gate_expired_burn_falls_back_to_normal_gating(tmp_path, monkeypatch):
    from tools.strategy_farm import quota_spawn_gate as gate
    _with_flag(tmp_path, monkeypatch,
               "AUTHORIZED_BY=OWNER\nexpires_at=2026-08-22T08:00:00+00:00\n")
    result = gate.evaluate_spawn(
        "codex", "build_ea", 50,
        state_path=tmp_path / "missing_state.json",
        summary_path=tmp_path / "summary.json",
        now=NOW, write_summary=False)
    assert not result["reason"].startswith("owner_burn_authorization_active")
