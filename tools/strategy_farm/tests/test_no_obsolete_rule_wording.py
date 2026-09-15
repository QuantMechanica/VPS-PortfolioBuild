"""Regression guard: obsolete OBJECTIVE wording must not reappear on operator surfaces.

OWNER-DEC-CBE-20260915 (Continuous Book Evolution, directive §3/§4/§11) abolished the
"Way to 25" / "Weg zu 25" candidate-count business objective. The count survives only as a
DIAGNOSTIC reference pool size (``reference_pool_size`` / ``Referenz-Pool``), never as a goal.

This test greps the operator surfaces named in the follow-up directive §11 for the obsolete
objective phrasing and FAILS if it reappears WITHOUT an explicit supersession/diagnostic
marker on the same line. Explanatory comments that mention the old phrase in a superseded
context (e.g. ``# the "Way to 25" objective block is abolished``) are allowed; a naive
reintroduction of the objective heading/label is not.

Slice: i3_old_rules_sweep_docs. This is the §11 contract regression test.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

# tools/strategy_farm/tests/ -> tools/strategy_farm/
SURFACE_DIR = Path(__file__).resolve().parent.parent

# Operator surfaces the directive §11 names explicitly.
SURFACES = (
    "render_cockpit_v2.py",
    "morning_brief.py",
    "heartbeat_snapshot.py",
    "operator_surfaces.py",
    "path_to_25.py",
)

# Obsolete OBJECTIVE phrases (candidate count framed as a business goal). Spaced/hyphenated
# forms only -- the snake_case module/function identifier ``path_to_25`` and the retained
# CSS hook ``mc-p25`` are NOT objective wording and must stay callable.
FORBIDDEN = (
    re.compile(r"weg\s+zu\s+25", re.IGNORECASE),
    re.compile(r"way\s+to\s+25", re.IGNORECASE),
    re.compile(r"path\s+to\s+25", re.IGNORECASE),
    re.compile(r"drive[\s-]+to[\s-]+25", re.IGNORECASE),
)

# A line that mentions a forbidden phrase is allowed ONLY when it also carries one of these
# supersession / diagnostic markers -- i.e. it is documenting the supersession, not asserting
# the objective.
ALLOW_MARKER = re.compile(
    r"supersed|supersede[sd]?|abolish|abgeschafft|diagnos|historic|historisch|"
    r"referenz|reference|ref-pool|ref\.?\s*pool|legacy|former|früher|no longer|"
    r"nicht mehr|replaces?|ersetzt|OWNER-DEC-CBE",
    re.IGNORECASE,
)


def _violations(path: Path) -> list[tuple[int, str]]:
    out: list[tuple[int, str]] = []
    text = path.read_text(encoding="utf-8", errors="replace")
    for i, line in enumerate(text.splitlines(), start=1):
        if any(rx.search(line) for rx in FORBIDDEN) and not ALLOW_MARKER.search(line):
            out.append((i, line.strip()[:160]))
    return out


@pytest.mark.parametrize("surface", SURFACES)
def test_no_unmarked_obsolete_objective_wording(surface: str) -> None:
    path = SURFACE_DIR / surface
    assert path.exists(), f"operator surface missing: {path}"
    violations = _violations(path)
    assert not violations, (
        f"Obsolete 'Way to 25' OBJECTIVE wording reappeared in {surface} without a "
        f"supersession/diagnostic marker (OWNER-DEC-CBE-20260915 §3/§4/§11). Offending "
        f"lines: {violations}. Frame the candidate count as a DIAGNOSTIC "
        f"(reference_pool_size / Referenz-Pool), never as a goal."
    )


def test_all_named_surfaces_are_present() -> None:
    # Guards against the surface set silently drifting (e.g. a renamed generator that would
    # no longer be scanned).
    missing = [s for s in SURFACES if not (SURFACE_DIR / s).exists()]
    assert not missing, f"named operator surfaces not found: {missing}"
