import json
from pathlib import Path

from tools.strategy_farm import farmctl


def test_pending_selector_excludes_canonical_supersession(tmp_path: Path) -> None:
    farmctl.init_db(tmp_path)
    now = farmctl.utc_now()
    with farmctl.connect(tmp_path) as conn:
        for item_id in ("historical", "successor"):
            conn.execute(
                """INSERT INTO work_items
                   (id,kind,phase,ea_id,symbol,setfile_path,status,attempt_count,
                    payload_json,created_at,updated_at)
                   VALUES (?,'compile','COMPILE_EA','QM5_1001','','','pending',0,?,?,?)""",
                (item_id, json.dumps({}), now, now),
            )
        conn.execute(
            """INSERT INTO work_item_supersedes
               (work_item_id,superseded_by_work_item_id,reason,source_encoding,
                evidence_path,recorded_by,recorded_at)
               VALUES ('historical','successor','test','operator:test',NULL,'test',?)""",
            (now,),
        )
        conn.commit()
        claimable = [row["id"] for row in conn.execute(farmctl.pending_claim_order_sql())]

    assert claimable == ["successor"]
