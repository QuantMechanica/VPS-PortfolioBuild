from pathlib import Path

import pytest

from tools.strategy_farm import build_q09_include_closure as closure


def test_programmatic_closure_is_immutable_and_reauthenticates_sources(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    repo = tmp_path / "repo"
    ea_id = "QM5_9999"
    ea_dir = repo / "framework" / "EAs" / "QM5_9999_demo"
    include_root = repo / "framework" / "include"
    ea_dir.mkdir(parents=True)
    (include_root / "QM").mkdir(parents=True)
    mq5 = ea_dir / "QM5_9999_demo.mq5"
    ex5 = ea_dir / "QM5_9999_demo.ex5"
    include = include_root / "QM" / "Demo.mqh"
    mq5.write_text('#include <QM/Demo.mqh>\nvoid OnTick() {}\n', encoding="utf-8")
    ex5.write_bytes(b"compiled")
    include.write_text("int demo = 1;\n", encoding="utf-8")
    monkeypatch.setattr(closure, "REPO", repo)
    monkeypatch.setattr(closure, "INCLUDE_ROOT", include_root)
    monkeypatch.setattr(closure, "STDLIB_TERMINAL", tmp_path / "T1")
    monkeypatch.setattr(closure, "STDLIB_ROOT", tmp_path / "T1" / "MQL5" / "Include")

    path = closure.build_include_closure(ea_id, tmp_path / "out")
    payload = closure.validate_include_closure(ea_id, path)
    assert payload["file_count"] == 2
    with pytest.raises(FileExistsError, match="refusing to overwrite"):
        closure.build_include_closure(ea_id, tmp_path / "out")

    include.write_text("int demo = 2;\n", encoding="utf-8")
    with pytest.raises(RuntimeError, match="inventory/hash mismatch"):
        closure.validate_include_closure(ea_id, path)
