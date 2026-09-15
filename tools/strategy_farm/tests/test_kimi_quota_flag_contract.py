"""F1 (2026-09-15): the KIMI_LOW_QUOTA flag is the ONE contract the governor writes
and BOTH planes read. This drives the real kimi_governor at NORMAL / CONSERVE (>=70 %)
/ EXHAUSTED thresholds and asserts the resulting on-disk flag makes:

  * agent_router.kimi_quota_state(flag)          and
  * agent_chain._read_kimi_flag_state(flag)

agree on the state, and that the router's sync_default_registry and the chain's
vendor_gate react (CONSERVE narrows, EXHAUSTED disables/gates). Before the fix the
governor wrote the flag ONLY on EXHAUSTED (a key=value body), so CONSERVE was inert
end-to-end and EXHAUSTED worked only by the routers' fail-closed accident.

No live Kimi calls; every path is a temp dir.
"""
from __future__ import annotations

import datetime as dt
import json
import sys
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import agent_chain as ac  # noqa: E402
import kimi_governor as kg  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))
from tools.strategy_farm import agent_router  # noqa: E402


NOW = dt.datetime(2026, 9, 20, 12, 0, 0, tzinfo=dt.timezone.utc)


def _ok_rows(n: int) -> list[dict]:
    rows = []
    for i in range(n):
        ts = (NOW - dt.timedelta(minutes=i)).replace(microsecond=0).isoformat().replace("+00:00", "Z")
        rows.append({"ts_utc": ts, "status": "ok", "usage": None})
    return rows


def _governor_cfg(root: Path) -> dict:
    return {
        "schema": "qm.kimi-adapter.v1",
        "governor": {
            "ledger_path": str(root / "kimi_usage_ledger.jsonl"),
            "flag_path": str(root / "KIMI_LOW_QUOTA.flag"),
            "state_path": str(root / "kimi_governor_state.json"),
            "log_path": str(root / "kimi_governor.log"),
            "managed_by": "kimi_governor",
            "caps": {"day": 10, "week": 40},
            "conserve_pct": 70,
            "consecutive_fail_threshold": 2,
            "consecutive_fail_statuses": ["rate_limited", "auth_expired"],
            "conserve_allowed_capabilities": ["edge_discovery", "hypothesis_authoring",
                                              "cross_experiment_analysis", "research_critic"],
            "subscription_period": {"start": "2026-09-15", "end": "2026-10-15"},
            "period_conserve_days_before_end": 3,
        },
    }


def _drive_governor(root: Path, n_calls: int) -> tuple[Path, str]:
    """Write a ledger with n_calls ok rows, run the real governor, return (flag, state)."""
    cfg = _governor_cfg(root)
    ledger = Path(cfg["governor"]["ledger_path"])
    ledger.parent.mkdir(parents=True, exist_ok=True)
    ledger.write_text("\n".join(json.dumps(r) for r in _ok_rows(n_calls)) + "\n", encoding="utf-8")
    info = kg.evaluate(cfg, now=NOW)
    return Path(cfg["governor"]["flag_path"]), info["state"]


def _chain_cfg(root: Path, flag: Path) -> dict:
    cfg = ac.load_config()
    kimi_bin = root / "kimi.exe"
    kimi_bin.write_text("stub", encoding="utf-8")
    kimi_cred = root / "kimi-code.json"
    kimi_cred.write_text("{}", encoding="utf-8")
    cfg["vendors"]["kimi"]["bin"] = str(kimi_bin)
    cfg["vendors"]["kimi"]["credential_file"] = str(kimi_cred)
    cfg["gates"] = {
        "codex_budget_line": False,
        "claude_disabled_flag": str(root / "CLAUDE_DISABLED.flag"),
        "codex_low_tokens_flag": str(root / "CODEX_LOW_TOKENS.flag"),
        "agy_low_quota_flag": str(root / "AGY_LOW_QUOTA.flag"),
        "kimi_low_quota_flag": str(flag),
    }
    return cfg


# --- the three thresholds -> one flag both planes agree on -----------------------

