from __future__ import annotations

from tools.strategy_farm import card_heading_language as headings


def test_render_normalisation_uses_the_shared_exact_map() -> None:
    assert headings.normalise_heading("Mechanik") == "Mechanics"
    assert headings.normalise_heading(" R1–R4 Bewertung ") == "R1-R4 assessment"
    assert headings.normalise_heading("Mechanik (legacy note)") == "Mechanik (legacy note)"


def test_heading_check_rejects_mapped_german_and_ignores_code_fences() -> None:
    result = headings.check_markdown_heading_language(
        "# English title\n\n"
        "```markdown\n## Mechanik\n```\n\n"
        "## Quelle\nSource details.\n"
    )

    assert result["ok"] is False
    assert result["unmapped_headings"] == []
    assert result["findings"] == [
        {
            "line": 7,
            "heading": "Quelle",
            "classification": "mapped_non_english_heading",
            "suggested_english": "Source",
            "normalization_map_update_required": False,
        }
    ]


def test_heading_check_reports_unseen_probable_german_for_map_extension() -> None:
    result = headings.check_markdown_heading_language(
        "# English title\n\n## Was ist das fuer eine Strategie?\n"
    )

    assert result["ok"] is False
    assert result["unmapped_headings"] == ["Was ist das fuer eine Strategie?"]
    assert result["findings"][0]["classification"] == "unmapped_probable_german_heading"
    assert result["findings"][0]["normalization_map_update_required"] is True


def test_heading_check_accepts_english_and_ambiguous_cross_language_terms() -> None:
    result = headings.check_markdown_heading_language(
        "# Strategy card\n\n## Entry\n## Status\n## Filter\n## Signal\n"
    )

    assert result == {"ok": True, "findings": [], "unmapped_headings": []}
