"""Tests for canonical-checkout guard (layer 2) and mass-invalidation circuit breaker (layer 3)."""
import importlib
import os
import sys
from pathlib import Path
import pytest


def _import_farmctl():
    try:
        import farmctl
        return farmctl
    except ImportError:
        sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools" / "strategy_farm"))
        import farmctl  # type: ignore
        return farmctl


def test_layer1_framework_eas_dir_uses_canonical():
    """FRAMEWORK_EAS_DIR must point to C:/QM/repo, not a worktree."""
    farmctl = _import_farmctl()

    canonical = Path(r"C:\QM\repo") / "framework" / "EAs"
    env_override = os.environ.get("QM_CANONICAL_REPO_ROOT")
    if env_override:
        canonical = Path(env_override) / "framework" / "EAs"
    assert farmctl.FRAMEWORK_EAS_DIR == canonical, (
        f"FRAMEWORK_EAS_DIR={farmctl.FRAMEWORK_EAS_DIR} should be {canonical}"
    )


def test_layer2_canonical_check_passes_for_canonical_path(monkeypatch, tmp_path):
    """_require_canonical_checkout should not abort when script is under C:/QM/repo."""
    farmctl = _import_farmctl()

    # Monkeypatch __file__ to simulate canonical path
    monkeypatch.setattr(farmctl, "__file__", r"C:\QM\repo\tools\strategy_farm\farmctl.py")
    monkeypatch.delenv("QM_ALLOW_NONCANONICAL", raising=False)
    farmctl._require_canonical_checkout()  # should not raise or exit


def test_layer2_canonical_check_aborts_for_worktree(monkeypatch, capsys):
    """_require_canonical_checkout should sys.exit(1) when running from a worktree."""
    farmctl = _import_farmctl()

    monkeypatch.setattr(
        farmctl, "__file__",
        r"C:\QM\worktrees\agents-claude-orchestration-1\tools\strategy_farm\farmctl.py"
    )
    monkeypatch.delenv("QM_ALLOW_NONCANONICAL", raising=False)
    with pytest.raises(SystemExit) as exc_info:
        farmctl._require_canonical_checkout()
    assert exc_info.value.code == 1


def test_layer2_canonical_check_env_bypass(monkeypatch, capsys):
    """QM_ALLOW_NONCANONICAL=1 should bypass the check."""
    farmctl = _import_farmctl()

    monkeypatch.setattr(
        farmctl, "__file__",
        r"C:\QM\worktrees\agents-test\tools\strategy_farm\farmctl.py"
    )
    monkeypatch.setenv("QM_ALLOW_NONCANONICAL", "1")
    farmctl._require_canonical_checkout()  # should not exit


def test_layer3_circuit_breaker_below_limit(tmp_path):
    """Circuit breaker should not abort when count is within limit."""
    farmctl = _import_farmctl()

    # Should not raise
    farmctl._check_mass_invalidation_circuit_breaker(None, 199, "test_context")
    farmctl._check_mass_invalidation_circuit_breaker(None, 200, "test_context")


def test_layer3_circuit_breaker_above_limit(tmp_path, monkeypatch):
    """Circuit breaker should abort and write alarm when count exceeds limit."""
    farmctl = _import_farmctl()

    monkeypatch.setattr(farmctl, "DEFAULT_ROOT", tmp_path)
    (tmp_path / "state").mkdir()
    monkeypatch.delenv("QM_ALLOW_NONCANONICAL", raising=False)

    with pytest.raises(SystemExit) as exc_info:
        farmctl._check_mass_invalidation_circuit_breaker(None, 201, "test_context")
    assert exc_info.value.code == 1

    alarm_path = tmp_path / "state" / "health_alarms.log"
    assert alarm_path.exists()
    content = alarm_path.read_text()
    assert "mass_invalidation" in content
    assert "count=201" in content


def test_layer3_circuit_breaker_env_bypass(tmp_path, monkeypatch):
    """QM_ALLOW_NONCANONICAL=1 should bypass the circuit breaker."""
    farmctl = _import_farmctl()

    monkeypatch.setattr(farmctl, "DEFAULT_ROOT", tmp_path)
    (tmp_path / "state").mkdir()
    monkeypatch.setenv("QM_ALLOW_NONCANONICAL", "1")

    # Should not exit even with a huge count
    farmctl._check_mass_invalidation_circuit_breaker(None, 9999, "test_bypass")
