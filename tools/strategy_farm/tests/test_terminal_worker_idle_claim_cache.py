"""Negative claim-result memo: cheap idle polling without selector changes."""

from __future__ import annotations

import json
import sqlite3
from pathlib import Path
import sys

import pytest


REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT_ROOT = REPO_ROOT / "tools" / "strategy_farm"
if str(SCRIPT_ROOT) not in sys.path:
    sys.path.insert(0, str(SCRIPT_ROOT))

import farmctl  # noqa: E402
import terminal_worker  # noqa: E402


@pytest.fixture(autouse=True)
def _clear_process_caches(monkeypatch: pytest.MonkeyPatch):
    terminal_worker._IDLE_CLAIM_CACHE.clear()
    farmctl._CLAIM_ORDER_CACHE.clear()
    farmctl._reset_claim_order_pollers()
    monkeypatch.setenv(terminal_worker.IDLE_CLAIM_CACHE_TTL_SECONDS_ENV, "8")
    yield
    terminal_worker._IDLE_CLAIM_CACHE.clear()
    farmctl._CLAIM_ORDER_CACHE.clear()
    farmctl._reset_claim_order_pollers()


def _seed_pending(root: Path, item_id: str = "candidate") -> None:
    farmctl.init_db(root)
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO work_items
              (id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
               attempt_count,payload_json,created_at,updated_at)
            VALUES (?, 'backtest', 'Q02', 'QM5_9999', 'EURUSD.DWX',
                    'fixture.set', 'pending', NULL, 0, ?, ?, ?)
            """,
            (item_id, json.dumps({}), now, now),
        )
        conn.commit()


def _patch_deterministic_host(
    monkeypatch: pytest.MonkeyPatch,
    free_ram: dict[str, float],
    process_calls: list[int],
) -> None:
    monkeypatch.setattr(
        farmctl, "_news_calendar_preflight", lambda **_kwargs: {"ok": True}
    )
    monkeypatch.setattr(terminal_worker, "_free_ram_gb", lambda: free_ram["gb"])
    monkeypatch.setattr(terminal_worker, "_commit_headroom_gb", lambda: 10_000.0)
    monkeypatch.setattr(terminal_worker, "_multisymbol_ea_ids", lambda: frozenset())
    monkeypatch.setattr(terminal_worker, "_drain_window_enabled", lambda: False)
    monkeypatch.setattr(
        terminal_worker,
        "_active_terminal_claim_preflight",
        lambda *_args, **_kwargs: {"ready": True},
    )
    monkeypatch.setattr(
        terminal_worker, "_watchdog_reset_admission_blocked", lambda _root: False
    )
    monkeypatch.setattr(
        terminal_worker, "_claim_spacing_remaining_seconds", lambda *_args: 0.0
    )
    monkeypatch.setattr(
        terminal_worker, "_census_first_ram_priority_enabled", lambda: False
    )
    monkeypatch.setattr(
        terminal_worker,
        "_p2_history_claimable",
        lambda *_args, **_kwargs: (True, None),
    )
    monkeypatch.setattr(farmctl, "terminal_reservation", lambda *_args: None)
    monkeypatch.setattr(
        terminal_worker.opt_census_pruning, "pruning_enabled", lambda: False
    )
    monkeypatch.setattr(
        terminal_worker.longrun_scheduling_policy, "policy_enabled", lambda: False
    )
    monkeypatch.setattr(
        terminal_worker.custom_history_gate, "load_activation", lambda _root: None
    )

    def process_snapshot():
        process_calls.append(1)
        return {}, {}, set()

    monkeypatch.setattr(
        terminal_worker, "_process_private_snapshot", process_snapshot
    )


def test_negative_claim_hit_skips_full_candidate_scan(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "farm"
    _seed_pending(root)
    free_ram = {"gb": 0.0}
    process_calls: list[int] = []
    _patch_deterministic_host(monkeypatch, free_ram, process_calls)

    first = terminal_worker.claim_atomic(root, "T1")
    second = terminal_worker.claim_atomic(root, "T1")

    assert first["reason"] == second["reason"] == "no_pending_claimable"
    assert first["idle_claim_cache_hit"] is False
    assert second["idle_claim_cache_hit"] is True
    assert len(process_calls) == 1
    with farmctl.connect(root) as conn:
        assert conn.execute(
            "SELECT status FROM work_items WHERE id='candidate'"
        ).fetchone()[0] == "pending"


def test_any_database_commit_invalidates_negative_claim(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "farm"
    _seed_pending(root)
    free_ram = {"gb": 0.0}
    process_calls: list[int] = []
    _patch_deterministic_host(monkeypatch, free_ram, process_calls)
    assert terminal_worker.claim_atomic(root, "T2")["reason"] == "no_pending_claimable"

    with farmctl.connect(root) as conn:
        conn.execute(
            "UPDATE work_items SET updated_at=? WHERE id='candidate'",
            (farmctl.utc_now(),),
        )
        conn.commit()

    result = terminal_worker.claim_atomic(root, "T2")
    assert result["reason"] == "no_pending_claimable"
    assert result["idle_claim_cache_hit"] is False
    assert len(process_calls) == 2


def test_resource_bucket_change_invalidates_and_preserves_first_claim(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    cached_root = tmp_path / "cached"
    baseline_root = tmp_path / "baseline"
    _seed_pending(cached_root, "same-first-row")
    _seed_pending(baseline_root, "same-first-row")
    free_ram = {"gb": 0.0}
    process_calls: list[int] = []
    _patch_deterministic_host(monkeypatch, free_ram, process_calls)

    warm = terminal_worker.claim_atomic(cached_root, "T3")
    assert warm["reason"] == "no_pending_claimable"

    free_ram["gb"] = 10_000.0
    cached_path = terminal_worker.claim_atomic(cached_root, "T3")
    assert cached_path["claimed"] is True

    monkeypatch.setenv(terminal_worker.IDLE_CLAIM_CACHE_TTL_SECONDS_ENV, "0")
    baseline_path = terminal_worker.claim_atomic(baseline_root, "T3")
    assert baseline_path["claimed"] is True
    assert cached_path["item"]["id"] == baseline_path["item"]["id"]
    assert cached_path["item"]["id"] == "same-first-row"


def test_qm_feature_flag_change_invalidates_negative_claim(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    root = tmp_path / "farm"
    _seed_pending(root)
    free_ram = {"gb": 0.0}
    process_calls: list[int] = []
    _patch_deterministic_host(monkeypatch, free_ram, process_calls)
    assert terminal_worker.claim_atomic(root, "T5")["reason"] == "no_pending_claimable"

    monkeypatch.setenv("QM_TEST_IDLE_CACHE_FEATURE_FLIP", "1")
    result = terminal_worker.claim_atomic(root, "T5")
    assert result["idle_claim_cache_hit"] is False
    assert len(process_calls) == 2


@pytest.mark.parametrize("terminal", [f"T{index}" for index in range(1, 11)])
def test_cache_miss_and_disabled_path_choose_same_first_row_for_every_terminal(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, terminal: str
) -> None:
    enabled_root = tmp_path / "enabled"
    disabled_root = tmp_path / "disabled"
    _seed_pending(enabled_root, "differential-first")
    _seed_pending(disabled_root, "differential-first")
    free_ram = {"gb": 10_000.0}
    process_calls: list[int] = []
    _patch_deterministic_host(monkeypatch, free_ram, process_calls)

    enabled = terminal_worker.claim_atomic(enabled_root, terminal)
    monkeypatch.setenv(terminal_worker.IDLE_CLAIM_CACHE_TTL_SECONDS_ENV, "0")
    disabled = terminal_worker.claim_atomic(disabled_root, terminal)

    assert enabled["claimed"] is disabled["claimed"] is True
    assert enabled["item"]["id"] == disabled["item"]["id"] == "differential-first"


def test_ttl_is_kill_switchable_and_hard_capped() -> None:
    name = terminal_worker.IDLE_CLAIM_CACHE_TTL_SECONDS_ENV
    assert terminal_worker._idle_claim_cache_ttl_seconds({}) == 8.0
    assert terminal_worker._idle_claim_cache_ttl_seconds({name: "60"}) == 8.0
    assert terminal_worker._idle_claim_cache_ttl_seconds({name: "0"}) == 0.0
    assert terminal_worker._idle_claim_cache_ttl_seconds({name: "bad"}) == 8.0


def test_cached_negative_expires_at_hard_bound(tmp_path: Path) -> None:
    probe = {
        "key": terminal_worker._idle_claim_cache_key(tmp_path, "T4"),
        "fingerprint": ("stable",),
    }
    terminal_worker._remember_idle_claim_cache(probe, monotonic=lambda: 100.0)
    assert terminal_worker._idle_claim_cache_hit(probe, monotonic=lambda: 107.999)
    assert not terminal_worker._idle_claim_cache_hit(probe, monotonic=lambda: 108.0)


def test_explicit_local_finish_invalidation(tmp_path: Path) -> None:
    root = tmp_path / "farm"
    terminal_worker._IDLE_CLAIM_CACHE[
        terminal_worker._idle_claim_cache_key(root, "T4")
    ] = {"fingerprint": (), "expires_monotonic": 999999999.0}
    terminal_worker._invalidate_idle_claim_cache(root, "T4")
    assert terminal_worker._IDLE_CLAIM_CACHE == {}
