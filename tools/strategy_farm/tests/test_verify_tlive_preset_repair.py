import csv
import hashlib
import json
from pathlib import Path

from tools.strategy_farm.verify_tlive_preset_repair import (
    DEFAULT_MANIFEST,
    DEFAULT_PROVENANCE,
    VerificationError,
    _git_blob,
    _load_provenance,
    functional_key_diff,
    parse_setfile_bytes,
    verify_manifest,
)


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _setfile(*, build_hash: str, slot: int = 3, news_mode: bool = True) -> bytes:
    news = "qm_filter_news_enabled=1\n" + ("qm_filter_news_mode=3\n" if news_mode else "")
    return (
        "; ea_id: 12989\n"
        "; ea_slug: grimes-nested-pb-v2\n"
        "; symbol: XAUUSD.DWX\n"
        "; timeframe: H4\n"
        "; environment: live\n"
        f"; magic_slot: {slot}\n"
        "; risk_mode: PERCENT\n"
        f"; build_hash: {build_hash}\n"
        f"qm_magic_slot_offset={slot}\n"
        "RISK_FIXED=0\n"
        "RISK_PERCENT=0.2420\n"
        "PORTFOLIO_WEIGHT=1.0\n"
        + news
        + "strategy_tolerance=0.0000000001\n"
    ).encode()


def test_functional_diff_is_raw_byte_exact_and_catches_exponent_trap() -> None:
    before = _setfile(build_hash="a" * 64)
    after = before.replace(b"0.0000000001", b"1.0e-10")
    diff = functional_key_diff(before, after)
    assert diff["all_functional_keys_byte_equal"] is False
    row = next(item for item in diff["keys"] if item["key"] == "strategy_tolerance")
    assert bytes.fromhex(row["deployed_value_hex"]) == b"0.0000000001"
    assert bytes.fromhex(row["regenerated_value_hex"]) == b"1.0e-10"


def test_parser_rejects_duplicate_functional_key() -> None:
    raw = _setfile(build_hash="a" * 64) + b"RISK_FIXED=0\n"
    try:
        parse_setfile_bytes(raw)
    except VerificationError as exc:
        assert "duplicate assignment RISK_FIXED" in str(exc)
    else:
        raise AssertionError("duplicate assignment was accepted")


def _fixture(tmp_path: Path, *, news_mode: bool = True) -> tuple[Path, Path, Path]:
    source = tmp_path / "source.set"
    target = tmp_path / "target.set"
    calendar = tmp_path / "calendar.csv"
    registry = tmp_path / "magic_numbers.csv"
    portfolio = tmp_path / "portfolio.json"
    binary = tmp_path / "QM5_12989_grimes-nested-pb-v2.ex5"
    binary.write_bytes(b"fixture binary")
    binary_hash = _sha(binary)
    source.write_bytes(_setfile(build_hash=binary_hash, news_mode=news_mode))
    target.write_bytes(b"old deployed bytes\n")
    calendar.write_text("timestamp,currency,impact\n", encoding="utf-8")
    with registry.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=("ea_id", "ea_slug", "symbol_slot", "symbol", "magic", "status"),
        )
        writer.writeheader()
        writer.writerow(
            {
                "ea_id": 12989,
                "ea_slug": "grimes-nested-pb-v2",
                "symbol_slot": 3,
                "symbol": "XAUUSD.DWX",
                "magic": 129890003,
                "status": "active",
            }
        )
    portfolio.write_text(
        json.dumps(
            {
                "n_sleeves": 24,
                "total_risk_pct": 9.7499,
                "sleeves": [{"ea_id": 12989, "symbol": "XAUUSD.DWX", "risk_percent": 0.242}],
            }
        ),
        encoding="utf-8",
    )
    manifest = tmp_path / "repair.json"
    manifest.write_text(
        json.dumps(
            {
                "schema_version": "qm.tlive_preset_repair.v1",
                "magic_registry_path": str(registry),
                "news_calendar_path": str(calendar),
                "portfolio_manifest_path": str(portfolio),
                "portfolio_manifest_sha256": _sha(portfolio),
                "presets": [
                    {
                        "ea_label": "QM5_12989_grimes-nested-pb-v2",
                        "ea_id": 12989,
                        "symbol": "XAUUSD.DWX",
                        "symbol_slot": 3,
                        "magic": 129890003,
                        "risk_percent": "0.2420",
                        "expected_build_hash": binary_hash,
                        "target_tlive_binary_path": str(binary),
                        "source_path": str(source),
                        "source_sha256": _sha(source),
                        "target_tlive_path": str(target),
                        "expected_pre_deploy_sha256": _sha(target),
                    }
                ]
                * 10,
            }
        ),
        encoding="utf-8",
    )
    return manifest, source, target


def test_verify_accepts_expected_predeploy_then_requires_source_target_match(tmp_path: Path) -> None:
    manifest, source, target = _fixture(tmp_path)
    assert verify_manifest(manifest)["status"] == "PASS"
    required = verify_manifest(manifest, require_deployed=True)
    assert required["status"] == "FAIL"
    assert any("source->target sha256 mismatch" in item for item in required["findings"])
    target.write_bytes(source.read_bytes())
    assert verify_manifest(manifest, require_deployed=True)["status"] == "PASS"


def test_verify_rejects_news_enabled_without_mode(tmp_path: Path) -> None:
    manifest, _, _ = _fixture(tmp_path, news_mode=False)
    result = verify_manifest(manifest)
    assert result["status"] == "FAIL"
    assert any("news enabled without qm_filter_news_mode" in item for item in result["findings"])


def test_verify_rejects_companion_binary_hash_drift(tmp_path: Path) -> None:
    manifest, _, _ = _fixture(tmp_path)
    payload = json.loads(manifest.read_text(encoding="utf-8"))
    Path(payload["presets"][0]["target_tlive_binary_path"]).write_bytes(b"drifted")
    result = verify_manifest(manifest)
    assert result["status"] == "FAIL"
    assert any("companion binary sha256 mismatch" in item for item in result["findings"])


def test_canonical_provenance_overlay_binds_archival_sources_and_receipt() -> None:
    findings: list[str] = []
    provenance, receipt_by_label = _load_provenance(
        DEFAULT_PROVENANCE,
        manifest_path=DEFAULT_MANIFEST,
        findings=findings,
    )
    manifest = json.loads(DEFAULT_MANIFEST.read_text(encoding="utf-8"))
    assert findings == []
    assert len(receipt_by_label) == len(manifest["presets"]) == 10
    for entry in manifest["presets"]:
        archival = _git_blob(
            provenance["source_git_commit"], entry["source_path"]
        )
        assert hashlib.sha256(archival).hexdigest() == entry["source_sha256"]
        assert receipt_by_label[entry["ea_label"]]["sha256"] == entry["source_sha256"]
