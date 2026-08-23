from __future__ import annotations

import ast
import re
import sqlite3
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent
STRATEGY_FARM = HERE.parent
sys.path.insert(0, str(STRATEGY_FARM))

import evidence_cascade_driver  # noqa: E402
import farmctl  # noqa: E402
import invalidate_unprofitable_cascade  # noqa: E402
import phase_ids  # noqa: E402


# Static source guard allowlist. PHASE_NOMENCLATURE translates canonical gates
# into retired runner *semantics* for old evidence parsers; it does not decide a
# successor and therefore remains intentionally local to farmctl.
_LITERAL_PHASE_MAP_ALLOWLIST = {
    ("farmctl.py", "PHASE_NOMENCLATURE"),
}
_ADVANCEMENT_CONSUMERS = (
    "farmctl.py",
    "evidence_cascade_driver.py",
    "terminal_worker.py",
    "sweep_enqueue_built_eas.py",
    "invalidate_unprofitable_cascade.py",
    "r_eval_drain.py",
    "repair.py",
)


def test_former_runtime_maps_equal_manifest_derived_values() -> None:
    # Frozen v3 compatibility values copied from the pre-ticket runtime. They
    # are assertions only; production code obtains every relation from
    # phase_ids.advancement_table().
    assert farmctl.PARENT_PROGRESSION_MAP == {
        "P2": "P3",
        "P3": "P3.5",
        "P3.5": "P4",
        "Q02": "Q03",
        "Q03": "Q04",
    }
    assert farmctl.SUPPORTED_BACKTEST_PHASES == ("Q02", "Q03", "Q04")
    expected_cascade = (
        "Q04", "Q05", "Q06", "Q07", "Q08", "Q09_NEWS",
        "Q09_PORTFOLIO", "Q10", "P5", "P5b", "P5c", "P6", "P7", "P8",
    )
    assert farmctl.CASCADE_BACKTEST_PHASES == expected_cascade
    assert farmctl.REAL_PHASE_RUNNER_PHASES == expected_cascade
    assert invalidate_unprofitable_cascade.CASCADE_PHASES == (
        "P3", "P3.5", "P4", "P5", "P5b", "P5c", "P6", "P7", "P8",
    )

    generated_rank = {
        phase: int(rank)
        for phase, rank in re.findall(
            r"WHEN '([^']+)' THEN (\d+)", farmctl._gate_priority_rank_sql()
        )
    }
    assert generated_rank == {
        "Q10": 0,
        "Q09_PORTFOLIO": 1,
        "Q09_NEWS": 1,
        "Q09": 1,
        "Q08": 2,
        "Q07": 3,
        "Q06": 4,
        "Q05": 5,
        "Q04": 6,
        "Q03": 7,
        "Q02": 8,
        "P8": 0,
        "P7": 1,
        "P6": 2,
        "P5c": 3,
        "P5b": 4,
        "P5": 5,
        "P4": 6,
        "P3.5": 7,
        "P3": 8,
        "P2": 9,
    }

    # The old exact-enqueue predecessor table included Q04's established
    # two-hop default-probe exception. Reconstruct it only through the shared
    # helpers and compare all former entries.
    derived_predecessors = {
        phase: (
            phase_ids.prev_phase(phase_ids.prev_phase(phase))
            if phase == farmctl.SUPPORTED_BACKTEST_PHASES[-1]
            else phase_ids.prev_phase(phase)
        )
        for phase in expected_cascade
    }
    assert derived_predecessors == {
        "Q04": "Q02",
        "Q05": "Q04",
        "Q06": "Q05",
        "Q07": "Q06",
        "Q08": "Q07",
        "Q09_NEWS": "Q08",
        "Q09_PORTFOLIO": "Q08",
        "Q10": "Q09_NEWS",
        "P5": "P4",
        "P5b": "P5",
        "P5c": "P5",
        "P6": "P5b",
        "P7": "P6",
        "P8": "P7",
    }