@pytest.mark.parametrize("n_calls,expected", [(2, "NORMAL"), (7, "CONSERVE"), (10, "EXHAUSTED")])
def test_governor_flag_drives_both_planes(n_calls: int, expected: str) -> None:
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        root = Path(tmp)
        flag, state = _drive_governor(root, n_calls)
        assert state == expected, f"governor computed {state}, expected {expected}"

        router_state = agent_router.kimi_quota_state(root, flag)
        chain_state = ac._read_kimi_flag_state(flag) if flag.exists() else None

        if expected == "NORMAL":
            # NORMAL = no flag: router reads NORMAL, chain reads None (open) = the same posture.
            assert not flag.exists()
            assert router_state == "NORMAL"
            assert chain_state is None
        else:
            assert flag.exists()
            body = json.loads(flag.read_text(encoding="utf-8"))
            assert body["state"] == expected and body["managed_by"] == "kimi_governor"
            assert router_state == expected
            assert chain_state == expected


# --- sync_default_registry reacts to the governor-produced flag ------------------

def test_sync_registry_reacts_to_governor_conserve_and_exhausted() -> None:
    # CONSERVE narrows the advertised kimi capabilities but keeps the lane enabled.
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        root = Path(tmp)
        flag, state = _drive_governor(root, 7)
        assert state == "CONSERVE"
        sync = agent_router.sync_default_registry(
            root, claude_disabled_flag=root / "missing.flag", kimi_low_quota_flag=flag)
        assert sync["kimi_quota_state"] == "CONSERVE"
        with agent_router.connect(root) as conn:
            row = conn.execute(
                "SELECT enabled, max_parallel, capabilities_json FROM agent_registry WHERE agent_id='kimi'"
            ).fetchone()
        assert int(row["enabled"]) == 1  # still enabled under CONSERVE
        assert set(json.loads(row["capabilities_json"])) == set(agent_router.KIMI_CONSERVE_CAPABILITIES)

    # EXHAUSTED disables the lane exactly like CLAUDE_DISABLED.
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        root = Path(tmp)
        flag, state = _drive_governor(root, 10)
        assert state == "EXHAUSTED"
        sync = agent_router.sync_default_registry(
            root, claude_disabled_flag=root / "missing.flag", kimi_low_quota_flag=flag)
        assert sync["kimi_quota_state"] == "EXHAUSTED"
        with agent_router.connect(root) as conn:
            row = conn.execute(
                "SELECT enabled, max_parallel FROM agent_registry WHERE agent_id='kimi'"
            ).fetchone()
        assert int(row["enabled"]) == 0 and int(row["max_parallel"]) == 0


# --- vendor_gate reacts to the governor-produced flag ---------------------------

def test_vendor_gate_reacts_to_governor_flag() -> None:
    env = {"QM_AGENT_CHAIN": "1"}
    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        root = Path(tmp)
        # CONSERVE: only a read-only critic for a non-kimi creator survives.
        flag, state = _drive_governor(root, 7)
        assert state == "CONSERVE"
        cfg = _chain_cfg(root, flag)
        assert ac.vendor_gate("kimi", cfg, env, role="critic", creator_vendor="claude") is None
        assert ac.vendor_gate("kimi", cfg, env, role="creator").startswith("kimi_conserve:")

    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        root = Path(tmp)
        flag, state = _drive_governor(root, 10)
        assert state == "EXHAUSTED"
        cfg = _chain_cfg(root, flag)
        assert ac.vendor_gate("kimi", cfg, env) == "kimi_low_quota_flag:EXHAUSTED"

    with tempfile.TemporaryDirectory(ignore_cleanup_errors=True) as tmp:
        root = Path(tmp)
        flag, state = _drive_governor(root, 2)
        assert state == "NORMAL" and not flag.exists()
        cfg = _chain_cfg(root, flag)
        assert ac.vendor_gate("kimi", cfg, env) is None  # open under NORMAL


if __name__ == "__main__":
    import pytest as _p
    raise SystemExit(_p.main([__file__, "-q"]))
