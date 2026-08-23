from __future__ import annotations

from pathlib import Path

import pytest

from tools.strategy_farm import include_mirror


def test_lock_held_pipeline_mirror_proceeds_beside_other_running_terminal(
    tmp_path: Path,
) -> None:
    source = tmp_path / "source"
    target = tmp_path / "target"
    source.mkdir()
    (source / "QM_Common.mqh").write_bytes(b"new-complete-content")
    lock_path = tmp_path / "include_mirror.lock"

    with include_mirror.IncludeMirrorMutex(lock_path, timeout_seconds=0) as mutex:
        include_mirror.validate_compile_contract(
            running_terminals={"T1"},
            pipeline_work_item_id="11111111-1111-1111-1111-111111111111",
            claimed_terminal="T2",
            lock_held=mutex.held,
        )
        result = include_mirror.mirror_targets(source, [target], mutex=mutex)

    assert result["atomic_replace"] is True
    assert result["copied_file_count"] == 1
    assert (target / "QM_Common.mqh").read_bytes() == b"new-complete-content"
    assert not lock_path.exists()


def test_running_terminal_without_pipeline_lock_refuses_without_retry(monkeypatch) -> None:
    def retry_would_be_a_bug(_seconds: float) -> None:
        raise AssertionError("refusal path attempted a retry")

    monkeypatch.setattr(include_mirror.time, "sleep", retry_would_be_a_bug)
    with pytest.raises(include_mirror.IncludeMirrorRefusal) as raised:
        include_mirror.validate_compile_contract(
            running_terminals={"T4"},
            pipeline_work_item_id=None,
            claimed_terminal=None,
            lock_held=False,
        )

    assert raised.value.failure_class == "LIVE_FACTORY_AD_HOC_COMPILE_REFUSED"
    assert raised.value.retry_attempted is False
    assert "enqueue-compile" in str(raised.value)
    assert "No retry was attempted" in str(raised.value)


def test_mid_mirror_failure_leaves_every_destination_fully_old_or_new(
    tmp_path: Path,
) -> None:
    source = tmp_path / "source"
    target = tmp_path / "target"
    source.mkdir()
    target.mkdir()
    new_a = b"A" * (128 * 1024)
    new_b = b"B" * (128 * 1024)
    old_a = b"old-a"
    old_b = b"old-b"
    (source / "a.mqh").write_bytes(new_a)
    (source / "b.mqh").write_bytes(new_b)
    (target / "a.mqh").write_bytes(old_a)
    (target / "b.mqh").write_bytes(old_b)

    with include_mirror.IncludeMirrorMutex(
        tmp_path / "include_mirror.lock", timeout_seconds=0
    ) as mutex:
        with pytest.raises(RuntimeError, match="simulated mid-mirror failure"):
            include_mirror.mirror_targets(
                source,
                [target],
                mutex=mutex,
                fail_after_files=1,
            )

    assert (target / "a.mqh").read_bytes() in {old_a, new_a}
    assert (target / "b.mqh").read_bytes() in {old_b, new_b}
    assert (target / "a.mqh").read_bytes() == new_a
    assert (target / "b.mqh").read_bytes() == old_b
    assert not list(target.glob("*.tmp"))


def test_repair_stdlib_targets_installs_full_same_build_set_without_overwriting_project_headers(
    tmp_path: Path,
) -> None:
    project = tmp_path / "framework_include"
    stdlib = tmp_path / "terminal_install" / "MQL5" / "Include"
    target = tmp_path / "roaming_profile" / "MQL5" / "Include"
    (project / "QM").mkdir(parents=True)
    (project / "QM" / "QM_Common.mqh").write_bytes(b"governed-project-header")
    (stdlib / "Trade").mkdir(parents=True)
    (stdlib / "QM").mkdir(parents=True)
    (stdlib / "Object.mqh").write_bytes(b"same-build-object")
    (stdlib / "StdLibErr.mqh").write_bytes(b"same-build-errors")
    (stdlib / "Trade" / "Trade.mqh").write_bytes(b"same-build-trade")
    # Install trees receive governed headers too.  They are not MT5 stdlib and
    # must never become the source of truth for project-header provisioning.
    (stdlib / "QM" / "QM_Common.mqh").write_bytes(b"stale-install-project-header")
    (stdlib / "QM" / "retired_project_header.mqh").write_bytes(b"also-not-stdlib")
    (target / "QM").mkdir(parents=True)
    (target / "QM" / "QM_Common.mqh").write_bytes(b"governed-project-header")

    with include_mirror.IncludeMirrorMutex(
        tmp_path / "include_mirror.lock", timeout_seconds=0
    ) as mutex:
        result = include_mirror.repair_stdlib_targets(
            stdlib,
            project,
            [target],
            mutex=mutex,
        )

    assert result["required_relative_paths"] == ["Object.mqh", "Trade/Trade.mqh"]
    assert result["files_per_target"][str(target.resolve())] == 3
    assert result["missing_before"][str(target.resolve())] == [
        "Object.mqh",
        "StdLibErr.mqh",
        "Trade/Trade.mqh",
    ]
    assert (target / "Object.mqh").read_bytes() == b"same-build-object"
    assert (target / "StdLibErr.mqh").read_bytes() == b"same-build-errors"
    assert (target / "Trade" / "Trade.mqh").read_bytes() == b"same-build-trade"
    assert (target / "QM" / "QM_Common.mqh").read_bytes() == b"governed-project-header"
    assert not (target / "QM" / "retired_project_header.mqh").exists()


def test_compile_one_checks_resolved_stdlib_before_starting_metaeditor() -> None:
    script = (
        Path(__file__).resolve().parents[3] / "framework" / "scripts" / "compile_one.ps1"
    ).read_text(encoding="utf-8")

    preflight = script.index("Get-CompileProfileStdlibMissing -IncludeRoots $includeTargets")
    launch = script.index("Start-Process -FilePath $MetaEditorPath")
    assert preflight < launch
    assert '"--stdlib-source", $compileProfileStdlibSource' in script
    assert '$reasonClass = "COMPILE_PROFILE_STDLIB_MISSING"' in script


def test_repair_stdlib_targets_refuses_source_without_required_contract(
    tmp_path: Path,
) -> None:
    project = tmp_path / "framework_include"
    stdlib = tmp_path / "terminal_install" / "MQL5" / "Include"
    target = tmp_path / "roaming_profile" / "MQL5" / "Include"
    project.mkdir()
    stdlib.mkdir(parents=True)
    (stdlib / "Object.mqh").write_bytes(b"object-only")

    with include_mirror.IncludeMirrorMutex(
        tmp_path / "include_mirror.lock", timeout_seconds=0
    ) as mutex:
        with pytest.raises(include_mirror.IncludeMirrorRefusal) as raised:
            include_mirror.repair_stdlib_targets(
                stdlib,
                project,
                [target],
                mutex=mutex,
            )

    assert raised.value.failure_class == "COMPILE_PROFILE_STDLIB_MISSING"
    assert "Trade/Trade.mqh" in str(raised.value)


def test_verify_compile_profile_stdlib_reports_missing_required_file(tmp_path: Path) -> None:
    include_root = tmp_path / "profile" / "MQL5" / "Include"
    include_root.mkdir(parents=True)
    (include_root / "Object.mqh").write_bytes(b"object")

    with pytest.raises(include_mirror.IncludeMirrorRefusal) as raised:
        include_mirror.verify_compile_profile_stdlib(include_root)

    assert raised.value.failure_class == "COMPILE_PROFILE_STDLIB_MISSING"
    assert "Trade/Trade.mqh" in str(raised.value)

