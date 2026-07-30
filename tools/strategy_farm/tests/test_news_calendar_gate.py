from __future__ import annotations

import datetime as dt
import hashlib
import json
import os
import sys
from pathlib import Path
from unittest import mock

import pytest


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import news_calendar_gate as gate  # noqa: E402


NOW = dt.datetime(2026, 7, 29, 12, 0, tzinfo=dt.UTC)
STAMP = "20260730T060000Z-0123456789abcdef0123456789abcdef"


def _calendar_bytes(tag: str) -> tuple[bytes, bytes]:
    primary = (
        "datetime,currency,event_name,impact\r\n"
        f"2026-07-28 08:30:00,USD,CPI {tag},high\r\n"
        "2026-07-28 12:00:00,EUR,ECB Press Conference,medium\r\n"
    ).encode("ascii")
    secondary = (
        "Date,DateTime_UTC,DateTime_EET,Currency,Impact,Event,Actual,Forecast,Previous\r\n"
        f"2026.07.28,2026.07.28 08:30,2026.07.28 10:30,USD,High,CPI {tag},,,\r\n"
        "2026.07.28,2026.07.28 12:00,2026.07.28 14:00,EUR,Medium,ECB Press Conference,,,\r\n"
    ).encode("ascii")
    return primary, secondary


def _write_pair(root: Path, tag: str = "BASE") -> None:
    root.mkdir(parents=True, exist_ok=True)
    primary, secondary = _calendar_bytes(tag)
    (root / gate.PRIMARY_NAME).write_bytes(primary)
    (root / gate.SECONDARY_NAME).write_bytes(secondary)


def _set_mtime(root: Path, when: dt.datetime) -> None:
    timestamp = when.timestamp()
    for name in gate.CALENDAR_NAMES:
        os.utime(root / name, (timestamp, timestamp))


def _snapshot(root: Path) -> list[tuple[str, bytes, int]]:
    return [
        (str(path.relative_to(root)), path.read_bytes(), path.stat().st_mtime_ns)
        for path in sorted(root.rglob("*"))
        if path.is_file()
    ]


def _test_policy(tmp_path: Path, *, common_count: int = 1) -> gate._PublicationPolicy:
    refresh = tmp_path / "harness" / "refresh_news_calendar.ps1"
    refresh.parent.mkdir(parents=True, exist_ok=True)
    refresh.write_bytes(b"Write-Host test-injected-refresh\r\n")
    return gate._test_publication_policy(
        source_dir=tmp_path / "source",
        common_dirs=[tmp_path / f"common-{index}" for index in range(common_count)],
        factory_off_flag=tmp_path / "factory-state" / "FACTORY_OFF.flag",
        refresh_script=refresh,
        evidence_dir=tmp_path / "evidence",
    )


def _build_plan(
    tmp_path: Path,
    *,
    tag: str = "NEW",
    common_count: int = 1,
) -> tuple[gate._PublicationPolicy, dict[str, object], Path]:
    policy = _test_policy(tmp_path, common_count=common_count)
    candidates = tmp_path / "candidates"
    _write_pair(candidates, tag)
    plan = gate.build_multi_principal_publication_plan(
        candidates / gate.PRIMARY_NAME,
        candidates / gate.SECONDARY_NAME,
        generated_at="2026-07-30T06:00:00Z",
        _policy=policy,
    )
    return policy, plan, candidates


def _set_factory_off(policy: gate._PublicationPolicy) -> str:
    policy.factory_off_flag.parent.mkdir(parents=True, exist_ok=True)
    policy.factory_off_flag.write_text(
        '{"reason":"intentional maintenance"}\n', encoding="ascii"
    )
    return hashlib.sha256(policy.factory_off_flag.read_bytes()).hexdigest()


def _evidence_path(policy: gate._PublicationPolicy, kind: str) -> Path:
    return policy.evidence_dir / f"news_calendar_publication_{kind}_{STAMP}.json"


