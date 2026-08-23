from __future__ import annotations

import functools
import hashlib
import json
from types import SimpleNamespace
from pathlib import Path

import pytest

from tools.strategy_farm import deploy_tlive_book
from tools.strategy_farm import generate_live_deployment_pointer as pointer
from tools.strategy_farm import mission_control_v2_data as mc
from tools.strategy_farm import risk_freeze
from tools.strategy_farm import reseal_chart09_ks_delta as reseal_chart
from tools.strategy_farm.portfolio import build_11422_preset_FINAL24b as build_11422
from tools.strategy_farm.portfolio import build_book_dxz
from tools.strategy_farm.portfolio import portfolio_manifest
from tools.strategy_farm.portfolio import stage_tlive_presets_risk as stage_risk


def _preset_tree(root: Path, *, risk: str = "0.5") -> Path:
    root.mkdir(parents=True)
    (root / "01_EURUSD_H1_QM5_100_fixture.set").write_text(
        "\n".join([
            f"RISK_PERCENT={risk}",
            "RISK_FIXED=0",
            "PORTFOLIO_WEIGHT=1",
            "qm_magic_slot_offset=0",
            "",
        ]),
        encoding="utf-8",
    )
    return root


def _freeze_state(path: Path, presets: Path, *, status: str = "ACTIVE") -> Path:
    payload = {
        "schema": risk_freeze.SCHEMA,
        "status": status,
        "armed_at_utc": "2026-08-22T18:00:00+00:00",
        "baseline": risk_freeze.measure(presets),
        "lift_conditions": risk_freeze.LIFT_CONDITIONS,
        "lift_rule": "All three conditions and explicit written OWNER lift.",
    }
    if status in risk_freeze.INACTIVE_STATUSES:
        payload.update({
            "lift_authority": "OWNER-DEC-FIXTURE",
            "lifted_at_utc": "2026-08-23T18:00:00+00:00",
        })
    path.write_text(json.dumps(payload), encoding="utf-8")
    return path


def _guard_for(state: Path, presets: Path):
    return functools.partial(
        risk_freeze.assert_live_book_mutation_allowed,
        state_path=state,
        presets_dir=presets,
    )


def test_canonical_guard_blocks_active_and_names_all_lift_conditions(tmp_path: Path):
    presets = _preset_tree(tmp_path / "presets")
    state = _freeze_state(tmp_path / "freeze.json", presets)
    with pytest.raises(risk_freeze.RiskFreezeBlocked) as caught:
        risk_freeze.assert_live_book_mutation_allowed(
            "fixture mutation", state_path=state, presets_dir=presets
        )
    message = str(caught.value)
    assert "LIVE_RISK_FREEZE_BLOCKED" in message
    for condition in risk_freeze.LIFT_CONDITIONS:
        assert condition["id"] in message


@pytest.mark.parametrize("case", ["missing", "unreadable", "invalid", "invalid_baseline"])
def test_canonical_guard_fails_closed_for_bad_state(tmp_path: Path, case: str):
    presets = _preset_tree(tmp_path / "presets")
    state = tmp_path / "freeze.json"
    if case == "unreadable":
        state.write_text("{", encoding="utf-8")
    elif case == "invalid":
        state.write_text(json.dumps({"schema": "wrong", "status": "INACTIVE"}), encoding="utf-8")
    elif case == "invalid_baseline":
        state.write_text(json.dumps({
            "schema": risk_freeze.SCHEMA,
            "status": "ACTIVE",
            "baseline": {
                "sleeves": [{}], "sleeve_count": 1,
                "total_risk_percent": 0.5, "roster_sha256": "fixture",
            },
        }), encoding="utf-8")
    with pytest.raises(risk_freeze.RiskFreezeBlocked):
        risk_freeze.assert_live_book_mutation_allowed(
            "fixture mutation", state_path=state, presets_dir=presets
        )


def test_canonical_guard_allows_explicit_owner_lift(tmp_path: Path):
    presets = _preset_tree(tmp_path / "presets")
    state = _freeze_state(tmp_path / "freeze.json", presets, status="LIFTED")
    result = risk_freeze.assert_live_book_mutation_allowed(
        "fixture mutation", state_path=state, presets_dir=presets
    )
    assert result["allowed"] is True
    assert result["lift_authority"] == "OWNER-DEC-FIXTURE"


def test_measure_unreadable_presets_is_a_complete_fail_closed_result(tmp_path: Path):
    result = risk_freeze.measure(tmp_path / "absent")
    assert result == {
        "ok": False,
        "problems": [f"presets_dir_unreadable:{tmp_path / 'absent'}"],
        "sleeve_count": 0,
        "total_risk_percent": None,
        "roster_sha256": None,
        "sleeves": [],
    }


