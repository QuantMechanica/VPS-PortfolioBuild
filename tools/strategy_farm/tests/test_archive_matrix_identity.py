from __future__ import annotations

import json
from pathlib import Path

from tools.strategy_farm import farmctl
from tools.strategy_farm.dashboards import archive_matrix


def test_f4_marks_only_identity_backed_mismatched_pass_as_stale(
    tmp_path: Path, monkeypatch,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    now = "2026-08-23T12:00:00Z"
    with farmctl.connect(root) as con:
        for wid, symbol, identity in (
            ("stale", "EURUSD.DWX", "a" * 64),
            ("fallback", "GBPUSD.DWX", None),
        ):
            con.execute(
                """
                INSERT INTO work_items(
                  id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
                  payload_json,created_at,updated_at,ex5_sha256
                ) VALUES(?, 'backtest','Q02','QM5_1',?,?,'done','PASS',0,?,?,?,?)
                """,
                (wid, symbol, "x.set", json.dumps({"verdict_taxonomy": "strategy"}),
                 now, now, identity),
            )
        con.commit()
    monkeypatch.setattr(archive_matrix, "current_ex5_sha256_by_ea", lambda: {"QM5_1": "b" * 64})
    monkeypatch.setattr(archive_matrix, "_card_targets", lambda: {})

    data = archive_matrix.collect(root / farmctl.DB_REL)
    card = data["cards"][0]
    states = [packed & 7 for packed in card["cells"]["Q02"]]
    assert archive_matrix.ST_STALE in states
    assert archive_matrix.ST_PASS in states
    assert data["identity_cells"] == 1
    assert data["stale_cells"] == 1
    rendered = archive_matrix.render_matrix_page(data)
    assert "F4 stale-pass identity is enabled" in rendered
    assert "stale PASS" in rendered