def test_advancement_helpers_are_manifest_ranked_and_storage_aware() -> None:
    contract_next = phase_ids.PHASE_NEXT
    table = phase_ids.advancement_table()

    assert table["Q08"].next == "Q09_NEWS"
    assert phase_ids.prev_phase("Q09_NEWS") == "Q08"
    assert phase_ids.prev_phase("Q09_PORTFOLIO") == "Q08"
    assert phase_ids.next_phase("Q09_PORTFOLIO") is None
    assert phase_ids.next_phase("Q09_NEWS") == contract_next["Q09"] == "Q10"
    assert phase_ids.prev_phase("Q10") == "Q09_NEWS"
    assert phase_ids.phase_rank("Q09_NEWS") == phase_ids.phase_rank("Q09")
    assert phase_ids.phase_rank("P8") == phase_ids.phase_rank("Q08")
    assert phase_ids.next_phase("P3") == "P3.5"
    assert phase_ids.next_phase("P3.5") == "P4"
    assert phase_ids.prev_phase("Q14") == "Q10"
    assert contract_next["Q16"] == "Q11"  # historical manifest evidence
    assert phase_ids.next_phase("Q10") == "Q14"  # mandatory audit (OWNER A2)
    assert phase_ids.next_phase("Q16") is None  # book guard is the only entry


def test_evidence_cascade_walks_q09_in_manifest_order() -> None:
    phases = evidence_cascade_driver.PHASES
    assert phases == (
        "Q02", "Q03", "Q04", "Q05", "Q06", "Q07", "Q08",
        "Q09_NEWS", "Q10",
    )
    assert phases.index("Q09_NEWS") == phases.index("Q08") + 1
    assert phases.index("Q10") == phases.index("Q09_NEWS") + 1


def test_dispatch_successors_match_pre_ticket_fixture_db(tmp_path: Path) -> None:
    """Dry-run the centralized resolver over the frozen pre-ticket routes."""
    fixture_db = tmp_path / "dispatch_successors.sqlite"
    expected = (
        ("Q02", "Q03"),
        ("Q03", "Q04"),
        ("Q04", "Q05"),
        ("Q05", "Q06"),
        ("Q06", "Q07"),
        ("Q07", "Q08"),
        ("Q08", "Q09_NEWS"),
        ("Q09_NEWS", "Q10"),
        ("P2", "P3"),
        ("P3", "P3.5"),
        ("P3.5", "P4"),
    )
    with sqlite3.connect(fixture_db) as conn:
        conn.execute(
            "CREATE TABLE dispatch_fixture(phase TEXT PRIMARY KEY, expected_next TEXT NOT NULL)"
        )
        conn.executemany("INSERT INTO dispatch_fixture VALUES (?, ?)", expected)
        rows = conn.execute(
            "SELECT phase,expected_next FROM dispatch_fixture ORDER BY rowid"
        ).fetchall()

    actual = tuple((phase, phase_ids.next_phase(phase)) for phase, _ in rows)
    assert actual == expected


def test_dispatch_tick_auto_cascade_domain_is_inert() -> None:
    """Regression for review P1: the centralized next_phase() lookup must not
    silently activate the dispatch_tick PASS auto-cascade.

    Pre-centralization the branch used a legacy P-name map guarded by
    ``in SUPPORTED_BACKTEST_PHASES`` and was therefore DEAD for every phase.
    The effective activation domain must stay empty so dispatch_tick behavior is
    byte-identical to pre-ticket; turning it on is a separate GELB decision.
    """
    assert farmctl._DISPATCH_TICK_AUTO_CASCADE_PHASES == frozenset()

    # If the domain is empty, no phase can pass the guard even though the
    # centralized resolver returns supported successors for Q02/Q03.
    for phase in ("Q02", "Q03"):
        successor = phase_ids.next_phase(phase)
        assert successor in farmctl.SUPPORTED_BACKTEST_PHASES  # resolver is live
        assert phase not in farmctl._DISPATCH_TICK_AUTO_CASCADE_PHASES  # gate is shut

    # Static guard: the dispatch_tick PASS branch must gate on the domain set,
    # so a future edit cannot re-enable the cascade by dropping the guard.
    source = (STRATEGY_FARM / "farmctl.py").read_text(encoding="utf-8")
    dispatch_body = source.split("def dispatch_tick(", 1)[1].split(
        "\ndef ", 1
    )[0]
    assert "_DISPATCH_TICK_AUTO_CASCADE_PHASES" in dispatch_body


