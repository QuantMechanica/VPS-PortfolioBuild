from __future__ import annotations

from pathlib import Path

import pytest

from tools.strategy_farm.portfolio.ftmo_merge_secret_joint_shards import merge_shards


def _evaluation(pass_pct: float) -> dict:
    return {"historical_rolling": {"pass_pct": pass_pct}, "start_windows": 10}


def _shard(name: str, normal: float, adverse: float | None) -> dict:
    return {
        "scenario": "locked",
        "manifest_sha256": "abc",
        "stopped_after_development": True,
        "representations_screened": [name],
        "validation": None,
        "confirmation": None,
        "development": {
            "control_normal": _evaluation(60.0),
            "control_adverse": _evaluation(50.0),
            "rows": [
                {
                    "representation": name,
                    "candidate_weight_pct": 1.0,
                    "normal_pass_pct": normal,
                    "adverse_pass_pct": adverse,
                }
            ],
        },
    }


def _path(tmp_path: Path, name: str) -> Path:
    path = tmp_path / name
    path.write_text("{}\n", encoding="utf-8")
    return path


def test_merge_selects_joint_winner(tmp_path: Path) -> None:
    artifact = merge_shards(
        [
            (_path(tmp_path, "a.json"), _shard("a", 61.0, 50.5)),
            (_path(tmp_path, "b.json"), _shard("b", 62.0, 49.0)),
        ]
    )
    assert artifact["status"] == "DEVELOPMENT_SURVIVOR"
    assert artifact["winner"]["representation"] == "a"


def test_merge_keeps_validation_closed_without_joint_winner(tmp_path: Path) -> None:
    artifact = merge_shards(
        [(_path(tmp_path, "a.json"), _shard("a", 61.0, 49.0))]
    )
    assert artifact["status"] == "NO_DEVELOPMENT_SURVIVOR"
    assert artifact["validation_open_allowed"] is False


def test_merge_rejects_opened_validation(tmp_path: Path) -> None:
    shard = _shard("a", 61.0, 50.5)
    shard["validation"] = {"opened": True}
    with pytest.raises(ValueError, match="opened"):
        merge_shards([(_path(tmp_path, "a.json"), shard)])
