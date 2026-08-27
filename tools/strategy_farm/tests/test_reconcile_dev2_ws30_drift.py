from __future__ import annotations

from pathlib import Path

import pytest

from tools.strategy_farm import reconcile_dev2_ws30_drift as subject


def test_provision_canonical_hash_matches_original_receipt() -> None:
    provision = subject._load_json(subject.PROVISION_RECEIPT)
    basis, expected = subject._expected_inventory(
        provision, custom_root=subject.CUSTOM_ROOT
    )
    assert len(expected) == 98
    assert subject._canonical_sha256(basis) == provision["target_file_set_sha256"]


def test_quarantine_projection_preserves_relative_custom_paths(tmp_path: Path) -> None:
    expected = {
        (subject.CUSTOM_ROOT / "history" / subject.SYMBOL / "2019.hcc").resolve(): {
            "kind": "history",
            "period": "2019",
            "size": 1,
            "sha256": "a" * 64,
        }
    }
    projected = subject._quarantine_expected_paths(expected, tmp_path.resolve())
    assert list(projected) == [
        (tmp_path / "Bases" / "Custom" / "history" / subject.SYMBOL / "2019.hcc").resolve()
    ]


def test_authorization_requires_process_scoped_flag(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv(subject.FLAG_NAME, raising=False)
    with pytest.raises(subject.ReconciliationRefused, match="required"):
        subject._validate_authorization(
            Path("missing.json"),
            quarantine_root=subject.DEFAULT_QUARANTINE_ROOT.resolve(),
            repo_root=subject.REPO_IMPORT_ROOT.resolve(),
        )
