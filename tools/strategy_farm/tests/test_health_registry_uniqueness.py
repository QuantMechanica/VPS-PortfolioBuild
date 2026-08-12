from __future__ import annotations

import csv
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(REPO / "tools" / "strategy_farm"))

import health  # noqa: E402


def _write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def _fixture(
    tmp_path: Path,
    registry_rows: list[dict[str, str]],
    magic_rows: list[dict[str, str]],
    directories: tuple[str, ...],
) -> Path:
    _write_csv(
        tmp_path / "framework" / "registry" / "ea_id_registry.csv",
        ["ea_id", "slug", "strategy_id", "status", "owner", "created_at"],
        registry_rows,
    )
    _write_csv(
        tmp_path / "framework" / "registry" / "magic_numbers.csv",
        [
            "ea_id",
            "ea_slug",
            "symbol_slot",
            "symbol",
            "magic",
            "reserved_at",
            "reserved_by",
            "status",
        ],
        magic_rows,
    )
    for name in directories:
        (tmp_path / "framework" / "EAs" / name).mkdir(parents=True)
    return tmp_path


def _registry(ea_id: str, slug: str, status: str = "active") -> dict[str, str]:
    return {
        "ea_id": ea_id,
        "slug": slug,
        "strategy_id": slug,
        "status": status,
        "owner": "test",
        "created_at": "2026-07-19",
    }


def _magic(ea_id: str, slug: str, status: str = "active") -> dict[str, str]:
    bare = ea_id.removeprefix("QM5_")
    return {
        "ea_id": ea_id,
        "ea_slug": slug,
        "symbol_slot": "0",
        "symbol": "EURUSD.DWX",
        "magic": f"{bare}0000",
        "reserved_at": "2026-07-19",
        "reserved_by": "test",
        "status": status,
    }


def test_live_collision_normalizes_qm5_prefix_and_fails(tmp_path: Path) -> None:
    root = _fixture(
        tmp_path,
        [_registry("12784", "alpha"), _registry("QM5_12784", "beta")],
        [_magic("12784", "alpha"), _magic("QM5_12784", "beta")],
        ("QM5_12784_alpha", "QM5_12784_beta"),
    )

    result = health.chk_ea_id_slug_uniqueness(root)

    assert result["status"] == "FAIL"
    assert result["value"] == 1
    assert "12784" in result["detail"]


def test_registry_only_duplicate_warns(tmp_path: Path) -> None:
    root = _fixture(
        tmp_path,
        [_registry("9197", "real"), _registry("9197", "orphan")],
        [_magic("9197", "real")],
        ("QM5_9197_real",),
    )

    result = health.chk_ea_id_slug_uniqueness(root)

    assert result["status"] == "WARN"
    assert result["value"] == 1


def test_same_slug_duplicate_is_not_a_collision(tmp_path: Path) -> None:
    root = _fixture(
        tmp_path,
        [_registry("1158", "same"), _registry("QM5_1158", "same")],
        [_magic("1158", "same")],
        ("QM5_1158_same",),
    )

    assert health.chk_ea_id_slug_uniqueness(root)["status"] == "OK"


def test_retired_old_identity_and_active_rekey_are_ok(tmp_path: Path) -> None:
    root = _fixture(
        tmp_path,
        [
            _registry("12784", "progo"),
            _registry("12784", "intraday", "retired"),
            _registry("20007", "intraday"),
        ],
        [
            _magic("12784", "progo"),
            _magic("12784", "intraday", "retired"),
            _magic("20007", "intraday"),
        ],
        ("QM5_12784_progo", "QM5_20007_intraday"),
    )

    assert health.chk_ea_id_slug_uniqueness(root)["status"] == "OK"


def test_missing_registry_warns(tmp_path: Path) -> None:
    result = health.chk_ea_id_slug_uniqueness(tmp_path)

    assert result["status"] == "WARN"
    assert result["value"] is None


def test_uniqueness_check_is_wired_into_health() -> None:
    assert any(name == "ea_id_slug_uniqueness" for name, _, _ in health.ALL_CHECKS)
