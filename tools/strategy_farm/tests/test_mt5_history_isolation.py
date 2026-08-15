from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path

import pytest

from tools.strategy_farm import mt5_history_isolation as isolation
from tools.strategy_farm import custom_history_contract as history_contract


def _row(terminal: str, component: str, identity: str, *, exists: bool = True):
    return {
        "terminal": terminal,
        "component": component,
        "path": f"X:/{terminal}/{component}",
        "exists": exists,
        "resolved_identity": identity,
    }


def _hash_without_identity(payload: dict) -> str:
    body = {key: value for key, value in payload.items() if key != "audit_sha256"}
    encoded = json.dumps(
        body,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
        allow_nan=False,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def test_unique_mutable_stores_pass_and_hash_deterministically(tmp_path: Path) -> None:
    rows = [
        _row("T1", "Tester", str(tmp_path / "T1" / "Tester")),
        _row("T1", "Bases", str(tmp_path / "T1" / "Bases")),
        _row("T1", "Bases/Custom", str(tmp_path / "T1" / "Bases" / "Custom")),
        _row("T2", "Tester", str(tmp_path / "T2" / "Tester")),
        _row("T2", "Bases", str(tmp_path / "T2" / "Bases")),
        _row("T2", "Bases/Custom", str(tmp_path / "T2" / "Bases" / "Custom")),
    ]
    protected = [str(tmp_path / "live")]
    first = isolation.evaluate_inventory(rows, protected_root_identities=protected)
    second = isolation.evaluate_inventory(
        list(reversed(rows)), protected_root_identities=protected
    )

    assert first == second
    assert first["status"] == "PASS_ISOLATED"
    assert first["findings"] == []
    assert first["audit_sha256"] == _hash_without_identity(first)


def test_shared_custom_history_fails_closed(tmp_path: Path) -> None:
    shared = str(tmp_path / "shared" / "Custom")
    payload = isolation.evaluate_inventory(
        [
            _row("T1", "Bases/Custom", shared),
            _row("T2", "Bases/Custom", shared.upper()),
        ],
        protected_root_identities=[],
    )

    assert payload["status"] == "FAIL_CLOSED"
    assert payload["findings"] == [
        {
            "code": "CROSS_TERMINAL_MUTABLE_STORE_COLLISION",
            "component": "bases/custom",
            "terminals": ["T1", "T2"],
            "resolved_identity": os.path.normcase(os.path.normpath(shared)).casefold(),
        }
    ]


def test_live_alias_and_missing_store_both_fail_closed(tmp_path: Path) -> None:
    protected = tmp_path / "T_Live"
    payload = isolation.evaluate_inventory(
        [
            _row("T1", "Tester", str(protected / "Tester")),
            _row("T2", "Tester", str(tmp_path / "T2" / "Tester"), exists=False),
        ],
        protected_root_identities=[str(protected)],
    )

    assert payload["status"] == "FAIL_CLOSED"
    assert {finding["code"] for finding in payload["findings"]} == {
        "LIVE_ADJACENT_STORE_ALIAS",
        "MUTABLE_STORE_MISSING",
    }


def test_collection_is_read_only_and_resolves_symlink_when_supported(tmp_path: Path) -> None:
    for terminal in ("T1", "T2"):
        (tmp_path / terminal / "Tester").mkdir(parents=True)
        (tmp_path / terminal / "Bases" / "Custom").mkdir(parents=True)

    before = sorted(str(path.relative_to(tmp_path)) for path in tmp_path.rglob("*"))
    rows = isolation.collect_inventory(mt5_root=tmp_path, terminals=("T1", "T2"))
    after = sorted(str(path.relative_to(tmp_path)) for path in tmp_path.rglob("*"))

    assert before == after
    assert len(rows) == 6
    assert all(row["exists"] for row in rows)


def test_cross_component_exact_alias_fails_closed(tmp_path: Path) -> None:
    shared = str(tmp_path / "shared")
    payload = isolation.evaluate_inventory(
        [
            _row("T1", "Tester", shared),
            _row("T2", "Bases", shared.upper()),
        ],
        protected_root_identities=[],
    )

    assert payload["status"] == "FAIL_CLOSED"
    finding = payload["findings"][0]
    assert finding["code"] == "CROSS_COMPONENT_MUTABLE_STORE_COLLISION"
    assert finding["components"] == ["bases", "tester"]
    assert finding["relationship"] == "EXACT_IDENTITY"
    assert finding["terminals"] == ["T1", "T2"]


def test_cross_terminal_ancestor_overlap_fails_closed(tmp_path: Path) -> None:
    shared = tmp_path / "shared"
    payload = isolation.evaluate_inventory(
        [
            _row("T1", "Tester", str(shared)),
            _row("T2", "Bases/Custom", str(shared / "child")),
        ],
        protected_root_identities=[],
    )

    assert payload["status"] == "FAIL_CLOSED"
    finding = payload["findings"][0]
    assert finding["code"] == "CROSS_TERMINAL_MUTABLE_STORE_OVERLAP"
    assert finding["relationship"] == "ANCESTOR_DESCENDANT"
    assert finding["ancestor"]["terminal"] == "T1"
    assert finding["descendant"]["terminal"] == "T2"


def test_unexpected_same_terminal_component_nesting_fails_closed(tmp_path: Path) -> None:
    bases = tmp_path / "T1" / "Bases"
    payload = isolation.evaluate_inventory(
        [
            _row("T1", "Bases", str(bases)),
            _row("T1", "Bases/Custom", str(bases / "Custom")),
            _row("T1", "Tester", str(bases / "Tester")),
        ],
        protected_root_identities=[],
    )

    assert payload["status"] == "FAIL_CLOSED"
    assert [finding["code"] for finding in payload["findings"]] == [
        "CROSS_COMPONENT_MUTABLE_STORE_OVERLAP"
    ]
    assert payload["findings"][0]["components"] == ["bases", "tester"]


def test_pure_evaluator_never_resolves_filesystem_paths(
    tmp_path: Path, monkeypatch
) -> None:
    def forbidden_resolve(*_args, **_kwargs):
        raise AssertionError("pure evaluator must not call Path.resolve")

    monkeypatch.setattr(Path, "resolve", forbidden_resolve)
    payload = isolation.evaluate_inventory(
        [_row("T1", "Tester", str(tmp_path / "T1" / "Tester"))],
        protected_root_identities=[str(tmp_path / "T_Live")],
    )

    assert payload["status"] == "PASS_ISOLATED"


@pytest.mark.parametrize(
    ("mutable_suffix", "protected_suffix", "relationship"),
    [
        ("T_Live/Tester", "T_Live", "MUTABLE_WITHIN_PROTECTED"),
        ("mt5", "mt5/T_Live", "PROTECTED_WITHIN_MUTABLE"),
        ("T_Live", "T_Live", "EXACT_IDENTITY"),
    ],
)
def test_pure_evaluator_detects_protected_overlap_in_both_directions(
    tmp_path: Path,
    monkeypatch,
    mutable_suffix: str,
    protected_suffix: str,
    relationship: str,
) -> None:
    def forbidden_resolve(*_args, **_kwargs):
        raise AssertionError("pure evaluator must not call Path.resolve")

    mutable = tmp_path.joinpath(*mutable_suffix.split("/"))
    protected = tmp_path.joinpath(*protected_suffix.split("/"))
    monkeypatch.setattr(Path, "resolve", forbidden_resolve)
    payload = isolation.evaluate_inventory(
        [_row("T1", "Tester", str(mutable))],
        protected_root_identities=[str(protected)],
    )

    assert payload["status"] == "FAIL_CLOSED"
    assert payload["findings"][0]["code"] == "LIVE_ADJACENT_STORE_ALIAS"
    assert payload["findings"][0]["protected_root_overlaps"] == [
        {
            "protected_root": isolation._normalize_identity_text(str(protected)),
            "relationship": relationship,
        }
    ]


def test_filesystem_boundary_resolves_protected_roots(tmp_path: Path) -> None:
    protected = tmp_path / "T_Live"
    protected.mkdir()

    identities = isolation.resolve_protected_root_identities([protected])

    assert identities == (isolation._identity(protected).casefold(),)


def _variant_a_fixture(tmp_path: Path) -> tuple[Path, Path]:
    archive_source = tmp_path / "archive-source"
    source_files = {
        "history/EURUSD.DWX/2025.hcc": b"archive-bars",
        "ticks/EURUSD.DWX/202501.tkc": b"archive-ticks",
        "history/GBPUSD.DWX/2025.hcc": b"gbp-archive-bars",
        "ticks/GBPUSD.DWX/202501.tkc": b"gbp-archive-ticks",
        "history/EURUSD.DWX/2026.hcc": b"private-bars",
        "state.dat": b"private-state",
    }
    for relative, body in source_files.items():
        path = archive_source.joinpath(*relative.split("/"))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(body)
    manifest = history_contract.build_archive_manifest(
        archive_source,
        runner_identity="TEST\\Runner",
        created_at_utc="2026-08-07T00:00:00+00:00",
    )
    manifest_path = tmp_path / "manifest.json"
    history_contract.write_json_atomic(manifest_path, manifest)
    archive_paths = {row["relative_path"] for row in manifest["files"]}
    mt5_root = tmp_path / "mt5"
    for terminal in history_contract.DEFAULT_RUNNER_TERMINALS:
        custom = mt5_root / terminal / "Bases" / "Custom"
        (mt5_root / terminal / "Tester").mkdir(parents=True)
        for relative in source_files:
            source = archive_source.joinpath(*relative.split("/"))
            target = custom.joinpath(*relative.split("/"))
            target.parent.mkdir(parents=True, exist_ok=True)
            if relative in archive_paths:
                os.link(source, target)
            else:
                target.write_bytes(source.read_bytes())
    return mt5_root, manifest_path


def test_variant_a_file_ids_and_manifest_equality_pass(tmp_path: Path) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    payload = isolation.audit_history_isolation(
        mt5_root=mt5_root,
        protected_roots=(),
        manifest_path=manifest_path,
        acl_probe=lambda path, identity: {"write_denied": True},
    )

    assert payload["status"] == "PASS_ISOLATED", payload
    assert payload["variant_a_file_audit"]["status"] == "PASS_ISOLATED"
    assert len(payload["variant_a_file_audit"]["terminal_summaries"]) == 10


def test_sparse_dispatch_records_absent_bystanders_as_pruned_by_design(
    tmp_path: Path,
) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    manifest = history_contract.load_manifest(manifest_path)
    for row in manifest["files"]:
        if "GBPUSD.DWX" in str(row["relative_path"]):
            (
                mt5_root
                / "T1"
                / "Bases"
                / "Custom"
                / Path(row["relative_path"])
            ).unlink()

    payload = isolation.audit_history_isolation(
        mt5_root=mt5_root,
        protected_roots=(),
        manifest_path=manifest_path,
        verify_archive_hashes=False,
        hash_private_terminals=("T1",),
        sparse_contract=True,
        claim_terminal="T1",
        required_symbols=("EURUSD.DWX",),
    )

    assert payload["status"] == "PASS_ISOLATED", payload
    audit = payload["variant_a_file_audit"]
    observations = [
        row for row in audit["observations"] if row["code"] == "PRUNED_BY_DESIGN"
    ]
    assert len(observations) == 2
    assert {row["terminal"] for row in observations} == {"T1"}
    assert all("GBPUSD.DWX" in row["relative_path"] for row in observations)
    assert not {
        "MANIFEST_ARCHIVE_FILE_MISSING",
        "TERMINAL_MANIFEST_INCOMPLETE",
    } & {row["code"] for row in audit["findings"]}


def test_sparse_dispatch_allows_pre_copy_restore_but_requires_post_copy_file(
    tmp_path: Path,
) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    required = (
        mt5_root
        / "T1"
        / "Bases"
        / "Custom"
        / "history"
        / "EURUSD.DWX"
        / "2025.hcc"
    )
    required.unlink()
    options = {
        "mt5_root": mt5_root,
        "protected_roots": (),
        "manifest_path": manifest_path,
        "verify_archive_hashes": False,
        "hash_private_terminals": ("T1",),
        "sparse_contract": True,
        "claim_terminal": "T1",
        "required_symbols": ("EURUSD.DWX",),
    }

    pre_copy = isolation.audit_history_isolation(
        **options, allow_required_restore=True
    )
    post_copy = isolation.audit_history_isolation(
        **options, allow_required_restore=False
    )

    assert pre_copy["status"] == "PASS_ISOLATED", pre_copy
    assert "RESTORE_ON_DEMAND_REQUIRED" in {
        row["code"]
        for row in pre_copy["variant_a_file_audit"]["observations"]
    }
    assert post_copy["status"] == "FAIL_CLOSED"
    assert "MANIFEST_ARCHIVE_FILE_MISSING" in {
        row["code"] for row in post_copy["variant_a_file_audit"]["findings"]
    }


def test_variant_a_mixed_family_and_private_archives_pass_without_acl_deny(
    tmp_path: Path,
) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    manifest = history_contract.load_manifest(manifest_path)
    for row in manifest["files"]:
        target = mt5_root / "T1" / "Bases" / "Custom" / Path(row["relative_path"])
        body = target.read_bytes()
        target.unlink()
        target.write_bytes(body)

    payload = isolation.audit_history_isolation(
        mt5_root=mt5_root,
        protected_roots=(),
        manifest_path=manifest_path,
        verify_archive_hashes=False,
        acl_probe=lambda path, identity: {"write_denied": False},
    )

    assert payload["status"] == "PASS_ISOLATED", payload
    audit = payload["variant_a_file_audit"]
    assert audit["terminal_private_hash_verification"] == "FULL"
    t1 = next(row for row in audit["terminal_summaries"] if row["terminal"] == "T1")
    assert t1["private_archive_files"] == len(manifest["files"])
    assert not {
        finding["code"] for finding in audit["findings"]
    } & {"ARCHIVE_LINK_COUNT_TOO_LOW", "ARCHIVE_RUNNER_WRITE_NOT_DENIED"}


def test_variant_a_fast_gate_hashes_and_rejects_corrupt_private_archive(
    tmp_path: Path,
) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    manifest = history_contract.load_manifest(manifest_path)
    row = manifest["files"][0]
    target = mt5_root / "T1" / "Bases" / "Custom" / Path(row["relative_path"])
    target.unlink()
    target.write_bytes(b"x" * int(row["size"]))

    payload = isolation.audit_history_isolation(
        mt5_root=mt5_root,
        protected_roots=(),
        manifest_path=manifest_path,
        verify_archive_hashes=False,
    )

    assert payload["status"] == "FAIL_CLOSED"
    codes = {row["code"] for row in payload["variant_a_file_audit"]["findings"]}
    assert "ARCHIVE_MANIFEST_MISMATCH" in codes


def test_variant_a_private_archive_inode_must_be_terminal_unique(tmp_path: Path) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    manifest = history_contract.load_manifest(manifest_path)
    row = manifest["files"][0]
    t1 = mt5_root / "T1" / "Bases" / "Custom" / Path(row["relative_path"])
    body = t1.read_bytes()
    t1.unlink()
    t1.write_bytes(body)
    t2 = mt5_root / "T2" / "Bases" / "Custom" / Path(row["relative_path"])
    t2.unlink()
    os.link(t1, t2)

    payload = isolation.audit_history_isolation(
        mt5_root=mt5_root,
        protected_roots=(),
        manifest_path=manifest_path,
        verify_archive_hashes=False,
    )

    assert payload["status"] == "FAIL_CLOSED"
    codes = {row["code"] for row in payload["variant_a_file_audit"]["findings"]}
    assert "PRIVATE_ARCHIVE_FILE_ID_SHARED" in codes
    assert "PRIVATE_ARCHIVE_LINK_COUNT_INVALID" in codes


def test_variant_a_shared_mutable_file_id_fails_closed(tmp_path: Path) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    t1 = mt5_root / "T1" / "Bases" / "Custom" / "history" / "EURUSD.DWX" / "2026.hcc"
    t2 = mt5_root / "T2" / "Bases" / "Custom" / "history" / "EURUSD.DWX" / "2026.hcc"
    t2.unlink()
    os.link(t1, t2)

    payload = isolation.audit_history_isolation(
        mt5_root=mt5_root,
        protected_roots=(),
        manifest_path=manifest_path,
        acl_probe=lambda path, identity: {"write_denied": True},
    )

    assert payload["status"] == "FAIL_CLOSED"
    codes = {row["code"] for row in payload["variant_a_file_audit"]["findings"]}
    assert "CROSS_TERMINAL_MUTABLE_FILE_ID" in codes


def test_variant_a_full_audit_rejects_incomplete_mutable_set(tmp_path: Path) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    missing = mt5_root / "T10" / "Bases" / "Custom" / "state.dat"
    missing.unlink()

    payload = isolation.audit_history_isolation(
        mt5_root=mt5_root,
        protected_roots=(),
        manifest_path=manifest_path,
        acl_probe=lambda path, identity: {"write_denied": True},
    )

    assert payload["status"] == "FAIL_CLOSED"
    codes = {row["code"] for row in payload["variant_a_file_audit"]["findings"]}
    assert "TERMINAL_MUTABLE_FILE_MISSING" in codes


def test_default_runner_and_protected_sets_resolve_t5_directive() -> None:
    assert "T5" in isolation.DEFAULT_RUNNER_TERMINALS
    assert Path(r"D:\QM\mt5\T5") not in isolation.DEFAULT_PROTECTED_ROOTS
    assert Path(r"C:\QM\mt5\T_Live") in isolation.DEFAULT_PROTECTED_ROOTS
    assert Path(r"D:\QM\mt5\FTMO_STREAM1") in isolation.DEFAULT_PROTECTED_ROOTS
    assert Path(r"D:\QM\mt5\FTMO_STREAM2") in isolation.DEFAULT_PROTECTED_ROOTS


def test_variant_a_dispatch_gate_never_opens_foreign_private_archives(
    tmp_path: Path, monkeypatch
) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    manifest = history_contract.load_manifest(manifest_path)
    for terminal in ("T1", "T2"):
        for row in manifest["files"]:
            target = mt5_root / terminal / "Bases" / "Custom" / Path(row["relative_path"])
            body = target.read_bytes()
            target.unlink()
            target.write_bytes(body)

    real_sha256_file = isolation.sha256_file
    opened: list[str] = []

    def guarded_sha256_file(path):
        text = str(path)
        opened.append(text)
        if f"{os.sep}T1{os.sep}" in text:
            raise PermissionError(13, "Permission denied")
        return real_sha256_file(path)

    monkeypatch.setattr(isolation, "sha256_file", guarded_sha256_file)

    payload = isolation.audit_history_isolation(
        mt5_root=mt5_root,
        protected_roots=(),
        manifest_path=manifest_path,
        verify_archive_hashes=False,
        hash_private_terminals=("T2",),
    )

    assert payload["status"] == "PASS_ISOLATED", payload
    audit = payload["variant_a_file_audit"]
    assert audit["terminal_private_hash_verification"] == "CLAIMING_TERMINAL_ONLY"
    assert not any(f"{os.sep}T1{os.sep}" in text for text in opened)


def test_variant_a_dispatch_gate_still_hashes_claiming_terminal(
    tmp_path: Path,
) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    manifest = history_contract.load_manifest(manifest_path)
    row = manifest["files"][0]
    target = mt5_root / "T1" / "Bases" / "Custom" / Path(row["relative_path"])
    target.unlink()
    target.write_bytes(b"x" * int(row["size"]))

    payload = isolation.audit_history_isolation(
        mt5_root=mt5_root,
        protected_roots=(),
        manifest_path=manifest_path,
        verify_archive_hashes=False,
        hash_private_terminals=("T1",),
    )

    assert payload["status"] == "FAIL_CLOSED"
    codes = {row["code"] for row in payload["variant_a_file_audit"]["findings"]}
    assert "ARCHIVE_MANIFEST_MISMATCH" in codes


def test_variant_a_foreign_private_size_drift_still_fails_stat_only(
    tmp_path: Path,
) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    manifest = history_contract.load_manifest(manifest_path)
    row = manifest["files"][0]
    target = mt5_root / "T1" / "Bases" / "Custom" / Path(row["relative_path"])
    target.unlink()
    target.write_bytes(b"short")

    payload = isolation.audit_history_isolation(
        mt5_root=mt5_root,
        protected_roots=(),
        manifest_path=manifest_path,
        verify_archive_hashes=False,
        hash_private_terminals=("T2",),
    )

    assert payload["status"] == "FAIL_CLOSED"
    codes = {row["code"] for row in payload["variant_a_file_audit"]["findings"]}
    assert "ARCHIVE_MANIFEST_MISMATCH" in codes


def test_variant_a_copy_on_claim_temp_files_are_ignored(tmp_path: Path) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    manifest = history_contract.load_manifest(manifest_path)
    temp = (
        mt5_root
        / "T1"
        / "Bases"
        / "Custom"
        / "history"
        / "EURUSD.DWX"
        / ".2025.hcc.copy-on-claim.123.deadbeef.tmp"
    )
    temp.write_bytes(b"transient")

    rows = isolation.collect_variant_a_file_inventory(
        mt5_root=mt5_root,
        terminals=history_contract.DEFAULT_RUNNER_TERMINALS,
        manifest=manifest,
        verify_archive_hashes=False,
    )
    assert not any(
        ".copy-on-claim." in str(row.get("relative_path")) for row in rows
    )

    payload = isolation.audit_history_isolation(
        mt5_root=mt5_root,
        protected_roots=(),
        manifest_path=manifest_path,
        verify_archive_hashes=False,
    )
    assert payload["status"] == "PASS_ISOLATED", payload


def _link_count_finding(relative: str, terminal: str = "T2") -> dict:
    return {
        "code": "ARCHIVE_LINK_COUNT_TOO_LOW",
        "terminal": terminal,
        "relative_path": relative,
        "storage_mode": "FAMILY_HARDLINK",
        "actual": 10,
        "minimum": 11,
    }


def test_reconcile_clears_torn_link_count_after_privatization(tmp_path: Path) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    manifest = history_contract.load_manifest(manifest_path)
    relative = "history/EURUSD.DWX/2025.hcc"
    target = mt5_root / "T1" / "Bases" / "Custom" / Path(relative)
    body = target.read_bytes()
    target.unlink()
    target.write_bytes(body)

    result = isolation.reconcile_archive_link_count_findings(
        mt5_root=mt5_root,
        terminals=history_contract.DEFAULT_RUNNER_TERMINALS,
        manifest=manifest,
        findings=[_link_count_finding(relative)],
    )

    assert result["remaining"] == []
    assert len(result["cleared"]) == 1
    recount = result["recounts"][0]
    assert recount["family_members"] == 9
    assert recount["link_count"] == recount["expected"]


def test_reconcile_keeps_deleted_rollback_link_fail_closed(tmp_path: Path) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    manifest = history_contract.load_manifest(manifest_path)
    relative = "history/EURUSD.DWX/2025.hcc"
    (tmp_path / "archive-source" / Path(relative)).unlink()

    result = isolation.reconcile_archive_link_count_findings(
        mt5_root=mt5_root,
        terminals=history_contract.DEFAULT_RUNNER_TERMINALS,
        manifest=manifest,
        findings=[_link_count_finding(relative)],
        attempts=2,
        sleeper=lambda seconds: None,
    )

    assert result["cleared"] == []
    assert len(result["remaining"]) == 1


def test_reconcile_keeps_cross_terminal_private_alias_fail_closed(
    tmp_path: Path,
) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    manifest = history_contract.load_manifest(manifest_path)
    relative = "history/EURUSD.DWX/2025.hcc"
    t1 = mt5_root / "T1" / "Bases" / "Custom" / Path(relative)
    t2 = mt5_root / "T2" / "Bases" / "Custom" / Path(relative)
    body = t1.read_bytes()
    t1.unlink()
    t1.write_bytes(body)
    t2.unlink()
    os.link(t1, t2)

    result = isolation.reconcile_archive_link_count_findings(
        mt5_root=mt5_root,
        terminals=history_contract.DEFAULT_RUNNER_TERMINALS,
        manifest=manifest,
        findings=[_link_count_finding(relative, terminal="T3")],
        attempts=2,
        sleeper=lambda seconds: None,
    )

    assert result["cleared"] == []
    assert len(result["remaining"]) == 1


def test_reconcile_keeps_missing_archive_fail_closed(tmp_path: Path) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    manifest = history_contract.load_manifest(manifest_path)
    relative = "history/EURUSD.DWX/2025.hcc"
    (mt5_root / "T2" / "Bases" / "Custom" / Path(relative)).unlink()

    result = isolation.reconcile_archive_link_count_findings(
        mt5_root=mt5_root,
        terminals=history_contract.DEFAULT_RUNNER_TERMINALS,
        manifest=manifest,
        findings=[_link_count_finding(relative, terminal="T3")],
        attempts=2,
        sleeper=lambda seconds: None,
    )

    assert result["cleared"] == []
    assert len(result["remaining"]) == 1


def test_reconcile_all_private_family_clears(tmp_path: Path) -> None:
    mt5_root, manifest_path = _variant_a_fixture(tmp_path)
    manifest = history_contract.load_manifest(manifest_path)
    relative = "history/EURUSD.DWX/2025.hcc"
    for terminal in history_contract.DEFAULT_RUNNER_TERMINALS:
        target = mt5_root / terminal / "Bases" / "Custom" / Path(relative)
        body = target.read_bytes()
        target.unlink()
        target.write_bytes(body)

    result = isolation.reconcile_archive_link_count_findings(
        mt5_root=mt5_root,
        terminals=history_contract.DEFAULT_RUNNER_TERMINALS,
        manifest=manifest,
        findings=[_link_count_finding(relative)],
    )

    assert result["remaining"] == []
    assert len(result["cleared"]) == 1
    assert result["recounts"][0]["family_members"] == 0
