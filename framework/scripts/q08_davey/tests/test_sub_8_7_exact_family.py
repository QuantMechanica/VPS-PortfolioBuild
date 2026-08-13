"""P0 (plan v2 A3 / codex finding 3) — PBO exact-family enforcement.

PBO is only defined on a rectangular (config x slice) grid from ONE family. A ragged
grid usually means losing configurations were lost, which biases PBO downward.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3]))

from scripts.q08_davey import sub_8_7_pbo as m  # noqa: E402


def _write(tmp_path: Path, rows: list[tuple[str, str, float]], meta: dict | None = None) -> Path:
    p = tmp_path / "scores.csv"
    lines = ["config_id,slice_id,score"]
    lines += [f"{c},{s},{v}" for c, s, v in rows]
    p.write_text("\n".join(lines) + "\n", encoding="utf-8")
    if meta is not None:
        (tmp_path / "scores_meta.json").write_text(json.dumps(meta), encoding="utf-8")
    return p


def _rect(n_cfg: int, n_slice: int) -> list[tuple[str, str, float]]:
    return [(f"c{c}", f"s{s}", float((c * 7 + s * 3) % 11) - 5.0)
            for c in range(n_cfg) for s in range(n_slice)]


def test_rectangular_family_is_accepted(tmp_path):
    path = _write(tmp_path, _rect(6, 10))
    res = m.run(scores_path=path)
    assert res["detail"] is None or "not_rectangular" not in res["detail"]
    assert "configs_lost" not in (res["detail"] or "")


def test_ragged_family_fails_closed(tmp_path):
    rows = _rect(6, 10)
    # drop two slices from one config — the classic "loser died early" shape
    rows = [r for r in rows if not (r[0] == "c3" and r[1] in {"s8", "s9"})]
    path = _write(tmp_path, rows)
    res = m.run(scores_path=path)
    assert res["status"] == "INVALID"
    assert "pbo_family_not_rectangular" in res["detail"]
    ev = res["evidence"]
    assert ev["n_slices_common"] < ev["n_slices_union"]
    assert ev["short_configs"][0]["config_id"] == "c3"
    assert ev["short_configs"][0]["missing_slices"] == 2


def test_lost_configs_detected_against_declared_count(tmp_path):
    path = _write(tmp_path, _rect(5, 10),
                  meta={"schema_version": 1, "n_configs": 9, "config_source": "Q03"})
    res = m.run(scores_path=path)
    assert res["status"] == "INVALID"
    assert "pbo_configs_lost" in res["detail"]
    assert res["evidence"]["declared_n_configs"] == 9
    assert res["evidence"]["present_n_configs"] == 5


def test_declared_count_matching_is_accepted(tmp_path):
    path = _write(tmp_path, _rect(5, 10),
                  meta={"schema_version": 1, "n_configs": 5, "config_source": "Q03"})
    res = m.run(scores_path=path)
    assert "configs_lost" not in (res["detail"] or "")


def test_declared_count_smaller_than_present_is_not_a_loss(tmp_path):
    """More configs than declared is not the failure mode this guard covers."""
    path = _write(tmp_path, _rect(7, 10),
                  meta={"schema_version": 1, "n_configs": 5, "config_source": "Q03"})
    res = m.run(scores_path=path)
    assert "configs_lost" not in (res["detail"] or "")
