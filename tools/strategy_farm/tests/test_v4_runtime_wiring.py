from __future__ import annotations

import ast
import hashlib
import json
import subprocess
from pathlib import Path

import pytest

from framework.scripts import q10_confirmation, q16_head_to_head
from tools.strategy_farm import farmctl, q09_news_schema, q10_confirmation_contract
from tools.strategy_farm.gate_manifest import (
    V3_MANIFEST,
    V4_DRAFT_MANIFEST,
    load_gate_manifest,
)
from tools.strategy_farm.phase_ids import build_advancement_table
from tools.strategy_farm import v4_readiness_check
from tools.strategy_farm.tests.test_q16_head_to_head import _fixture as q16_fixture


REPO_ROOT = Path(__file__).resolve().parents[3]


@pytest.fixture(params=("v3", "v4"))
def manifest_case(request: pytest.FixtureRequest):
    path = V3_MANIFEST if request.param == "v3" else V4_DRAFT_MANIFEST
    return request.param, load_gate_manifest(path)


def _contract_version(manifest) -> str:
    return manifest.schema_version.rsplit("/", 1)[-1]


def _patch_runtime(monkeypatch: pytest.MonkeyPatch, manifest) -> None:
    monkeypatch.setattr(farmctl, "ACTIVE_GATE_MANIFEST", manifest)
    monkeypatch.setattr(farmctl, "ACTIVE_GATE_CONTRACT_VERSION", _contract_version(manifest))
    monkeypatch.setattr(farmctl, "_NEWS_GATE", manifest.gate_for_role("NEWS"))
    monkeypatch.setattr(
        farmctl, "_NEWS_PHASE", manifest.storage_phase_for_role("NEWS", "NEWS")
    )
    monkeypatch.setattr(
        farmctl,
        "_NEWS_PORTFOLIO_PHASE",
        manifest.storage_phase_for_role("NEWS", "PORTFOLIO"),
    )
    monkeypatch.setattr(farmctl, "_INCUMBENT_PHASE", manifest.gate_for_role("INCUMBENT"))
    monkeypatch.setattr(
        farmctl, "_BASELINE_FULL_RUN_PHASE", manifest.gate_for_role("BASELINE_FULL_RUN")
    )
    monkeypatch.setattr(farmctl, "_PATTERN_PHASE", manifest.gate_for_role("PATTERN"))
    monkeypatch.setattr(farmctl, "_PARAM_OPT_PHASE", manifest.gate_for_role("PARAM_OPT"))
    monkeypatch.setattr(
        farmctl, "_HEAD_TO_HEAD_PHASE", manifest.gate_for_role("HEAD_TO_HEAD")
    )
    monkeypatch.setattr(q09_news_schema, "ACTIVE_GATE_MANIFEST", manifest)
    # farmctl supports direct-script imports as well as package imports; under
    # the full suite these can be two module objects sharing the same file.
    monkeypatch.setitem(
        farmctl.hold_q09_until_plan_bound.__globals__,
        "ACTIVE_GATE_MANIFEST",
        manifest,
    )


def test_role_lookup_and_runtime_chain_are_versioned(manifest_case) -> None:
    version, manifest = manifest_case
    expected_roles = {
        "v3": {
            "BASELINE_FULL_RUN": "Q10A", "NEWS": "Q09", "INCUMBENT": "Q10",
            "PATTERN": "Q14", "PARAM_OPT": "Q15", "HEAD_TO_HEAD": "Q16",
            "PORTFOLIO": "Q11", "OPS": "Q12", "LIVE": "Q13",
        },
        "v4": {
            "BASELINE_FULL_RUN": "Q09", "NEWS": "Q10", "INCUMBENT": "Q11",
            "PATTERN": "Q12", "PARAM_OPT": "Q13", "HEAD_TO_HEAD": "Q14",
            "PORTFOLIO": "Q15", "OPS": "Q16", "LIVE": "Q17",
        },
    }[version]
    assert {role: manifest.gate_for_role(role) for role in expected_roles} == expected_roles

    table = build_advancement_table(manifest)
    path = ["Q08"]
    while table[path[-1]].next is not None:
        path.append(str(table[path[-1]].next))
    assert tuple(path) == {
        "v3": ("Q08", "Q09_NEWS", "Q10", "Q14", "Q15", "Q16"),
        "v4": ("Q08", "Q09", "Q10_NEWS", "Q11", "Q12", "Q13", "Q14"),
    }[version]
    assert table[path[-1]].next is None
    assert manifest.storage_phase_for_role("NEWS", "NEWS") == {
        "v3": "Q09_NEWS", "v4": "Q10_NEWS"
    }[version]
    assert manifest.storage_phase_for_role("NEWS", "PORTFOLIO") == {
        "v3": "Q09_PORTFOLIO", "v4": "Q10_PORTFOLIO"
    }[version]
    assert manifest.head_to_head_dependency_roles == {
        "v3": ("PARENT_LINEAGE", "CHALLENGER_Q10"),
        "v4": ("BASELINE_Q09", "INCUMBENT_Q11", "CHALLENGER_Q11"),
    }[version]
    assert manifest.dependency_role("Q14_ADMISSION") == {
        "v3": "Q14_ADMISSION", "v4": "Q12_ADMISSION"
    }[version]


