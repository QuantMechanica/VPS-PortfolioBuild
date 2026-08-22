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


def _make_ea(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> tuple[str, Path, Path, Path]:
    """Build an EA that includes the generated magic resolver and validate it.

    Returns (ea_id, closure_path, resolver_include, ex5).
    """
    repo = tmp_path / "repo"
    ea_id = "QM5_9998"
    ea_dir = repo / "framework" / "EAs" / "QM5_9998_demo"
    include_root = repo / "framework" / "include"
    ea_dir.mkdir(parents=True)
    (include_root / "QM").mkdir(parents=True)
    mq5 = ea_dir / "QM5_9998_demo.mq5"
    ex5 = ea_dir / "QM5_9998_demo.ex5"
    resolver = include_root / "QM" / "QM_MagicResolver.mqh"
    other = include_root / "QM" / "Other.mqh"
    mq5.write_text(
        '#include <QM/QM_MagicResolver.mqh>\n#include <QM/Other.mqh>\nvoid OnTick() {}\n',
        encoding="utf-8",
    )
    ex5.write_bytes(b"compiled-9998")
    resolver.write_text("// AUTO-GENERATED\nint magic = 1;\n", encoding="utf-8")
    other.write_text("int other = 1;\n", encoding="utf-8")
    monkeypatch.setattr(closure, "REPO", repo)
    monkeypatch.setattr(closure, "INCLUDE_ROOT", include_root)
    monkeypatch.setattr(closure, "STDLIB_TERMINAL", tmp_path / "T1")
    monkeypatch.setattr(closure, "STDLIB_ROOT", tmp_path / "T1" / "MQL5" / "Include")

    path = closure.build_include_closure(ea_id, tmp_path / "out")
    return ea_id, path, resolver, ex5


def test_generated_resolver_drift_is_accepted_with_drift_record_and_immutable_closure(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    ea_id, path, resolver, _ex5 = _make_ea(tmp_path, monkeypatch)

    # Exact match first: drift record present and empty.
    clean = closure.validate_include_closure(ea_id, path)
    assert clean["generated_source_drift"] == []

    closure_bytes_before = path.read_bytes()

    # Regenerate the magic resolver (as a later magic allocation would); the EX5 is
    # unchanged, so the closure still binds the binary exactly.
    resolver.write_text("// AUTO-GENERATED\nint magic = 2;\n", encoding="utf-8")

    payload = closure.validate_include_closure(ea_id, path)
    drift = payload["generated_source_drift"]
    assert len(drift) == 1
    record = drift[0]
    assert record["relative_path"] == "framework/include/QM/QM_MagicResolver.mqh"
    assert record["closure_sha256"] != record["current_sha256"]
    assert record["closure_sha256"] and record["current_sha256"]

    # The immutable closure file on disk was NOT rewritten.
    assert path.read_bytes() == closure_bytes_before


def test_non_generated_include_drift_is_rejected(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    ea_id, path, _resolver, _ex5 = _make_ea(tmp_path, monkeypatch)
    include_other = closure.INCLUDE_ROOT / "QM" / "Other.mqh"
    include_other.write_text("int other = 999;\n", encoding="utf-8")

    with pytest.raises(RuntimeError, match="inventory/hash mismatch"):
        closure.validate_include_closure(ea_id, path)


def test_ex5_mismatch_rejected_even_with_identical_sources(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    ea_id, path, _resolver, ex5 = _make_ea(tmp_path, monkeypatch)
    # Sources are byte-identical to the closure; only the EX5 changed.
    ex5.write_bytes(b"compiled-9998-RECOMPILED")

    with pytest.raises(RuntimeError, match="EX5 hash mismatch"):
        closure.validate_include_closure(ea_id, path)
