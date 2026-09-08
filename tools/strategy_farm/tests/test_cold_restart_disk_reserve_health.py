from types import SimpleNamespace

import pytest

from tools.strategy_farm import health


@pytest.mark.parametrize("free,status,margin", [(113, "WARN", -7), (120, "WARN", 0),
                                               (124.5, "WARN", 4.5), (136, "OK", 16)])
def test_cold_restart_reserve_is_observational(monkeypatch, free, status, margin):
    monkeypatch.setattr(health.shutil, "disk_usage", lambda _: SimpleNamespace(free=free * 1024**3))
    result = health.chk_cold_restart_disk_reserve()
    assert result["status"] == status
    assert result["value"] == {"free_gib": free, "required_gib": 120.0, "margin_gib": margin}
    assert result["threshold"] == 136


def test_check_is_registered():
    assert ("cold_restart_disk_reserve", health.chk_cold_restart_disk_reserve, False) in health.ALL_CHECKS
