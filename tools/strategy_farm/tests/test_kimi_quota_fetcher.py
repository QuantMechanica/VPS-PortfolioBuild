"""kimi_quota_fetcher.py: one read-only GET to the managed usage endpoint, normalized
into kimi_quota_state.json with the directive sec32 fields, fail-closed on every error
class (auth/network/schema/disabled), and NEVER leaking the OAuth token. No live calls -
the HTTP layer is monkeypatched; the live probe evidence is in the slice report."""
from __future__ import annotations

import datetime as dt
import io
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import kimi_quota_fetcher as kqf  # noqa: E402


NOW = dt.datetime(2026, 9, 20, 12, 0, 0, tzinfo=dt.timezone.utc)
SECRET = "SECRET_ACCESS_TOKEN_MUST_NOT_LEAK"

# A fixture /usages payload shaped exactly like the live 2026-09-15 response.
USAGES_FIXTURE = {
    "usage": {"limit": "100", "remaining": "80", "resetTime": "2026-09-22T09:31:53.7Z"},
    "limits": [{"window": {"duration": 300, "timeUnit": "TIME_UNIT_MINUTE"},
                "detail": {"limit": "100", "remaining": "15", "resetTime": "2026-09-20T14:31:53Z"}}],
    "usages": {
        "limit_5h": {"used_ratio": 0.85, "reset_time": "2026-09-20T14:31:53Z"},
        "limit_7d": {"used_ratio": 0.10, "reset_time": "2026-09-22T09:31:53Z"},
    },
}
ME_FIXTURE = {
    "user_level_name": "Allegro", "status": "USER_STATUS_NORMAL", "region": "REGION_OVERSEA",
    "email": "leak@example.com", "phone": "+000", "nickname": "leaky", "user_id": "uid-123",
    "global_id": "gid-456", "avatar": "http://x/y.png",
}


def _write_cred(tmp_path: Path, *, fresh: bool = True, token: str = SECRET) -> Path:
    exp = int(NOW.timestamp()) + (3600 if fresh else -3600)
    cred = tmp_path / "kimi-code.json"
    cred.write_text(json.dumps({
        "access_token": token, "refresh_token": "refresh-secret",
        "expires_at": exp, "expires_in": 900, "scope": "kimi-code", "token_type": "Bearer",
    }), encoding="utf-8")
    return cred


def _cfg(tmp_path: Path, cred: Path, *, fetch_me: bool = True, refresh: bool = False) -> dict:
    return {
        "schema": "qm.kimi-quota-fetcher.v1",
        "enabled": True,
        "kill_switch_env": "QM_KIMI_QUOTA_FETCH",
        "base_url": "https://api.kimi.com/coding/v1",
        "credential_file": str(cred),
        "kimi_bin": str(tmp_path / "nonexistent-kimi.exe"),
        "endpoints": {"usages": "/usages", "me": "/me"},
        "fetch_me": fetch_me,
        "timeout_s": 8,
        "skew_s": 60,
        "state_path": str(tmp_path / "kimi_quota_state.json"),
        "raw_schema_version": "coding/v1/usages@test",
        "subscription_period": {"start": "2026-09-15", "end": "2026-10-15"},
        "refresh": {"via_cli": refresh, "cli_args": ["-p", "OK"], "timeout_s": 5},
        "governor": {"max_state_age_s": 1800,
                     "thresholds": {"conserve_window_ratio": 0.80,
                                    "conserve_monthly_ratio": 0.85,
                                    "exhausted_window_ratio": 0.98},
                     "runaway_guard": {"day": 120, "week": 600}},
    }


class _Resp:
    def __init__(self, payload: dict) -> None:
        self._raw = json.dumps(payload).encode("utf-8")

    def read(self) -> bytes:
        return self._raw

    def __enter__(self) -> "_Resp":
        return self

    def __exit__(self, *a) -> None:
        return None


def _fake_urlopen_ok(monkeypatch: pytest.MonkeyPatch, *, captured: list | None = None):
    def fake(req, timeout=None):  # noqa: ANN001
        url = req.full_url
        if captured is not None:
            captured.append(dict(req.headers))
        if url.endswith("/usages"):
            return _Resp(USAGES_FIXTURE)
        if url.endswith("/me"):
            return _Resp(ME_FIXTURE)
        raise AssertionError(f"unexpected url {url}")
    monkeypatch.setattr(urllib.request, "urlopen", fake)


# --- normalize (schema parse) -----------------------------------------------------

