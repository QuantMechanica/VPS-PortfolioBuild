"""ops_issue 237837be-dffe-4687-a3f1-763c88715473 (2026-09-19): the dirty-guard
detail string used to read '... uncommitted file(s): <raw porcelain line>' --
useless for diagnosing WHICH tool re-dirtied the tree. Pins that a recognized
recurring generator output now names its generator script in the detail."""
import sys
from pathlib import Path
from unittest import mock

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "tools" / "strategy_farm"))

import farmctl  # noqa: E402
import health  # noqa: E402


def test_detail_names_the_generator_for_a_known_recurring_doc() -> None:
    blocked = {
        "blocked": True,
        "entries": [" M docs/ops/FTMO_CHALLENGE_READINESS.md"],
        "count": 1,
    }
    with mock.patch.object(farmctl, "_repo_dirty_status", return_value=blocked):
        reason, detail = health._build_lane_block_reason(None)

    assert reason == "dirty_guard"
    assert "tools/strategy_farm/ftmo/challenge_readiness.py" in detail
    assert "docs/ops/FTMO_CHALLENGE_READINESS.md" in detail


def test_detail_omits_generator_label_for_unrecognized_source_edit() -> None:
    blocked = {
        "blocked": True,
        "entries": [" M docs/ops/human_note.md"],
        "count": 1,
    }
    with mock.patch.object(farmctl, "_repo_dirty_status", return_value=blocked):
        reason, detail = health._build_lane_block_reason(None)

    assert reason == "dirty_guard"
    assert "generator:" not in detail
    assert "docs/ops/human_note.md" in detail