@pytest.mark.parametrize(
    ("fault", "expected"),
    [
        ("missing_source", gate.STATUS_MISSING_SOURCE),
        ("missing_common", gate.STATUS_MISSING_COMMON),
        ("stale", gate.STATUS_STALE_COMMON),
        ("mismatch", gate.STATUS_COMMON_MISMATCH),
        ("parse_invalid", gate.STATUS_PARSE_INVALID),
    ],
)
def test_preflight_fault_taxonomy_is_side_effect_free(
    tmp_path: Path, fault: str, expected: str
) -> None:
    source = tmp_path / "source"
    common = tmp_path / "common"
    _write_pair(source)
    _write_pair(common)
    _set_mtime(common, NOW - dt.timedelta(hours=2))

    if fault == "missing_source":
        (source / gate.PRIMARY_NAME).unlink()
    elif fault == "missing_common":
        (common / gate.SECONDARY_NAME).unlink()
    elif fault == "stale":
        _set_mtime(common, NOW - dt.timedelta(hours=gate.MAX_AGE_HOURS + 1))
    elif fault == "mismatch":
        _, secondary = _calendar_bytes("DRIFT")
        (common / gate.SECONDARY_NAME).write_bytes(secondary)
    elif fault == "parse_invalid":
        (source / gate.PRIMARY_NAME).write_text("wrong,header\n1,2\n", encoding="utf-8")

    before = _snapshot(tmp_path)
    result = gate.preflight_news_calendar(source, common, now=NOW, use_cache=False)
    assert _snapshot(tmp_path) == before
    assert result.status == expected
    assert result.ok is False
    assert result.principal


def test_preflight_accepts_valid_legacy_flat_pair(tmp_path: Path) -> None:
    source = tmp_path / "source"
    common = tmp_path / "common"
    _write_pair(source)
    _write_pair(common)
    _set_mtime(common, NOW - dt.timedelta(hours=2))

    result = gate.preflight_news_calendar(source, common, now=NOW, use_cache=False)

    assert result.ok is True
    assert result.legacy_flat_files is True
    assert result.age_hours == 2.0


def test_multi_plan_is_read_only_and_policy_binds_targets_and_provenance(
    tmp_path: Path,
) -> None:
    policy = _test_policy(tmp_path, common_count=2)
    candidates = tmp_path / "candidates"
    _write_pair(candidates, "PLANNED")
    before = _snapshot(tmp_path)

    plan = gate.build_multi_principal_publication_plan(
        candidates / gate.PRIMARY_NAME,
        candidates / gate.SECONDARY_NAME,
        generated_at="2026-07-30T06:00:00Z",
        _policy=policy,
    )

    validated_policy = gate._validated_policy(policy)
    assert _snapshot(tmp_path) == before
    assert plan["targets"] == [
        {"role": "source", "path": str(validated_policy.source_dir)},
        *(
            {"role": "common", "path": str(common)}
            for common in validated_policy.common_dirs
        ),
    ]
    assert plan["provenance"] == gate._policy_provenance(validated_policy)
    validated = gate._validate_multi_plan(plan, validated_policy)
    assert validated[2] == validated_policy.source_dir
    assert validated[3] == list(validated_policy.common_dirs)

    policy.refresh_script.write_bytes(b"changed\r\n")
    with pytest.raises(gate.NewsCalendarError, match="provenance differs"):
        gate._validate_multi_plan(plan, gate._validated_policy(policy))


def test_multi_publisher_installs_all_principals_and_identical_reapply_keeps_mtime(
    tmp_path: Path,
) -> None:
    policy, plan, candidates = _build_plan(tmp_path, common_count=3)

    result = gate.publish_calendar_bundle_multi(
        plan,
        expected_plan_sha256=str(plan["plan_sha256"]),
        allow_factory_on=True,
        _policy=policy,
    )

    assert result["status"] == "committed"
    assert result["lock_release_succeeded"] is True
    assert len(result["preflights"]) == 3
    validated = gate._validated_policy(policy)
    mtimes: dict[tuple[str, str], int] = {}
    for root in (validated.source_dir, *validated.common_dirs):
        for name in gate.CALENDAR_NAMES:
            assert (root / name).read_bytes() == (candidates / name).read_bytes()
            mtimes[(str(root), name)] = (root / name).stat().st_mtime_ns
        bundle = root / gate.BUNDLE_DIRECTORY_NAME / str(plan["manifest"]["bundle_id"])
        assert (bundle / gate.ACTIVE_MANIFEST_NAME).is_file()

    again = gate.publish_calendar_bundle_multi(
        plan,
        expected_plan_sha256=str(plan["plan_sha256"]),
        allow_factory_on=True,
        _policy=policy,
    )
    assert again["status"] == "committed"
    for (root, name), mtime in mtimes.items():
        assert (Path(root) / name).stat().st_mtime_ns == mtime
    assert not gate.path_for_factory_flag(policy.factory_off_flag).exists()


