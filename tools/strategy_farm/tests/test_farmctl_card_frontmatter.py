from pathlib import Path

import pytest

from tools.strategy_farm.farmctl import reject_card, update_card_frontmatter


@pytest.mark.parametrize("with_bom", [False, True])
def test_update_card_frontmatter_accepts_and_preserves_utf8_bom(
    tmp_path: Path, with_bom: bool
) -> None:
    card = tmp_path / "QM5_99999_test.md"
    encoding = "utf-8-sig" if with_bom else "utf-8"
    card.write_text(
        "---\nea_id: 99999\ng0_status: DRAFT\n---\n\n# Test\n",
        encoding=encoding,
        newline="\n",
    )

    update_card_frontmatter(
        card,
        {"g0_status": "REJECTED", "g0_rejection_reason": '"R1 FAIL"'},
    )

    raw = card.read_bytes()
    assert raw.startswith(b"\xef\xbb\xbf") is with_bom
    text = raw.decode("utf-8-sig")
    assert "g0_status: REJECTED" in text
    assert 'g0_rejection_reason: "R1 FAIL"' in text
    assert text.endswith("# Test\n")


def test_update_card_frontmatter_preserves_leading_rejection_comment(tmp_path: Path) -> None:
    card = tmp_path / "QM5_99998_test.md"
    card.write_text(
        "<!-- REJECTED 2026-07-02: banned. -->\n"
        "---\nea_id: 99998\ng0_status: DRAFT\n---\n",
        encoding="utf-8",
        newline="\n",
    )

    update_card_frontmatter(card, {"g0_status": "REJECTED"})

    text = card.read_text(encoding="utf-8")
    assert text.startswith("<!-- REJECTED 2026-07-02: banned. -->\n---\n")
    assert "g0_status: REJECTED" in text


def test_reject_card_is_idempotent_for_card_already_in_rejected_pool(tmp_path: Path) -> None:
    card_dir = tmp_path / "artifacts" / "cards_rejected"
    card_dir.mkdir(parents=True)
    card = card_dir / "QM5_99999_test.md"
    card.write_text(
        "---\nea_id: 99999\nslug: test\ng0_status: DRAFT\n---\n\n# Test\n",
        encoding="utf-8",
        newline="\n",
    )

    first = reject_card(tmp_path, str(card), "R1 FAIL: banned mechanics")
    second = reject_card(tmp_path, str(card), "R1 FAIL: banned mechanics")

    assert first["rejected"] is True
    assert second["rejected"] is True
    assert card.exists()
    updated = card.read_text(encoding="utf-8")
    assert "g0_status: REJECTED" in updated
    assert 'g0_rejection_reason: "R1 FAIL: banned mechanics"' in updated