def test_stage_risk_apply_guard_negative_and_positive(tmp_path: Path, monkeypatch):
    def blocked(_operation):
        raise risk_freeze.RiskFreezeBlocked("blocked", {})

    monkeypatch.setattr(stage_risk.risk_freeze, "assert_live_book_mutation_allowed", blocked)
    with pytest.raises(risk_freeze.RiskFreezeBlocked):
        stage_risk.main(["--apply", "--out-dir", str(tmp_path / "never")])
    assert not (tmp_path / "never").exists()

    monkeypatch.setattr(stage_risk.risk_freeze, "assert_live_book_mutation_allowed", lambda _op: {})
    presets = _preset_tree(tmp_path / "source")
    manifest = tmp_path / "manifest.json"
    manifest.write_text(json.dumps({
        "sleeves": [{"ea_id": 100, "symbol": "EURUSD.DWX", "risk_percent": 0.4}]
    }), encoding="utf-8")
    out = tmp_path / "staged"
    assert stage_risk.main([
        "--apply", "--presets", str(presets), "--manifest", str(manifest),
        "--out-dir", str(out),
    ]) == 0
    assert "RISK_PERCENT=0.4" in next(out.glob("*.set")).read_text(encoding="utf-8")


def test_new_sleeve_staging_guard_negative_and_positive(tmp_path: Path, monkeypatch):
    def blocked(_operation):
        raise risk_freeze.RiskFreezeBlocked("blocked", {})

    monkeypatch.setattr(build_11422.risk_freeze, "assert_live_book_mutation_allowed", blocked)
    with pytest.raises(risk_freeze.RiskFreezeBlocked):
        build_11422.build([
            "--apply", "--out-dir", str(tmp_path / "never"),
            "--incumbent-report", str(tmp_path / "missing.json"),
            "--json", str(tmp_path / "missing-out.json"),
        ])

    monkeypatch.setattr(build_11422.risk_freeze, "assert_live_book_mutation_allowed", lambda _op: {})
    base = tmp_path / "base.set"
    base.write_text(
        "; environment:  backtest\n; risk_mode:    FIXED\n; timeframe: D1\n"
        "RISK_FIXED=1000\nRISK_PERCENT=0\nPORTFOLIO_WEIGHT=1\n"
        "qm_magic_slot_offset=4\n",
        encoding="utf-8",
    )
    manifest = tmp_path / "manifest.json"
    manifest.write_text(json.dumps({
        "sleeves": [{"ea_id": 11422, "symbol": "USDCAD.DWX", "risk_percent": 0.45}]
    }), encoding="utf-8")
    incumbent = tmp_path / "incumbent.json"
    incumbent.write_text(json.dumps({"mode": "APPLY", "staged": [], "problems": []}), encoding="utf-8")
    monkeypatch.setattr(build_11422, "BASE_SET", base)
    monkeypatch.setattr(build_11422, "MANIFEST", manifest)
    monkeypatch.setattr(build_11422, "DROPPED_PRESET", tmp_path / "not-deployed.set")
    out = tmp_path / "stage-11422"
    report = tmp_path / "unified.json"
    assert build_11422.build([
        "--apply", "--out-dir", str(out), "--incumbent-report", str(incumbent),
        "--json", str(report),
    ]) == 0
    assert (out / build_11422.NEW_NAME).is_file()


def _pointer_args(tmp_path: Path) -> list[str]:
    manifest = tmp_path / "book.json"
    manifest.write_text(json.dumps({"book": "DXZ", "status": "APPROVED", "sleeves": []}), encoding="utf-8")
    approval = tmp_path / "owner.md"
    approval.write_text("OWNER approved fixture", encoding="utf-8")
    return [
        "--manifest", str(manifest), "--expected-account", "123456",
        "--expected-server", "Fixture", "--expected-phase", "Q12",
        "--deployment-epoch-utc", "2026-08-23T10:00:00+00:00",
        "--written-at-utc", "2026-08-23T10:01:00+00:00", "--signed",
        "--approved-by", "OWNER", "--approval-evidence", str(approval),
        "--out", str(tmp_path / "pointer.json"),
    ]


def test_signed_pointer_guard_negative_and_positive(tmp_path: Path, monkeypatch):
    args = _pointer_args(tmp_path)

    def blocked(_operation):
        raise risk_freeze.RiskFreezeBlocked("blocked", {})

    monkeypatch.setattr(pointer.risk_freeze, "assert_live_book_mutation_allowed", blocked)
    with pytest.raises(risk_freeze.RiskFreezeBlocked):
        pointer.main(args)
    assert not (tmp_path / "pointer.json").exists()

    monkeypatch.setattr(pointer.risk_freeze, "assert_live_book_mutation_allowed", lambda _op: {})
    assert pointer.main(args) == 0
    assert json.loads((tmp_path / "pointer.json").read_text(encoding="utf-8"))["signed"] is True