def test_off_mode_is_exact_flag_hash_bound_before_target_writes(tmp_path: Path) -> None:
    policy, plan, _ = _build_plan(tmp_path)
    flag_sha = _set_factory_off(policy)

    with pytest.raises(gate.NewsCalendarError, match="SHA-256 mismatch"):
        gate.publish_calendar_bundle_multi(
            plan,
            expected_plan_sha256=str(plan["plan_sha256"]),
            expected_factory_off_sha256="0" * 64,
            _policy=policy,
        )
    assert not policy.source_dir.exists()
    assert not policy.common_dirs[0].exists()

    result = gate.publish_calendar_bundle_multi(
        plan,
        expected_plan_sha256=str(plan["plan_sha256"]),
        expected_factory_off_sha256=flag_sha,
        _policy=policy,
    )
    assert result["factory_mode"] == "OFF_HASH_BOUND"
    assert result["factory_off_sha256"] == flag_sha
    assert policy.factory_off_flag.is_file()


def test_interrupted_multi_publish_fails_closed_and_same_plan_recovers(
    tmp_path: Path,
) -> None:
    policy = _test_policy(tmp_path, common_count=2)
    old = tmp_path / "old"
    new = tmp_path / "new"
    _write_pair(old, "OLD")
    _write_pair(new, "NEW")
    old_plan = gate.build_multi_principal_publication_plan(
        old / gate.PRIMARY_NAME,
        old / gate.SECONDARY_NAME,
        generated_at="2026-07-30T05:00:00Z",
        _policy=policy,
    )
    new_plan = gate.build_multi_principal_publication_plan(
        new / gate.PRIMARY_NAME,
        new / gate.SECONDARY_NAME,
        generated_at="2026-07-30T06:00:00Z",
        _policy=policy,
    )
    gate.publish_calendar_bundle_multi(
        old_plan,
        expected_plan_sha256=str(old_plan["plan_sha256"]),
        allow_factory_on=True,
        _policy=policy,
    )

    with pytest.raises(gate.InjectedPublishFailure, match="COMMON_0_MANIFEST_REPLACED"):
        gate.publish_calendar_bundle_multi(
            new_plan,
            expected_plan_sha256=str(new_plan["plan_sha256"]),
            allow_factory_on=True,
            fault_after="COMMON_0_MANIFEST_REPLACED",
            _policy=policy,
        )

    interrupted = gate.preflight_news_calendar(
        policy.source_dir, policy.common_dirs[0], use_cache=False
    )
    assert interrupted.ok is False
    assert interrupted.status == gate.STATUS_COMMON_MISMATCH
    recovered = gate.publish_calendar_bundle_multi(
        new_plan,
        expected_plan_sha256=str(new_plan["plan_sha256"]),
        allow_factory_on=True,
        _policy=policy,
    )
    assert recovered["status"] == "committed"


def test_on_mode_aborts_if_off_flag_appears_mid_publication(tmp_path: Path) -> None:
    policy, plan, _ = _build_plan(tmp_path)
    real_replace = gate._replace_active_file
    calls = 0

    def replace_then_turn_off(root: Path, name: str, raw: bytes) -> bool:
        nonlocal calls
        replaced = real_replace(root, name, raw)
        calls += 1
        if calls == 1:
            policy.factory_off_flag.write_text("maintenance\n", encoding="ascii")
        return replaced

    with mock.patch.object(gate, "_replace_active_file", side_effect=replace_then_turn_off):
        with pytest.raises(gate.NewsCalendarError, match="FACTORY_OFF flag appeared"):
            gate.publish_calendar_bundle_multi(
                plan,
                expected_plan_sha256=str(plan["plan_sha256"]),
                allow_factory_on=True,
                _policy=policy,
            )
    assert calls == 1
    assert policy.factory_off_flag.is_file()
    assert not gate.path_for_factory_flag(policy.factory_off_flag).exists()


