"""EA_ML_FORBIDDEN predicate scope (ticket 690fc42a, 2026-09-06).

The Hard Rule forbids ML *libraries* and *learning* inside V5 EAs. The predicate
in ``framework/scripts/build_check.ps1`` previously carried a bare
``\\bweights\\s*\\[`` token and therefore failed any EA that merely names an array
``weights`` -- e.g. QM5_41193's closed-form fractional-differencing coefficients.

These tests pin the intended scope by running the SHIPPED regexes and the SHIPPED
scan loop (both lifted verbatim out of build_check.ps1 between QM-MARK sentinels)
over fixture sources, so the tests cannot drift away from the production predicate.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[3]
BUILD_CHECK = REPO_ROOT / "framework" / "scripts" / "build_check.ps1"

PWSH = shutil.which("pwsh") or shutil.which("powershell")


def _extract(marker: str) -> str:
    text = BUILD_CHECK.read_text(encoding="utf-8")
    pattern = (
        rf"^\s*#\s*QM-MARK:\s*BEGIN\s+{marker}\s*$(?P<body>.*?)"
        rf"^\s*#\s*QM-MARK:\s*END\s+{marker}\s*$"
    )
    match = re.search(pattern, text, re.MULTILINE | re.DOTALL)
    assert match is not None, f"QM-MARK block {marker} missing from {BUILD_CHECK}"
    return match.group("body")


def run_ml_predicate(tmp_path: Path, sources: dict[str, str]) -> list[str]:
    """Scan ``sources`` (name -> MQL text) with the shipped ML predicate."""
    scan_dir = tmp_path / "scan"
    scan_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for name, body in sources.items():
        target = scan_dir / name
        target.write_text(body, encoding="utf-8")
        paths.append(target)

    harness = tmp_path / "ml_harness.ps1"
    file_list = ",".join(f"'{p}'" for p in paths)
    harness.write_text(
        "$ErrorActionPreference = 'Stop'\n"
        "$script:found = New-Object 'System.Collections.Generic.List[string]'\n"
        "function Add-Failure { param([string]$Message) $script:found.Add($Message) }\n"
        f"$mqlFiles = @({file_list})\n"
        + _extract("ML_PREDICATE_PATTERNS")
        + "\n"
        + _extract("ML_PREDICATE_SCAN")
        + "\nConvertTo-Json -InputObject @($script:found) -Compress\n",
        encoding="utf-8",
    )

    result = subprocess.run(
        [PWSH, "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-File", str(harness)],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    assert result.returncode == 0, f"harness failed: {result.stdout}\n{result.stderr}"
    return list(json.loads(result.stdout or "[]"))


# --------------------------------------------------------------------------- #
# Fixtures
# --------------------------------------------------------------------------- #

# Verbatim shape of QM5_41193_xtixng-fracd-rv (fractional differencing): a closed-
# form binomial recurrence over a fixed lag count. No data, no error term, no state
# carried across bars -- deterministic arithmetic that happens to be named "weights".
FRACDIFF_NEGATIVE = r"""
input int    strategy_frac_lags  = 32;
input double strategy_frac_order = 0.4;

bool Strategy_FracDiff(const double &chronological_ratios[], double &outputs[])
  {
   double weights[64];
   int weight_count = 0;

   weights[0] = 1.0;
   weight_count = 1;
   for(int lag = 1; lag < strategy_frac_lags; ++lag)
     {
      weights[lag] =
         weights[lag - 1] *
         ((double)lag - 1.0 - strategy_frac_order) / (double)lag;
      if(!MathIsValidNumber(weights[lag]))
         return false;
      ++weight_count;
     }
   if(weight_count != strategy_frac_lags ||
      MathAbs(weights[0] - 1.0) > 1.0e-12 ||
      MathAbs(weights[1] + strategy_frac_order) > 1.0e-12)
      return false;

   int output_count = 0;
   for(int endpoint = strategy_frac_lags - 1; endpoint < 316; ++endpoint)
     {
      double filtered = 0.0;
      for(int lag = 0; lag < strategy_frac_lags; ++lag)
         filtered += weights[lag] * chronological_ratios[endpoint - lag];
      outputs[output_count++] = filtered;
     }
   return true;
  }
"""

# Other legitimate deterministic coefficient shapes that must stay clean.
DETERMINISTIC_NEGATIVES = r"""
// A neural network would be forbidden here; this EA deliberately uses none.
// Historical note: an earlier draft mentioned a learning_rate in prose only.
double g_weights[3] = {0.5, 0.3, 0.2};
double g_coefficients[3];

double Strategy_WeightedScore(const double &features[])
  {
   double score = 0.0;
   for(int i = 0; i < 3; ++i)
     {
      g_coefficients[i] = g_weights[i] * 2.0;
      score += g_weights[i] * features[i];
     }
   const double last_error = GetLastError();
   if(last_error != 0)
      return 0.0;
   double stop_loss = 1.5;
   g_weights[0] = stop_loss / 3.0;
   return score;
  }
"""

# Realistic online learning: stored parameters updated each bar from an error term
# scaled by a learning rate.
ONLINE_LEARNING_POSITIVE = r"""
double g_weights[8];

void Strategy_OnBarUpdate(const double target, const double &features[])
  {
   const double learning_rate = 0.01;
   double prediction = 0.0;
   for(int i = 0; i < 8; ++i)
      prediction += g_weights[i] * features[i];
   const double err = target - prediction;
   for(int i = 0; i < 8; ++i)
      g_weights[i] += learning_rate * err * features[i];
  }