def test_normalize_parses_live_schema(tmp_path: Path) -> None:
    cred = _write_cred(tmp_path)
    state = kqf.normalize(USAGES_FIXTURE, ME_FIXTURE, _cfg(tmp_path, cred),
                          fetch_status="ok", now=NOW)
    assert state["schema"] == "qm.kimi-quota/v1"
    assert state["fetch_status"] == "ok"
    assert state["source"] == "api.kimi.com/coding/v1/usages"
    assert state["plan"] == "Allegro"
    assert state["rolling_5h"]["used_ratio"] == 0.85
    assert state["rolling_7d"]["used_ratio"] == 0.10
    assert state["monthly"] is None  # absent on this account -> honest null
    assert state["extra_quota_active"] is False
    assert state["raw_schema_version"] == "coding/v1/usages@test"
    assert state["observed_top_keys"] == ["limits", "usage", "usages"]


def test_normalize_kimi_vs_code_breakdown_when_present(tmp_path: Path) -> None:
    payload = json.loads(json.dumps(USAGES_FIXTURE))
    payload["usages"]["limit_month_total"] = {"used_ratio": 0.30, "reset_time": "2026-10-15T00:00:00Z"}
    payload["usages"]["limit_month_code"] = {"used_ratio": 0.12, "reset_time": "2026-10-15T00:00:00Z"}
    state = kqf.normalize(payload, None, _cfg(tmp_path, tmp_path / "c.json"),
                          fetch_status="ok", now=NOW)
    assert state["monthly"]["used_ratio"] == 0.30
    assert state["breakdown"]["code_ratio"] == 0.12
    assert abs(state["breakdown"]["kimi_ratio"] - 0.18) < 1e-9


def test_normalize_booster_wallet_sets_extra_quota(tmp_path: Path) -> None:
    payload = json.loads(json.dumps(USAGES_FIXTURE))
    payload["boosterWallet"] = {"balance": {"type": "BOOSTER", "amount": "500"}}
    state = kqf.normalize(payload, None, _cfg(tmp_path, tmp_path / "c.json"),
                          fetch_status="ok", now=NOW)
    assert state["extra_quota_active"] is True


