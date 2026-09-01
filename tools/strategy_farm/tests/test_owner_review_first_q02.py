from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path

from tools.strategy_farm import farmctl


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _bound_inputs(tmp_path: Path, monkeypatch) -> tuple[dict, dict]:
    card = tmp_path / "QM5_41272_card.md"
    receipt = tmp_path / "compile_evidence.json"
    card.write_text("approved card\n", encoding="utf-8")
    receipt.write_text('{"verdict":"COMPILE_OK"}\n', encoding="utf-8")
    authority = "2e0bc944-0f47-47e2-b6c2-e7b83db89147"
    binding = {
        "authority_task_id": authority,
        "card_path": str(card),
        "card_sha256": _sha(card),
        "card_source_id": "source-bound",
        "slug": "turn-of-month-index-long-restart-r1",
        "supersedes_runtime_identity": "QM5_20004",
        "compile_evidence_path": str(receipt),
        "compile_evidence_sha256": _sha(receipt),
    }
    monkeypatch.setattr(
        farmctl,
        "OWNER_REVIEW_FIRST_BUILD_BINDINGS",
        {"QM5_41272": binding},
    )
    result = {
        "ea_id": "QM5_41272",
        "review_first_authority_task_id": authority,
        "review_first_card_sha256": binding["card_sha256"],
        "compile_evidence_path": str(receipt),
        "compile_evidence_sha256": binding["compile_evidence_sha256"],
    }
    task_payload = {
        "ea_id": "QM5_41272",
        "card_path": str(card),
        "frontmatter": {
            "ea_id": "QM5_41272",
            "slug": binding["slug"],
            "source_id": binding["card_source_id"],
            "g0_status": "APPROVED",
            "g0_approval_authority": f"OWNER task {authority}, 2026-09-01",
            "supersedes_runtime_identity": "QM5_20004",
        },
    }
    return result, task_payload


def test_exact_owner_recovery_binding_requires_review_before_q02(
    tmp_path: Path, monkeypatch,
) -> None:
    result, task_payload = _bound_inputs(tmp_path, monkeypatch)

    decision = farmctl._owner_review_first_q02_decision(result, task_payload)

    assert decision == {
        "applicable": True,
        "valid": True,
        "reason": "owner_recovery_review_required_before_q02",
        "authority_task_id": "2e0bc944-0f47-47e2-b6c2-e7b83db89147",
        "card_sha256": result["review_first_card_sha256"],
        "compile_evidence_sha256": result["compile_evidence_sha256"],
        "failures": [],
    }


def test_owner_recovery_binding_fails_closed_on_every_authority_surface(
    tmp_path: Path, monkeypatch,
) -> None:
    result, task_payload = _bound_inputs(tmp_path, monkeypatch)
    cases: list[tuple[str, dict, dict, str]] = []

    wrong_result_authority = copy.deepcopy(result)
    wrong_result_authority["review_first_authority_task_id"] = "wrong"
    cases.append(("result_authority", wrong_result_authority, task_payload, "result_authority_task_id"))

    wrong_card_sha = copy.deepcopy(result)
    wrong_card_sha["review_first_card_sha256"] = "0" * 64
    cases.append(("result_card_sha", wrong_card_sha, task_payload, "result_card_sha256"))

    wrong_receipt_sha = copy.deepcopy(result)
    wrong_receipt_sha["compile_evidence_sha256"] = "0" * 64
    cases.append(("result_receipt_sha", wrong_receipt_sha, task_payload, "result_compile_evidence_sha256"))

    wrong_source = copy.deepcopy(task_payload)
    wrong_source["frontmatter"]["source_id"] = "wrong"
    cases.append(("frontmatter_source", result, wrong_source, "frontmatter_source_id"))

    wrong_parent = copy.deepcopy(task_payload)
    wrong_parent["frontmatter"]["supersedes_runtime_identity"] = "QM5_99999"
    cases.append(("frontmatter_parent", result, wrong_parent, "frontmatter_supersedes_runtime_identity"))

    for name, candidate_result, candidate_payload, expected_failure in cases:
        decision = farmctl._owner_review_first_q02_decision(
            candidate_result, candidate_payload,
        )
        assert decision["applicable"] is True, name
        assert decision["valid"] is False, name
        assert expected_failure in decision["failures"], name


