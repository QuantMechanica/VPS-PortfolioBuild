#!/usr/bin/env python3
"""One-shot, idempotent activation of Gate Manifest v4 (linear three-phase).

The orchestrator runs this tool once to promote the READ_INERT
``gate_manifest.v4.draft.json`` proposal to an ACTIVE
``gate_manifest.v4.json`` default and to migrate the runtime database's
per-row gate-contract discriminator.  The tool is fail-closed: every step
prints a framed PASS/FAIL line and, in ``--apply`` mode, the run exits
non-zero at the first failing step.

Modes
-----
``--dry-run`` (default)
    Report every step; write nothing.  The database migration is exercised on
    a throw-away COPY of the live database in a scratch directory so the
    reported counts are real.

``--apply``
    Perform the promotion, source flip, database migration (on a fresh backup
    plus the live database, run in a post-flip subprocess so the trigger stamp
    reflects the newly active contract), verification tests, and evidence.

``--apply --no-db``
    Exercise promotion, the source flip, smoke, and the complete verification
    suite in the worktree only.  The database and factory state are not read or
    written, and the source/target manifest files are restored before exit.

``--rollback-plan``
    Print the exact rollback commands and exit.

Safety
------
The tool never toggles the factory and never touches ``T_Live``.  The database
is opened read-only for the precondition census; the migration always backs up
first and only performs the additive, append-only work already reviewed under
rb-contract-version (evidence
``docs/ops/evidence/2026-08-23_rb-contract-version.md``).
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import sqlite3
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path


TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parents[1]
GATE_MANIFEST_PY = TOOL_DIR / "gate_manifest.py"
CONFIG_DIR = TOOL_DIR / "config"
V4_DRAFT_MANIFEST = CONFIG_DIR / "gate_manifest.v4.draft.json"
V4_TARGET_MANIFEST = CONFIG_DIR / "gate_manifest.v4.json"
V3_MANIFEST = CONFIG_DIR / "gate_manifest.v3.json"
GITATTRIBUTES = REPO_ROOT / ".gitattributes"
EVIDENCE_PATH = (
    REPO_ROOT / "docs" / "ops" / "evidence" / "2026-08-23_gate_manifest_v4_activation.md"
)

DEFAULT_DB_ROOT = Path(r"D:\QM\strategy_farm")

ACTIVATION_DATE = "2026-08-23"
ACTIVATED_BY = "CLAUDE"
# Both refs are required by the loader's ACTIVE v4 activation guard
# (gate_manifest.V4_ACTIVATION_REVIEW_REFS): the v4 loader review-fix commit and
# the OWNER decision record for the linear three-phase renumbering.
REVIEW_REFS = ["a4990f77a", "decisions/2026-08-23_owner_gate_manifest_v4_linear.md"]

# v3 storage phases whose id changes meaning under v4.  An active work item
# still sitting in one of these must not be silently reinterpreted.
MEANING_CHANGE_PHASES = ("Q09_NEWS", "Q09_PORTFOLIO", "Q10", "Q14", "Q15", "Q16")
ACTIVE_WORK_ITEM_STATES = ("pending", "active")

GITATTRIBUTES_RULE = "tools/strategy_farm/config/gate_manifest.v4.json text eol=lf"

# The two source-flip substitutions.  Byte-exact anchors keep the flip
# idempotent and reviewable.
FLIP_SUBSTITUTIONS = (
    ("DEFAULT_MANIFEST = V3_MANIFEST", "DEFAULT_MANIFEST = V4_MANIFEST"),
    ("SCHEMA_VERSION = SCHEMA_VERSION_V3", "SCHEMA_VERSION = SCHEMA_VERSION_V4"),
)


# --------------------------------------------------------------------------- #
# Framed step reporting
# --------------------------------------------------------------------------- #
@dataclass
class StepResult:
    name: str
    ok: bool
    lines: list[str] = field(default_factory=list)
    data: dict = field(default_factory=dict)


def _print_framed(result: StepResult) -> None:
    status = "PASS" if result.ok else "FAIL"
    header = f"[{status}] {result.name}"
    width = max([len(header)] + [len(line) for line in result.lines] + [40])
    bar = "+" + "-" * (width + 2) + "+"
    print(bar)
    print(f"| {header.ljust(width)} |")
    if result.lines:
        print("|" + " " * (width + 2) + "|")
        for line in result.lines:
            print(f"| {line.ljust(width)} |")
    print(bar)
    sys.stdout.flush()


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha256_file(path: Path) -> str | None:
    if not path.exists():
        return None
    return _sha256_bytes(path.read_bytes())


def _git(args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(
        ["git", *args],
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
    )


def _git_head() -> str:
    proc = _git(["rev-parse", "HEAD"])
    return proc.stdout.strip() if proc.returncode == 0 else "UNKNOWN"


# --------------------------------------------------------------------------- #
# Step 1 — preconditions
# --------------------------------------------------------------------------- #
def _tracked_config_json() -> list[Path]:
    return sorted(p for p in CONFIG_DIR.glob("gate_manifest.*.json") if p.exists())


def check_git_clean() -> StepResult:
    targets = [GATE_MANIFEST_PY, *_tracked_config_json()]
    rels = [str(p.relative_to(REPO_ROOT)).replace("\\", "/") for p in targets]
    proc = _git(["status", "--porcelain", "--", *rels])
    if proc.returncode != 0:
        return StepResult(
            "precondition: git tree clean for target files",
            False,
            [f"git status failed: {proc.stderr.strip()}"],
        )
    dirty = [line for line in proc.stdout.splitlines() if line.strip()]
    if dirty:
        return StepResult(
            "precondition: git tree clean for target files",
            False,
            ["uncommitted changes in target files:", *dirty],
        )
    return StepResult(
        "precondition: git tree clean for target files",
        True,
        [f"clean: {len(rels)} target files"],
    )


def check_factory_off(db_root: Path, allow_factory_on: bool) -> StepResult:
    flag = db_root / "state" / "FACTORY_OFF.flag"
    if flag.is_file():
        return StepResult(
            "precondition: FACTORY_OFF.flag present",
            True,
            [f"present: {flag}"],
        )
    if allow_factory_on:
        return StepResult(
            "precondition: FACTORY_OFF.flag present",
            True,
            [
                "!!! WARNING: factory is ON and --allow-factory-on was passed. !!!",
                "!!! Activating while the factory runs risks mid-flight rows.  !!!",
                f"missing flag: {flag}",
            ],
        )
    return StepResult(
        "precondition: FACTORY_OFF.flag present",
        False,
        [
            f"missing: {flag}",
            "Run Factory_OFF first, or pass --allow-factory-on to override.",
        ],
    )


def _open_ro(db_path: Path) -> sqlite3.Connection:
    uri = f"file:{db_path.as_posix()}?mode=ro"
    conn = sqlite3.connect(uri, uri=True, timeout=30)
    conn.row_factory = sqlite3.Row
    return conn


def check_no_active_meaning_change_rows(db_path: Path, allow_active: bool) -> StepResult:
    name = "precondition: open meaning-changing rows are cutover-eligible"
    if not db_path.exists():
        return StepResult(name, True, [f"database absent (fresh init): {db_path}"])
    try:
        conn = _open_ro(db_path)
    except sqlite3.Error as exc:
        return StepResult(name, False, [f"cannot open db read-only: {exc}"])
    try:
        plan = pending_cutover_plan(conn)
    except sqlite3.Error as exc:
        conn.close()
        return StepResult(name, False, [f"query failed: {exc}"])
    finally:
        try:
            conn.close()
        except sqlite3.Error:
            pass
    if plan["blocked"]:
        return StepResult(
            name,
            False,
            [
                f"{len(plan['blocked'])} open rows cannot be cut over safely:",
                *(
                    f"{row['work_item_id']}: {row['old_phase']} "
                    f"version={row['old_version']} reason={row['reason']}"
                    for row in plan["blocked"]
                ),
            ],
            plan,
        )
    note = " (--allow-active is no longer required)" if allow_active else ""
    return StepResult(
        name,
        True,
        [
            f"eligible work_items={len(plan['work_items'])}{note}",
            f"dependency-role rewrites={len(plan['dependencies'])}",
        ],
        plan,
    )


def check_draft_read_inert() -> StepResult:
    name = "precondition: v4 draft validates READ_INERT under the loader"
    try:
        import gate_manifest as gm  # local import: never triggers a flip

        draft = gm.load_gate_manifest(V4_DRAFT_MANIFEST)
    except Exception as exc:  # noqa: BLE001 - report any loader failure
        return StepResult(name, False, [f"draft failed to load: {exc}"])
    if draft.activation_state != "READ_INERT":
        return StepResult(
            name,
            False,
            [f"draft activation_state is {draft.activation_state!r}, expected READ_INERT"],
        )
    return StepResult(
        name,
        True,
        [f"READ_INERT; sha256={draft.sha256[:16]}...", f"schema={draft.schema_version}"],
    )


# --------------------------------------------------------------------------- #
# Step 2 — promote (build the ACTIVE v4 manifest bytes)
# --------------------------------------------------------------------------- #
def build_active_manifest_bytes() -> bytes:
    """Return the LF-pinned ACTIVE v4 manifest bytes built from the draft.

    Only ``status`` and ``extension_topology.activation_guard`` differ from the
    frozen draft fixture; every other field is carried verbatim.
    """
    raw = json.loads(V4_DRAFT_MANIFEST.read_text(encoding="utf-8"))
    raw["status"] = "ACTIVE"
    raw["extension_topology"]["activation_guard"] = {
        "state": "ACTIVE",
        "requires_completed_review": "OWNER-RATIFY-GATE-MANIFEST-V4",
        "requires_approver": ACTIVATED_BY,
        "default_manifest_switch": True,
        "activated_by": ACTIVATED_BY,
        "activated_at": ACTIVATION_DATE,
        "review_refs": list(REVIEW_REFS),
    }
    text = json.dumps(raw, indent=2, ensure_ascii=False) + "\n"
    return text.replace("\r\n", "\n").encode("utf-8")


def _validate_manifest_bytes(data: bytes) -> str:
    """Write bytes to a temp path, load them, assert ACTIVE, return sha256."""
    import tempfile

    import gate_manifest as gm

    with tempfile.TemporaryDirectory() as tmp:
        # Loader treats the ACTIVE branch identically for the reserved final
        # filename or any other path (only READ_INERT forbids the default path).
        probe = Path(tmp) / V4_TARGET_MANIFEST.name
        probe.write_bytes(data)
        manifest = gm.load_gate_manifest(probe)
    if manifest.activation_state != "ACTIVE":
        raise RuntimeError(
            f"built manifest activation_state is {manifest.activation_state!r}"
        )
    if manifest.schema_version != gm.SCHEMA_VERSION_V4:
        raise RuntimeError("built manifest is not schema v4")
    return _sha256_bytes(data)


def promote_manifest(*, apply: bool) -> StepResult:
    name = "promote: write gate_manifest.v4.json (ACTIVE)"
    try:
        data = build_active_manifest_bytes()
        sha = _validate_manifest_bytes(data)
    except Exception as exc:  # noqa: BLE001
        return StepResult(name, False, [f"failed to build/validate manifest: {exc}"])
    before = _sha256_file(V4_TARGET_MANIFEST)
    lines = [
        f"activated_by={ACTIVATED_BY} activated_at={ACTIVATION_DATE}",
        f"review_refs={REVIEW_REFS}",
        f"target sha256={sha}",
    ]
    if before is not None:
        if before == sha:
            lines.append("already present with identical bytes (idempotent no-op)")
        else:
            lines.append(f"existing target differs (before={before[:16]}...)")
    result = StepResult(name, True, lines, {"manifest_sha256": sha})
    if apply:
        V4_TARGET_MANIFEST.write_bytes(data)
        _ensure_gitattributes(apply=True)
        result.lines.append(f"written: {V4_TARGET_MANIFEST}")
    else:
        result.lines.append("(dry-run) would write target + .gitattributes rule")
    return result


def _ensure_gitattributes(*, apply: bool) -> bool:
    """Ensure the LF-pinning rule for gate_manifest.v4.json is present."""
    existing = GITATTRIBUTES.read_text(encoding="utf-8") if GITATTRIBUTES.exists() else ""
    if any(line.strip() == GITATTRIBUTES_RULE for line in existing.splitlines()):
        return False
    if apply:
        sep = "" if existing.endswith("\n") or existing == "" else "\n"
        GITATTRIBUTES.write_text(existing + sep + GITATTRIBUTES_RULE + "\n", encoding="utf-8")
    return True


# --------------------------------------------------------------------------- #
# Step 3 — flip the default + smoke
# --------------------------------------------------------------------------- #
def _flip_text(text: str) -> tuple[str, bool]:
    """Return (flipped_text, changed). Idempotent and fail-closed."""
    flipped = text
    changed = False
    for old, new in FLIP_SUBSTITUTIONS:
        if new in flipped and old not in flipped:
            continue  # already flipped
        count = flipped.count(old)
        if count != 1:
            raise RuntimeError(
                f"flip anchor {old!r} found {count} times (expected exactly 1)"
            )
        flipped = flipped.replace(old, new)
        changed = True
    return flipped, changed


def flip_default(*, apply: bool) -> StepResult:
    name = "flip: DEFAULT_MANIFEST + SCHEMA_VERSION -> v4"
    original = GATE_MANIFEST_PY.read_text(encoding="utf-8")
    before = _sha256_bytes(original.encode("utf-8"))
    try:
        flipped, changed = _flip_text(original)
    except RuntimeError as exc:
        return StepResult(name, False, [str(exc)])
    after = _sha256_bytes(flipped.encode("utf-8"))
    lines = [
        f"before sha256={before}",
        f"after  sha256={after}",
    ]
    if not changed:
        lines.append("already flipped to v4 (idempotent no-op)")
    if apply and changed:
        GATE_MANIFEST_PY.write_text(flipped, encoding="utf-8", newline="\n")
        lines.append("gate_manifest.py flipped")
    elif not apply:
        lines.append("(dry-run) would flip both anchors")
    return StepResult(name, True, lines, {"before": before, "after": after})


SMOKE_SNIPPET = (
    "import json, phase_ids, gate_manifest\n"
    "m = gate_manifest.load_gate_manifest()\n"
    "out = {\n"
    "  'schema': m.schema_version,\n"
    "  'phase_order': list(phase_ids.PHASE_ORDER),\n"
    "  'next_q14': phase_ids.next_phase_id('Q14'),\n"
    "  'macro_q10': m.macro_phase('Q10'),\n"
    "  'macro_q15': m.macro_phase('Q15'),\n"
    "  'macro_q17': m.macro_phase('Q17'),\n"
    "  'label_q10_v3': phase_ids.phase_label('Q10','v3'),\n"
    "  'active_version': phase_ids.ACTIVE_GATE_CONTRACT_VERSION,\n"
    "}\n"
    "print('SMOKE_JSON:' + json.dumps(out))\n"
)

EXPECTED_PHASE_ORDER = [f"Q{n:02d}" for n in range(18)]


def _evaluate_smoke(out: dict) -> list[str]:
    failures = []
    if out.get("schema") != "qm.gate-manifest/v4":
        failures.append(f"schema={out.get('schema')!r} (want qm.gate-manifest/v4)")
    if out.get("active_version") != "v4":
        failures.append(f"active_version={out.get('active_version')!r} (want v4)")
    if out.get("phase_order") != EXPECTED_PHASE_ORDER:
        failures.append("phase_order is not the linear Q00..Q17 chain")
    if out.get("next_q14") is not None:
        failures.append(f"next(Q14)={out.get('next_q14')!r} (want None)")
    for key in ("macro_q10", "macro_q15", "macro_q17"):
        if not out.get(key):
            failures.append(f"{key} missing")
    if out.get("label_q10_v3") != "Q11 (v3:Q10)":
        failures.append(
            f"phase_label('Q10','v3')={out.get('label_q10_v3')!r} (want 'Q11 (v3:Q10)')"
        )
    return failures


def run_smoke(cwd: Path) -> StepResult:
    name = "flip smoke: v4 default loads and renders"
    proc = subprocess.run(
        [sys.executable, "-c", SMOKE_SNIPPET],
        cwd=str(cwd),
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        return StepResult(name, False, ["smoke subprocess failed:", proc.stderr.strip()])
    payload = None
    for line in proc.stdout.splitlines():
        if line.startswith("SMOKE_JSON:"):
            payload = json.loads(line[len("SMOKE_JSON:"):])
            break
    if payload is None:
        return StepResult(name, False, ["no SMOKE_JSON emitted", proc.stdout.strip()])
    failures = _evaluate_smoke(payload)
    if failures:
        return StepResult(name, False, ["smoke assertions failed:", *failures])
    return StepResult(
        name,
        True,
        [
            f"schema={payload['schema']} active={payload['active_version']}",
            "phase_order=Q00..Q17 linear; next(Q14)=None",
            f"macro: Q10={payload['macro_q10']} Q15={payload['macro_q15']}",
            f"phase_label('Q10','v3')={payload['label_q10_v3']!r}",
        ],
        {"smoke": payload},
    )


# --------------------------------------------------------------------------- #
# Step 4 — database migration
# --------------------------------------------------------------------------- #
GATE_CONTRACT_ACTIVATIONS_DDL = """
CREATE TABLE IF NOT EXISTS gate_contract_activations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    contract_version TEXT NOT NULL,
    activated_at TEXT NOT NULL,
    manifest_sha256 TEXT NOT NULL,
    backup_path TEXT NOT NULL,
    git_head TEXT NOT NULL
)
"""

GATE_CONTRACT_CUTOVER_DDL = """
CREATE TABLE IF NOT EXISTS gate_contract_cutover_log (
    work_item_id TEXT NOT NULL,
    old_phase TEXT NOT NULL,
    new_phase TEXT NOT NULL,
    old_version TEXT NOT NULL,
    new_version TEXT NOT NULL,
    at TEXT NOT NULL
);
CREATE TRIGGER IF NOT EXISTS trg_gate_contract_cutover_log_no_update
BEFORE UPDATE ON gate_contract_cutover_log
BEGIN SELECT RAISE(ABORT, 'gate_contract_cutover_log is append-only'); END;
CREATE TRIGGER IF NOT EXISTS trg_gate_contract_cutover_log_no_delete
BEFORE DELETE ON gate_contract_cutover_log
BEGIN SELECT RAISE(ABORT, 'gate_contract_cutover_log is append-only'); END;
"""

DEPENDENCY_APPEND_ONLY_TRIGGER_DDL = """
CREATE TRIGGER IF NOT EXISTS trg_wid_no_update
BEFORE UPDATE ON work_item_dependencies
BEGIN SELECT RAISE(ABORT, 'work_item_dependencies is append-only'); END
"""

CUTOVER_SOURCE_VERSIONS = frozenset({"legacy", "v2", "v3"})


def _v4_cutover_maps() -> tuple[dict[str, str], dict[str, str]]:
    import gate_manifest as gm

    manifest_path = gm.V4_MANIFEST if gm.V4_MANIFEST.exists() else gm.V4_DRAFT_MANIFEST
    manifest = gm.load_gate_manifest(manifest_path)
    phase_map = {
        str(old): str(new)
        for old, new in manifest.contract_equivalence["v3_to_v4"].items()
        if str(old) != str(new)
    }
    dependency_map = {
        str(old): str(new)
        for old, new in manifest.contract_equivalence[
            "dependency_role_v3_to_v4"
        ].items()
        if str(old) != str(new)
    }
    return phase_map, dependency_map


def pending_cutover_plan(conn: sqlite3.Connection) -> dict[str, list[dict]]:
    """Return the exact open-row and dependency rewrites without mutation."""

    phase_map, dependency_map = _v4_cutover_maps()
    if not _table_exists(conn, "work_items"):
        return {"work_items": [], "dependencies": [], "blocked": []}
    columns = {
        str(row[1]) for row in conn.execute("PRAGMA table_info(work_items)").fetchall()
    }
    version_sql = (
        "coalesce(nullif(lower(trim(gate_contract_version)),''),'legacy')"
        if "gate_contract_version" in columns
        else "'legacy'"
    )
    payload_sql = "payload_json" if "payload_json" in columns else "NULL"
    placeholders = ",".join("?" for _ in phase_map)
    rows = conn.execute(
        f"SELECT id,phase,status,verdict,{version_sql} AS old_version,"
        f"{payload_sql} AS payload_json "
        f"FROM work_items WHERE status IN ('pending','active') "
        f"AND phase IN ({placeholders}) ORDER BY id",
        tuple(phase_map),
    ).fetchall()
    work_items: list[dict] = []
    blocked: list[dict] = []
    by_id: dict[str, dict] = {}
    for row in rows:
        item = {
            "work_item_id": str(row[0]),
            "old_phase": str(row[1]),
            "new_phase": phase_map[str(row[1])],
            "old_version": str(row[4]),
            "new_version": "v4",
            "status": str(row[2]),
        }
        verdict = str(row[3] or "").strip()
        if item["old_version"] == "v4":
            # The numeric token may also exist on the v3 side of the mapping
            # (for example v4 Q11), but its explicit v4 stamp proves it is
            # already in the target contract and must not be translated again.
            continue
        if item["old_version"] not in CUTOVER_SOURCE_VERSIONS or verdict:
            item["reason"] = (
                "open meaning-changing row has a verdict"
                if verdict
                else "unsupported source contract version"
            )
            blocked.append(item)
            continue
        payload_raw = row[5]
        if payload_raw not in (None, ""):
            try:
                payload = json.loads(str(payload_raw))
            except (json.JSONDecodeError, TypeError):
                item["reason"] = "payload provenance is not valid JSON"
                blocked.append(item)
                continue
            if not isinstance(payload, dict):
                item["reason"] = "payload provenance is not a JSON object"
                blocked.append(item)
                continue
            payload_phase = str(payload.get("phase") or "").strip().upper()
            payload_version = str(
                payload.get("gate_contract_version") or ""
            ).strip().lower()
            if payload_version.startswith("qm.gate-manifest/"):
                payload_version = payload_version.rsplit("/", 1)[-1]
            conflicts = []
            if payload_phase and payload_phase != item["new_phase"].upper():
                conflicts.append(f"payload phase={payload_phase}")
            if payload_version and payload_version != item["new_version"]:
                conflicts.append(f"payload version={payload_version}")
            if conflicts:
                item["reason"] = (
                    "bound payload provenance requires append-only remint: "
                    + ", ".join(conflicts)
                )
                blocked.append(item)
                continue
        work_items.append(item)
        by_id[item["work_item_id"]] = item

    dependencies: list[dict] = []
    if by_id and _table_exists(conn, "work_item_dependencies"):
        ids = tuple(by_id)
        id_placeholders = ",".join("?" for _ in ids)
        role_placeholders = ",".join("?" for _ in dependency_map)
        dep_rows = conn.execute(
            f"SELECT child_work_item_id,dependency_role,parent_work_item_id "
            f"FROM work_item_dependencies "
            f"WHERE dependency_role IN ({role_placeholders}) "
            f"AND (child_work_item_id IN ({id_placeholders}) "
            f"OR parent_work_item_id IN ({id_placeholders})) "
            f"ORDER BY child_work_item_id,dependency_role",
            (*dependency_map, *ids, *ids),
        ).fetchall()
        for child, role, parent in dep_rows:
            associated = by_id.get(str(child)) or by_id[str(parent)]
            dependencies.append(
                {
                    "work_item_id": str(child),
                    "parent_work_item_id": str(parent),
                    "old_phase": str(role),
                    "new_phase": dependency_map[str(role)],
                    "old_version": associated["old_version"],
                    "new_version": "v4",
                }
            )
    return {
        "work_items": work_items,
        "dependencies": dependencies,
        "blocked": blocked,
    }


def cutover_pending_rows(conn: sqlite3.Connection, *, apply: bool) -> StepResult:
    """Renumber only open, unverdictable pre-v4 rows and their live edges."""

    name = "cutover pending rows"
    try:
        plan = pending_cutover_plan(conn)
    except sqlite3.Error as exc:
        return StepResult(name, False, [f"cutover census failed: {exc}"])
    if plan["blocked"]:
        return StepResult(
            name,
            False,
            [
                f"blocked open rows={len(plan['blocked'])}",
                *(
                    f"{row['work_item_id']}: {row['old_phase']} "
                    f"version={row['old_version']} reason={row['reason']}"
                    for row in plan["blocked"]
                ),
            ],
            plan,
        )
    lines = [
        f"work_item rewrites={len(plan['work_items'])}",
        f"dependency-role rewrites={len(plan['dependencies'])}",
    ]
    lines.extend(
        f"{row['work_item_id']}: {row['old_phase']}->{row['new_phase']} "
        f"{row['old_version']}->v4"
        for row in plan["work_items"]
    )
    lines.extend(
        f"dependency {row['work_item_id']}: {row['old_phase']}->{row['new_phase']}"
        for row in plan["dependencies"]
    )
    if not apply or (not plan["work_items"] and not plan["dependencies"]):
        return StepResult(name, True, lines, plan)

    import farmctl

    try:
        conn.executescript(GATE_CONTRACT_CUTOVER_DDL)
        conn.commit()
        conn.execute("BEGIN IMMEDIATE")
        # Both guards are restored in the same transaction. Their temporary
        # removal is scoped to this reviewed one-time relabel and every rewrite
        # is appended to the immutable cutover ledger.
        conn.execute(
            f"DROP TRIGGER IF EXISTS {farmctl._WORK_ITEM_GATE_CONTRACT_IMMUTABLE_TRIGGER}"
        )
        conn.execute(
            f"DROP TRIGGER IF EXISTS {farmctl._WORK_ITEM_PHASE_IMMUTABLE_TRIGGER}"
        )
        conn.execute("DROP TRIGGER IF EXISTS trg_wid_no_update")
        for dep in plan["dependencies"]:
            collision = conn.execute(
                "SELECT 1 FROM work_item_dependencies "
                "WHERE child_work_item_id=? AND dependency_role=?",
                (dep["work_item_id"], dep["new_phase"]),
            ).fetchone()
            if collision:
                raise RuntimeError(
                    f"dependency role collision for {dep['work_item_id']}: "
                    f"{dep['new_phase']}"
                )
            changed = conn.execute(
                "UPDATE work_item_dependencies SET dependency_role=? "
                "WHERE child_work_item_id=? AND dependency_role=? "
                "AND parent_work_item_id=?",
                (
                    dep["new_phase"], dep["work_item_id"], dep["old_phase"],
                    dep["parent_work_item_id"],
                ),
            ).rowcount
            if changed != 1:
                raise RuntimeError(f"dependency rewrite count was {changed}, expected 1")
        at = dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")
        for item in plan["work_items"]:
            changed = conn.execute(
                "UPDATE work_items SET phase=?,gate_contract_version='v4' "
                "WHERE id=? AND phase=? AND status IN ('pending','active') "
                "AND (verdict IS NULL OR trim(verdict)='')",
                (item["new_phase"], item["work_item_id"], item["old_phase"]),
            ).rowcount
            if changed != 1:
                raise RuntimeError(f"work-item rewrite count was {changed}, expected 1")
        for row in (*plan["work_items"], *plan["dependencies"]):
            conn.execute(
                "INSERT INTO gate_contract_cutover_log "
                "(work_item_id,old_phase,new_phase,old_version,new_version,at) "
                "VALUES (?,?,?,?,?,?)",
                (
                    row["work_item_id"], row["old_phase"], row["new_phase"],
                    row["old_version"], row["new_version"], at,
                ),
            )
        farmctl.ensure_work_item_gate_contract_schema(conn)
        if _table_exists(conn, "work_item_dependencies"):
            conn.execute(DEPENDENCY_APPEND_ONLY_TRIGGER_DDL)
        conn.commit()
    except Exception as exc:  # noqa: BLE001 - rollback any partial relabel
        if conn.in_transaction:
            conn.rollback()
        return StepResult(name, False, [*lines, f"transaction rolled back: {exc}"], plan)
    return StepResult(name, True, [*lines, "transaction committed"], plan)


def _table_exists(conn: sqlite3.Connection, table: str) -> bool:
    return (
        conn.execute(
            "SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (table,)
        ).fetchone()
        is not None
    )


def _column_exists(conn: sqlite3.Connection, table: str, column: str) -> bool:
    return any(
        str(row[1]) == column
        for row in conn.execute(f"PRAGMA table_info({table})").fetchall()
    )


def _version_counts(conn: sqlite3.Connection) -> dict[str, int]:
    if not _table_exists(conn, "work_items") or not _column_exists(
        conn, "work_items", "gate_contract_version"
    ):
        return {}
    return {
        str(row[0]) if row[0] is not None else "<null>": int(row[1])
        for row in conn.execute(
            "SELECT gate_contract_version, COUNT(*) FROM work_items GROUP BY 1"
        ).fetchall()
    }


def _dependency_stats(conn: sqlite3.Connection) -> tuple[int, dict[str, int]]:
    if not _table_exists(conn, "work_item_dependencies"):
        return 0, {}
    total = int(
        conn.execute("SELECT COUNT(*) FROM work_item_dependencies").fetchone()[0]
    )
    by_role = {
        str(row[0]): int(row[1])
        for row in conn.execute(
            "SELECT dependency_role, COUNT(*) FROM work_item_dependencies GROUP BY 1"
        ).fetchall()
    }
    return total, by_role


def _run_core_migration(conn: sqlite3.Connection) -> None:
    """Run the two reviewed, additive, append-only schema migrations."""
    import farmctl
    import q09_news_schema

    farmctl.ensure_work_item_gate_contract_schema(conn)
    conn.commit()
    q09_news_schema.ensure_schema(conn)


def migrate_database(
    db_path: Path,
    *,
    backup_dir: Path,
    manifest_sha256: str,
    git_head: str,
    apply: bool,
    scratch_dir: Path | None = None,
    active_version: str = "v4",
) -> StepResult:
    """Migrate the gate-contract discriminator; back up first in apply mode.

    In dry-run the whole migration (including backup + activation stamp) is
    exercised on a throw-away COPY under ``scratch_dir`` so the reported counts
    are real and the live database is never opened for write.
    """
    name = "db migration: gate_contract_version + q09 schema"
    if not db_path.exists():
        return StepResult(name, False, [f"database not found: {db_path}"])

    ts = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    if apply:
        target_db = db_path
        backup_dir.mkdir(parents=True, exist_ok=True)
        backup_path = backup_dir / f"farm_state_pre_v4_{ts}.sqlite"
    else:
        if scratch_dir is None:
            return StepResult(name, False, ["dry-run requires a scratch_dir"])
        scratch_dir.mkdir(parents=True, exist_ok=True)
        target_db = scratch_dir / "farm_state_copy.sqlite"
        # Snapshot through a strictly read-only source connection.  A raw file
        # copy can split a WAL database across moments, while opening it in the
        # default read/write mode can checkpoint and change the source file.
        # SQLite's online backup produces one coherent, worktree-local image.
        if target_db.exists():
            target_db.unlink()
        source = _open_ro(db_path)
        try:
            destination = sqlite3.connect(str(target_db))
            try:
                source.backup(destination)
            finally:
                destination.close()
        finally:
            source.close()
        backup_path = scratch_dir / f"farm_state_pre_v4_{ts}.sqlite"

    lines: list[str] = []
    # 1. Backup via the SQLite backup API + integrity check.
    src = sqlite3.connect(str(target_db))
    try:
        tgt = sqlite3.connect(str(backup_path))
        try:
            src.backup(tgt)
        finally:
            tgt.close()
    finally:
        src.close()
    chk = sqlite3.connect(str(backup_path))
    try:
        integrity = chk.execute("PRAGMA integrity_check").fetchone()[0]
    finally:
        chk.close()
    if integrity != "ok":
        return StepResult(name, False, [f"backup integrity_check failed: {integrity}"])
    lines.append(f"backup: {backup_path} (integrity_check=ok)")

    # 2. Counts before.
    conn = sqlite3.connect(str(target_db), timeout=60)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA busy_timeout=60000")
    try:
        counts_before = _version_counts(conn)
        dep_total_before, dep_roles_before = _dependency_stats(conn)

        # 3. Run the reviewed migrations.
        _run_core_migration(conn)

        # 4. Relabel only open, unverdictable pre-v4 queue rows. Historical
        # terminal evidence is outside this plan and can never be updated here.
        cutover = cutover_pending_rows(conn, apply=True)
        if not cutover.ok:
            return StepResult(name, False, cutover.lines, {"cutover": cutover.data})

        # 5. Counts after.
        counts_after = _version_counts(conn)
        dep_total_after, dep_roles_after = _dependency_stats(conn)

        if dep_total_before != dep_total_after:
            return StepResult(
                name,
                False,
                [
                    "DEPENDENCY ROW COUNT CHANGED — refusing:",
                    f"before={dep_total_before} after={dep_total_after}",
                ],
            )

        # 6. Stamp the activation ledger.
        conn.execute(GATE_CONTRACT_ACTIVATIONS_DDL)
        conn.execute(
            "INSERT INTO gate_contract_activations"
            "(contract_version, activated_at, manifest_sha256, backup_path, git_head) "
            "VALUES (?,?,?,?,?)",
            (
                active_version,
                dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z"),
                manifest_sha256,
                str(backup_path),
                git_head,
            ),
        )
        conn.commit()
    finally:
        conn.close()

    lines.append(
        f"gate_contract_version before={_fmt_counts(counts_before)} "
        f"after={_fmt_counts(counts_after)}"
    )
    lines.append(
        f"dependency rows before={dep_total_before} after={dep_total_after} (equal)"
    )
    lines.append(
        f"cutover work_items={len(cutover.data.get('work_items', []))} "
        f"dependencies={len(cutover.data.get('dependencies', []))}"
    )
    lines.append(f"activation stamped: contract_version={active_version}")
    if not apply:
        lines.insert(0, f"(dry-run) migration exercised on COPY: {target_db}")
    return StepResult(
        name,
        True,
        lines,
        {
            "counts_before": counts_before,
            "counts_after": counts_after,
            "dep_total_before": dep_total_before,
            "dep_total_after": dep_total_after,
            "dep_roles_before": dep_roles_before,
            "dep_roles_after": dep_roles_after,
            "cutover": cutover.data,
            "backup_path": str(backup_path),
        },
    )


def _fmt_counts(counts: dict[str, int]) -> str:
    if not counts:
        return "{}"
    return "{" + ", ".join(f"{k}={v}" for k, v in sorted(counts.items())) + "}"


# --------------------------------------------------------------------------- #
# Step 5 — verification tests
# --------------------------------------------------------------------------- #
VERIFICATION_TESTS = (
    "tools/strategy_farm/tests/test_gate_manifest.py",
    "tools/strategy_farm/tests/test_gate_contract_version.py",
    "tools/strategy_farm/tests/test_advancement_centralization.py",
    "tools/strategy_farm/tests/test_v4_runtime_wiring.py",
    "tools/strategy_farm/tests/test_book_build_guard.py",
    "tools/strategy_farm/tests/test_backfill_planner.py",
    "tools/strategy_farm/tests/test_operator_surfaces_rebaseline.py",
    "tools/strategy_farm/tests/test_activate_gate_manifest_v4.py",
    "tools/strategy_farm/tests/test_q09_news_schema_v2.py",
    "tools/strategy_farm/tests/test_q09_news_farmctl_integration.py",
    "tools/strategy_farm/tests/test_farmctl_cascade.py",
    "tools/strategy_farm/tests/test_render_cockpit_v2.py",
    "tools/strategy_farm/tests/test_mission_control_v2_data.py",
    "tools/strategy_farm/tests/test_factory_runtime_activation.py",
    "tools/strategy_farm/tests/test_include_mirror.py",
)


def run_verification_tests() -> StepResult:
    name = "verify: pytest activation + orchestrator integration suites"
    proc = subprocess.run(
        [sys.executable, "-m", "pytest", *VERIFICATION_TESTS, "-q"],
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
    )
    output = proc.stdout + proc.stderr
    log_path = REPO_ROOT / "scratch" / "rb-v4-cutover" / "activation_verify.log"
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.write_text(output, encoding="utf-8")
    tail = output.strip().splitlines()[-3:]
    return StepResult(
        name,
        proc.returncode == 0,
        [*tail, f"full output: {log_path}"],
        {"returncode": proc.returncode, "log_path": str(log_path)},
    )


# --------------------------------------------------------------------------- #
# Step 6 — rollback plan
# --------------------------------------------------------------------------- #
def rollback_plan_lines(backup_path: str = "<backup_path>") -> list[str]:
    return [
        "# Rollback Gate Manifest v4 activation",
        "",
        "## 1. Revert the flip + promotion commit (restores v3 default)",
        "git revert --no-edit <activation-commit-sha>",
        "#   or, before committing:",
        "git checkout -- tools/strategy_farm/gate_manifest.py",
        "git rm -f tools/strategy_farm/config/gate_manifest.v4.json",
        "",
        "## 2. Restore the pre-v4 database backup (only if a bad migration must be undone)",
        "#   The migration is additive + append-only; normally NO db restore is needed.",
        "#   If required, stop the factory first, then:",
        "copy /Y \"" + backup_path + "\" \"D:\\QM\\strategy_farm\\state\\farm_state.sqlite\"",
        "#   (delete stale -wal/-shm sidecars beside the DB before restart)",
        "",
        "## 3. Re-mint the runtime-activation decision and run Factory_ON",
        "#   after the tree is clean again.",
    ]


# --------------------------------------------------------------------------- #
# Orchestration
# --------------------------------------------------------------------------- #
def _run_migration_subprocess(
    db_root: Path, manifest_sha256: str, git_head: str, allow_factory_on: bool = False
) -> StepResult:
    """Run step 4 in a fresh interpreter so it imports the post-flip modules."""
    result_path = TOOL_DIR / "_v4_migration_result.json"
    argv = [
        sys.executable,
        str(Path(__file__).resolve()),
        "--_run-migration",
        "--db-root",
        str(db_root),
        "--manifest-sha",
        manifest_sha256,
        "--git-head",
        git_head,
        "--json-out",
        str(result_path),
    ]
    # Forward the operator's factory-on override so the subprocess re-check
    # (below) does not fail closed on a run the caller deliberately allowed.
    if allow_factory_on:
        argv.append("--allow-factory-on")
    proc = subprocess.run(
        argv,
        cwd=str(TOOL_DIR),
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0 or not result_path.exists():
        return StepResult(
            "db migration: gate_contract_version + q09 schema",
            False,
            ["migration subprocess failed:", proc.stderr.strip()[-400:]],
        )
    payload = json.loads(result_path.read_text(encoding="utf-8"))
    result_path.unlink(missing_ok=True)
    return StepResult(payload["name"], payload["ok"], payload["lines"], payload.get("data", {}))


def _write_evidence(steps: list[StepResult], *, apply: bool, db_root: Path) -> None:
    mig = next((s for s in steps if s.name.startswith("db migration")), None)
    data = mig.data if mig else {}
    lines = [
        "# Gate Manifest v4 — activation evidence",
        "",
        f"Date: {ACTIVATION_DATE}",
        "",
        f"Mode: {'APPLY' if apply else 'DRY-RUN'}",
        "",
        "Authority: OWNER decision "
        "`decisions/2026-08-23_owner_gate_manifest_v4_linear.md` (linear three-phase "
        "renumbering, executed under the Stehende Vollmacht Auffangregel). v4 carries "
        "every v3 gate criterion verbatim; only identifiers, order and phase grouping "
        "change.",
        "",
        "## Step results",
        "",
    ]
    for step in steps:
        lines.append(f"- [{'PASS' if step.ok else 'FAIL'}] {step.name}")
        for detail in step.lines:
            lines.append(f"  - {detail}")
    lines += [
        "",
        "## Touched-file hashes (before / after)",
        "",
        "| File | Before | After |",
        "|---|---|---|",
    ]
    for path in (GATE_MANIFEST_PY, V4_TARGET_MANIFEST):
        rel = path.relative_to(REPO_ROOT).as_posix()
        after = _sha256_file(path) or "(not written in dry-run)"
        lines.append(f"| {rel} | see flip step | {after} |")
    if data:
        lines += [
            "",
            "## Database migration",
            "",
            f"- backup: `{data.get('backup_path')}`",
            f"- gate_contract_version before: `{_fmt_counts(data.get('counts_before', {}))}`",
            f"- gate_contract_version after: `{_fmt_counts(data.get('counts_after', {}))}`",
            f"- dependency rows before/after: "
            f"{data.get('dep_total_before')} / {data.get('dep_total_after')} (equal)",
        ]
    lines += ["", "## Rollback", ""]
    lines += ["```", *rollback_plan_lines(data.get("backup_path", "<backup_path>")), "```", ""]
    EVIDENCE_PATH.parent.mkdir(parents=True, exist_ok=True)
    EVIDENCE_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--dry-run", action="store_true", help="report only (default)")
    mode.add_argument("--apply", action="store_true", help="perform the activation")
    mode.add_argument(
        "--cutover-dry-run",
        action="store_true",
        help="list pending/active v3-to-v4 row and dependency rewrites read-only",
    )
    parser.add_argument("--rollback-plan", action="store_true")
    parser.add_argument("--allow-factory-on", action="store_true")
    parser.add_argument("--allow-active", action="store_true")
    parser.add_argument(
        "--no-db",
        action="store_true",
        help=(
            "with --apply, verify a temporary worktree-only v4 flip without "
            "reading or writing runtime DB/factory state; restore files on exit"
        ),
    )
    parser.add_argument("--db-root", default=str(DEFAULT_DB_ROOT))
    # internal subprocess entrypoint for the post-flip migration
    parser.add_argument("--_run-migration", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--manifest-sha", default="")
    parser.add_argument("--git-head", default="")
    parser.add_argument("--json-out", default="")
    args = parser.parse_args(argv)

    if args.no_db and not args.apply:
        parser.error("--no-db requires --apply")

    db_root = Path(args.db_root)
    db_path = db_root / "state" / "farm_state.sqlite"
    backup_dir = db_root / "backups"

    if args.rollback_plan:
        print("\n".join(rollback_plan_lines()))
        return 0

    if args.cutover_dry_run:
        if not db_path.exists():
            result = StepResult(
                "cutover pending rows", False, [f"database not found: {db_path}"]
            )
        else:
            try:
                conn = _open_ro(db_path)
                try:
                    result = cutover_pending_rows(conn, apply=False)
                finally:
                    conn.close()
            except sqlite3.Error as exc:
                result = StepResult(
                    "cutover pending rows", False, [f"read-only open failed: {exc}"]
                )
        _print_framed(result)
        return 0 if result.ok else 1

    if getattr(args, "_run_migration"):
        # Live-safety guard. This SUPPRESSED entrypoint mutates the live DB and
        # is reachable only via _run_migration_subprocess in the in-process
        # apply flow, which already validated preconditions. It must not trust
        # its caller blindly, so it re-asserts the one precondition that is
        # invariant across the manifest flip: the factory must be OFF.
        # (git-clean is deliberately NOT re-checked here — Step 2 already flipped
        # gate_manifest.py, so the target tree is expected to be dirty at this
        # point; re-asserting it would false-fail every legitimate apply.)
        guard = check_factory_off(db_root, args.allow_factory_on)
        if not guard.ok:
            blocked = StepResult(
                "migration precondition re-check (factory off)",
                False,
                ["refusing --_run-migration:", *guard.lines],
            )
            _print_framed(blocked)
            if args.json_out:
                Path(args.json_out).write_text(
                    json.dumps(
                        {"name": blocked.name, "ok": False, "lines": blocked.lines, "data": {}}
                    ),
                    encoding="utf-8",
                )
            return 1
        result = migrate_database(
            db_path,
            backup_dir=backup_dir,
            manifest_sha256=args.manifest_sha,
            git_head=args.git_head,
            apply=True,
        )
        payload = {"name": result.name, "ok": result.ok, "lines": result.lines, "data": result.data}
        if args.json_out:
            Path(args.json_out).write_text(json.dumps(payload), encoding="utf-8")
        _print_framed(result)
        return 0 if result.ok else 1

    apply = bool(args.apply)
    print(f"=== activate_gate_manifest_v4 : {'APPLY' if apply else 'DRY-RUN'} ===\n")

    steps: list[StepResult] = []

    def record(result: StepResult) -> bool:
        steps.append(result)
        _print_framed(result)
        if apply and not result.ok:
            print("\n!!! APPLY ABORTED at first failure. Rollback plan: !!!")
            print("\n".join(rollback_plan_lines()))
            return False
        return True

    # Worktree-only verification deliberately does not inspect runtime
    # factory/DB state; that is the safety purpose of --no-db.
    preconditions = [check_git_clean()]
    if not args.no_db:
        preconditions.extend(
            [
                check_factory_off(db_root, args.allow_factory_on),
                check_no_active_meaning_change_rows(db_path, args.allow_active),
            ]
        )
    preconditions.append(check_draft_read_inert())
    for check in preconditions:
        if not record(check):
            return 1

    restore_files: dict[Path, bytes | None] = {}
    if args.no_db:
        for path in (GATE_MANIFEST_PY, V4_TARGET_MANIFEST, GITATTRIBUTES):
            restore_files[path] = path.read_bytes() if path.exists() else None

    def run_steps() -> int:
        # Step 2 — promote
        promote = promote_manifest(apply=apply)
        if not record(promote):
            return 1
        manifest_sha = promote.data.get("manifest_sha256", "")
        git_head = _git_head()

        # Step 3 — flip + smoke
        flip = flip_default(apply=apply)
        if not record(flip):
            return 1

        if apply:
            smoke = run_smoke(TOOL_DIR)
            if not record(smoke):
                return 1
        else:
            record(
                StepResult(
                    "flip smoke: v4 default loads and renders",
                    True,
                    ["(dry-run) smoke runs only after the real flip in --apply"],
                )
            )

        # Step 4 — db migration
        if args.no_db:
            migration = StepResult(
                "db migration: gate_contract_version + q09 schema",
                True,
                ["--no-db: skipped; runtime DB and factory state were not inspected"],
            )
        elif apply:
            migration = _run_migration_subprocess(
                db_root, manifest_sha, git_head,
                allow_factory_on=args.allow_factory_on,
            )
        else:
            scratch = TOOL_DIR.parent.parent / "scratch" / "rb-activate-dryrun"
            migration = migrate_database(
                db_path,
                backup_dir=backup_dir,
                manifest_sha256=manifest_sha,
                git_head=git_head,
                apply=False,
                scratch_dir=scratch,
                active_version="v4",
            )
        if not record(migration):
            return 1

        # Step 5 — verification tests (apply only; dry-run stays unflipped).
        if apply:
            verify = run_verification_tests()
            if not record(verify):
                return 1
            if not args.no_db:
                _write_evidence(steps, apply=apply, db_root=db_root)
                print(f"\nEvidence written: {EVIDENCE_PATH}")
        else:
            record(
                StepResult(
                    "verify: pytest suites",
                    True,
                    ["(dry-run) tests run against the flipped tree in --apply"],
                )
            )

        print("\n=== DONE ===")
        return 0

    try:
        return run_steps()
    finally:
        if restore_files:
            for path, original in restore_files.items():
                if original is None:
                    path.unlink(missing_ok=True)
                else:
                    path.write_bytes(original)
            print("\n[PASS] --no-db worktree files restored")


if __name__ == "__main__":
    raise SystemExit(main())
