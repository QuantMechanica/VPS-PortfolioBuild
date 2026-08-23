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
import shutil
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
    name = "precondition: no active work_items in meaning-changing phases"
    if not db_path.exists():
        return StepResult(name, True, [f"database absent (fresh init): {db_path}"])
    try:
        conn = _open_ro(db_path)
    except sqlite3.Error as exc:
        return StepResult(name, False, [f"cannot open db read-only: {exc}"])
    try:
        placeholders = ",".join("?" for _ in MEANING_CHANGE_PHASES)
        states = ",".join("?" for _ in ACTIVE_WORK_ITEM_STATES)
        rows = conn.execute(
            f"SELECT phase, COUNT(*) AS n FROM work_items "
            f"WHERE phase IN ({placeholders}) AND status IN ({states}) "
            f"GROUP BY phase ORDER BY phase",
            (*MEANING_CHANGE_PHASES, *ACTIVE_WORK_ITEM_STATES),
        ).fetchall()
    except sqlite3.Error as exc:
        conn.close()
        return StepResult(name, False, [f"query failed: {exc}"])
    finally:
        try:
            conn.close()
        except sqlite3.Error:
            pass
    active = {row["phase"]: row["n"] for row in rows}
    total = sum(active.values())
    if total == 0:
        return StepResult(name, True, ["0 active rows in meaning-changing phases"])
    detail = [f"{phase}: {n}" for phase, n in active.items()]
    if allow_active:
        return StepResult(
            name,
            True,
            ["--allow-active passed; proceeding despite active rows:", *detail],
        )
    return StepResult(
        name,
        False,
        [
            f"{total} active rows in meaning-changing phases; "
            "drain or pass --allow-active:",
            *detail,
        ],
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
        # Copy the live DB (plus WAL/SHM if present) into the scratch sandbox.
        shutil.copy2(db_path, target_db)
        for suffix in ("-wal", "-shm"):
            side = db_path.with_name(db_path.name + suffix)
            if side.exists():
                shutil.copy2(side, target_db.with_name(target_db.name + suffix))
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

        # 4. Counts after.
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

        # 5. Stamp the activation ledger.
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
    "tools/strategy_farm/tests/test_book_build_guard.py",
    "tools/strategy_farm/tests/test_q09_news_schema_v2.py",
)


def run_verification_tests() -> StepResult:
    name = "verify: pytest gate/contract/advancement/book/q09 suites"
    proc = subprocess.run(
        [sys.executable, "-m", "pytest", *VERIFICATION_TESTS, "-q"],
        cwd=str(REPO_ROOT),
        capture_output=True,
        text=True,
    )
    tail = (proc.stdout + proc.stderr).strip().splitlines()[-3:]
    return StepResult(name, proc.returncode == 0, tail, {"returncode": proc.returncode})


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
    db_root: Path, manifest_sha256: str, git_head: str
) -> StepResult:
    """Run step 4 in a fresh interpreter so it imports the post-flip modules."""
    result_path = TOOL_DIR / "_v4_migration_result.json"
    proc = subprocess.run(
        [
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
        ],
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
    parser.add_argument("--rollback-plan", action="store_true")
    parser.add_argument("--allow-factory-on", action="store_true")
    parser.add_argument("--allow-active", action="store_true")
    parser.add_argument("--db-root", default=str(DEFAULT_DB_ROOT))
    # internal subprocess entrypoint for the post-flip migration
    parser.add_argument("--_run-migration", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--manifest-sha", default="")
    parser.add_argument("--git-head", default="")
    parser.add_argument("--json-out", default="")
    args = parser.parse_args(argv)

    db_root = Path(args.db_root)
    db_path = db_root / "state" / "farm_state.sqlite"
    backup_dir = db_root / "backups"

    if args.rollback_plan:
        print("\n".join(rollback_plan_lines()))
        return 0

    if getattr(args, "_run_migration"):
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

    # Step 1 — preconditions
    for check in (
        check_git_clean(),
        check_factory_off(db_root, args.allow_factory_on),
        check_no_active_meaning_change_rows(db_path, args.allow_active),
        check_draft_read_inert(),
    ):
        if not record(check):
            return 1

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
    if apply:
        migration = _run_migration_subprocess(db_root, manifest_sha, git_head)
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

    # Step 5 — verification tests (apply only; dry-run leaves the tree unflipped)
    if apply:
        verify = run_verification_tests()
        if not record(verify):
            return 1
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


if __name__ == "__main__":
    raise SystemExit(main())
