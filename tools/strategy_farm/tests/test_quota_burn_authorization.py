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
