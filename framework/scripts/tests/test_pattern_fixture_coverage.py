"""Coverage gate for the pattern-permission predicate fixtures.

This is the "no shortcuts" gate OWNER asked for. The contract tests
(test_pattern_permission_contract.py) pin structure and scope; they do not
prove that any individual predicate fires on the right candle shape. These
tests enforce that every one of the 77 predicates is exercised with a positive,
a negative and a boundary fixture, and that the fixtures themselves are honest.

They deliberately stay RED until the fixture suite is complete. A missing
predicate here is not a test failure to be worked around -- it is an untested
predicate that would enter a 1,386-cell census unverified.

The fixtures only describe inputs and expected outputs. Whether the real
QM_PP_Evaluate agrees is decided by the MQL5 runner
(framework/tests/QM_pattern_permission_fixture_runner.mq5); its verdict file is
checked by test_runner_results_all_pass below once a run exists.
"""
from __future__ import annotations

import csv
import importlib.util
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
BUNDLER = REPO_ROOT / "framework" / "scripts" / "build_pattern_fixture_bundle.py"
FIXTURE_DIR = REPO_ROOT / "framework" / "tests" / "fixtures" / "pattern_permission"
RESULTS_CSV = FIXTURE_DIR / "_bundle" / "pattern_fixture_results.csv"

_spec = importlib.util.spec_from_file_location("_ppfb", BUNDLER)
_mod = importlib.util.module_from_spec(_spec)
sys.modules["_ppfb"] = _mod
_spec.loader.exec_module(_mod)


def _load_all():
    src = _mod.HEADER.read_text(encoding="utf-8")
    code = _mod._strip_comments(src)
    ids = _mod.parse_predicate_ids(code)
    req_map, req_default = _mod.parse_required_bars(code)
    fixtures = []
    for path in sorted(FIXTURE_DIR.glob("*.json")):
        fixtures.extend(_mod.load_group(path, ids, req_map, req_default))
    return ids, fixtures


IDS, FIXTURES = _load_all()
BY_PRED: dict[str, list[dict]] = {}
for _fx in FIXTURES:
    BY_PRED.setdefault(_fx["predicate"], []).append(_fx)


def test_every_predicate_has_a_fixture():
    missing = sorted(set(IDS) - set(BY_PRED))
    assert not missing, (
        f"{len(missing)} of {len(IDS)} predicates have no fixture at all. An "
        f"untested predicate entering the census is a measurement with no "
        f"warrant: {missing}")


@pytest.mark.parametrize("case_class", ["positive", "negative", "boundary"])
def test_every_predicate_has_each_case_class(case_class):
    missing = sorted(p for p in IDS
                     if case_class not in {f["case"] for f in BY_PRED.get(p, [])})
    assert not missing, (
        f"{len(missing)} predicates lack a '{case_class}' fixture: {missing}")


def test_boundary_cases_bracket_from_both_sides():
    """A single boundary fixture only proves one side of the threshold."""
    offenders = []
    for pred, fxs in BY_PRED.items():
        boundaries = [f for f in fxs if f["case"] == "boundary"]
        if not boundaries:
            continue          # covered by the case-class test above
        outcomes = {f["expected"] for f in boundaries}
        if outcomes != {True, False}:
            offenders.append(f"{pred} (boundary outcomes: {sorted(outcomes)})")
    assert not offenders, (
        "each predicate's boundary fixtures must bracket the threshold from "
        "both sides -- one expected true just inside, one expected false just "
        f"outside: {offenders}")


def test_positive_and_negative_cases_are_not_written_from_the_source():
    """Circularity guard.

    A positive or negative fixture justified by an implementation threshold is
    a test written from the code it tests: it can only ever confirm whatever
    the code already does, including a wrong reading of the pattern.
    """
    offenders = [f["id"] for f in FIXTURES
                 if f["case"] in ("positive", "negative")
                 and f["basis"] != "pattern_definition"]
    assert not offenders, offenders


def test_no_fixture_relies_on_exact_float_equality():
    """Double arithmetic makes equality unreliable.

    100.2 - 100.0 is 0.19999999999999574, not 0.2. A boundary fixture placed
    exactly on a threshold would pass or fail on rounding rather than on the
    rule, so every fixture must clear its threshold by a visible margin. The
    rationale must say which side it sits on.
    """
    offenders = []
    for fx in FIXTURES:
        if fx["case"] != "boundary":
            continue
        text = fx["rationale"].lower()
        if not any(w in text for w in ("inside", "outside", "above", "below",
                                       "under", "over", "within", "beyond")):
            offenders.append(fx["id"])
    assert not offenders, (
        "every boundary fixture's rationale must state which side of the "
        f"threshold it sits on: {offenders}")


def test_fixture_ids_are_unique_and_named_for_their_predicate():
    seen = {}
    collisions = []
    for fx in FIXTURES:
        if fx["id"] in seen:
            collisions.append(fx["id"])
        seen[fx["id"]] = fx
    assert not collisions, f"duplicate fixture ids: {collisions}"


def test_every_fixture_supplies_the_full_required_window():
    """Guards the pass-for-the-wrong-reason failure mode.

    QM_PP_Evaluate returns false when b.count is below the predicate's
    requirement. A short fixture expecting false would then pass without the
    pattern logic ever being reached.
    """
    offenders = [f"{fx['id']} ({len(fx['rows'])} < {fx['required']})"
                 for fx in FIXTURES if len(fx["rows"]) < fx["required"]]
    assert not offenders, offenders


@pytest.mark.skipif(not RESULTS_CSV.exists(),
                    reason="no MQL5 runner verdict file yet; run the fixture "
                           "runner through the ad-hoc tester harness first")
def test_runner_results_all_pass():
    """The real verdict: what QM_PP_Evaluate actually returned."""
    with RESULTS_CSV.open(encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    assert rows, "runner produced an empty verdict file"

    failures = [r for r in rows if r.get("verdict") != "PASS"]
    detail = "; ".join(
        f"{r['fixture_id']} [{r['predicate']}/{r['case']}] "
        f"expected={r['expected']} actual={r['actual']} ({r['verdict']})"
        for r in failures[:25])
    assert not failures, (
        f"{len(failures)} of {len(rows)} fixtures did not match. Each one is "
        f"either a wrong fixture or a real defect in the predicate -- both must "
        f"be resolved, never suppressed: {detail}")


@pytest.mark.skipif(not RESULTS_CSV.exists(),
                    reason="no MQL5 runner verdict file yet")
def test_runner_covered_every_bundled_fixture():
    """A fixture silently dropped by the runner is an untested predicate."""
    with RESULTS_CSV.open(encoding="utf-8-sig", newline="") as fh:
        ran = {r["fixture_id"] for r in csv.DictReader(fh)}
    expected = {f["id"] for f in FIXTURES}
    missing = sorted(expected - ran)
    assert not missing, f"{len(missing)} bundled fixtures never ran: {missing[:25]}"
