from __future__ import annotations

from pathlib import Path

from framework.scripts import validate_spec_doc


def _write_spec(ea_dir: Path, extra: str = "") -> None:
    ea_dir.mkdir()
    sections = "\n".join(
        f"## {section}\ncomplete" for section in validate_spec_doc.REQUIRED_SECTIONS
    )
    (ea_dir / "SPEC.md").write_text(
        f"**EA ID:** QM5_9467\n{sections}\n{extra}\n",
        encoding="utf-8",
    )


def test_check_one_rejects_control_bytes(tmp_path: Path) -> None:
    ea_dir = tmp_path / "QM5_9467_connors-crsi-pullback-d1"
    _write_spec(ea_dir, "source: \x1bef14 and path: \x07artifacts/cards_approved")

    ok, failures = validate_spec_doc.check_one(ea_dir)

    assert not ok
    assert "disallowed control character(s): 0x07, 0x1B" in failures


def test_check_one_rejects_truncated_currency_but_accepts_literal_dollar(
    tmp_path: Path,
) -> None:
    malformed = tmp_path / "bad" / "QM5_9467_connors-crsi-pullback-d1"
    malformed.parent.mkdir()
    _write_spec(malformed, "RISK_FIXED = ,000 per trade")

    ok, failures = validate_spec_doc.check_one(malformed)

    assert not ok
    assert any("malformed currency token" in failure for failure in failures)

    valid = tmp_path / "good" / "QM5_9467_connors-crsi-pullback-d1"
    valid.parent.mkdir()
    _write_spec(valid, "RISK_FIXED = $1,000 per trade")

    assert validate_spec_doc.check_one(valid) == (True, [])