def test_unlisted_ea_does_not_change_generic_auto_q02_policy() -> None:
    decision = farmctl._owner_review_first_q02_decision(
        {"ea_id": "QM5_99999"}, {"ea_id": "QM5_99999"},
    )
    assert decision == {"applicable": False, "valid": True, "failures": []}


def test_record_build_stops_bound_recovery_before_generic_q02(
    tmp_path: Path, monkeypatch,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    with farmctl.connect(root) as conn:
        build_id = farmctl.create_task(
            conn,
            kind="build_ea",
            source_id=None,
            card_id="QM5_41272",
            payload={"ea_id": "QM5_41272"},
        )
        conn.execute("UPDATE tasks SET status='active' WHERE id=?", (build_id,))
        conn.commit()
    result_path = tmp_path / "build_result.json"
    result_path.write_text(
        json.dumps({
            "task_id": build_id,
            "ea_id": "QM5_41272",
            "compile_succeeded": True,
            "build_check_passed": True,
            "smoke_result": "passed",
        }) + "\n",
        encoding="utf-8",
    )
    decision = {
        "applicable": True,
        "valid": True,
        "reason": "owner_recovery_review_required_before_q02",
        "authority_task_id": "authority",
        "card_sha256": "a" * 64,
        "compile_evidence_sha256": "b" * 64,
        "failures": [],
    }
    monkeypatch.setattr(
        farmctl, "_owner_review_first_q02_decision", lambda _result, _payload: decision,
    )
    monkeypatch.setattr(
        farmctl, "_validate_raw_mq5_promotion", lambda _result: {"allowed": True},
    )
    monkeypatch.setattr(
        farmctl, "_validate_ea_spec_md", lambda _result, _root: {"ok": True},
    )
    monkeypatch.setattr(
        farmctl, "_validate_ea_strategy_entry", lambda _result: {"ok": True},
    )

    def refuse_generic_q02(*_args, **_kwargs):
        raise AssertionError("generic Q02 enqueue must not run")

    monkeypatch.setattr(farmctl, "_auto_enqueue_q02_for_build", refuse_generic_q02)

    recorded = farmctl.record_build_result(root, build_id, str(result_path))

    assert recorded["recorded"] is True
    assert recorded["new_status"] == "done"
    assert recorded["auto_q02_enqueued"]["enqueued"] == []
    assert recorded["auto_q02_enqueued"]["reason"] == decision["reason"]
    with farmctl.connect(root) as conn:
        stored = conn.execute(
            "SELECT status,payload_json FROM tasks WHERE id=?", (build_id,),
        ).fetchone()
        q02_count = conn.execute(
            "SELECT COUNT(*) FROM work_items WHERE phase='Q02'",
        ).fetchone()[0]
    assert stored["status"] == "done"
    assert json.loads(stored["payload_json"])["owner_review_first_q02"] == decision
    assert q02_count == 0


def test_claude_review_prompt_binds_recorded_nondefault_build_result_path(
    tmp_path: Path,
) -> None:
    root = tmp_path / "farm"
    farmctl.init_db(root)
    result_path = tmp_path / "committed_build_result.json"
    result_path.write_text("{}\n", encoding="utf-8")
    payload = {
        "ea_id": "QM5_41272",
        "card_path": str(tmp_path / "card.md"),
        "build_result_path": str(result_path),
        "codex_result": {
            "mq5_path": str(tmp_path / "ea.mq5"),
            "ex5_path": str(tmp_path / "ea.ex5"),
            "smoke_report_path": None,
        },
    }
    with farmctl.connect(root) as conn:
        build_id = farmctl.create_task(
            conn,
            kind="build_ea",
            source_id=None,
            card_id="QM5_41272",
            payload=payload,
        )
        conn.execute(
            "UPDATE tasks SET status='done', payload_json=? WHERE id=?",
            (json.dumps(payload), build_id),
        )
        conn.commit()

    rendered = farmctl.render_claude_review_prompt(root, build_id, None)

    assert rendered["written"] is True
    prompt = Path(rendered["prompt_path"]).read_text(encoding="utf-8")
    assert str(result_path) in prompt
    with farmctl.connect(root) as conn:
        review = conn.execute(
            "SELECT payload_json FROM tasks WHERE id=?",
            (rendered["review_task_id"],),
        ).fetchone()
    assert json.loads(review["payload_json"])["build_result_path"] == str(result_path)
