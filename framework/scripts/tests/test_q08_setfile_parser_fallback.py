from __future__ import annotations

import hashlib
from pathlib import Path

import pytest

from framework.scripts import q08_5_neighborhood_runner as runner


REPO_ROOT = Path(__file__).resolve().parents[3]
EA_10582_SETS = REPO_ROOT / "framework" / "EAs" / "QM5_10582_mql5-ema-pred" / "sets"


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


@pytest.mark.parametrize(
    ("child", "sha256", "expected_values"),
    (
        (
            "00",
            "8d47c4cc8191e067af31920bceb3cdcb1af2ebea63b4ddb8df954b9a975cb4f3",
            [1, 2, 16, 2.086268, 1.408344, 96],
        ),
        (
            "01",
            "f2bf459a3255c09eaf4b2333d870eb1a7d06462132c18e0d85dc3a06ac73d5d6",
            [1, 2, 14, 1.947944, 1.550112, 73],
        ),
        (
            "02",
            "477bc9142a10fc09e590d32aad14e056af0710d520f35882525313e4babc6cf1",
            [1, 2, 15, 1.946532, 1.303297, 67],
        ),
    ),
)
def test_real_10582_markerless_ablation_uses_override_block(
    child: str, sha256: str, expected_values: list[object]
) -> None:
    path = EA_10582_SETS / (
        f"QM5_10582_mql5-ema-pred_XAUUSD.DWX_H6_backtest_ablation_{child}.set"
    )

    assignments = runner.parse_setfile_assignments(path)

    assert hashlib.sha256(path.read_bytes()).hexdigest() == sha256
    assert list(assignments) == [
        "strategy_fast_ema_period",
        "strategy_slow_ema_period",
        "strategy_atr_period",
        "strategy_atr_sl_mult",
        "strategy_take_profit_rr",
        "strategy_max_spread_points",
    ]
    assert [row["value"] for row in assignments.values()] == expected_values
    assert all(row["line_number"] >= 28 for row in assignments.values())


def test_real_10582_ablation_materializes_only_effective_override_block(
    tmp_path: Path,
) -> None:
    source = EA_10582_SETS / (
        "QM5_10582_mql5-ema-pred_XAUUSD.DWX_H6_backtest_ablation_00.set"
    )
    source_sha = hashlib.sha256(source.read_bytes()).hexdigest()
    generated = tmp_path / "nominal.set"

    identity = runner.materialize_setfile(
        source,
        {"strategy_atr_period": 17},
        generated,
    )

    lines = generated.read_text(encoding="utf-8").splitlines()
    assert lines[22] == "strategy_atr_period=14"
    assert lines[29] == "strategy_atr_period=17"
    assert runner.parse_setfile_assignments(generated)["strategy_atr_period"]["value"] == 17
    assert identity["strategy_param_count"] == 6
    assert hashlib.sha256(source.read_bytes()).hexdigest() == source_sha


@pytest.mark.parametrize(
    ("content", "message"),
    (
        (
            "strategy_alpha=1\nstrategy_beta=2\n"
            "; --- ablation child 00 of fixture (perturb=±25%) ---\n"
            "strategy_alpha=3\n",
            "key sets differ",
        ),
        (
            "strategy_alpha=1\n"
            "; --- ablation child 00 of fixture (perturb=±25%) ---\n"
            "strategy_alpha=2\n"
            "; --- ablation child 01 of fixture (perturb=±25%) ---\n"
            "strategy_alpha=3\n",
            "exactly two contiguous blocks",
        ),
        (
            "strategy_alpha=1\nstrategy_alpha=2\n"
            "; --- ablation child 00 of fixture (perturb=±25%) ---\n"
            "strategy_alpha=3\n",
            "inside markerless block",
        ),
        (
            "strategy_alpha=1\n; unrelated separator\nstrategy_alpha=2\n",
            "exact ablation-child separator",
        ),
        (
            "strategy_alpha=1\nstrategy_beta=2\n"
            "; --- ablation child 00 of fixture (perturb=±25%) ---\n"
            "strategy_alpha=3\n; nested split\nstrategy_beta=4\n",
            "exactly two contiguous blocks",
        ),
    ),
)
def test_markerless_noncanonical_duplicate_shapes_fail_closed(
    tmp_path: Path, content: str, message: str
) -> None:
    path = _setfile(tmp_path, content)

    with pytest.raises(ValueError, match=message):
        runner.parse_setfile_assignments(path)


def test_marked_file_duplicate_remains_fail_closed(tmp_path: Path) -> None:
    path = _setfile(
        tmp_path,
        "; strategy-specific params\nstrategy_alpha=1\nstrategy_alpha=2\n",
    )

    with pytest.raises(ValueError, match="duplicate strategy parameter strategy_alpha"):
        runner.parse_setfile_assignments(path)
