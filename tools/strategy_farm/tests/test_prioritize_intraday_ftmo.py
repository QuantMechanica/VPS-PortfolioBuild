import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import prioritize_intraday_ftmo  # noqa: E402


def test_normalize_epoch_timestamp_to_utc_iso() -> None:
    assert prioritize_intraday_ftmo.normalize_epoch_timestamp("1783629183") == (
        "2026-07-09T20:33:03+00:00"
    )


def test_normalize_epoch_timestamp_leaves_iso_untouched() -> None:
    assert prioritize_intraday_ftmo.normalize_epoch_timestamp("2026-07-09T20:33:03+00:00") is None