def test_news_promotions_autoseal_selection_and_incumbent_enqueue_run_twice(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, manifest_case
) -> None:
    version, manifest = manifest_case
    _patch_runtime(monkeypatch, manifest)
    root = tmp_path / version
    farmctl.init_db(root)
    evidence = root / "q08.json"
    setfile = root / "baseline.set"
    evidence.write_text('{"q08_trade_count":300,"verdict":"PASS"}\n', encoding="utf-8")
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
              attempt_count,evidence_path,payload_json,created_at,updated_at
            ) VALUES('q08','backtest','Q08','QM5_42','EURUSD.DWX',?,
                     'done','PASS',0,?,'{}',?,?)
            """,
            (str(setfile), str(evidence), now, now),
        )
        news_result: dict[str, object] = {}
        assert farmctl._promote_paired_q09_portfolio_passes_to_news(
            conn, news_result
        ) == 1
        portfolio_result = {
            "q09_portfolio_promotions": [],
            "q09_portfolio_promotions_skipped": [],
        }
        assert farmctl._promote_q08_soft_fails_to_q09_portfolio(
            conn, portfolio_result
        ) == 1
        conn.commit()
        phases = {
            row[0] for row in conn.execute(
                "SELECT phase FROM work_items WHERE id<>'q08'"
            ).fetchall()
        }
        news_id = conn.execute(
            "SELECT id FROM work_items WHERE phase=?",
            (manifest.storage_phase_for_role("NEWS", "NEWS"),),
        ).fetchone()[0]
    assert phases == {
        manifest.storage_phase_for_role("NEWS", "NEWS"),
        manifest.storage_phase_for_role("NEWS", "PORTFOLIO"),
    }

    # The autosealer must select the manifest's lane.  This deliberately lacks
    # runnable EA artifacts, so selection is evidenced by a structured failure.
    autoseal = farmctl.auto_seal_pending_q09_news(root)
    assert autoseal["failed_count"] == 1
    assert autoseal["rows"][0]["work_item_id"] == news_id

    with farmctl.connect(root) as conn:
        conn.execute(
            "UPDATE work_items SET status='done',verdict='CONFIG_LOCKED' WHERE id=?",
            (news_id,),
        )
        conn.commit()
    calls: list[tuple[Path, str, str, str | None]] = []

    def fake_enqueue(root_arg, ea_id, phase, predecessor_work_item_id=None):
        calls.append((root_arg, ea_id, phase, predecessor_work_item_id))
        return {"enqueued": True}

    monkeypatch.setattr(farmctl, "enqueue_cascade_backtest_for_ea", fake_enqueue)
    result = farmctl.auto_enqueue_q10_after_q09_result(
        root, q09_news_work_item_id=news_id
    )
    assert result["enqueued"] is True
    assert calls == [(root, "QM5_42", manifest.gate_for_role("INCUMBENT"), news_id)]


def test_q10_materialization_uses_active_gate_and_dependency_tokens(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, manifest_case
) -> None:
    version, manifest = manifest_case
    monkeypatch.setattr(q10_confirmation_contract, "ACTIVE_GATE_MANIFEST", manifest)
    source = tmp_path / version / "source.set"
    ex5 = tmp_path / version / "ea.ex5"
    closure = tmp_path / version / "closure.json"
    source.parent.mkdir(parents=True)
    source.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    ex5.write_bytes(b"compiled")
    closure.write_text("{}\n", encoding="utf-8")
    digest = lambda path: hashlib.sha256(path.read_bytes()).hexdigest()
    binding = q10_confirmation_contract.VerifiedBinding(
        q10_work_item_id="incumbent", q09_news_work_item_id="news",
        q09_portfolio_work_item_id=None, q09_news_evidence_path="news.json",
        q09_news_evidence_sha256="a" * 64, q09_portfolio_evidence_path=None,
        q09_portfolio_evidence_sha256=None, calendar_bundle_id="calendar",
        calendar_manifest_path="manifest.json", calendar_manifest_sha256="b" * 64,
        calendar_content_sha256="c" * 64, chosen_temporal="WINDOW_30M",
        chosen_temporal_id=1, chosen_compliance="DXZ", chosen_compliance_id=1,
        baseline_setfile_sha256=digest(source), ex5_sha256=digest(ex5),
        include_closure_sha256=digest(closure),
    )
    result = q10_confirmation_contract.materialize_q10_inputs(
        binding, source_setfile=source, ex5_path=ex5,
        include_closure_path=closure, report_root=tmp_path / version / "report",
        calendar_relative_common_path="QM/news/events.csv",
    )
    output = result["manifest"]
    assert output["phase"] == manifest.gate_for_role("INCUMBENT")
    assert set(output["dependencies"]) == {
        manifest.dependency_role("Q09_NEWS"),
        manifest.dependency_role("Q09_PORTFOLIO"),
    }


def test_full_history_runner_propagates_each_manifest_incumbent_gate(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, manifest_case
) -> None:
    _, manifest = manifest_case
    captured: list[str] = []

    def fake_run(args, **_kwargs):
        captured.extend(args)
        return subprocess.CompletedProcess(args=args, returncode=1, stdout="", stderr="")

    monkeypatch.setattr(q10_confirmation, "run_with_launch_fault_retry", fake_run)
    result = q10_confirmation.run_confirmation(
        ea_id=42, ea_expert="QM/QM5_42_fixture/QM5_42_fixture",
        symbol="EURUSD.DWX", setfile=tmp_path / "baseline.set", terminal="T2",
        report_root=tmp_path, timeout_sec=1,
        gate_phase=manifest.gate_for_role("INCUMBENT"),
    )
    assert result["phase"] == manifest.gate_for_role("INCUMBENT")
    assert captured[captured.index("-DispatchPhase") + 1] == result["phase"]


def test_head_to_head_runner_accepts_each_manifest_incumbent_id(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, manifest_case
) -> None:
    version, manifest = manifest_case
    monkeypatch.setattr(q16_head_to_head, "ACTIVE_GATE_MANIFEST", manifest)
    base = tmp_path / version
    base.mkdir(parents=True)
    binary = base / "ea.ex5"
    setfile = base / "ea.set"
    stream = base / "stream.jsonl"
    incumbent = base / "incumbent.json"
    binary.write_bytes(b"compiled")
    setfile.write_text("RISK_FIXED=1000\nRISK_PERCENT=0\n", encoding="utf-8")
    stream.write_text("", encoding="utf-8")
    incumbent.write_text(json.dumps({
        "phase": manifest.gate_for_role("INCUMBENT"), "verdict": "PASS"
    }), encoding="utf-8")

    def bound(path: Path) -> dict[str, object]:
        return {"path": str(path), "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}

    lineage_path = base / "lineage.json"
    lineage_path.write_text(json.dumps({
        "schema": q16_head_to_head.LINEAGE_SCHEMA, "role": "PARENT",
        "ea_id": "QM5_42", "symbol": "EURUSD.DWX", "binary": bound(binary),
        "setfile": bound(setfile),
        "stream": {**bound(stream), "frozen": True, "risk_fixed": 1000,
                   "risk_percent": 0, "trade_count": 0},
        "q10": {"verdict": "PASS", "evidence": bound(incumbent)},
    }, sort_keys=True), encoding="utf-8")
    loaded = q16_head_to_head.load_lineage(lineage_path, "PARENT")
    assert loaded["q10"]["verdict"] == "PASS"


def test_v4_head_to_head_enqueue_binds_baseline_and_both_q11_rows(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    manifest = load_gate_manifest(V4_DRAFT_MANIFEST)
    _patch_runtime(monkeypatch, manifest)
    monkeypatch.setattr(q16_head_to_head, "ACTIVE_GATE_MANIFEST", manifest)
    paths = q16_fixture(tmp_path / "inputs")
    inputs = paths["parent_lineage_path"].parent
    for name in ("parent", "challenger"):
        evidence = inputs / f"{name}_q10.json"
        evidence.write_text(
            json.dumps({"phase": "Q11", "verdict": "PASS"}), encoding="utf-8"
        )
        lineage_path = paths[f"{name}_lineage_path"]
        lineage = json.loads(lineage_path.read_text(encoding="utf-8"))
        lineage["q10"]["evidence"]["sha256"] = hashlib.sha256(
            evidence.read_bytes()
        ).hexdigest()
        lineage_path.write_text(json.dumps(lineage, sort_keys=True), encoding="utf-8")

    root = tmp_path / "farm"
    farmctl.init_db(root)
    baseline = inputs / "baseline_q09.json"
    baseline.write_text('{"phase":"Q09","verdict":"PASS"}\n', encoding="utf-8")
    now = farmctl.utc_now()
    with farmctl.connect(root) as conn:
        rows = (
            ("baseline", "Q09", "QM5_10939", baseline),
            ("parent-q11", "Q11", "QM5_10939", inputs / "parent_q10.json"),
            ("challenger-q11", "Q11", "QM5_12990", inputs / "challenger_q10.json"),
        )
        for item_id, phase, ea_id, evidence in rows:
            conn.execute(
                """
                INSERT INTO work_items(
                  id,kind,phase,ea_id,symbol,setfile_path,status,verdict,
                  attempt_count,evidence_path,payload_json,created_at,updated_at
                ) VALUES(?,'backtest',?,?,'GBPUSD.DWX',?,'done','PASS',0,?,'{}',?,?)
                """,
                (
                    item_id, phase, ea_id, str(inputs / "challenger.set"),
                    str(evidence), now, now,
                ),
            )
        conn.commit()

    result = farmctl.enqueue_head_to_head(
        root,
        opt_card_path=str(paths["opt_card_path"]),
        parent_lineage_path=str(paths["parent_lineage_path"]),
        challenger_lineage_path=str(paths["challenger_lineage_path"]),
        trial_ledger_path=str(paths["trial_ledger_path"]),
        book_manifest_path=str(paths["book_manifest_path"]),
        book_stream_manifest_path=str(paths["book_stream_manifest_path"]),
        parent_q10_work_item_id="parent-q11",
        challenger_q10_work_item_id="challenger-q11",
        baseline_work_item_id="baseline",
        apply=True,
    )
    assert result["enqueued"] is True
    with farmctl.connect(root) as conn:
        child = conn.execute(
            "SELECT phase FROM work_items WHERE id=?",
            (result["would_create_work_item_id"],),
        ).fetchone()
        dependencies = conn.execute(
            """
            SELECT dependency_role,parent_work_item_id
            FROM work_item_dependencies WHERE child_work_item_id=?
            ORDER BY dependency_role
            """,
            (result["would_create_work_item_id"],),
        ).fetchall()
    assert child[0] == "Q14"
    assert [tuple(row) for row in dependencies] == [
        ("BASELINE_Q09", "baseline"),
        ("CHALLENGER_Q11", "challenger-q11"),
        ("INCUMBENT_Q11", "parent-q11"),
    ]


def test_no_runtime_auto_portfolio_enqueue_and_readiness_is_green(capsys) -> None:
    source = (REPO_ROOT / "tools/strategy_farm/farmctl.py").read_text(encoding="utf-8")
    tree = ast.parse(source)
    assert 'gate_for_role("PORTFOLIO")' not in source
    assert "portfolio_route(" not in source
    assert not any(
        isinstance(node, ast.Call)
        and isinstance(node.func, ast.Name)
        and "enqueue" in node.func.id
        and any(
            isinstance(arg, ast.Name) and arg.id == "_PORTFOLIO_PHASE"
            for arg in node.args
        )
        for node in ast.walk(tree)
    )
    assert v4_readiness_check.main() == 0
    output = capsys.readouterr().out
    assert "remaining_hardcoded_v3_gate_literals=0" in output
    assert "runtime_violations=0" in output
