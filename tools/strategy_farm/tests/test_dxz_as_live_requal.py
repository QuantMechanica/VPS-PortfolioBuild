from __future__ import annotations

import json
from pathlib import Path

import pytest

from tools.strategy_farm import dxz_as_live_requal as subject


def test_validate_sandbox_rejects_tier_and_live_roots(tmp_path: Path) -> None:
    for name in ("T1", "T10", "T_Live", "random"):
        root = tmp_path / name
        root.mkdir()
        (root / "terminal64.exe").write_bytes(b"x")
        with pytest.raises(subject.RequalError):
            subject.validate_sandbox_root(root)


def test_validate_sandbox_requires_accountless_dxz_truth_root(tmp_path: Path) -> None:
    root = tmp_path / "DXZ_Truth_1"
    (root / "Config").mkdir(parents=True)
    (root / "terminal64.exe").write_bytes(b"x")
    (root / "Config" / "accounts.dat").write_bytes(b"account")
    with pytest.raises(subject.RequalError, match="no verified outbound Internet block"):
        subject.validate_sandbox_root(root)
    assert subject.validate_sandbox_root(
        root, network_isolation_verifier=lambda _: True
    ) == root.resolve()
    (root / "Config" / "accounts.dat").unlink()
    assert subject.validate_sandbox_root(root) == root.resolve()


def test_execute_rejects_live_profile_common_tree() -> None:
    with pytest.raises(subject.RequalError, match="live Windows-profile Common tree"):
        subject.validate_common_root(subject.KNOWN_LIVE_COMMON, execute=True)


def test_plan_may_inspect_live_profile_common_tree() -> None:
    assert subject.validate_common_root(
        subject.KNOWN_LIVE_COMMON, execute=False
    ) == subject.KNOWN_LIVE_COMMON.resolve()


@pytest.mark.parametrize("tier", ["T_Live", "T1", "T10"])
def test_output_root_rejects_every_live_and_tier_tree(
    tmp_path: Path, tier: str
) -> None:
    live_root = tmp_path / "T_Live" / "MT5_Base"
    with pytest.raises(subject.RequalError, match="outside every T_Live/T1-T10"):
        subject.validate_output_root(tmp_path / tier / "reports", live_root)


def test_output_root_accepts_isolated_evidence_tree(tmp_path: Path) -> None:
    live_root = tmp_path / "T_Live" / "MT5_Base"
    output = tmp_path / "evidence" / "target_requal"
    assert subject.validate_output_root(output, live_root) == output.resolve()


def test_resolve_live_preset_uses_header_identity(tmp_path: Path) -> None:
    preset = tmp_path / "odd_name.set"
    preset.write_text(
        "; ea_id: 11165\n; symbol: AUDCAD.DWX\n; timeframe: H1\n; environment: live\n",
        encoding="utf-8",
    )
    resolved, timeframe = subject.resolve_live_preset(tmp_path, 11165, "AUDCAD.DWX")
    assert resolved == preset
    assert timeframe == "H1"


def test_resolve_live_preset_uses_timeframe_and_variant_identity(tmp_path: Path) -> None:
    for timeframe, variant in (("H1", "VARIANT_A"), ("H4", "VARIANT_B")):
        preset = tmp_path / f"preset_{timeframe}.set"
        preset.write_text(
            "; ea_id: 11165\n"
            "; symbol: AUDCAD.DWX\n"
            f"; timeframe: {timeframe}\n"
            f"; variant_id: {variant}\n"
            "; environment: live\n",
            encoding="utf-8",
        )

    resolved, timeframe = subject.resolve_live_preset(
        tmp_path,
        11165,
        "AUDCAD.DWX",
        timeframe="H4",
        variant_id="VARIANT_B",
    )

    assert resolved.name == "preset_H4.set"
    assert timeframe == "H4"


def test_build_jobs_rejects_non_dwx_symbol(tmp_path: Path) -> None:
    manifest = tmp_path / "manifest.json"
    manifest.write_text(
        json.dumps(
            {
                "n_sleeves": 1,
                "sleeves": [
                    {"ea_id": 1, "symbol": "EURUSD", "ea_label": "QM5_1_x", "trades": 1}
                ],
            }
        ),
        encoding="utf-8",
    )
    with pytest.raises(subject.RequalError, match="non-literal DWX"):
        subject.build_jobs(manifest, tmp_path, None)


def test_common_capture_restores_previous_bytes(tmp_path: Path) -> None:
    common = tmp_path / "1_EURUSD_DWX.jsonl"
    common.write_bytes(b"new run\n")
    evidence = tmp_path / "evidence.jsonl"
    result = subject._capture_common_stream(common, evidence, b"previous\n")
    assert result["captured"] is True
    assert result["restored"] is True
    assert evidence.read_bytes() == b"new run\n"
    assert common.read_bytes() == b"previous\n"


def test_trade_stats_hashes_ordered_close_sequence() -> None:
    left = subject.trade_stats([{"time": 1, "net": 2}, {"time": 3, "net": -1}])
    same = subject.trade_stats([{"time": 1, "net": 20}, {"time": 3, "net": -10}])
    other = subject.trade_stats([{"time": 3, "net": -1}, {"time": 1, "net": 2}])
    assert left["close_times_sha256"] == same["close_times_sha256"]
    assert left["close_times_sha256"] != other["close_times_sha256"]
