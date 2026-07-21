#!/usr/bin/env python3
"""Generation-2 adapter for the frozen QM5_20002 short-NY auditor.

The adapter deliberately imports the reviewed G1 auditor twice under private
module names.  One copy remains byte-for-byte/G1-global exact for historical
closure verification; the other receives only the G2 control-plane bindings.
No G1 module in ``sys.modules`` is modified.

G2 PRE remains fail-closed until the separately reviewed runtime-freeze
manifest is injected with its externally supplied SHA-256.
"""

from __future__ import annotations

import hashlib
import importlib.util
import sys
from pathlib import Path
from types import ModuleType
from typing import Any


TOOL_PATH = Path(__file__).resolve()
EA_ROOT = TOOL_PATH.parents[2]
REPO_ROOT = EA_ROOT.parents[2]
DOC_ROOT = EA_ROOT / "docs" / "candidate-analysis"
TOOLS_ROOT = EA_ROOT / "tools" / "candidate_analysis"

BASE_AUDITOR_PATH = TOOLS_ROOT / "audit_short_ny_reverse_time.py"
G2_CONTRACT_PATH = DOC_ROOT / "short_ny_reverse_time_g2_contract.json"
STRATEGY_CONTRACT_PATH = DOC_ROOT / "short_ny_reverse_time_contract.json"
G2_RUNTIME_FREEZE_PATH = (
    DOC_ROOT / "short_ny_reverse_time_g2_runtime_freeze_20260721.json"
)
G1_CLOSURE_LANDED_PATH = (
    DOC_ROOT / "g1_pre_outcome_closure_landed_20260721.json"
)
G1_CLOSURE_FREEZE_PATH = (
    DOC_ROOT / "g1_pre_outcome_closure_freeze_20260721.json"
)
G1_CLOSURE_UTILITY_PATH = TOOLS_ROOT / "close_qm20002_g1.py"
G1_CLOSURE_TASK_HELPER_PATH = TOOLS_ROOT / "close_qm20002_g1_task.ps1"
G2_RUNNER_PROVENANCE_PATH = (
    DOC_ROOT / "g2_run_smoke_worktree_provenance_20260721.json"
)
G2_SCHEDULED_TASK_HELPER_PATH = TOOLS_ROOT / "run_outcome_fenced_task_g2.ps1"
G2_CONTROL_PATH_HELPER_PATH = TOOLS_ROOT / "assert_qm20002_control_path_g2.ps1"

G2_CONTROL_ROOT = Path(r"D:\QM\reports\qm20002\short_ny_reverse_time_g2")
G2_SCHEDULED_TASK_PREFIX = "QM_QM20002_G2_AUDIT_"
G2_LAUNCHER_REVISION = 5
GENERATION = "G2"

BASE_AUDITOR_SIZE = 249680
BASE_AUDITOR_SHA256 = (
    "4f9068c710a34d7f0bd72ad0c93a856d966ca58943ca84fa48f4addc686b0a2f"
)
G2_CONTRACT_SIZE = 4182
G2_CONTRACT_SHA256 = (
    "417521437a1354ccd2d610fa02dc6439e4295b3563a43175cf85dbce54e9ded9"
)
G2_SCHEDULER_SIZE = 11527
G2_SCHEDULER_SHA256 = (
    "13cd1335dba15a74a4253e1d6d1874ca69d80808812210b26510f6ff6f0fe0b1"
)
G2_CONTROL_HELPER_SIZE = 32945
G2_CONTROL_HELPER_SHA256 = (
    "94089ccda7420aaa1d56d959b8e8278453008514fd0be0569e32455618342330"
)


class G2IntegrationError(RuntimeError):
    """A G2 integration root or immutable byte guard failed."""


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _exact_file_binding(
    path: Path, *, expected_size: int, expected_sha256: str, label: str
) -> dict[str, Any]:
    resolved = path.resolve()
    if not resolved.is_file():
        raise G2IntegrationError(f"{label} is missing: {resolved}")
    size = resolved.stat().st_size
    digest = _sha256_file(resolved)
    if size != expected_size or digest != expected_sha256:
        raise G2IntegrationError(
            f"{label} immutable byte guard failed: "
            f"size={size}, sha256={digest}"
        )
    return {"path": str(resolved), "size": size, "sha256": digest}


