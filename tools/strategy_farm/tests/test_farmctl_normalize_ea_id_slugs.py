from __future__ import annotations

import csv
from pathlib import Path

from tools.strategy_farm import farmctl


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _fixture(tmp_path: Path) -> Path:
    _write_csv(
        tmp_path / "framework" / "registry" / "ea_id_registry.csv",
        ["ea_id", "slug", "strategy_id", "status", "owner", "created_at"],
        [{
            "ea_id": "12108",
            "slug": "QM5_1271_hopwood",
            "strategy_id": "source",
            "status": "active",
            "owner": "test",
            "created_at": "2026-05-26",
        }],
    )
    _write_csv(
        tmp_path / "framework" / "registry" / "magic_numbers.csv",
        ["ea_id", "ea_slug", "symbol_slot", "symbol", "magic", "reserved_at", "reserved_by", "status"],
        [{
            "ea_id": "12108",
            "ea_slug": "hopwood",
            "symbol_slot": "0",
            "symbol": "EURUSD.DWX",
            "magic": "121080000",
            "reserved_at": "2026-05-26",
            "reserved_by": "test",
            "status": "active",
        }],
    )
    (tmp_path / "framework" / "EAs" / "QM5_12108_hopwood").mkdir(parents=True)
    return tmp_path


def test_normalize_ea_id_slug_dry_run_apply_and_idempotent(tmp_path: Path, monkeypatch) -> None:
    root = _fixture(tmp_path)
    monkeypatch.setattr(farmctl, "REPO_ROOT", root)

    dry_run = farmctl.normalize_ea_id_slugs(["QM5_12108"], evidence="evidence.md")
    applied = farmctl.normalize_ea_id_slugs(["12108"], evidence="evidence.md", apply=True)
    repeated = farmctl.normalize_ea_id_slugs(["12108"], evidence="evidence.md", apply=True)

    assert dry_run["dry_run"] is True
    assert dry_run["planned"][0]["after_slug"] == "hopwood"
    assert applied["applied"] is True
    assert applied["changed_count"] == 1
    assert repeated["idempotent_noop"] is True
    with (root / "framework" / "registry" / "ea_id_registry.csv").open(
        encoding="utf-8", newline=""
    ) as handle:
        assert next(csv.DictReader(handle))["slug"] == "hopwood"


def test_normalize_ea_id_slug_refuses_disagreeing_magic_without_mutation(
    tmp_path: Path, monkeypatch
) -> None:
    root = _fixture(tmp_path)
    magic = root / "framework" / "registry" / "magic_numbers.csv"
    text = magic.read_text(encoding="utf-8").replace(",hopwood,", ",different,")
    magic.write_text(text, encoding="utf-8", newline="\n")
    registry = root / "framework" / "registry" / "ea_id_registry.csv"
    before = registry.read_bytes()
    monkeypatch.setattr(farmctl, "REPO_ROOT", root)

    result = farmctl.normalize_ea_id_slugs(
        ["12108"], evidence="evidence.md", apply=True
    )

    assert result["applied"] is False
    assert result["refused"][0]["reason"] == "identity_sources_disagree"
    assert registry.read_bytes() == before