def test_retargeted_rehashed_plan_cannot_select_publication_authority(
    tmp_path: Path,
) -> None:
    policy, plan, _ = _build_plan(tmp_path)
    original_sha = str(plan["plan_sha256"])
    tampered = json.loads(json.dumps(plan))
    tampered["targets"][1]["path"] = str((tmp_path / "retargeted").resolve())
    material = dict(tampered)
    material.pop("plan_sha256")
    tampered["plan_sha256"] = hashlib.sha256(
        gate._canonical_json_bytes(material)
    ).hexdigest()

    with pytest.raises(gate.NewsCalendarError, match="independently expected"):
        gate.publish_calendar_bundle_multi(
            tampered,
            expected_plan_sha256=original_sha,
            allow_factory_on=True,
            _policy=policy,
        )
    with pytest.raises(gate.NewsCalendarError, match="pinned authority"):
        gate.publish_calendar_bundle_multi(
            tampered,
            expected_plan_sha256=tampered["plan_sha256"],
            allow_factory_on=True,
            _policy=policy,
        )
    assert not (tmp_path / "retargeted").exists()


@pytest.mark.parametrize("overlap", ["equal", "nested", "ancestor", "protected", "evidence"])
def test_policy_rejects_equal_nested_ancestor_and_protected_overlaps(
    tmp_path: Path, overlap: str
) -> None:
    refresh = tmp_path / "harness" / "refresh.ps1"
    refresh.parent.mkdir(parents=True)
    refresh.write_text("test\n", encoding="ascii")
    source = tmp_path / "source"
    common = tmp_path / "common"
    evidence = tmp_path / "evidence"
    protected: list[Path] = []
    if overlap == "equal":
        common = source
    elif overlap == "nested":
        common = source / "nested"
    elif overlap == "ancestor":
        source = common / "nested"
    elif overlap == "protected":
        protected = [tmp_path / "protected"]
        source = protected[0] / "nested"
    elif overlap == "evidence":
        source = evidence / "nested"
    policy = gate._test_publication_policy(
        source_dir=source,
        common_dirs=[common],
        factory_off_flag=tmp_path / "state" / "FACTORY_OFF.flag",
        refresh_script=refresh,
        evidence_dir=evidence,
        protected_roots=protected,
    )

    with pytest.raises(gate.NewsCalendarError, match="overlap"):
        gate._validated_policy(policy)


def test_candidate_and_output_symlink_components_are_rejected(tmp_path: Path) -> None:
    policy, _plan, candidates = _build_plan(tmp_path)
    candidate_link = tmp_path / "candidate-link"
    evidence_link = tmp_path / "evidence-link"
    policy.evidence_dir.mkdir(parents=True, exist_ok=True)
    try:
        candidate_link.symlink_to(candidates, target_is_directory=True)
        evidence_link.symlink_to(policy.evidence_dir, target_is_directory=True)
    except OSError as exc:
        pytest.skip(f"symlink creation unavailable: {exc}")

    with pytest.raises(gate.NewsCalendarError, match="symlink/reparse"):
        gate.build_multi_principal_publication_plan(
            candidate_link / gate.PRIMARY_NAME,
            candidate_link / gate.SECONDARY_NAME,
            _policy=policy,
        )
    with pytest.raises(gate.NewsCalendarError, match="symlink/reparse"):
        gate._validate_evidence_output(
            evidence_link / f"news_calendar_publication_plan_{STAMP}.json",
            gate._validated_policy(policy),
            kind="plan",
        )


