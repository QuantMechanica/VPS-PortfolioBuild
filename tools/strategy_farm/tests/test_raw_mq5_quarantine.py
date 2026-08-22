from __future__ import annotations

import json
import subprocess
from pathlib import Path

from tools.strategy_farm import agent_router, farmctl, raw_mq5_quarantine as quarantine


REPO_ROOT = Path(__file__).resolve().parents[3]
LEDGER = REPO_ROOT / quarantine.LEDGER_REL
COMPILE_ONE = REPO_ROOT / "framework" / "scripts" / "compile_one.ps1"


def test_three_raw_sources_are_registered_do_not_deploy() -> None:
    entries = quarantine.load_ledger(REPO_ROOT)

    assert len(entries) == 3
    assert {entry.source_basename for entry in entries} == {
        "Prop Challenger EA.mq5",
        "King Trader EA.mq5",
        "TickTrader2.mq5",
    }
    assert {entry.intake_state for entry in entries} == {"RAW_UNTRUSTED"}
    assert {entry.deployment_policy for entry in entries} == {"DO_NOT_DEPLOY"}
    assert {entry.required_reentry for entry in entries} == {
        "NEW_CARD_V5_REIMPLEMENT_FULL_GATE_CHAIN"
    }
    assert all(
        entry.farm_source_id
        == farmctl.source_id(
            {"source_type": "local_archive", "uri": entry.source_locator}
        )
        for entry in entries
    )


def test_direct_gdrive_compile_and_promotion_are_refused_before_io() -> None:
    missing_g_source = r"G:\My Drive\Incoming\Prop Challenger EA.mq5"

    compile_result = quarantine.check_source_path(
        missing_g_source,
        purpose="compile",
        repo_root=REPO_ROOT,
    )
    promotion_result = quarantine.check_source_path(
        missing_g_source,
        purpose="promotion",
        repo_root=REPO_ROOT,
        enforce_canonical=False,
    )

    assert compile_result["code"] == "RAW_MQ5_GDRIVE_DIRECT_USE_REFUSED"
    assert promotion_result["code"] == "RAW_MQ5_GDRIVE_DIRECT_USE_REFUSED"
    assert not compile_result["allowed"]
    assert not promotion_result["allowed"]


def test_quarantined_basename_copy_is_refused_but_v5_reimplementation_passes(
    tmp_path: Path,
) -> None:
    ea_dir = tmp_path / "framework" / "EAs" / "QM5_99003_fixture"
    ea_dir.mkdir(parents=True)
    raw_copy = ea_dir / "King Trader EA.mq5"
    v5_source = ea_dir / "QM5_99003_fixture.mq5"
    raw_copy.write_text("void OnTick() {}\n", encoding="utf-8")
    v5_source.write_text("void OnTick() {}\n", encoding="utf-8")

    refused = quarantine.check_source_path(
        raw_copy,
        purpose="promotion",
        repo_root=tmp_path,
        ledger_path=LEDGER,
    )
    allowed = quarantine.check_source_path(
        v5_source,
        purpose="promotion",
        repo_root=tmp_path,
        ledger_path=LEDGER,
    )

    assert refused["code"] == "RAW_MQ5_QUARANTINED_BASENAME_REFUSED"
    assert not refused["allowed"]
    assert allowed["code"] == "RAW_MQ5_SOURCE_ALLOWED"
    assert allowed["allowed"]


def test_compile_one_refuses_gdrive_source_without_starting_metaeditor() -> None:
    result = subprocess.run(
        [
            "pwsh",
            "-NoProfile",
            "-File",
            str(COMPILE_ONE),
            "-EAPath",
            r"G:\My Drive\Incoming\TickTrader2.mq5",
        ],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=30,
    )

    assert result.returncode != 0
    assert "RAW_MQ5_GDRIVE_DIRECT_USE_REFUSED" in result.stdout + result.stderr
    assert "metaeditor" not in (result.stdout + result.stderr).lower()


def test_farmctl_promotion_gate_refuses_gdrive_source() -> None:
    result = farmctl._validate_raw_mq5_promotion(
        {"mq5_path": r"G:\My Drive\Incoming\Prop Challenger EA.mq5"}
    )

    assert not result["allowed"]
    assert result["code"] == "RAW_MQ5_GDRIVE_DIRECT_USE_REFUSED"


def test_record_build_blocks_gdrive_source_before_q02(
    tmp_path: Path,
    monkeypatch,
) -> None:
    root = tmp_path / "farm"
    task_id = "raw-mq5-build"
    farmctl.init_db(root)
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO tasks(
                id, kind, status, source_id, card_id, payload_json, created_at, updated_at
            )
            VALUES (?, 'build_ea', 'active', NULL, 'QM5_99004', ?, ?, ?)
            """,
            (task_id, json.dumps({"build_generation": 0}), now, now),
        )
        conn.commit()
    result_path = tmp_path / "build_result.json"
    result_path.write_text(
        json.dumps(
            {
                "task_id": task_id,
                "build_generation": 0,
                "mq5_path": r"G:\My Drive\Incoming\Prop Challenger EA.mq5",
                "compile_succeeded": True,
                "build_check_passed": True,
                "smoke_result": "passed",
                "setfiles_generated": ["G:/My Drive/Incoming/raw.set"],
            }
        ),
        encoding="utf-8",
    )
    monkeypatch.setattr(
        farmctl,
        "_validate_ea_spec_md",
        lambda *_: (_ for _ in ()).throw(AssertionError("spec gate must not run")),
    )

    recorded = farmctl.record_build_result(root, task_id, str(result_path))

    assert recorded["recorded"]
    assert recorded["new_status"] == "blocked"
    assert recorded["fail_code"] == "raw_mq5_quarantine_refused"
    with farmctl.connect(root) as conn:
        task = conn.execute(
            "SELECT payload_json FROM tasks WHERE id=?", (task_id,)
        ).fetchone()
        work_items = conn.execute("SELECT COUNT(*) FROM work_items").fetchone()[0]
    payload = json.loads(task["payload_json"])
    assert payload["raw_mq5_quarantine_code"] == "RAW_MQ5_GDRIVE_DIRECT_USE_REFUSED"
    assert work_items == 0


def test_gemini_review_dispatch_refuses_gdrive_source(tmp_path: Path) -> None:
    artifact = tmp_path / "gemini_raw_build.json"
    artifact.write_text(
        json.dumps(
            {
                "build_check_passed": True,
                "mq5_path": r"G:\My Drive\Incoming\King Trader EA.mq5",
            }
        ),
        encoding="utf-8",
    )

    result = agent_router._build_review_dispatch_gate(str(artifact))

    assert not result["allowed"]
    assert result["gate_code"] == "RAW_MQ5_GDRIVE_DIRECT_USE_REFUSED"
    assert result["reason"] == "raw_mq5_quarantine_refused_review_dispatch"
