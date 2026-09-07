from __future__ import annotations

from pathlib import Path

from tools.strategy_farm import audit_q08_empty_strategy_params as audit


def test_sealed_cohort_has_18_unique_rows_and_two_prepared_replacements() -> None:
    assert len(audit.COHORT_IDS) == 18
    assert len(set(audit.COHORT_IDS)) == 18
    assert set(audit.REPLACEMENTS) == {
        "906b7644-c9ce-4b4c-925a-a11054a95226",
        "2cdb6a16-de65-4ef8-91aa-e45ba4d0704a",
    }


def test_strategy_input_and_assignment_inventory_is_exact(tmp_path: Path) -> None:
    source = tmp_path / "fixture.mq5"
    source.write_text(
        "input int strategy_period = 20;\n"
        "input double strategy_threshold=1.5;\n"
        "input int unrelated = 7;\n",
        encoding="utf-8",
    )
    setfile = tmp_path / "fixture.set"
    setfile.write_text(
        "strategy_threshold=1.5\n"
        "strategy_period=20\n"
        "strategy_period=20\n",
        encoding="utf-8",
    )

    assert audit._declared_strategy_inputs(source) == [
        "strategy_period",
        "strategy_threshold",
    ]
    assert audit._strategy_assignments(setfile) == [
        "strategy_period",
        "strategy_threshold",
    ]


def test_descendants_are_recursive_and_cycle_safe() -> None:
    children = {
        "root": [{"id": "child"}],
        "child": [{"id": "grandchild"}],
        "grandchild": [{"id": "root"}],
    }

    assert [row["id"] for row in audit._descendants("root", children)] == [
        "child",
        "grandchild",
    ]