def test_cascade_verdict_policy_matches_pre_ticket_per_target() -> None:
    """Regression for review P2: the predecessor-keyed verdict dict must be the
    single applied source of truth and reproduce the pre-ticket per-target
    verdict policy without any per-target special-case override.
    """
    # Frozen pre-ticket phase_prev_verdicts, keyed by TARGET phase.
    pre_ticket_by_target = {
        "Q04": {"PASS"},
        "Q05": {"PASS", "PASS_SOFT", "PASS_LOWFREQ"},
        "Q06": {"PASS"},
        "Q07": {"PASS", "PASS_SOFT"},
        "Q08": {"PASS", "MULTI_SEED_PASS"},
        "Q09_NEWS": {"PASS", "FAIL_SOFT"},
        "Q09_PORTFOLIO": {"PASS", "FAIL_SOFT"},
        "Q10": set(farmctl.Q09_NEWS_SUCCESS_VERDICTS),
        "P5": {"PASS"},
        "P5b": {"PASS"},
        "P5c": {"PASS"},
        "P6": {"PASS"},
        "P7": {"PASS"},
        "P8": {"PASS"},
    }
    supported_last = farmctl.SUPPORTED_BACKTEST_PHASES[-1]
    for target, expected in pre_ticket_by_target.items():
        manifest_prev = phase_ids.prev_phase(target)
        effective_prev = (
            phase_ids.prev_phase(manifest_prev)
            if target == supported_last
            else manifest_prev
        )
        resolved = set(farmctl._CASCADE_PASS_VERDICTS_BY_PREDECESSOR[effective_prev])
        assert resolved == expected, (
            f"target {target} (effective_prev {effective_prev}) resolved "
            f"{resolved!r}, expected {expected!r}"
        )

    # P7 must still admit on {PASS} only, now via the dict rather than a shadow.
    assert farmctl._CASCADE_PASS_VERDICTS_BY_PREDECESSOR["P6"] == {"PASS"}
    # The removed special-case must not reappear in enqueue_cascade.
    source = (STRATEGY_FARM / "farmctl.py").read_text(encoding="utf-8")
    cascade_body = source.split(
        "def enqueue_cascade_backtest_for_ea(", 1
    )[1].split("\ndef ", 1)[0]
    assert 'if phase.upper() == "P7"' not in cascade_body


def test_static_grep_guard_has_no_literal_advancement_maps() -> None:
    """Fail if a listed consumer grows another literal phase-to-phase dict."""
    violations: list[str] = []
    for name in _ADVANCEMENT_CONSUMERS:
        path = STRATEGY_FARM / name
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
        for node in ast.walk(tree):
            if not isinstance(node, (ast.Assign, ast.AnnAssign)):
                continue
            value = node.value
            if not isinstance(value, ast.Dict):
                continue
            target = node.target if isinstance(node, ast.AnnAssign) else node.targets[0]
            target_name = target.id if isinstance(target, ast.Name) else "<non-name>"
            string_arrows = [
                (key.value, item.value)
                for key, item in zip(value.keys, value.values)
                if isinstance(key, ast.Constant)
                and isinstance(key.value, str)
                and isinstance(item, ast.Constant)
                and isinstance(item.value, str)
                and (key.value.startswith(("Q", "P", "G0")))
                and (item.value.startswith(("Q", "P", "G0")))
            ]
            if not string_arrows:
                continue
            if (name, target_name) in _LITERAL_PHASE_MAP_ALLOWLIST:
                continue
            violations.append(f"{name}:{node.lineno}:{target_name}:{string_arrows}")
    assert violations == []