def test_tlive_chart_reseal_guard_negative_and_positive(tmp_path: Path, monkeypatch):
    def blocked(_operation):
        raise risk_freeze.RiskFreezeBlocked("blocked", {})

    monkeypatch.setattr(reseal_chart.risk_freeze, "assert_live_book_mutation_allowed", blocked)
    with pytest.raises(risk_freeze.RiskFreezeBlocked):
        reseal_chart.main()

    monkeypatch.setattr(reseal_chart.risk_freeze, "assert_live_book_mutation_allowed", lambda _op: {})
    sealed = tmp_path / "chart09.chr"
    sealed.write_bytes("PORTFOLIO_WEIGHT=1.0\r\n".encode("utf-16-le"))
    verifier = tmp_path / "prepare.ps1"
    verifier.write_text("'chart09.chr' = '" + "A" * 64 + "'\n", encoding="utf-8")
    monkeypatch.setattr(reseal_chart, "SEALED", sealed)
    monkeypatch.setattr(reseal_chart, "BK_DIR", tmp_path / "backup")
    monkeypatch.setattr(reseal_chart, "BK", tmp_path / "backup" / "before.chr")
    monkeypatch.setattr(reseal_chart, "VERIFIER", verifier)
    monkeypatch.setattr(
        reseal_chart.subprocess,
        "run",
        lambda *_a, **_kw: SimpleNamespace(stdout="VERIFIED", stderr="", returncode=0),
    )
    assert reseal_chart.main() == 0
    assert "qm_risk_cap_pct=1.0" in sealed.read_bytes().decode("utf-16-le")
    assert (tmp_path / "backup" / "before.chr").is_file()


def test_portfolio_manifest_guard_negative_and_positive(tmp_path: Path, monkeypatch):
    monkeypatch.setattr(portfolio_manifest, "_selected_book", lambda **_kw: ([], {}, "fixture"))
    monkeypatch.setattr(portfolio_manifest, "build_manifest", lambda *_a, **_kw: {
        "n_sleeves": 0, "kpis": {}, "sleeves": [], "status": "DRAFT"
    })
    monkeypatch.setattr(portfolio_manifest, "finalize_cap_decision", lambda manifest, **_kw: manifest)
    writes: list[Path] = []
    monkeypatch.setattr(portfolio_manifest, "write_manifest", lambda _m, path: writes.append(path))

    def blocked(_operation):
        raise risk_freeze.RiskFreezeBlocked("blocked", {})

    monkeypatch.setattr(portfolio_manifest.risk_freeze, "assert_live_book_mutation_allowed", blocked)
    with pytest.raises(risk_freeze.RiskFreezeBlocked):
        portfolio_manifest.main(["--out", str(tmp_path / "never.json")])
    assert writes == []

    monkeypatch.setattr(
        portfolio_manifest.risk_freeze, "assert_live_book_mutation_allowed", lambda _op: {}
    )
    assert portfolio_manifest.main(["--out", str(tmp_path / "allowed.json")]) == 0
    assert writes == [tmp_path / "allowed.json"]


def test_current_dxz_book_builder_guard_negative_and_positive(tmp_path: Path, monkeypatch):
    manifest = {"status": "DRY_RUN", "sleeves": []}
    monkeypatch.setattr(build_book_dxz, "build_dxz_manifest", lambda **_kw: manifest)
    monkeypatch.setattr(build_book_dxz, "validate_dual_book_manifest", lambda _m: None)
    monkeypatch.setattr(build_book_dxz, "evidence_markdown", lambda *_a: "fixture")
    writes: list[Path] = []
    monkeypatch.setattr(build_book_dxz, "write_json", lambda path, _m: writes.append(path))
    monkeypatch.setattr(build_book_dxz, "write_text", lambda path, _text: writes.append(path))

    def blocked(_operation):
        raise risk_freeze.RiskFreezeBlocked("blocked", {})

    monkeypatch.setattr(build_book_dxz.risk_freeze, "assert_live_book_mutation_allowed", blocked)
    with pytest.raises(risk_freeze.RiskFreezeBlocked):
        build_book_dxz.main(["--out-dir", str(tmp_path / "never")])
    assert writes == []

    monkeypatch.setattr(build_book_dxz.risk_freeze, "assert_live_book_mutation_allowed", lambda _op: {})
    assert build_book_dxz.main(["--out-dir", str(tmp_path / "allowed")]) == 0
    assert writes == [tmp_path / "allowed" / "manifest.json", tmp_path / "allowed" / "evidence.md"]


