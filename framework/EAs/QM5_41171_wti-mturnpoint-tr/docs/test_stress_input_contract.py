"""Execute the changed MQL stress predicate with governed Q06 input values."""
import math
from pathlib import Path
import re
import subprocess

import pytest

ROOT = Path(__file__).resolve().parents[4]
BASE = "5c14b24bd5"
FAMILY = [41171, 41319, 41358, 41359, 41360, 41361, 41362]


def source_path(ea):
    directory = next((ROOT / "framework/EAs").glob(f"QM5_{ea}_*"))
    return directory / (directory.name + ".mq5")


def predicate(source, probability):
    # Translate only the actual finite/range expression, not a parallel model.
    reject = re.search(r"!MathIsValidNumber\(qm_stress_reject_probability\)\s*\|\|\s*qm_stress_reject_probability < 0\.0\s*\|\|\s*qm_stress_reject_probability > 1\.0", source)
    accept = re.search(r"MathIsValidNumber\(qm_stress_reject_probability\)\s*&&\s*qm_stress_reject_probability >= 0\.0\s*&&\s*qm_stress_reject_probability <= 1\.0", source)
    assert bool(reject) != bool(accept)
    expression = (reject or accept)[0].replace("||", " or ").replace("&&", " and ").replace("!", "not ")
    expression = " ".join(expression.split())
    value = eval(expression, {"__builtins__": {}, "MathIsValidNumber": math.isfinite,
                              "qm_stress_reject_probability": probability})
    return not value if reject else value


@pytest.mark.parametrize("ea", FAMILY)
@pytest.mark.parametrize("probability,allowed", [(0, True), (.1, True), (.5, True),
    (1, True), (-.01, False), (1.01, False), (math.nan, False), (math.inf, False), (-math.inf, False)])
def test_actual_family_predicate(ea, probability, allowed):
    assert predicate(source_path(ea).read_text(), probability) is allowed


@pytest.mark.parametrize("ea", FAMILY)
def test_only_stress_pin_changed_and_original_rejects_harsh(ea):
    path = source_path(ea)
    old = subprocess.check_output(["git", "-C", str(ROOT), "show", f"{BASE}:{path.relative_to(ROOT).as_posix()}"], text=True)
    new = path.read_text()
    if ea in (41171, 41319):
        before = "MathAbs(qm_stress_reject_probability) > 0.000000000001)"
        after = "!MathIsValidNumber(qm_stress_reject_probability) ||\n      qm_stress_reject_probability < 0.0 ||\n      qm_stress_reject_probability > 1.0)"
        assert abs(.1) > 0.000000000001
    else:
        before = "MathAbs(qm_stress_reject_probability) <= 1.0e-12)"
        after = "MathIsValidNumber(qm_stress_reject_probability) &&\n            qm_stress_reject_probability >= 0.0 &&\n            qm_stress_reject_probability <= 1.0)"
        assert not abs(.1) <= 1e-12
    assert old.count(before) == 1
    assert new == old.replace(before, after)
    assert predicate(new, .1)


def test_framework_already_accepts_harsh_probability():
    entry = (ROOT / "framework/Include/QM/QM_Entry.mqh").read_text()
    assert "(stress_reject_probability < 0.0) ? 0.0" in entry
    assert "(stress_reject_probability > 1.0) ? 1.0 : stress_reject_probability" in entry