"""

# Gradient-driven parameter update without the words "learning rate".
GRADIENT_UPDATE_POSITIVE = r"""
struct ModelState { double coeffs[8]; };
ModelState g_state;

void Strategy_Step(const double &gradient[])
  {
   for(int i = 0; i < 8; ++i)
      g_state.coeffs[i] -= 0.05 * gradient[i];
  }
"""

ML_LIBRARY_POSITIVE = """
#include <Math/Onnx/InferenceModel.mqh>
#resource "\\\\Files\\\\xgboost_booster.mqh"
"""

ONNX_API_POSITIVE = r"""
long g_model = INVALID_HANDLE;

double Strategy_Predict(const float &inputs[], float &outputs[])
  {
   g_model = OnnxCreate("classifier.onnx", ONNX_DEFAULT);
   if(!OnnxRun(g_model, ONNX_NO_CONVERSION, inputs, outputs))
      return 0.0;
   OnnxRelease(g_model);
   return (double)outputs[0];
  }
"""

MODEL_ARTIFACT_POSITIVE = r"""
string Strategy_ModelPath()
  {
   return "MQL5\\Files\\gbm_model.onnx";
  }
"""


# --------------------------------------------------------------------------- #
# Tests
# --------------------------------------------------------------------------- #


@pytest.mark.skipif(PWSH is None, reason="PowerShell not available")
def test_fractional_differencing_coefficients_are_not_ml(tmp_path: Path) -> None:
    """QM5_41193's fracdiff recurrence must NOT trip EA_ML_FORBIDDEN."""
    hits = run_ml_predicate(tmp_path, {"fracdiff.mq5": FRACDIFF_NEGATIVE})
    assert hits == [], f"deterministic coefficient array flagged as ML: {hits}"


@pytest.mark.skipif(PWSH is None, reason="PowerShell not available")
def test_deterministic_weight_arrays_and_ml_prose_are_not_ml(tmp_path: Path) -> None:
    hits = run_ml_predicate(tmp_path, {"deterministic.mq5": DETERMINISTIC_NEGATIVES})
    assert hits == [], f"deterministic/prose source flagged as ML: {hits}"


@pytest.mark.skipif(PWSH is None, reason="PowerShell not available")
def test_online_learning_update_is_ml(tmp_path: Path) -> None:
    hits = run_ml_predicate(tmp_path, {"online.mq5": ONLINE_LEARNING_POSITIVE})
    assert hits, "online weight learning was not detected"
    assert all(h.startswith("EA_ML_FORBIDDEN:") for h in hits)
    assert any("learning rate" in h for h in hits)


@pytest.mark.skipif(PWSH is None, reason="PowerShell not available")
def test_gradient_parameter_update_is_ml(tmp_path: Path) -> None:
    hits = run_ml_predicate(tmp_path, {"gradient.mq5": GRADIENT_UPDATE_POSITIVE})
    assert any("learning signal" in h for h in hits), hits


@pytest.mark.skipif(PWSH is None, reason="PowerShell not available")
def test_ml_library_include_is_ml(tmp_path: Path) -> None:
    hits = run_ml_predicate(tmp_path, {"lib.mq5": ML_LIBRARY_POSITIVE})
    assert any("include or import" in h for h in hits), hits


@pytest.mark.skipif(PWSH is None, reason="PowerShell not available")
def test_onnx_inference_api_is_ml(tmp_path: Path) -> None:
    hits = run_ml_predicate(tmp_path, {"onnx.mq5": ONNX_API_POSITIVE})
    assert any("inference / training API" in h for h in hits), hits


@pytest.mark.skipif(PWSH is None, reason="PowerShell not available")
def test_serialized_model_artifact_is_ml(tmp_path: Path) -> None:
    hits = run_ml_predicate(tmp_path, {"artifact.mq5": MODEL_ARTIFACT_POSITIVE})
    assert any("model artifact" in h for h in hits), hits


@pytest.mark.skipif(PWSH is None, reason="PowerShell not available")
def test_reported_line_numbers_survive_comment_blanking(tmp_path: Path) -> None:
    source = "// filler\n/* block\n   comment */\nvoid F() { double lr_probe = 0.0; }\n"
    source = source.replace("lr_probe = 0.0", "learning_rate = 0.0")
    hits = run_ml_predicate(tmp_path, {"lines.mq5": source})
    assert len(hits) == 1, hits
    assert hits[0].split(":")[-2].strip().endswith("4") or ":4 " in hits[0], hits[0]


def test_predicate_no_longer_carries_bare_weights_token() -> None:
    patterns = _extract("ML_PREDICATE_PATTERNS")
    assert r"\bweights\s*\[" not in patterns, (
        "bare `weights[` token is back in the EA_ML_FORBIDDEN predicate"
    )


@pytest.mark.skipif(PWSH is None, reason="PowerShell not available")
def test_build_check_still_parses() -> None:
    command = (
        "$errors = $null; "
        "[void][System.Management.Automation.Language.Parser]::ParseFile("
        f"'{BUILD_CHECK}', [ref]$null, [ref]$errors); "
        "if ($errors) { $errors | ForEach-Object { $_.Message }; exit 1 }"
    )
    result = subprocess.run(
        [PWSH, "-NoProfile", "-NonInteractive", "-Command", command],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    assert result.returncode == 0, result.stdout + result.stderr