def test_every_deploy_capable_dxz_manifest_generator_calls_canonical_guard():
    root = Path(__file__).resolve().parents[1] / "portfolio"
    names = [
        "portfolio_manifest.py", "build_book_dxz.py", "gen_dxz_23sleeve_manifest.py",
        "gen_dxz24_weekend_manifest.py", "gen_dxz_final_manifest.py",
        "gen_dxz23_20260726.py", "gen_dxz24b_20260726.py",
    ]
    for name in names:
        source = (root / name).read_text(encoding="utf-8-sig")
        assert "risk_freeze.assert_live_book_mutation_allowed(" in source, name


def test_liveops_profile_creation_guard_preserves_verify_only_path():
    script = (
        Path(__file__).resolve().parents[1] / "prepare_dxz_v2_liveops_profile.ps1"
    ).read_text(encoding="utf-8-sig")
    assert "if (-not $VerifyOnly)" in script
    assert "risk_freeze.py" in script
    assert "guard --operation" in script
    assert script.index("if (-not $VerifyOnly)") < script.index("New-Item -ItemType Directory")


def _copy_plan(tmp_path: Path, source: Path) -> Path:
    approval = tmp_path / "owner.md"
    approval.write_text("OWNER fixture", encoding="utf-8")
    plan = tmp_path / "copy-plan.json"
    plan.write_text(json.dumps({
        "schema": deploy_tlive_book.SCHEMA,
        "owner_approval_evidence": str(approval),
        "items": [{
            "source": str(source),
            "destination_relative": "MQL5/Presets/01_fixture.set",
            "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        }],
    }), encoding="utf-8")
    return plan


def test_tlive_copy_guard_negative_and_positive(tmp_path: Path):
    presets = _preset_tree(tmp_path / "freeze-presets")
    state = _freeze_state(tmp_path / "active.json", presets)
    source = tmp_path / "source.set"
    source.write_bytes(b"new live bytes")
    plan = _copy_plan(tmp_path, source)
    live_root = tmp_path / "T_Live" / "MT5_Base"
    destination = live_root / "MQL5" / "Presets" / "01_fixture.set"

    with pytest.raises(risk_freeze.RiskFreezeBlocked):
        deploy_tlive_book.execute(
            plan, live_root=live_root, backup_dir=tmp_path / "never-backup",
            apply=True, guard=_guard_for(state, presets),
        )
    assert not destination.exists()
    assert not (tmp_path / "never-backup").exists()

    lifted = _freeze_state(tmp_path / "lifted.json", presets, status="LIFTED")
    destination.parent.mkdir(parents=True)
    destination.write_bytes(b"old live bytes")
    backup = tmp_path / "backup"
    result = deploy_tlive_book.execute(
        plan, live_root=live_root, backup_dir=backup,
        apply=True, guard=_guard_for(lifted, presets),
    )
    assert result["written_items"] == 1
    assert destination.read_bytes() == b"new live bytes"
    assert (backup / "MQL5" / "Presets" / "01_fixture.set").read_bytes() == b"old live bytes"


def test_tlive_copy_dry_run_remains_read_only_during_active_freeze(tmp_path: Path):
    source = tmp_path / "source.set"
    source.write_bytes(b"staged")
    plan = _copy_plan(tmp_path, source)
    live_root = tmp_path / "T_Live" / "MT5_Base"
    result = deploy_tlive_book.execute(plan, live_root=live_root, apply=False)
    assert result["mode"] == "DRY_RUN"
    assert result["written_items"] == 0
    assert not live_root.exists()


def test_mission_control_exposes_active_freeze_and_three_conditions(tmp_path: Path, monkeypatch):
    presets = _preset_tree(tmp_path / "presets")
    state = _freeze_state(tmp_path / "freeze.json", presets)
    monkeypatch.setattr(mc, "RISK_FREEZE_STATE", state)
    monkeypatch.setattr(mc, "RISK_FREEZE_PRESETS", presets)
    section = mc.build_risk_freeze()
    assert section["status"] == "ACTIVE"
    assert section["held"] is True
    assert section["baseline_sleeve_count"] == section["current_sleeve_count"] == 1
    assert len(section["lift_conditions"]) == 3


def test_freeze_guard_is_not_imported_by_factory_or_q02_q10_modules():
    root = Path(__file__).resolve().parents[1]
    unaffected = [
        "farmctl.py", "terminal_worker.py", "compile_ea.py",
        "build_gate_hardening.py", "agent_router.py", "q09_news_runner.py",
    ]
    for name in unaffected:
        assert "risk_freeze" not in (root / name).read_text(encoding="utf-8-sig"), name
