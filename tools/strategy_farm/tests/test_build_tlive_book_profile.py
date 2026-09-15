"""build_tlive_book_profile.py: chart grammar, re-weight/replace/new sleeve construction, invariants, verify."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import build_tlive_book_profile as bp  # noqa: E402

EOL = "\r\n"


def _chart(chart_id: int, symbol: str, ptype: int, psize: int, name: str, inputs: list[tuple[str, str]], digits: int = 5) -> str:
    lines = ["<chart>", f"id={chart_id}", f"symbol={symbol}", f"description={symbol} desc", f"period_type={ptype}",
             f"period_size={psize}", f"digits={digits}", "tick_size=0.000000", "<expert>", f"name={name}",
             f"path=Experts\\Live EAs\\{name}.ex5", "expertmode=1", "<inputs>"]
    lines += [f"{k}={v}" for k, v in inputs]
    lines += ["</inputs>", "</expert>", "<window>", "height=100.000000", "<indicator>", "name=Main", "path=", "</indicator>",
              "</window>", "</chart>"]
    return EOL.join(lines) + EOL


FRAMEWORK = [("qm_chartui_enabled", "true"), ("InpQMSimCommissionPerLot", "0.0"), ("QuantMechanica V5 Framework", "")]


def _sleeve_inputs(ea: int, slot: int, risk: str, extra: list[tuple[str, str]]) -> list[tuple[str, str]]:
    return FRAMEWORK + [("qm_ea_id", str(ea)), ("qm_magic_slot_offset", str(slot)), ("Risk", ""), ("RISK_PERCENT", risk),
                        ("RISK_FIXED", "0"), ("PORTFOLIO_WEIGHT", "1.0"), ("qm_news_temporal", "3"), ("Strategy", "")] + extra


@pytest.fixture()
def world(tmp_path: Path) -> dict:
    tpl = tmp_path / "template"
    tpl.mkdir()
    bp.write_chart(tpl / "chart01.chr", _chart(100, "EURUSD", 1, 24, "QM5_11421_ohlc", _sleeve_inputs(11421, 0, "0.3364", [("strategy_len", "20")])))
    bp.write_chart(tpl / "chart02.chr", _chart(101, "XAUUSD", 1, 24, "QM5_10403_turtle", _sleeve_inputs(10403, 2, "0.2204", [("strategy_n", "20")]), digits=2))
    bp.write_chart(tpl / "chart03.chr", _chart(102, "USDJPY", 0, 30, "QM5_12969_fix", _sleeve_inputs(12969, 0, "0.5100", [("strategy_x", "1")]), digits=3))
    bp.write_chart(tpl / "chart04.chr", _chart(103, "EURUSD", 1, 1, bp.MONITOR_NAME, [("mon", "1")]))
    staging = tmp_path / "staging"
    (staging / "presets" / "existing").mkdir(parents=True)
    (staging / "presets" / "new_burnin").mkdir(parents=True)
    (staging / "repair_v2" / "presets").mkdir(parents=True)
    (staging / "presets" / "existing" / "01_EURUSD_D1_QM5_11421_ohlc.set").write_text("; hdr\nqm_ea_id=11421\nqm_magic_slot_offset=0\nRISK_FIXED=0\nRISK_PERCENT=0.321345\nstrategy_len=20\n", encoding="utf-8")
    (staging / "presets" / "existing" / "02_XAUUSD_D1_QM5_10403_turtle.set").write_text("RISK_PERCENT=0.217916\nRISK_FIXED=0\n", encoding="utf-8")
    (staging / "presets" / "new_burnin" / "25_XAGUSD_D1_QM5_1537_aa-vol.set").write_text(
        "qm_ea_id=1537\nqm_magic_slot_offset=1\nRISK_FIXED=0\nRISK_PERCENT=0.0769\nstrategy_sma=10||5||1||20||N\nstrategy_calendar_symbol=XAGUSD.DWX\n", encoding="utf-8")
    (staging / "repair_v2" / "presets" / "17_USDJPY_M30_QM5_41470_fix-symfix.set").write_text(
        "qm_ea_id=41470\nqm_magic_slot_offset=0\nRISK_FIXED=0\nRISK_PERCENT=0.590437\nstrategy_x=1\nstrategy_symbol=USDJPY\n", encoding="utf-8")
    manifest = {"variant": "T", "owner_decision": "D", "sleeves": [
        {"ea_id": 11421, "symbol": "EURUSD.DWX", "is_new_sleeve": False, "magic": 114210000},
        {"ea_id": 10403, "symbol": "XAUUSD.DWX", "is_new_sleeve": False, "magic": 104030002},
        {"ea_id": 12969, "symbol": "USDJPY.DWX", "is_new_sleeve": False, "magic": 129690000},
        {"ea_id": 1537, "symbol": "XAGUSD.DWX", "is_new_sleeve": True, "magic": 15370001},
    ]}
    delta = {"sleeve": {"ea_id": 41470, "ea_slug": "fix-symfix", "symbol": "USDJPY", "magic": 414700000,
                        "replaces": {"ea_id": 12969, "symbol": "USDJPY"}}}
    return {"tpl": tpl, "staging": staging, "manifest": manifest, "delta": delta, "out": tmp_path / "out"}


def test_chart_roundtrip_is_utf16_and_fields_parse(tmp_path: Path) -> None:
    p = tmp_path / "c.chr"
    bp.write_chart(p, _chart(7, "GBPUSD", 1, 4, "QM5_1_x", _sleeve_inputs(1, 3, "0.1", [])))
    assert p.read_bytes()[:2] == b"\xff\xfe"
    rec = bp.chart_record(p)
    assert (rec["symbol"], rec["period_type"], rec["period_size"], rec["ea_id"], rec["slot"], rec["risk_percent"]) == ("GBPUSD", "1", "4", "1", "3", "0.1")
    assert rec["expert_path"] == "Experts\\Live EAs\\QM5_1_x.ex5" and rec["is_monitor"] is False


def test_dry_run_builds_all_kinds_without_writing(world: dict) -> None:
    r = bp.build_profile(manifest=world["manifest"], staging=world["staging"], template_profile=world["tpl"],
                         out_dir=world["out"], profile_name="P", repair_delta=world["delta"], apply=False)
    assert r["status"] == "DRY_RUN" and r["problems"] == []
    assert r["kinds"] == {"reweighted": 2, "replaced": 1, "new": 1, "monitor": 1}
    assert not world["out"].exists()
    by_kind = {c["kind"]: c for c in r["charts"]}
    assert by_kind["reweighted"]["risk_percent"] in {"0.321345", "0.217916"}
    assert by_kind["replaced"]["ea_id"] == 41470 and by_kind["replaced"]["magic"] == 414700000
    assert by_kind["replaced"]["expert_path"] == "Experts\\Live EAs\\QM5_41470_fix-symfix.ex5"
    new = by_kind["new"]
    assert new["symbol_in_chart"] == "XAGUSD" and new["period"] == "1/24" and new["magic"] == 15370001
    assert new["template"] == "chart02.chr"  # same asset class (metal)
    assert "qm_news_temporal" in new["inputs_from_template"] and "strategy_n" not in new["inputs_from_template"]
    assert r["charts"][-1]["kind"] == "monitor" and r["charts"][-1]["file"] == "chart05.chr"
    assert abs(r["total_risk_percent_at_cutover"] - (0.321345 + 0.217916 + 0.590437 + 0.0769)) < 1e-9


def test_apply_writes_profile_and_verify_passes(world: dict) -> None:
    r = bp.build_profile(manifest=world["manifest"], staging=world["staging"], template_profile=world["tpl"],
                         out_dir=world["out"], profile_name="P", repair_delta=world["delta"], apply=True)
    assert r["status"] == "APPLIED"
    pdir = world["out"] / "P"
    assert sorted(p.name for p in pdir.glob("chart*.chr")) == ["chart01.chr", "chart02.chr", "chart03.chr", "chart04.chr", "chart05.chr"]
    manifest_path = pdir / "profile_manifest.json"
    assert manifest_path.exists() and (pdir / "profile_sha256.txt").exists()
    new_text = bp.read_chart(pdir / "chart04.chr")
    assert "strategy_sma=10" in new_text and "||" not in new_text  # optimisation suffix stripped
    assert "strategy_n=" not in new_text  # other EA's parameters never carry over
    assert "qm_news_temporal=3" in new_text  # framework contract inherited
    assert "digits=3" in new_text
    v = bp.verify_profile(pdir, manifest_path)
    assert v["status"] == "OK", v
    # semantic verify tolerates MT5 re-saving window state, catches a risk change
    t = bp.read_chart(pdir / "chart01.chr").replace("height=100.000000", "height=120.000000")
    bp.write_chart(pdir / "chart01.chr", t)
    assert bp.verify_profile(pdir, manifest_path)["status"] == "OK"
    t = bp._set_field(t, "RISK_PERCENT", "0.9", section="inputs")
    bp.write_chart(pdir / "chart01.chr", t)
    v = bp.verify_profile(pdir, manifest_path)
    assert v["status"] == "MISMATCH" and any("RISK_PERCENT" in m for m in v["mismatches"])


def test_apply_refuses_non_empty_target(world: dict) -> None:
    target = world["out"] / "P"
    target.mkdir(parents=True)
    (target / "stale.txt").write_text("x")
    with pytest.raises(bp.ProfileError):
        bp.build_profile(manifest=world["manifest"], staging=world["staging"], template_profile=world["tpl"],
                         out_dir=world["out"], profile_name="P", repair_delta=world["delta"], apply=True)


def test_blocked_on_missing_preset_and_magic_mismatch(world: dict) -> None:
    (world["staging"] / "presets" / "existing" / "02_XAUUSD_D1_QM5_10403_turtle.set").unlink()
    world["manifest"]["sleeves"][0]["magic"] = 999
    r = bp.build_profile(manifest=world["manifest"], staging=world["staging"], template_profile=world["tpl"],
                         out_dir=world["out"], profile_name="P", repair_delta=world["delta"], apply=True)
    assert r["status"] == "BLOCKED"
    assert any("existing (10403, 'XAUUSD')" in p for p in r["problems"])
    assert any("manifest magic 999" in p for p in r["problems"])
    assert not (world["out"] / "P").exists()


def test_risk_fixed_nonzero_blocks(world: dict) -> None:
    (world["staging"] / "presets" / "new_burnin" / "25_XAGUSD_D1_QM5_1537_aa-vol.set").write_text(
        "qm_ea_id=1537\nqm_magic_slot_offset=1\nRISK_FIXED=100\nRISK_PERCENT=0\n", encoding="utf-8")
    r = bp.build_profile(manifest=world["manifest"], staging=world["staging"], template_profile=world["tpl"],
                         out_dir=world["out"], profile_name="P", repair_delta=world["delta"], apply=False)
    assert r["status"] == "BLOCKED" and any("RISK_FIXED=100" in p for p in r["problems"])
