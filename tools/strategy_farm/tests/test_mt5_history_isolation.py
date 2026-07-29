from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path

import pytest

from tools.strategy_farm import mt5_history_isolation as isolation


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
