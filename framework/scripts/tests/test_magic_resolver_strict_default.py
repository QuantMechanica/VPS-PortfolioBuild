from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "update_magic_resolver.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("update_magic_resolver_strict_test", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _fixture(module, tmp_path: Path) -> Path:
    registry_dir = tmp_path / "framework" / "registry"
    ea_root = tmp_path / "framework" / "EAs"
    include_dir = tmp_path / "framework" / "include" / "QM"
    registry_dir.mkdir(parents=True)
    ea_root.mkdir(parents=True)
    include_dir.mkdir(parents=True)
    (ea_root / "QM5_1001_present").mkdir()

    registry = registry_dir / "magic_numbers.csv"
    registry.write_text(
        "ea_id,ea_slug,symbol_slot,symbol,magic,status\n"
        "1001,present,0,EURUSD.DWX,10010000,active\n"
        "1002,missing,0,GBPUSD.DWX,10020000,active\n",
        encoding="utf-8",
        newline="\n",
    )
    (registry_dir / "ea_id_registry.csv").write_text(
        "ea_id,slug,status\n", encoding="utf-8", newline="\n"
    )
    resolver = include_dir / "QM_MagicResolver.mqh"
    resolver.write_bytes(b"PREEXISTING-RESOLVER\n")

    module.REPO_ROOT = tmp_path
    module.REGISTRY_CSV = registry
    module.EA_ID_REGISTRY = registry_dir / "ea_id_registry.csv"
    module.RESOLVER_MQH = resolver
    module.EA_ROOT = ea_root
    return resolver


def test_missing_active_directory_fails_before_replacing_resolver(
    tmp_path: Path, monkeypatch, capsys
) -> None:
    module = _load_module()
    resolver = _fixture(module, tmp_path)
    before = resolver.read_bytes()
    monkeypatch.setattr(sys, "argv", [str(SCRIPT)])

    assert module.main() == 2
    assert resolver.read_bytes() == before
    assert "strict-default" in capsys.readouterr().err


def test_allow_dropped_is_explicit_escape_hatch(tmp_path: Path, monkeypatch) -> None:
    module = _load_module()
    resolver = _fixture(module, tmp_path)
    monkeypatch.setattr(sys, "argv", [str(SCRIPT), "--allow-dropped"])

    assert module.main() == 0
    rendered = resolver.read_text(encoding="utf-8")
    assert "#define QM_MAGIC_REGISTRY_ROWS 1" in rendered
    assert "1001" in rendered
    assert "1002" not in rendered


def test_legacy_strict_flag_remains_accepted_and_strict(
    tmp_path: Path, monkeypatch
) -> None:
    module = _load_module()
    resolver = _fixture(module, tmp_path)
    before = resolver.read_bytes()
    monkeypatch.setattr(sys, "argv", [str(SCRIPT), "--strict"])

    assert module.main() == 2
    assert resolver.read_bytes() == before
