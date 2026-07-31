from __future__ import annotations

from pathlib import Path

import pytest

from framework.scripts import q08_5_neighborhood_runner as runner


def _setfile(tmp_path: Path, content: str) -> Path:
    path = tmp_path / "fixture.set"
    path.write_text(content, encoding="utf-8")
    return path


def test_marked_file_keeps_existing_block_semantics(tmp_path: Path) -> None:
    path = _setfile(
        tmp_path,
        "\n".join(
            (
                "strategy_before_marker=1",
                "non_strategy_before=2",
                "; strategy-specific params from card must be appended below this line",
                "custom_card_key=3",
                "strategy_after_marker=4||1||1||9||Y",
                "RISK_FIXED=1000",
                "qm_news_stale_max_hours=336",
                "PORTFOLIO_WEIGHT=1",
            )
        ),
    )

    assignments = runner.parse_setfile_assignments(path)

    assert list(assignments) == ["custom_card_key", "strategy_after_marker"]
    assert assignments["strategy_after_marker"]["value"] == 4
    assert assignments["strategy_after_marker"]["step"] == 1
    assert assignments["strategy_after_marker"]["minimum"] == 1
    assert assignments["strategy_after_marker"]["maximum"] == 9


def test_markerless_legacy_file_harvests_only_exact_strategy_assignments(
    tmp_path: Path,
) -> None:
    path = _setfile(
        tmp_path,
        "\n".join(
            (
                "RISK_FIXED=1000",
                "non_strategy_before=2",
                "strategy_alpha=12",
                "strategy_beta=1.5||0.5||0.25||2.0||Y",
                "non_strategy_after=3",
                "qm_news_stale_max_hours=336",
                "PORTFOLIO_WEIGHT=1",
                "strategy_flag=true",
            )
        ),
    )

    assignments = runner.parse_setfile_assignments(path)

    assert list(assignments) == ["strategy_alpha", "strategy_beta", "strategy_flag"]
    assert assignments["strategy_alpha"]["value"] == 12
    assert assignments["strategy_beta"]["value"] == 1.5
    assert assignments["strategy_beta"]["cells"] == ["1.5", "0.5", "0.25", "2.0", "Y"]
    assert assignments["strategy_beta"]["step"] == 0.25
    assert assignments["strategy_flag"]["value"] is True


@pytest.mark.parametrize(
    "near_miss",
    (
        " strategy_indented=1",
        "Strategy_wrong_case=1",
        "strategy_has_space =1",
        "strategy-hyphen=1",
        "prefix_strategy_extra=1",
        ";strategy_comment=1",
    ),
)
def test_markerless_fallback_requires_exact_column_zero_syntax(
    tmp_path: Path,
    near_miss: str,
) -> None:
    path = _setfile(tmp_path, f"{near_miss}\nstrategy_valid=2\n")

    assignments = runner.parse_setfile_assignments(path)

    assert list(assignments) == ["strategy_valid"]


def test_marker_presence_disables_fallback_for_pre_marker_mixed_content(
    tmp_path: Path,
) -> None:
    path = _setfile(
        tmp_path,
        "\n".join(
            (
                "strategy_legacy_looking=1",
                "; STRATEGY-SPECIFIC PARAMS",
                "strategy_marked=2",
            )
        ),
    )

    assignments = runner.parse_setfile_assignments(path)

    assert list(assignments) == ["strategy_marked"]


def test_markerless_duplicate_strategy_key_fails_closed(tmp_path: Path) -> None:
    path = _setfile(tmp_path, "strategy_alpha=1\nstrategy_alpha=2\n")

    with pytest.raises(ValueError, match="duplicate strategy parameter strategy_alpha"):
        runner.parse_setfile_assignments(path)


def test_markerless_empty_strategy_value_fails_closed(tmp_path: Path) -> None:
    path = _setfile(tmp_path, "strategy_alpha=   \n")

    with pytest.raises(ValueError, match="empty strategy parameter strategy_alpha"):
        runner.parse_setfile_assignments(path)
