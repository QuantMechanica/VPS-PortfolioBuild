"""Build the canonical FACTORY_RUNTIME_ACTIVATION_OWNER_DECISION artifacts.

Fail-closed: every hash is computed from the live repo/flag bytes and
cross-checked against the known pins before anything is written.
"""
import datetime as dt
import hashlib
import json
import secrets
import subprocess
import sys
from pathlib import Path

REPO = Path(r"C:\QM\repo")
FLAG = Path(r"D:\QM\strategy_farm\state\FACTORY_OFF.flag")
TEMPLATE = REPO / "tools/strategy_farm/factory_runtime_activation.v1.template.json"
DECISION_REL = "docs/ops/evidence/FACTORY_RUNTIME_ACTIVATION_OWNER_DECISION.json"
DIGEST_REL = "docs/ops/evidence/FACTORY_RUNTIME_ACTIVATION_OWNER_DECISION.sha256"
EXPECTED_FLAG_SHA = "a36aaefdd09e56bdd314647ea5580b1ac936013d5133c2fc499d5509e49c3f8b"
EXPECTED_MAP_SHA = "ccfb16110aa5722fdbc72bec361c180a485ae14afe2f3c1c99a9949301e0297f"

BINDINGS = {
    "factory_on": "tools/strategy_farm/Factory_ON.ps1",
    "factory_off": "tools/strategy_farm/Factory_OFF.ps1",
    "maintenance_control": "tools/strategy_farm/maintenance_control.py",
    "runtime_activation_validator": "tools/strategy_farm/factory_runtime_activation.py",
    "restart_health": "tools/strategy_farm/factory_restart_health.ps1",
    "process_scope": "tools/strategy_farm/factory_process_scope.ps1",
    "mutation_lock_protocol": "tools/strategy_farm/factory_mutation_lock.ps1",
    "task_manifest": "tools/strategy_farm/qm_tasks.manifest.ps1",
    "worker_launcher": "tools/strategy_farm/start_terminal_workers.py",
    "farmctl": "tools/strategy_farm/farmctl.py",
    "public_snapshot_task_wrapper": "scripts/run_public_snapshot_task.ps1",
    "public_snapshot_incident_guard": "tools/strategy_farm/public_snapshot_incident_guard.py",
}


def git(*args: str) -> str:
    result = subprocess.run(
        ("git", "-C", str(REPO), *args),
        capture_output=True, text=True, encoding="utf-8", check=True,
    )
    return result.stdout.strip()


def sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def git_blob(raw: bytes) -> str:
    return hashlib.sha1(f"blob {len(raw)}\0".encode("ascii") + raw).hexdigest()


def main() -> int:
    prep = json.loads(
        (REPO / "docs/ops/evidence/2026-07-30_factory_preparation_owner_decision.json")
        .read_bytes().decode("utf-8")
    )
    task_map = prep["restore_intent"]["task_enabled_before"]
    map_sha = sha256(json.dumps(task_map, sort_keys=True, separators=(",", ":")).encode())
    assert map_sha == EXPECTED_MAP_SHA, f"task map sha drift: {map_sha}"
    assert len(task_map) == 21

    flag_raw = FLAG.read_bytes()
    flag_sha = sha256(flag_raw)
    flag = json.loads(flag_raw.lstrip(b"\xef\xbb\xbf").decode("utf-8"))
    assert flag["schema_version"] == 2 and flag["state"] == "OFF", (
        f"flag not a clean schema-v2 OFF record: state={flag.get('state')}"
    )
    assert flag["task_enabled_before"] == task_map, "flag map != preparation map"

    dirty = git("status", "--porcelain")
    assert dirty == "", f"repo dirty before binding: {dirty!r}"

    head = git("rev-parse", "HEAD")
    bindings = {}
    for label, rel in BINDINGS.items():
        raw = (REPO / rel).read_bytes()
        blob = git_blob(raw)
        committed_blob = git("rev-parse", f"{head}:{rel}")
        if committed_blob != blob:
            # autocrlf smudged the checkout to CRLF; the validator compares raw
            # worktree bytes against the committed LF blob. Restore exact blob
            # bytes (binary-safe, no shell redirection).
            blob_bytes = subprocess.run(
                ("git", "-C", str(REPO), "cat-file", "blob", f"{head}:{rel}"),
                capture_output=True, check=True,
            ).stdout
            assert git_blob(blob_bytes) == committed_blob, f"{rel}: cat-file mismatch"
            (REPO / rel).write_bytes(blob_bytes)
            raw = (REPO / rel).read_bytes()
            blob = git_blob(raw)
        assert committed_blob == blob, f"{rel}: worktree != HEAD blob"
        commit = head
        bindings[label] = {
            "relative_path": rel,
            "sha256": sha256(raw),
            "git_commit": commit,
            "git_blob": blob,
        }

    payload = json.loads(TEMPLATE.read_bytes().decode("utf-8"))
    now = dt.datetime.now(dt.UTC).replace(microsecond=0)
    payload["decision_id"] = "FACTORY_RUNTIME_ACTIVATION_20260731_OWNER_SESSION_GO"
    payload["activation_nonce"] = secrets.token_hex(16)
    payload["authorized_at_utc"] = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    payload["expires_at_utc"] = (now + dt.timedelta(hours=24)).strftime("%Y-%m-%dT%H:%M:%SZ")
    payload["restore_intent"]["factory_off_flag_sha256"] = flag_sha
    payload["restore_intent"]["task_enabled_before_sha256"] = map_sha
    payload["source_bindings"] = bindings

    decision_bytes = (json.dumps(payload, indent=2) + "\n").encode("utf-8")
    decision_sha = sha256(decision_bytes)
    (REPO / DECISION_REL).write_bytes(decision_bytes)
    sidecar = f"{decision_sha}  FACTORY_RUNTIME_ACTIVATION_OWNER_DECISION.json\n"
    (REPO / DIGEST_REL).write_bytes(sidecar.encode("ascii"))

    print(json.dumps({
        "decision_sha256": decision_sha,
        "flag_sha256": flag_sha,
        "task_map_sha256": map_sha,
        "authorized_at_utc": payload["authorized_at_utc"],
        "expires_at_utc": payload["expires_at_utc"],
        "bindings_head": {k: v["git_commit"][:9] for k, v in bindings.items()},
    }, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
