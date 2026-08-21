from pathlib import Path

import pytest

from tools.strategy_farm.farmctl import update_card_frontmatter


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