def test_production_policy_is_exact_and_cli_exposes_no_authority_overrides(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
) -> None:
    policy = gate._validated_policy(gate._PRODUCTION_POLICY)
    assert gate.PRODUCTION_GATE_SCRIPT == Path(
        r"C:\QM\repo\tools\strategy_farm\news_calendar_gate.py"
    )
    assert Path(gate.__file__).resolve() == gate.PRODUCTION_GATE_SCRIPT
    assert gate.PRODUCTION_REFRESH_SCRIPT == Path(
        r"C:\QM\repo\tools\strategy_farm\refresh_news_calendar.ps1"
    )
    assert policy.source_dir == Path(r"D:\QM\data\news_calendar")
    assert policy.common_dirs == tuple(path.resolve() for path in gate.PRODUCTION_COMMON_DIRS)
    assert policy.factory_off_flag == Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")
    assert gate.path_for_factory_flag(policy.factory_off_flag) == Path(
        r"D:\QM\strategy_farm\state\FACTORY_MUTATION.lock"
    )
    assert policy.provenance_kind == "scheduled-refresh-script"
    assert gate._policy_provenance(policy) == {
        "kind": "scheduled-refresh-script",
        "path": str(gate.PRODUCTION_REFRESH_SCRIPT),
        "sha256": hashlib.sha256(gate.PRODUCTION_REFRESH_SCRIPT.read_bytes()).hexdigest(),
    }

    fake_flag = tmp_path / "FACTORY_OFF.flag"
    fake_lock = gate.path_for_factory_flag(fake_flag)
    fake_flag.write_text("fake\n", encoding="ascii")
    fake_lock.write_text("fake-lock\n", encoding="ascii")
    with pytest.raises(SystemExit) as exc:
        gate.main(
            [
                "multi-publish",
                "--plan", str(tmp_path / "plan.json"),
                "--expected-plan-sha256", "0" * 64,
                "--allow-factory-on",
                "--factory-off-flag", str(fake_flag),
            ]
        )
    assert exc.value.code == 2
    assert fake_flag.read_text(encoding="ascii") == "fake\n"
    assert fake_lock.read_text(encoding="ascii") == "fake-lock\n"

    monkeypatch.setattr(gate, "__file__", str(tmp_path / "copied" / "news_calendar_gate.py"))
    with pytest.raises(gate.NewsCalendarError, match="not the canonical"):
        gate._validated_policy(gate._PRODUCTION_POLICY)


@pytest.mark.parametrize(
    "forbidden",
    [
        ("--source-dir", r"X:\source"),
        ("--common-dir", r"X:\common"),
        ("--provenance-kind", "fake"),
        ("--provenance-path", r"X:\fake.ps1"),
        ("--provenance-sha256", "0" * 64),
    ],
)
def test_multi_plan_cli_rejects_caller_selected_authority(
    forbidden: tuple[str, str],
) -> None:
    with pytest.raises(SystemExit) as exc:
        gate.main(
            [
                "multi-plan",
                "--primary-candidate", r"D:\QM\data\news_calendar\news_calendar_2015_2025.csv",
                "--secondary-candidate", r"D:\QM\data\news_calendar\forex_factory_calendar_clean.csv",
                forbidden[0], forbidden[1],
            ]
        )
    assert exc.value.code == 2


def test_arbitrary_candidates_are_unavailable_to_production_policy(tmp_path: Path) -> None:
    candidates = tmp_path / "candidates"
    _write_pair(candidates)
    with pytest.raises(gate.NewsCalendarError, match="exact D source pair"):
        gate.build_multi_principal_publication_plan(
            candidates / gate.PRIMARY_NAME,
            candidates / gate.SECONDARY_NAME,
        )


def test_journal_is_pre_reserved_and_success_is_durably_receipted(tmp_path: Path) -> None:
    policy, plan, _ = _build_plan(tmp_path)
    journal = _evidence_path(policy, "journal")
    receipt = _evidence_path(policy, "receipt")
    real_publish = gate.publish_calendar_bundle_multi

    def assert_prepared(*args: object, **kwargs: object) -> dict[str, object]:
        record = json.loads(journal.read_text(encoding="utf-8"))
        assert record["state"] == "PREPARED"
        assert record["committed"] is False
        return real_publish(*args, **kwargs)

    with mock.patch.object(gate, "publish_calendar_bundle_multi", side_effect=assert_prepared):
        result = gate.execute_multi_principal_publication(
            plan,
            expected_plan_sha256=str(plan["plan_sha256"]),
            allow_factory_on=True,
            journal_output=journal,
            receipt_output=receipt,
            _policy=policy,
        )

    assert result["status"] == "committed"
    assert result["ok"] is True
    assert json.loads(receipt.read_text(encoding="utf-8")) == result
    final_journal = json.loads(journal.read_text(encoding="utf-8"))
    assert final_journal["state"] == "COMMITTED_RECEIPTED"
    assert final_journal["committed"] is True


