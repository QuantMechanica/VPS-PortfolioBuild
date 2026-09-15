"""Regression tests for the recalibrated research resource guard.

Proves the OWNER master directive 2026-09-15 §34 (OWNER-DEC-CBE-20260915) and the
audit ``research_disk_guard.md`` resolution: the guard watches the volume that
actually hosts research scratch with a measured 20 GB floor, and only imposes the
60 GB tester-cache-purge low-water on the factory drive (D:) when scratch is
placed there. Every path is injected; nothing touches D:/QM.
"""
from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

from research import research_env  # noqa: E402


# Neutral non-disk inputs so each test isolates the disk logic.
_CLEAR = dict(cpu_percent=0.0, free_ram_gb=64.0, lock_status="absent")


# --------------------------------------------------------------------------- #
# Scratch on C: — factory (D:) is not consulted
# --------------------------------------------------------------------------- #
def test_scratch_on_c_with_d_at_61_is_allowed() -> None:
    result = research_env.research_guard(
        research_scratch=r"C:\QM\repo\artifacts\research_datasets",
        disk_free_gb=200.0,      # plenty free on the C: scratch volume
        factory_free_gb=61.0,    # D: at 61 GB — must be ignored (scratch not on D:)
        **_CLEAR,
    )
    assert result.allowed, result.reasons
    assert result.measurements["scratch_on_factory_drive"] is False


def test_scratch_on_c_below_20_refuses() -> None:
    result = research_env.research_guard(
        research_scratch=r"C:\QM\repo\artifacts\research_datasets",
        disk_free_gb=19.0,
        **_CLEAR,
    )
    assert not result.allowed
    assert any(r.startswith("DISK_LOW") for r in result.reasons)


# --------------------------------------------------------------------------- #
# Scratch on D: — the 60 GB factory-purge low-water becomes the binding floor
# --------------------------------------------------------------------------- #
def test_scratch_on_d_at_61_is_allowed() -> None:
    result = research_env.research_guard(
        research_scratch=r"D:\QM\research\scratch",
        disk_free_gb=61.0,       # same volume, so factory free defaults to this
        **_CLEAR,
    )
    assert result.allowed, result.reasons
    assert result.measurements["scratch_on_factory_drive"] is True
    # Floor sourced from the shared config, not hardcoded here.
    assert result.measurements["factory_min_free_gb"] == 60.0


def test_scratch_on_d_at_59_refuses() -> None:
    result = research_env.research_guard(
        research_scratch=r"D:\QM\research\scratch",
        disk_free_gb=59.0,       # 59 >= 20 scratch floor, but 59 < 60 factory floor
        **_CLEAR,
    )
    assert not result.allowed
    assert any(r.startswith("FACTORY_DISK_LOW") for r in result.reasons)
    # The scratch floor itself is NOT the reason it failed.
    assert not any(r.startswith("DISK_LOW") for r in result.reasons)


def test_scratch_on_d_independent_factory_measurement_refuses() -> None:
    # Scratch volume looks fine but the factory drive is separately low.
    result = research_env.research_guard(
        research_scratch=r"D:\QM\research\scratch",
        disk_free_gb=500.0,
        factory_free_gb=59.0,
        **_CLEAR,
    )
    assert not result.allowed
    assert any(r.startswith("FACTORY_DISK_LOW") for r in result.reasons)


# --------------------------------------------------------------------------- #
# Environment overrides (OWNER/ops-tunable without a code change)
# --------------------------------------------------------------------------- #
def test_env_min_free_override_honoured(monkeypatch) -> None:
    monkeypatch.setenv(research_env.ENV_RESEARCH_MIN_FREE_GB, "100")
    result = research_env.research_guard(
        research_scratch=r"C:\QM\repo\artifacts\research_datasets",
        disk_free_gb=50.0,   # 50 >= default 20, but < the overridden 100
        **_CLEAR,
    )
    assert not result.allowed
    assert any(r.startswith("DISK_LOW") for r in result.reasons)
    assert result.measurements["scratch_min_free_gb"] == 100.0


def test_env_scratch_root_override_honoured(monkeypatch) -> None:
    # Point the scratch root at D: via env; the factory floor then applies.
    monkeypatch.setenv(research_env.ENV_RESEARCH_SCRATCH, r"D:\QM\research\scratch")
    result = research_env.research_guard(disk_free_gb=59.0, **_CLEAR)
    assert not result.allowed
    assert result.measurements["scratch_on_factory_drive"] is True
    assert any(r.startswith("FACTORY_DISK_LOW") for r in result.reasons)


def test_env_factory_min_free_override_honoured(monkeypatch) -> None:
    monkeypatch.setenv(research_env.ENV_FACTORY_MIN_FREE_GB, "40")
    result = research_env.research_guard(
        research_scratch=r"D:\QM\research\scratch",
        disk_free_gb=45.0,   # below old 60 floor, above the overridden 40
        **_CLEAR,
    )
    assert result.allowed, result.reasons
    assert result.measurements["factory_min_free_gb"] == 40.0


# --------------------------------------------------------------------------- #
# Fail-closed on an unknown / unmeasurable volume
# --------------------------------------------------------------------------- #
def test_unknown_scratch_volume_refuses() -> None:
    result = research_env.research_guard(
        research_scratch=r"C:\QM\repo\artifacts\research_datasets",
        disk_free_gb=lambda _p: None,   # measurement failed -> unknown volume
        **_CLEAR,
    )
    assert not result.allowed
    assert any(r.startswith("DISK_UNMEASURED") for r in result.reasons)


def test_unmeasurable_factory_drive_refuses() -> None:
    result = research_env.research_guard(
        research_scratch=r"D:\QM\research\scratch",
        disk_free_gb=500.0,
        factory_free_gb=lambda _p: None,
        **_CLEAR,
    )
    assert not result.allowed
    assert any(r.startswith("FACTORY_DISK_UNMEASURED") for r in result.reasons)


# --------------------------------------------------------------------------- #
# Shared low-water config wiring + layering invariant
# --------------------------------------------------------------------------- #
def test_factory_low_water_reads_shared_config() -> None:
    assert research_env._tester_purge_low_water_gb() == 60.0


def test_layering_invariant_holds() -> None:
    import terminal_worker  # noqa: E402

    worker_floor = float(terminal_worker.DISK_MIN_FREE_GB)
    purge_low_water = research_env._tester_purge_low_water_gb()
    research_floor = research_env.RESEARCH_DISK_MIN_FREE_GB
    # worker (40) <= purge (60); research scratch floor (20) yields first on its
    # own volume, and on D: the binding floor is the purge low-water itself.
    assert worker_floor <= purge_low_water
    assert research_floor <= purge_low_water
