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
import json
import re
import subprocess
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path
from types import ModuleType
from typing import Any, Callable, Mapping


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
G1_CLOSURE_LANDED_SIZE = 2541
G1_CLOSURE_LANDED_SHA256 = (
    "832535837651271b35e52ee08df6ddf34115777c0d01e3db3a18f78adac1106c"
)
G1_CLOSURE_LANDED_COMMIT = "4df65f5f633f807b39b3c5426cdf3397a12f8e3e"
G1_CLOSURE_FREEZE_SIZE = 7233
G1_CLOSURE_FREEZE_SHA256 = (
    "84aa9a569d5e6a369ebf65fd6e40062070aa3b40cc4ff96e11d7d1b91586e453"
)
G1_CLOSURE_FREEZE_COMMIT = "dc6b25d6e9db156dbbcf6853f78081b7239eae2e"
G1_CLOSURE_UTILITY_SIZE = 117730
G1_CLOSURE_UTILITY_SHA256 = (
    "60869a4584f2415b7f1200f6ccec403da78ef97894990b28527564fee222408b"
)
G1_CLOSURE_TASK_HELPER_SIZE = 30387
G1_CLOSURE_TASK_HELPER_SHA256 = (
    "0f375586ab41745f66636e0faa995d8dc7d1075a648803e565af500a7ea536da"
)
G1_RUN_ID = "20260721T025051Z_24ed7b13baac4e9ea10a2cff755ae5f5"
G1_TASK_NAME = "QM_QM20002_AUDIT_d3fc294915f4ef4af1ed2795"
G1_REASON_CODE = "SCHEDULER_TRIGGER_NULL_COLLECTION_CONTRACT_DEFECT"
G1_AUTHORIZED_UTC = "2026-07-21T06:02:29.2154412Z"
G1_STATE_SIZE = 7936
G1_STATE_SHA256 = (
    "71876c77e8a26f1371bc4cb2080ce8c92e6f7c2cdabe80ac45d4a39bbae7e212"
)
G1_INTENT_SIZE = 8109
G1_INTENT_SHA256 = (
    "791aa3a1798eaa7be51a18809ea5bfe6518d5d43fc2ad898ef712bde8acf3fab"
)
G1_ANCHOR_SIZE = 10504
G1_ANCHOR_SHA256 = (
    "fbd1457974d276fe421265e43e9e583d2adf51e52a6060446e1ec348d4f70f84"
)
G1_RECEIPT_SIZE = 6739
G1_RECEIPT_SHA256 = (
    "cb8c6470123ee86fd110bea0ee2c06439b47552ebf45be93489df1d2839cee6b"
)
HEX64 = re.compile(r"[0-9a-f]{64}")


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

# Runtime validation errors must enter the frozen auditor's normal fail-closed
# lifecycle (including worker-state publication), so replace the bootstrap
# exception with an AuditError subtype after the exact base import succeeds.
class G2IntegrationError(_BASE.AuditError):
    """A G2 integration root or immutable byte guard failed."""


