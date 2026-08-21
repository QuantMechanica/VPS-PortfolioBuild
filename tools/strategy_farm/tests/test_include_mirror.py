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