def _load_exact_private_module(
    path: Path,
    *,
    expected_size: int,
    expected_sha256: str,
    private_name: str,
    label: str,
) -> ModuleType:
    _exact_file_binding(
        path,
        expected_size=expected_size,
        expected_sha256=expected_sha256,
        label=label,
    )
    spec = importlib.util.spec_from_file_location(private_name, path)
    if spec is None or spec.loader is None:
        raise G2IntegrationError(f"cannot create private import for {label}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[private_name] = module
    try:
        spec.loader.exec_module(module)
    except Exception:
        sys.modules.pop(private_name, None)
        raise
    return module


# The historical copy is never patched.  Closure validation must see exactly
# the globals with which G1 PRE/job/state were produced.
_G1_AUDITOR = _load_exact_private_module(
    BASE_AUDITOR_PATH,
    expected_size=BASE_AUDITOR_SIZE,
    expected_sha256=BASE_AUDITOR_SHA256,
    private_name="_qm20002_short_ny_g1_frozen_for_g2_gate",
    label="frozen G1 auditor",
)

# The execution copy is private as well.  Only this copy receives G2 bindings.
_BASE = _load_exact_private_module(
    BASE_AUDITOR_PATH,
    expected_size=BASE_AUDITOR_SIZE,
    expected_sha256=BASE_AUDITOR_SHA256,
    private_name="_qm20002_short_ny_g2_private_base",
    label="G2 private base auditor",
)

_BASE_PREFLIGHT = _BASE.preflight
_BASE_VALIDATE_RUNTIME = _BASE.validate_runtime
_BASE_VALIDATE_PRE_SEMANTICS = _BASE._validate_pre_semantics
_BASE_WORKER_RUN = _BASE._worker_run

_BASE.TOOL_PATH = TOOL_PATH
_BASE.AUDIT_CONTROL_ROOT = G2_CONTROL_ROOT
_BASE.SCHEDULED_TASK_HELPER_PATH = G2_SCHEDULED_TASK_HELPER_PATH
_BASE.CONTROL_PATH_HELPER_PATH = G2_CONTROL_PATH_HELPER_PATH
_BASE.SCHEDULED_TASK_PREFIX = G2_SCHEDULED_TASK_PREFIX
_BASE.LAUNCHER_REVISION = G2_LAUNCHER_REVISION

_g2_runtime_roles = dict(_BASE.RUNTIME_ROLES)
_g2_runtime_roles.update(
    {
        "scheduled_task_helper": G2_SCHEDULED_TASK_HELPER_PATH,
        "audit_control_path_helper": G2_CONTROL_PATH_HELPER_PATH,
        "g2_adapter": TOOL_PATH,
        "g2_private_base_auditor": BASE_AUDITOR_PATH,
        "g2_integration_contract": G2_CONTRACT_PATH,
        "g1_closure_landed_manifest": G1_CLOSURE_LANDED_PATH,
        "g1_closure_freeze_manifest": G1_CLOSURE_FREEZE_PATH,
        "g1_closure_utility": G1_CLOSURE_UTILITY_PATH,
        "g1_closure_task_helper": G1_CLOSURE_TASK_HELPER_PATH,
        "g2_runner_worktree_provenance": G2_RUNNER_PROVENANCE_PATH,
    }
)
_BASE.RUNTIME_ROLES = _g2_runtime_roles
RUNTIME_ROLES = _g2_runtime_roles


def integration_profile() -> dict[str, Any]:
    """Return the mutation-free adapter profile used by focused tests/review."""

    return {
        "generation": GENERATION,
        "analysis_id": _BASE.ANALYSIS_ID,
        "launcher_revision": _BASE.LAUNCHER_REVISION,
        "control_root": str(_BASE.AUDIT_CONTROL_ROOT),
        "scheduled_task_prefix": _BASE.SCHEDULED_TASK_PREFIX,
        "base_auditor": _exact_file_binding(
            BASE_AUDITOR_PATH,
            expected_size=BASE_AUDITOR_SIZE,
            expected_sha256=BASE_AUDITOR_SHA256,
            label="frozen G1/G2 base auditor",
        ),
        "g2_contract": _exact_file_binding(
            G2_CONTRACT_PATH,
            expected_size=G2_CONTRACT_SIZE,
            expected_sha256=G2_CONTRACT_SHA256,
            label="G2 integration contract",
        ),
        "scheduler_helper": _exact_file_binding(
            G2_SCHEDULED_TASK_HELPER_PATH,
            expected_size=G2_SCHEDULER_SIZE,
            expected_sha256=G2_SCHEDULER_SHA256,
            label="G2 scheduler helper",
        ),
        "control_helper": _exact_file_binding(
            G2_CONTROL_PATH_HELPER_PATH,
            expected_size=G2_CONTROL_HELPER_SIZE,
            expected_sha256=G2_CONTROL_HELPER_SHA256,
            label="G2 control helper",
        ),
        "runtime_freeze_required": True,
        "runtime_freeze_path": str(G2_RUNTIME_FREEZE_PATH.resolve()),
    }


def main() -> int:
    raise G2IntegrationError(
        "G2 CLI is fail-closed until closure-gate and external runtime-freeze "
        "validation are integrated"
    )


if __name__ == "__main__":
    raise SystemExit(main())