def test_me_pii_is_discarded(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    cred = _write_cred(tmp_path)
    _fake_urlopen_ok(monkeypatch)
    state = kqf.fetch(_cfg(tmp_path, cred), now=NOW)
    dumped = json.dumps(state)
    for pii in ("leak@example.com", "leaky", "uid-123", "gid-456", "+000", "avatar"):
        assert pii not in dumped
    assert state["plan"] == "Allegro" and state["plan_status"] == "USER_STATUS_NORMAL"


# --- fetch end-to-end (happy path) ------------------------------------------------

def test_fetch_ok_writes_state_and_no_token_leak(tmp_path: Path,
                                                 monkeypatch: pytest.MonkeyPatch) -> None:
    cred = _write_cred(tmp_path)
    cfg = _cfg(tmp_path, cred)
    _fake_urlopen_ok(monkeypatch)
    state = kqf.fetch(cfg, now=NOW)
    assert state["fetch_status"] == "ok"
    on_disk = Path(cfg["state_path"]).read_text(encoding="utf-8")
    # The secret token must NEVER appear in the persisted state.
    assert SECRET not in on_disk and "refresh-secret" not in on_disk
    assert json.loads(on_disk)["rolling_5h"]["used_ratio"] == 0.85


def test_fetch_sends_bearer_header_but_never_persists_it(tmp_path: Path,
                                                         monkeypatch: pytest.MonkeyPatch) -> None:
    cred = _write_cred(tmp_path)
    cfg = _cfg(tmp_path, cred)
    captured: list = []
    _fake_urlopen_ok(monkeypatch, captured=captured)
    kqf.fetch(cfg, now=NOW)
    # The request DID carry the real bearer token (auth works)...
    assert any(SECRET in (h.get("Authorization", "")) for h in captured)
    # ...but the redactor masks it for any log line.
    red = kqf.redact_headers({"Authorization": f"Bearer {SECRET}", "Accept": "application/json"})
    assert red["Authorization"] == "Bearer <redacted>" and SECRET not in json.dumps(red)


# --- fail-closed classes ----------------------------------------------------------

def test_auth_error_401_falls_back(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    cred = _write_cred(tmp_path)
    cfg = _cfg(tmp_path, cred)

    def fake(req, timeout=None):  # noqa: ANN001
        raise urllib.error.HTTPError(req.full_url, 401, "Unauthorized", {},
                                     io.BytesIO(b'{"error":"invalid"}'))
    monkeypatch.setattr(urllib.request, "urlopen", fake)
    state = kqf.fetch(cfg, now=NOW)
    assert state["fetch_status"] == "auth_error"
    assert state["rolling_5h"] is None


def test_stale_token_short_circuits_to_auth_error(tmp_path: Path,
                                                  monkeypatch: pytest.MonkeyPatch) -> None:
    # Stale token + refresh disabled -> no wasted request, direct auth_error.
    cred = _write_cred(tmp_path, fresh=False)
    cfg = _cfg(tmp_path, cred, refresh=False)
    called = {"n": 0}

    def fake(req, timeout=None):  # noqa: ANN001
        called["n"] += 1
        return _Resp(USAGES_FIXTURE)
    monkeypatch.setattr(urllib.request, "urlopen", fake)
    state = kqf.fetch(cfg, now=NOW)
    assert state["fetch_status"] == "auth_error" and state["error"] == "token_stale"
    assert called["n"] == 0  # never issued the guaranteed-401 request


def test_network_timeout_falls_back(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    import socket
    cred = _write_cred(tmp_path)
    cfg = _cfg(tmp_path, cred)

    def fake(req, timeout=None):  # noqa: ANN001
        raise socket.timeout("timed out")
    monkeypatch.setattr(urllib.request, "urlopen", fake)
    state = kqf.fetch(cfg, now=NOW)
    assert state["fetch_status"] == "network_error"


def test_http_404_is_network_error(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    cred = _write_cred(tmp_path)
    cfg = _cfg(tmp_path, cred)

    def fake(req, timeout=None):  # noqa: ANN001
        raise urllib.error.HTTPError(req.full_url, 404, "Not Found", {}, io.BytesIO(b"{}"))
    monkeypatch.setattr(urllib.request, "urlopen", fake)
    assert kqf.fetch(cfg, now=NOW)["fetch_status"] == "network_error"


def test_schema_error_on_garbage_json(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    cred = _write_cred(tmp_path)
    cfg = _cfg(tmp_path, cred)

    class _Bad(_Resp):
        def read(self) -> bytes:
            return b"not json at all"
    monkeypatch.setattr(urllib.request, "urlopen", lambda req, timeout=None: _Bad({}))
    assert kqf.fetch(cfg, now=NOW)["fetch_status"] == "schema_error"


def test_kill_switch_disables_without_network(tmp_path: Path,
                                              monkeypatch: pytest.MonkeyPatch) -> None:
    cred = _write_cred(tmp_path)
    cfg = _cfg(tmp_path, cred)
    called = {"n": 0}
    monkeypatch.setattr(urllib.request, "urlopen",
                        lambda req, timeout=None: called.__setitem__("n", called["n"] + 1))
    state = kqf.fetch(cfg, env={"QM_KIMI_QUOTA_FETCH": "0"}, now=NOW)
    assert state["fetch_status"] == "disabled" and called["n"] == 0


def test_missing_credential_is_disabled(tmp_path: Path) -> None:
    cfg = _cfg(tmp_path, tmp_path / "does-not-exist.json")
    state = kqf.fetch(cfg, now=NOW)
    assert state["fetch_status"] == "disabled" and state["error"] == "credential_file_missing"


# --- freshness helper -------------------------------------------------------------

def test_is_fresh_respects_max_age(tmp_path: Path) -> None:
    fresh = {"fetch_status": "ok", "source_timestamp": kqf._utc_iso(NOW)}
    stale = {"fetch_status": "ok",
             "source_timestamp": kqf._utc_iso(NOW - dt.timedelta(seconds=3600))}
    assert kqf.is_fresh(fresh, 1800, now=NOW) is True
    assert kqf.is_fresh(stale, 1800, now=NOW) is False
    assert kqf.is_fresh({"fetch_status": "auth_error",
                         "source_timestamp": kqf._utc_iso(NOW)}, 1800, now=NOW) is False


# --- bounded refresh interval guard (directive sec31-33) ---------------------------

def _cfg_refresh(tmp_path: Path, cred: Path, *, min_interval_s: int = 21600) -> dict:
    cfg = _cfg(tmp_path, cred, refresh=True)
    cfg["refresh"]["min_interval_s"] = min_interval_s
    cfg["ledger_path"] = str(tmp_path / "kimi_usage_ledger.jsonl")
    return cfg


def test_refresh_allowed_gated_by_last_success(tmp_path: Path) -> None:
    cfg = _cfg_refresh(tmp_path, tmp_path / "c.json")
    # A recent successful fetch -> no refresh needed (clock not elapsed).
    recent = {"fetch_status": "ok", "source_timestamp": kqf._utc_iso(NOW - dt.timedelta(hours=1))}
    assert kqf.refresh_allowed(cfg, recent, NOW) is False
    # An old successful fetch AND no recent refresh -> allowed.
    old = {"fetch_status": "ok", "source_timestamp": kqf._utc_iso(NOW - dt.timedelta(hours=7))}
    assert kqf.refresh_allowed(cfg, old, NOW) is True
    # No prior state at all -> allowed.
    assert kqf.refresh_allowed(cfg, None, NOW) is True
    # A recent refresh attempt blocks even when the last success is old (no loop).
    looping = {"fetch_status": "auth_error",
               "refresh_last_utc": kqf._utc_iso(NOW - dt.timedelta(minutes=15))}
    assert kqf.refresh_allowed(cfg, looping, NOW) is False
    # via_cli off -> never.
    cfg_off = _cfg_refresh(tmp_path, tmp_path / "c.json")
    cfg_off["refresh"]["via_cli"] = False
    assert kqf.refresh_allowed(cfg_off, None, NOW) is False


def test_stale_token_recent_success_does_not_spawn_refresh(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    cred = _write_cred(tmp_path, fresh=False)  # stale token
    cfg = _cfg_refresh(tmp_path, cred)
    # Seed a RECENT successful fetch so the interval guard blocks a paid refresh.
    kqf.write_state({"fetch_status": "ok", "source_timestamp": kqf._utc_iso(NOW - dt.timedelta(minutes=30))},
                    cfg["state_path"])
    calls: list[int] = []
    monkeypatch.setattr(kqf, "_refresh_via_cli", lambda *a, **k: calls.append(1) or True)
    state = kqf.fetch(cfg, now=NOW)
    assert not calls, "refresh must not be spawned within min_interval of a success"
    assert state["fetch_status"] == "auth_error"  # stale token, fell back
    assert state["refresh_calls"] == 0


def test_stale_token_old_success_spawns_bounded_refresh_and_records(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    cred = _write_cred(tmp_path, fresh=False)  # stale token
    cfg = _cfg_refresh(tmp_path, cred)
    kqf.write_state({"fetch_status": "ok", "source_timestamp": kqf._utc_iso(NOW - dt.timedelta(hours=8))},
                    cfg["state_path"])
    calls: list[int] = []
    # Refresh "succeeds" but token stays stale (CLI ran, our fixture token unchanged).
    monkeypatch.setattr(kqf, "_refresh_via_cli", lambda *a, **k: calls.append(1) or True)
    state = kqf.fetch(cfg, now=NOW)
    assert calls, "an elapsed interval must allow one bounded refresh"
    assert state["refresh_calls"] == 1
    assert state["refresh_last_utc"] is not None
    # The refresh was recorded in the usage ledger with role 'quota_refresh'.
    ledger = Path(cfg["ledger_path"]).read_text(encoding="utf-8").strip().splitlines()
    roles = [json.loads(line)["role"] for line in ledger]
    assert "quota_refresh" in roles


def test_refresh_never_leaks_token_in_state_or_ledger(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    cred = _write_cred(tmp_path, fresh=False, token=SECRET)
    cfg = _cfg_refresh(tmp_path, cred)
    kqf.write_state({"fetch_status": "ok", "source_timestamp": kqf._utc_iso(NOW - dt.timedelta(hours=8))},
                    cfg["state_path"])
    monkeypatch.setattr(kqf, "_refresh_via_cli", lambda *a, **k: True)
    kqf.fetch(cfg, now=NOW)
    state_text = Path(cfg["state_path"]).read_text(encoding="utf-8")
    ledger_text = Path(cfg["ledger_path"]).read_text(encoding="utf-8")
    assert SECRET not in state_text and "refresh_token" not in state_text
    assert SECRET not in ledger_text
    # _print_redacted's defence-in-depth guard passes on the written state.
    kqf._print_redacted(json.loads(state_text))


def test_failed_fetch_carries_last_ok_forward(tmp_path):
    """A failed cycle must keep the previous successful snapshot under last_ok (no token)."""
    import json as _json
    import kimi_quota_fetcher as f
    state_path = tmp_path / "state.json"
    prev = {"fetch_status": "ok", "plan": "Allegro", "monthly": {"used_ratio": 0.01},
            "rolling_5h": None, "rolling_7d": None, "source": "x",
            "source_timestamp": "2026-09-15T13:00:00Z",
            "refresh_calls": 1, "refresh_last_utc": "2026-09-15T13:00:00Z"}
    state_path.write_text(_json.dumps(prev), encoding="utf-8")
    cfg = dict(f.load_config())
    cfg["state_path"] = str(state_path)
    cfg["refresh"] = dict(cfg.get("refresh") or {}, via_cli=False)
    # Point the credential lookup at an empty profile so the fetch fails before any network call.
    cfg["credential_file"] = str(tmp_path / "missing-credentials.json")
    out = f.fetch(cfg, env={"HOME": str(tmp_path), "USERPROFILE": str(tmp_path)}, write=True)
    assert out["fetch_status"] != "ok"
    assert out["last_ok"]["plan"] == "Allegro"
    assert out["last_ok"]["source_timestamp"] == "2026-09-15T13:00:00Z"
    persisted = _json.loads(state_path.read_text(encoding="utf-8"))
    assert persisted["last_ok"]["plan"] == "Allegro"
    assert "access_token" not in _json.dumps(persisted)