_G1_CLOSURE = _load_exact_private_module(
    G1_CLOSURE_UTILITY_PATH,
    expected_size=G1_CLOSURE_UTILITY_SIZE,
    expected_sha256=G1_CLOSURE_UTILITY_SHA256,
    private_name="_qm20002_g1_closure_frozen_for_g2_gate",
    label="frozen G1 closure utility",
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


def _require_exact_fields(
    value: Mapping[str, Any], expected: set[str], label: str
) -> None:
    if set(value) != expected:
        raise G2IntegrationError(f"{label} exact field closure drift")


def _load_strict_json(path: Path, label: str) -> dict[str, Any]:
    try:
        text = path.read_text(encoding="utf-8")
        value = json.loads(
            text,
            object_pairs_hook=lambda pairs: _strict_object(pairs, label),
            parse_constant=lambda token: (_ for _ in ()).throw(
                ValueError(f"non-finite JSON token: {token}")
            ),
        )
    except (OSError, UnicodeError, json.JSONDecodeError, ValueError) as exc:
        raise G2IntegrationError(f"{label} is not strict JSON: {path}") from exc
    if not isinstance(value, dict):
        raise G2IntegrationError(f"{label} must be a JSON object")
    return value


def _strict_object(pairs: list[tuple[str, Any]], label: str) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ValueError(f"duplicate property in {label}: {key}")
        result[key] = value
    return result


def _repo_relative(path: Path) -> str:
    try:
        return path.resolve().relative_to(REPO_ROOT.resolve()).as_posix()
    except ValueError as exc:
        raise G2IntegrationError(f"repository binding escaped root: {path}") from exc


def _assert_committed_blob(
    path: Path,
    commit: str,
    *,
    expected_size: int,
    expected_sha256: str,
    label: str,
) -> None:
    if re.fullmatch(r"[0-9a-f]{40}", commit) is None:
        raise G2IntegrationError(f"{label} commit is not an exact object id")
    completed = subprocess.run(
        ["git", "-C", str(REPO_ROOT), "show", f"{commit}:{_repo_relative(path)}"],
        check=False,
        capture_output=True,
        timeout=30,
    )
    if completed.returncode != 0:
        raise G2IntegrationError(f"{label} committed blob cannot be read")
    observed = completed.stdout
    if len(observed) != expected_size or hashlib.sha256(observed).hexdigest() != expected_sha256:
        raise G2IntegrationError(f"{label} committed blob differs from its frozen binding")


def _g1_historical_chain() -> tuple[Any, dict[str, Any]]:
    """Rebuild the frozen G1 byte/auth/job chain without live DEV1 inventory."""

    contract = _G1_CLOSURE.default_contract()
    if (
        contract.run_id != G1_RUN_ID
        or contract.task_name != G1_TASK_NAME
        or contract.analysis_id != _BASE.ANALYSIS_ID
        or contract.auditor_path.resolve() != BASE_AUDITOR_PATH.resolve()
        or contract.task_helper_path.resolve() != G1_CLOSURE_TASK_HELPER_PATH.resolve()
    ):
        raise G2IntegrationError("frozen G1 closure contract identity drift")
    bindings = {
        "pre_receipt": _G1_CLOSURE.file_binding(
            contract.pre_path, contract.pre_sha256
        ),
        "authorization": _G1_CLOSURE.file_binding(
            contract.authorization_path, contract.authorization_sha256
        ),
        "authorization_consumption": _G1_CLOSURE.file_binding(
            contract.consumption_path, contract.consumption_sha256
        ),
        "launch_job": _G1_CLOSURE.file_binding(contract.job_path, contract.job_sha256),
        "frozen_auditor": _G1_CLOSURE.file_binding(
            contract.auditor_path, contract.auditor_sha256
        ),
        "frozen_scheduler": _G1_CLOSURE.file_binding(
            contract.scheduler_path, contract.scheduler_sha256
        ),
        "frozen_control_helper": _G1_CLOSURE.file_binding(
            contract.control_helper_path, contract.control_helper_sha256
        ),
        "runtime_freeze": _G1_CLOSURE.file_binding(
            contract.freeze_path, contract.freeze_sha256
        ),
        "closure_utility": _G1_CLOSURE.file_binding(
            G1_CLOSURE_UTILITY_PATH, G1_CLOSURE_UTILITY_SHA256
        ),
        "closure_task_helper": _G1_CLOSURE.file_binding(
            G1_CLOSURE_TASK_HELPER_PATH, G1_CLOSURE_TASK_HELPER_SHA256
        ),
    }
    pre = _G1_CLOSURE._assert_historical_pre_receipt(
        contract, _G1_AUDITOR, bindings["pre_receipt"]
    )
    _G1_CLOSURE._git_assert_frozen_bytes(contract, pre)
    authorization = _G1_AUDITOR.validate_authorization(
        contract.authorization_path, contract.pre_sha256, pre
    )
    job = _G1_CLOSURE.load_strict_json(contract.job_path, "G1 launch job")
    _G1_AUDITOR._validate_launch_job(
        job, pre, contract.pre_path, contract.pre_sha256, contract.state_path
    )
    if job.get("authorization") != authorization:
        raise G2IntegrationError("G1 launch-job authorization envelope drift")
    _G1_AUDITOR._assert_authorization_consumption(
        job.get("authorization_consumption"),
        authorization,
        contract.pre_path,
        contract.pre_sha256,
        contract.state_path,
        contract.job_path,
        contract.task_name,
        contract.control_helper_sha256,
    )
    if (
        job.get("authorization_consumption", {}).get("binding")
        != bindings["authorization_consumption"]
        or job.get("tool") != bindings["frozen_auditor"]
        or job.get("scheduler", {}).get("helper") != bindings["frozen_scheduler"]
        or pre.get("runtime", {}).get("audit_control_path_helper")
        != bindings["frozen_control_helper"]
    ):
        raise G2IntegrationError("G1 historical launch chain drift")
    chain = {
        "bindings": bindings,
        "pre": pre,
        "authorization": authorization,
        "job": job,
        "runtime_freeze_commit": contract.freeze_commit,
    }
    _G1_CLOSURE._reassert_historical_bindings(chain)
    return contract, chain


def _validate_g1_landing_manifest(
    landed: Mapping[str, Any],
    contract: Any,
    intent_binding: Mapping[str, Any],
    anchor_binding: Mapping[str, Any],
    state_binding: Mapping[str, Any],
    receipt_binding: Mapping[str, Any],
) -> None:
    if (
        landed.get("schema_version") != 1
        or landed.get("artifact_type") != "QM5_20002_G1_PRE_OUTCOME_CLOSURE_LANDED"
        or landed.get("analysis_id") != _BASE.ANALYSIS_ID
        or landed.get("run_id") != G1_RUN_ID
        or landed.get("status") != "TERMINAL_REJECT_EVIDENCE_CLOSED"
        or landed.get("reason_code") != G1_REASON_CODE
        or landed.get("closure_freeze")
        != {
            "path": _repo_relative(G1_CLOSURE_FREEZE_PATH),
            "size": G1_CLOSURE_FREEZE_SIZE,
            "sha256": G1_CLOSURE_FREEZE_SHA256,
            "commit": G1_CLOSURE_FREEZE_COMMIT,
        }
        or landed.get("closure_intent") != intent_binding
        or landed.get("quiescence_anchor") != anchor_binding
        or landed.get("launch_state")
        != {
            **state_binding,
            "state_status": "REJECT",
            "resume_allowed": False,
            "post_allowed": False,
            "evidence_closed": True,
        }
        or landed.get("closure_receipt") != receipt_binding
        or landed.get("verification")
        != {
            "first_invocation": "CLOSED",
            "exact_replay": "ALREADY_CLOSED",
            "status_classification": "TERMINAL_REJECT_EVIDENCE_CLOSED",
            "scheduled_task_absent": True,
            "worker_absent": True,
            "post_receipt_absent": True,
            "no_resume": True,
            "outcome_fence_crossed": False,
            "outcome_data_read": False,
        }
        or landed.get("g2_gate")
        != {
            "must_validate_all_bindings_recursively": True,
            "must_reprobe_scheduled_task_absence": True,
            "must_reject_any_g1_outcome_or_post_artifact": True,
            "must_use_separate_control_root": str(G2_CONTROL_ROOT),
        }
    ):
        raise G2IntegrationError("G1 closure landing manifest semantic drift")
    if Path(str(intent_binding["path"])).resolve() != contract.intent_path.resolve():
        raise G2IntegrationError("G1 closure landing intent path drift")


def validate_g1_closure_gate() -> dict[str, Any]:
    """Pure read-only proof that G1 is terminal, evidence-closed and absent."""

    try:
        landed_binding = _exact_file_binding(
            G1_CLOSURE_LANDED_PATH,
            expected_size=G1_CLOSURE_LANDED_SIZE,
            expected_sha256=G1_CLOSURE_LANDED_SHA256,
            label="G1 closure landing manifest",
        )
        _assert_committed_blob(
            G1_CLOSURE_LANDED_PATH,
            G1_CLOSURE_LANDED_COMMIT,
            expected_size=G1_CLOSURE_LANDED_SIZE,
            expected_sha256=G1_CLOSURE_LANDED_SHA256,
            label="G1 closure landing manifest",
        )
        freeze_binding = _exact_file_binding(
            G1_CLOSURE_FREEZE_PATH,
            expected_size=G1_CLOSURE_FREEZE_SIZE,
            expected_sha256=G1_CLOSURE_FREEZE_SHA256,
            label="G1 closure freeze",
        )
        _assert_committed_blob(
            G1_CLOSURE_FREEZE_PATH,
            G1_CLOSURE_FREEZE_COMMIT,
            expected_size=G1_CLOSURE_FREEZE_SIZE,
            expected_sha256=G1_CLOSURE_FREEZE_SHA256,
            label="G1 closure freeze",
        )
        freeze = _load_strict_json(G1_CLOSURE_FREEZE_PATH, "G1 closure freeze")
        if (
            freeze.get("artifact_type") != "QM5_20002_G1_PRE_OUTCOME_CLOSURE_FREEZE"
            or freeze.get("analysis_id") != _BASE.ANALYSIS_ID
            or freeze.get("run_id") != G1_RUN_ID
            or freeze.get("reason_code") != G1_REASON_CODE
            or freeze.get("owner_closure_authorized_utc") != G1_AUTHORIZED_UTC
        ):
            raise G2IntegrationError("G1 closure freeze identity drift")

        contract, chain = _g1_historical_chain()
        intent_binding = _G1_CLOSURE.file_binding(
            contract.intent_path, G1_INTENT_SHA256
        )
        if intent_binding["size"] != G1_INTENT_SIZE:
            raise G2IntegrationError("G1 closure intent size drift")
        intent = _G1_CLOSURE.load_strict_json(contract.intent_path, "G1 closure intent")
        _G1_CLOSURE._validate_intent(
            contract, intent, chain, G1_AUTHORIZED_UTC, _G1_AUDITOR
        )
        state_binding = _G1_CLOSURE.file_binding(contract.state_path, G1_STATE_SHA256)
        if state_binding["size"] != G1_STATE_SIZE:
            raise G2IntegrationError("G1 terminal state size drift")
        state = _G1_CLOSURE.load_strict_json(contract.state_path, "G1 terminal state")
        _G1_CLOSURE._assert_no_outcome_side_effects(contract)
        proof = _G1_CLOSURE._validate_closed_state_historical_chain(
            contract,
            state,
            intent,
            str(intent_binding["sha256"]),
            chain,
            _G1_AUDITOR,
            require_final=True,
        )
        anchor, anchor_binding = _G1_CLOSURE._load_and_validate_final_anchor(
            contract, proof, chain, intent_binding, intent, _G1_AUDITOR
        )
        del anchor
        if (
            anchor_binding["size"] != G1_ANCHOR_SIZE
            or anchor_binding["sha256"] != G1_ANCHOR_SHA256
        ):
            raise G2IntegrationError("G1 quiescence anchor binding drift")
        fresh_absent = _G1_CLOSURE._task_call(
            contract,
            chain["job"],
            chain["pre"],
            G1_CLOSURE_TASK_HELPER_SHA256,
            "ProbeAbsent",
            allow_observed_start_race=(proof["start_race"] == "true"),
        )
        _G1_CLOSURE._validate_absent_probe(
            fresh_absent,
            contract,
            expected_helper_sha256=G1_CLOSURE_TASK_HELPER_SHA256,
            expected_start_race=(proof["start_race"] == "true"),
        )
        receipt_binding = _G1_CLOSURE.file_binding(
            contract.receipt_path, G1_RECEIPT_SHA256
        )
        if receipt_binding["size"] != G1_RECEIPT_SIZE:
            raise G2IntegrationError("G1 closure receipt size drift")
        receipt = _G1_CLOSURE.load_strict_json(
            contract.receipt_path, "G1 closure receipt"
        )
        _G1_CLOSURE._validate_receipt(
            contract,
            receipt,
            chain,
            intent_binding,
            intent,
            state_binding,
            anchor_binding,
            proof,
            fresh_absent,
        )
        _G1_CLOSURE._assert_no_outcome_side_effects(contract)
        _G1_CLOSURE._reassert_historical_bindings(chain)
        landed = _load_strict_json(
            G1_CLOSURE_LANDED_PATH, "G1 closure landing manifest"
        )
        _validate_g1_landing_manifest(
            landed,
            contract,
            intent_binding,
            anchor_binding,
            state_binding,
            receipt_binding,
        )
        return {
            "schema_version": 1,
            "artifact_type": "QM5_20002_G1_CLOSURE_GATE",
            "status": "PASS",
            "analysis_id": _BASE.ANALYSIS_ID,
            "run_id": G1_RUN_ID,
            "reason_code": G1_REASON_CODE,
            "closure_landed": {
                **landed_binding,
                "commit": G1_CLOSURE_LANDED_COMMIT,
            },
            "closure_freeze": {
                **freeze_binding,
                "commit": G1_CLOSURE_FREEZE_COMMIT,
            },
            "closure_intent": intent_binding,
            "quiescence_anchor": anchor_binding,
            "launch_state": state_binding,
            "closure_receipt": receipt_binding,
            "scheduled_task": {
                "task_name": G1_TASK_NAME,
                "absent": True,
                "fresh_probe": fresh_absent,
                "fresh_probe_sha256": _G1_CLOSURE.canonical_sha256(fresh_absent),
            },
            "no_resume": True,
            "outcome_fence_crossed": False,
            "outcome_data_read": False,
        }
    except G2IntegrationError:
        raise
    except Exception as exc:
        raise G2IntegrationError(f"G1 closure prerequisite failed: {exc}") from exc


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
