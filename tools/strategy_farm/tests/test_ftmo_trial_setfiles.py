from __future__ import annotations

from pathlib import Path

import pytest

from tools.strategy_farm.portfolio import ftmo_trial_setfiles as subject


def test_live_or_non_trial_output_is_refused() -> None:
    with pytest.raises(subject.TrialSetError, match="output_not_declared"):
        subject.safe_output_dir(Path(r"C:\QM\mt5\T_Live\sets_unsafe"))
    with pytest.raises(subject.TrialSetError, match="output_not_declared"):
        subject.safe_output_dir(Path(r"D:\QM\reports\ftmo_trial\ordinary"))


def test_all_sources_render_guarded_trial_contract() -> None:
    slots = subject.registry_slots()
    risk = subject.RISK_TOTAL / len(subject.CANDIDATES)
    seen_magics = set()
    for candidate in subject.CANDIDATES:
        slot = slots[(candidate.ea_id, candidate.source_symbol)]
        source = subject.source_set(candidate).read_text(encoding="utf-8-sig")
        result = subject.render(candidate, risk_percent=risk, slot=slot, build_hash=subject.sha256(subject.binary(candidate)))
        subject.validate(result, candidate=candidate, expected_risk=risk, expected_slot=slot)
        assert "RISK_FIXED=0" in result
        assert "RISK_PERCENT=0.3125" in result
        assert "qm_news_stale_max_hours=336" in result
        assert "DO_NOT_COPY_TO_T_LIVE" in result
        for key, value in subject.assignments(source).items():
            if key not in {"RISK_FIXED", "RISK_PERCENT", "qm_news_stale_max_hours"}:
                assert subject.assignments(result)[key] == value
        magic = candidate.ea_id * 10000 + slot
        assert magic not in seen_magics
        seen_magics.add(magic)


def test_generation_static_caps_and_hashes(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    allowed = tmp_path / "ftmo_trial"
    monkeypatch.setattr(subject, "ALLOWED_ROOT", allowed)
    out = allowed / "sets_20260905_000000"
    manifest = subject.generate(out)
    assert len(manifest["sets"]) == 8
    assert manifest["risk"]["total_percent"] == 2.5
    assert max(manifest["risk"]["symbol_totals"].values()) <= manifest["risk"]["symbol_cap_percent"]
    assert max(manifest["risk"]["asset_class_totals"].values()) <= manifest["risk"]["asset_class_cap_percent"]
    assert all(subject.sha256(Path(row["output"])) == row["output_sha256"] for row in manifest["sets"])
    assert (out / "manifest.json").is_file()


def test_validator_refuses_stale_news_weakening() -> None:
    candidate = subject.CANDIDATES[0]
    slot = subject.registry_slots()[(candidate.ea_id, candidate.source_symbol)]
    text = subject.render(candidate, risk_percent=0.3125, slot=slot, build_hash=subject.sha256(subject.binary(candidate)))
    weakened = text.replace("qm_news_stale_max_hours=336", "qm_news_stale_max_hours=337")
    with pytest.raises(subject.TrialSetError, match="news_stale"):
        subject.validate(weakened, candidate=candidate, expected_risk=0.3125, expected_slot=slot)
