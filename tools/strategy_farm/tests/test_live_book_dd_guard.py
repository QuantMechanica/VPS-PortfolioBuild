from __future__ import annotations

import datetime as dt
import json
import sys
from pathlib import Path

from tools.strategy_farm import live_book_dd_guard as guard


NOW = dt.datetime(2026, 8, 22, 10, 50, tzinfo=dt.UTC)
LOGIN = 4000090541


def _snapshot(*, observed_at: str = "2026-08-22T10:49:30Z") -> dict:
    return {
        "account_login": LOGIN,
        "time_utc": observed_at,
        "equity": 99_095.26,
        "balance": 99_095.26,
        "free_margin": 99_095.26,
        "write_ok": True,
    }


def _configure_paths(monkeypatch, tmp_path: Path) -> Path:
    snapshot_path = tmp_path / "account_snapshot.json"
    monkeypatch.setattr(guard, "ACCOUNT_SNAPSHOT_JSON", snapshot_path)
    monkeypatch.setattr(guard, "STATE_JSON", tmp_path / "state.json")
    monkeypatch.setattr(guard, "GUARD_LOG", tmp_path / "guard.log")
    monkeypatch.setattr(guard, "ALARM_LOG", tmp_path / "alarms.log")
    monkeypatch.setattr(guard, "QM_LOG_DIR", tmp_path / "qm_logs")
    monkeypatch.setattr(guard, "SIGNAL_TARGETS", (tmp_path / "portfolio_dd.signal",))
    monkeypatch.setattr(guard, "_now_utc", lambda: NOW)
    return snapshot_path


def test_reads_fresh_account_snapshot_values_and_login(monkeypatch, tmp_path: Path) -> None:
    snapshot_path = _configure_paths(monkeypatch, tmp_path)
    snapshot_path.write_text(json.dumps(_snapshot()), encoding="utf-8")

    equity, balance, free_margin, observed_at, login, error = (
        guard._read_account_snapshot()
    )

    assert error == ""
    assert (equity, balance, free_margin, login) == (
        99_095.26,
        99_095.26,
        99_095.26,
        LOGIN,
    )
    assert observed_at == dt.datetime(2026, 8, 22, 10, 49, 30, tzinfo=dt.UTC)


def test_rejects_snapshot_when_writer_did_not_complete(monkeypatch, tmp_path: Path) -> None:
    snapshot_path = _configure_paths(monkeypatch, tmp_path)
    payload = _snapshot()
    payload["write_ok"] = False
    snapshot_path.write_text(json.dumps(payload), encoding="utf-8")

    *values, error = guard._read_account_snapshot()

    assert values == [None, None, None, None, None]
    assert error == "account_snapshot_writer_not_ok"


def test_negative_equity_or_free_margin_remains_valid_drawdown_evidence(
    monkeypatch, tmp_path: Path
) -> None:
    snapshot_path = _configure_paths(monkeypatch, tmp_path)
    payload = _snapshot()
    payload["equity"] = -100.0
    payload["free_margin"] = -500.0
    snapshot_path.write_text(json.dumps(payload), encoding="utf-8")

    equity, balance, free_margin, observed_at, login, error = (
        guard._read_account_snapshot()
    )

    assert error == ""
    assert (equity, balance, free_margin, login) == (-100.0, 99_095.26, -500.0, LOGIN)
    assert observed_at is not None


def test_main_persists_fresh_source_and_never_signals_below_limit(
    monkeypatch, tmp_path: Path
) -> None:
    snapshot_path = _configure_paths(monkeypatch, tmp_path)
    snapshot_path.write_text(json.dumps(_snapshot()), encoding="utf-8")
    guard.STATE_JSON.write_text(
        json.dumps({"hwm_equity": 101_871.44, "breached": False}),
        encoding="utf-8",
    )
    monkeypatch.setattr(sys, "argv", ["live_book_dd_guard.py"])

    assert guard.main() == 0

    state = json.loads(guard.STATE_JSON.read_text(encoding="utf-8"))
    assert state["equity_source"] == "account_snapshot"
    assert state["account_snapshot_age_sec"] == 30.0
    assert state["account_login"] == LOGIN
    assert state["last_equity"] == 99_095.26
    assert state["last_free_margin"] == 99_095.26
    assert state["breached"] is False
    assert not guard.SIGNAL_TARGETS[0].exists()
    log = guard.GUARD_LOG.read_text(encoding="utf-8")
    assert "source=account_snapshot" in log
    assert "snapshot_age_sec=30.0" in log


def test_severe_drawdown_still_signals_when_free_margin_is_negative(
    monkeypatch, tmp_path: Path
) -> None:
    snapshot_path = _configure_paths(monkeypatch, tmp_path)
    payload = _snapshot()
    payload["equity"] = 85_000.0
    payload["free_margin"] = -1_000.0
    snapshot_path.write_text(json.dumps(payload), encoding="utf-8")
    guard.STATE_JSON.write_text(
        json.dumps({"hwm_equity": 100_000.0, "breached": False}),
        encoding="utf-8",
    )
    monkeypatch.setattr(sys, "argv", ["live_book_dd_guard.py"])

    assert guard.main() == 0

    signal = json.loads(guard.SIGNAL_TARGETS[0].read_text(encoding="utf-8"))
    assert signal["reason"] == "book_max_drawdown_halt"
    assert signal["dd_pct"] == 15.0
    assert json.loads(guard.STATE_JSON.read_text(encoding="utf-8"))["breached"] is True


def test_stale_snapshot_fails_closed_as_blind(monkeypatch, tmp_path: Path) -> None:
    snapshot_path = _configure_paths(monkeypatch, tmp_path)
    snapshot_path.write_text(
        json.dumps(_snapshot(observed_at="2026-08-22T10:40:00Z")),
        encoding="utf-8",
    )
    monkeypatch.setattr(sys, "argv", ["live_book_dd_guard.py"])

    assert guard.main() == 0

    state = json.loads(guard.STATE_JSON.read_text(encoding="utf-8"))
    assert state["blind_runs"] == 1
    assert not guard.SIGNAL_TARGETS[0].exists()
    assert "BLIND stale_account_snapshot" in guard.GUARD_LOG.read_text(
        encoding="utf-8"
    )


def test_default_freshness_contract_has_no_event_pulse_fallback() -> None:
    source = Path(guard.__file__).read_text(encoding="utf-8")

    assert guard.DEFAULT_MAX_ACCOUNT_SNAPSHOT_AGE_SEC == 180.0
    assert "_read_pulse" not in source
    assert "DEFAULT_MAX_EQUITY_AGE_MIN" not in source
    assert "3000" not in source