def test_receipt_failure_after_mutation_reports_exact_committed_outcome(
    tmp_path: Path,
) -> None:
    policy, plan, _ = _build_plan(tmp_path)
    journal = _evidence_path(policy, "journal")
    receipt = _evidence_path(policy, "receipt")
    receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt.write_text('{"conflict":true}\n', encoding="ascii")

    result = gate.execute_multi_principal_publication(
        plan,
        expected_plan_sha256=str(plan["plan_sha256"]),
        allow_factory_on=True,
        journal_output=journal,
        receipt_output=receipt,
        _policy=policy,
    )

    assert result["status"] == "committed_receipt_failed"
    assert result["committed"] is True
    assert result["published"] is True
    assert result["ok"] is False
    assert gate._publication_outcome_exit_code(result) == 4
    final_journal = json.loads(journal.read_text(encoding="utf-8"))
    assert final_journal["state"] == "COMMITTED_RECEIPT_FAILED"
    assert gate.preflight_news_calendar(
        policy.source_dir, policy.common_dirs[0], use_cache=False
    ).ok


def test_receipt_and_journal_failure_still_returns_committed_receipt_failed(
    tmp_path: Path,
) -> None:
    policy, plan, _ = _build_plan(tmp_path)
    journal = _evidence_path(policy, "journal")
    receipt = _evidence_path(policy, "receipt")
    receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt.write_text('{"conflict":true}\n', encoding="ascii")
    real_transition = gate._replace_json_atomic_expected
    transitions = 0

    def fail_second_transition(*args: object, **kwargs: object) -> bytes:
        nonlocal transitions
        transitions += 1
        if transitions == 2:
            raise OSError("injected journal failure")
        return real_transition(*args, **kwargs)

    with mock.patch.object(
        gate, "_replace_json_atomic_expected", side_effect=fail_second_transition
    ):
        result = gate.execute_multi_principal_publication(
            plan,
            expected_plan_sha256=str(plan["plan_sha256"]),
            allow_factory_on=True,
            journal_output=journal,
            receipt_output=receipt,
            _policy=policy,
        )

    assert result["status"] == "committed_receipt_failed"
    assert result["committed"] is True
    assert "injected journal failure" in result["journal_error"]


def test_lock_release_failure_is_committed_but_retained_and_nonzero(
    tmp_path: Path,
) -> None:
    policy, plan, _ = _build_plan(tmp_path)
    journal = _evidence_path(policy, "journal")
    receipt = _evidence_path(policy, "receipt")
    lock_path = gate.path_for_factory_flag(policy.factory_off_flag)

    with mock.patch.object(
        gate.FactoryMutationLock,
        "_release_owned_open_file",
        return_value="unlink_failed",
    ):
        result = gate.execute_multi_principal_publication(
            plan,
            expected_plan_sha256=str(plan["plan_sha256"]),
            allow_factory_on=True,
            journal_output=journal,
            receipt_output=receipt,
            _policy=policy,
        )

    assert result["status"] == "committed_lock_retained"
    assert result["committed"] is True
    assert result["ok"] is False
    assert result["lock_release_status"] == "unlink_failed"
    assert gate._publication_outcome_exit_code(result) == 3
    assert json.loads(journal.read_text(encoding="utf-8"))["state"] == (
        "COMMITTED_LOCK_RETAINED_RECEIPTED"
    )
    assert json.loads(receipt.read_text(encoding="utf-8"))["status"] == (
        "committed_lock_retained"
    )
    lock_path.unlink(missing_ok=True)


def test_plan_reader_rejects_duplicate_json_keys(tmp_path: Path) -> None:
    plan_path = tmp_path / "duplicate.json"
    plan_path.write_text(
        '{"schema":"first","schema":"second","nested":{"x":1,"x":2}}',
        encoding="utf-8",
    )
    with pytest.raises(gate.NewsCalendarError, match="duplicate JSON key"):
        gate._read_plan(plan_path)


def test_atomic_json_output_is_create_only_or_byte_identical(tmp_path: Path) -> None:
    output = tmp_path / "evidence" / "plan.json"
    payload = {"schema": "fixture/v1", "plan_sha256": "a" * 64}
    assert gate._write_json_atomic_output(output, payload) == output.resolve()
    first = output.read_bytes()
    assert gate._write_json_atomic_output(output, payload) == output.resolve()
    assert output.read_bytes() == first

    with pytest.raises(gate.NewsCalendarError, match="refusing to overwrite differing"):
        gate._write_json_atomic_output(
            output, {"schema": "fixture/v1", "plan_sha256": "b" * 64}
        )
    assert output.read_bytes() == first
