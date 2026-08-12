from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
STRATEGY_FARM = ROOT / "tools" / "strategy_farm"
if str(STRATEGY_FARM) not in sys.path:
    sys.path.insert(0, str(STRATEGY_FARM))

import agy_governor  # noqa: E402
import agy_quota  # noqa: E402


def _redirect_state(monkeypatch, tmp_path: Path) -> None:
    farm = tmp_path / "farm"
    reports = tmp_path / "reports"
    monkeypatch.setattr(agy_governor, "ROOT", farm)
    monkeypatch.setattr(agy_governor, "FLAG", farm / "AGY_LOW_QUOTA.flag")
    monkeypatch.setattr(agy_governor, "QUOTA_STATE", reports / "agy_quota.json")
    monkeypatch.setattr(agy_governor, "STATE", reports / "agy_governor_state.json")
    monkeypatch.setattr(agy_governor, "LOG", reports / "agy_governor.log")


def test_quota_auth_failure_sets_conservative_owned_gate(monkeypatch, tmp_path: Path) -> None:
    _redirect_state(monkeypatch, tmp_path)
    monkeypatch.setattr(
        agy_governor.agy_quota,
        "pull",
        lambda: {"ok": False, "error": "HTTP 401 UNAUTHENTICATED", "token_expired": True},
    )

    assert agy_governor.main([]) == 0

    flag = json.loads(agy_governor.FLAG.read_text(encoding="utf-8"))
    state = json.loads(agy_governor.STATE.read_text(encoding="utf-8"))
    assert flag["owner"] == "agy_governor"
    assert flag["reason"] == "quota_unknown"
    assert flag["failure_class"] == "token_expired"
    assert state["flag_owned"] is True


def test_auth_failure_never_clears_owned_gate_from_stale_reset(
    monkeypatch, tmp_path: Path
) -> None:
    _redirect_state(monkeypatch, tmp_path)
    agy_governor.FLAG.parent.mkdir(parents=True)
    original = {
        "owner": "agy_governor",
        "reason": "low_quota",
        "reset": "2000-01-01T00:00:00Z",
    }
    agy_governor.FLAG.write_text(json.dumps(original), encoding="utf-8")
    agy_governor.STATE.parent.mkdir(parents=True)
    agy_governor.STATE.write_text(json.dumps({"flag_owned": True}), encoding="utf-8")
    monkeypatch.setattr(
        agy_governor.agy_quota,
        "pull",
        lambda: {"ok": False, "error": "HTTP 401 UNAUTHENTICATED", "token_expired": True},
    )

    assert agy_governor.main([]) == 0
    assert json.loads(agy_governor.FLAG.read_text(encoding="utf-8")) == original


def test_authenticated_recovery_can_clear_owned_unknown_gate(
    monkeypatch, tmp_path: Path
) -> None:
    _redirect_state(monkeypatch, tmp_path)
    agy_governor.FLAG.parent.mkdir(parents=True)
    agy_governor.FLAG.write_text(
        json.dumps({"owner": "agy_governor", "reason": "quota_unknown"}),
        encoding="utf-8",
    )
    agy_governor.STATE.parent.mkdir(parents=True)
    agy_governor.STATE.write_text(json.dumps({"flag_owned": True}), encoding="utf-8")
    monkeypatch.setattr(
        agy_governor.agy_quota,
        "pull",
        lambda: {"ok": True, "binding_remaining_pct": 50.0, "binding_reset": None},
    )

    assert agy_governor.main([]) == 0
    assert not agy_governor.FLAG.exists()
    assert json.loads(agy_governor.STATE.read_text(encoding="utf-8"))["flag_owned"] is False


def test_missing_credential_is_structured_without_secret_material(monkeypatch) -> None:
    def _missing():
        raise RuntimeError("CredRead failed for gemini:antigravity (err 1168)")

    monkeypatch.setattr(agy_quota, "read_credential", _missing)
    result = agy_quota.pull()

    assert result["ok"] is False
    assert result["credential_target"] == "gemini:antigravity"
    assert result["token_expiry"] is None
    assert result["token_expired"] is None
    assert "access_token" not in json.dumps(result)
