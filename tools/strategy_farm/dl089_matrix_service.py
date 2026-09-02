"""Governed executor for declared DL-089 Q12 pattern matrices.

Generic terminal workers execute one setfile.  A Q12 row carrying
``dl089-annual-wf-cells-v1`` instead declares 1,085 annual cells plus four
sealed walk-forward combination cells, so it must be expanded by this service
before any terminal work is claimable.  The service is append-only:

* invalid single-run Q12 receipts are preserved and receive new deterministic
  successor rows;
* each declared cell becomes its own OPT_CENSUS work item/evidence receipt;
* the approved ``_opt`` sibling supplies executable identity, while cell keys
  and UUIDs remain exactly those sealed against the incumbent declaration;
* the first bounded set of programs in canonical queue order is maintained,
  each with its own eight-cell rolling priority window;
* Q12 is completed only from the sealed matrix/WF evidence, never from a
  generic smoke summary.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import re
import sqlite3
import uuid
from pathlib import Path
from typing import Any, Iterable, Mapping

try:
    import dl089_scheduling as scheduling
    import opt_census as census
    import opt_census_pruning as pruning
    import opt_census_select as selector
    from optimization_fork_driver import (
        PATTERN_DECLARATION_REVISION,
        _pattern_measurement_readiness,
    )
except ModuleNotFoundError:
    from tools.strategy_farm import dl089_scheduling as scheduling
    from tools.strategy_farm import opt_census as census
    from tools.strategy_farm import opt_census_pruning as pruning
    from tools.strategy_farm import opt_census_select as selector
    from tools.strategy_farm.optimization_fork_driver import (
        PATTERN_DECLARATION_REVISION,
        _pattern_measurement_readiness,
    )


SERVICE_SCHEMA = "qm.dl089-matrix-service/v1"
RUNNER_SCHEMA = "qm.dl089-matrix-runner/v1"
RUNNER_REVISION = "dl089-matrix-runner-v2"
RECOVERY_NAMESPACE = uuid.UUID("02796ca2-5be9-4e78-8fa8-53a4048b3e42")
Q02_NAMESPACE = uuid.UUID("d4ee1e63-76ea-4db9-96aa-0927bec724d8")
DEFAULT_ARTIFACT_ROOT = Path(r"D:\QM\strategy_farm\artifacts\opt_census")
MISMATCH_HOLD_CODE = "Q12_DL089_RUNNER_MISMATCH_GUARD"
ROLLOUT_HOLD_CODE = "Q12_DL089_MATRIX_WORKER_ROLLOUT_PENDING"
SUPERSEDED_Q02_HOLD_CODE = "Q02_DL089_SUPERSEDED_SETFILE_BINDING"
ALLOWED_SERVICE_HOLDS = frozenset({MISMATCH_HOLD_CODE, ROLLOUT_HOLD_CODE})
RECOVERY_SOURCE_ENCODING = "append_only:dl089-invalid-single-run-successor/v1"
Q02_FROM_YEAR = 2017
Q02_TO_YEAR = 2022
program_slots = scheduling.program_slots

# OWNER-DEC-SIBLING-REBIND-20260829 preserved the legacy bound setfiles and
# compiled these two measurement siblings from fresh append-only ceremony
# setfiles. Matrix materialization must follow that compiled setfile lineage;
# selecting the legacy default silently restores QM5_41195's obsolete slot 1.
DL089_SIBLING_REBIND_SETFILE_DIRECTORIES = {
    "QM5_41195_aa-vol-sma10-opt": "sibling_rebind_6b66b181_r2",
    "QM5_41196_qs-kama-trend-xau-opt": "sibling_rebind_e8ed1e85",
}

_ROUTING_PAYLOAD_KEYS = (
    "schema",
    "role",
    "phase",
    "gate_contract_version",
    "gate_manifest_sha256",
    "parent_work_item_id",
    "parent_phase",
    "parent_verdict",
    "parent_bindings",
    "expected_ex5_sha256",
    "expected_mq5_sha256",
    "expected_setfile_sha256",
    "expected_symbol",
    "dl089_contract",
    "numeric_parameter_sweep",
    "activation_state",
    "machine_reason",
    "fixture_harness",
    "routing_revision",
    "pattern_filter_sweep",
)


class MatrixServiceError(RuntimeError):
    """A DL-089 row cannot be safely serviced."""


def _measurement_source_base_setfile(
    ea_dir: Path, label: str, symbol: str, timeframe: str
) -> Path:
    filename = f"{label}_{symbol}_{timeframe}_backtest.set"
    rebind_directory = DL089_SIBLING_REBIND_SETFILE_DIRECTORIES.get(label)
    if rebind_directory is not None:
        return ea_dir / "sets" / rebind_directory / filename
    return ea_dir / "sets" / filename


def _now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def _canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        + "\n"
    ).encode("utf-8")


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _binding(path: Path) -> dict[str, Any]:
    resolved = path.resolve()
    if not resolved.is_file():
        raise MatrixServiceError(f"bound file missing: {resolved}")
    return {
        "path": str(resolved),
        "sha256": _sha256_file(resolved),
        "size_bytes": resolved.stat().st_size,
    }


def _content_binding(path: Path, content: str) -> dict[str, Any]:
    data = content.encode("utf-8")
    return {
        "path": str(path.resolve()),
        "sha256": _sha256_bytes(data),
        "size_bytes": len(data),
    }


def _neutral_matrix_setfile(source: Path, ea_id: str) -> str:
    """Bind all pattern levers to neutral values without editing an EA set."""

    text = source.read_text(encoding="utf-8-sig")
    values: dict[str, str] = {}
    counts: dict[str, int] = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(";") or "=" not in stripped:
            continue
        key, value = stripped.split("=", 1)
        key = key.strip()
        values[key] = value.strip()
        counts[key] = counts.get(key, 0) + 1
    required = {"qm_ea_id", "RISK_FIXED", "RISK_PERCENT"}
    missing = sorted(required - values.keys())
    if missing:
        raise MatrixServiceError(f"source base setfile missing inputs: {', '.join(missing)}")
    if values["qm_ea_id"] != ea_id.removeprefix("QM5_"):
        raise MatrixServiceError(f"source base setfile qm_ea_id does not match {ea_id}")
    try:
        risk_fixed = float(values["RISK_FIXED"])
        risk_percent = float(values["RISK_PERCENT"])
        news_stale = (
            None
            if "qm_news_stale_max_hours" not in values
            else float(values["qm_news_stale_max_hours"])
        )
    except ValueError as exc:
        raise MatrixServiceError("source base setfile risk/news values are not numeric") from exc
    if risk_fixed <= 0 or risk_percent != 0:
        raise MatrixServiceError("OPT_CENSUS requires RISK_FIXED > 0 and RISK_PERCENT = 0")
    if news_stale is not None and news_stale > 336:
        raise MatrixServiceError("qm_news_stale_max_hours must not exceed 336")
    if "; environment:" not in text.lower() or "backtest" not in text.lower():
        raise MatrixServiceError("source base setfile must declare environment: backtest")
    duplicates = sorted(key for key in census.SET_KEYS if counts.get(key, 0) > 1)
    if duplicates:
        raise MatrixServiceError(
            "source base setfile has duplicate pattern inputs: " + ", ".join(duplicates)
        )

    output: list[str] = []
    seen: set[str] = set()
    for line in text.splitlines():
        stripped = line.strip()
        key = stripped.split("=", 1)[0].strip() if "=" in stripped else ""
        if key in census.SET_KEYS:
            output.append(f"{key}=0")
            seen.add(key)
        else:
            output.append(line)
    if output and output[-1].strip():
        output.append("")
    output.append("; DL-089 governed neutral pattern bindings")
    for key in census.SET_KEYS:
        if key not in seen:
            output.append(f"{key}=0")
    return "\n".join(output).rstrip() + "\n"


def _payload(row: sqlite3.Row | Mapping[str, Any]) -> dict[str, Any]:
    try:
        value = json.loads(str(row["payload_json"] or "{}"))
    except (TypeError, json.JSONDecodeError) as exc:
        raise MatrixServiceError(f"work item {row['id']} payload is invalid") from exc
    if not isinstance(value, dict):
        raise MatrixServiceError(f"work item {row['id']} payload is not an object")
    return value


def _is_dl089_pattern(row: sqlite3.Row, payload: Mapping[str, Any]) -> bool:
    return (
        str(row["phase"]).upper() == "Q12"
        and str(payload.get("role") or "").upper() == "PATTERN"
        and payload.get("routing_revision") == PATTERN_DECLARATION_REVISION
        and isinstance(payload.get("pattern_filter_sweep"), Mapping)
    )


def _parse_card(path: Path) -> dict[str, Any]:
    text = path.read_text(encoding="utf-8-sig")
    if not text.startswith("---"):
        raise MatrixServiceError(f"strategy card has no frontmatter: {path}")
    try:
        block = text.split("---", 2)[1]
    except IndexError as exc:
        raise MatrixServiceError(f"strategy card frontmatter is incomplete: {path}") from exc
    result: dict[str, Any] = {}
    for line in block.splitlines():
        if not line.strip() or line.lstrip().startswith("#") or ":" not in line:
            continue
        key, raw = line.split(":", 1)
        value = raw.strip().strip('"').strip("'")
        if value.startswith("[") and value.endswith("]"):
            result[key.strip()] = [
                token.strip().strip('"').strip("'")
                for token in value[1:-1].split(",")
                if token.strip()
            ]
        else:
            result[key.strip()] = value
    return result


def _measurement_sibling(
    repo_root: Path,
    subject_ea_id: str,
    symbol: str,
    *,
    artifact_root: Path,
    program_id: str,
    apply: bool,
) -> dict[str, Any]:
    matches: list[dict[str, Any]] = []
    eas_root = repo_root / "framework" / "EAs"
    for card in eas_root.glob("QM5_*_*-opt/docs/strategy_card.md"):
        try:
            frontmatter = _parse_card(card)
        except (OSError, MatrixServiceError):
            # A legacy or unrelated sibling card must not prevent discovery of
            # the uniquely matching governed measurement EA.  The selected
            # card below is still required to parse and carry explicit approval.
            continue
        if str(frontmatter.get("parent_ea_id") or "").upper() != subject_ea_id.upper():
            continue
        targets = {str(value).upper() for value in frontmatter.get("target_symbols", [])}
        if symbol.upper() not in targets:
            continue
        if str(frontmatter.get("g0_status") or "").upper() != "APPROVED":
            continue
        ea_id = str(frontmatter.get("ea_id") or "").upper()
        timeframe = str(frontmatter.get("period") or "").upper()
        ea_dir = card.parent.parent
        label = ea_dir.name
        source_base_setfile = _measurement_source_base_setfile(
            ea_dir, label, symbol, timeframe
        )
        matches.append(
            {
                "ea_id": ea_id,
                "ea_label": label,
                "timeframe": timeframe,
                "card_path": str(card.resolve()),
                "ea_dir": ea_dir.resolve(),
                "source": ea_dir / f"{label}.mq5",
                "binary": ea_dir / f"{label}.ex5",
                "source_base_setfile": source_base_setfile,
            }
        )
    if len(matches) != 1:
        raise MatrixServiceError(
            f"expected one approved _opt sibling for {subject_ea_id}/{symbol}, found {len(matches)}"
        )
    sibling = matches[0]
    if not re.fullmatch(r"QM5_\d+", sibling["ea_id"]):
        raise MatrixServiceError("measurement sibling EA id is invalid")
    if not sibling["timeframe"]:
        raise MatrixServiceError("measurement sibling timeframe is missing")
    for key in ("source", "binary", "source_base_setfile"):
        if not Path(sibling[key]).is_file():
            raise MatrixServiceError(f"measurement sibling {key} missing: {sibling[key]}")
    neutral_setfile = _neutral_matrix_setfile(
        Path(sibling["source_base_setfile"]), str(sibling["ea_id"])
    )
    neutral_sha = _sha256_bytes(neutral_setfile.encode("utf-8"))
    base_setfile = (
        artifact_root
        / program_id
        / "base_setfiles"
        / f"{sibling['ea_label']}_{symbol}_{sibling['timeframe']}_{neutral_sha[:16]}.set"
    )
    if apply:
        census._atomic_write(base_setfile, neutral_setfile)
        census.validate_base_setfile(base_setfile, sibling["ea_id"])
    sibling["base_setfile"] = base_setfile.resolve()
    readiness = _pattern_measurement_readiness(
        {
            "source": {"path": str(sibling["source"])},
            "setfile": {"path": str(base_setfile), "text": neutral_setfile},
        }
    )
    if readiness.get("ready") is not True:
        raise MatrixServiceError(
            "measurement sibling is not ready: " + ",".join(readiness.get("blockers", []))
        )
    sibling["readiness"] = readiness
    sibling["bindings"] = {
        "source": _binding(Path(sibling["source"])),
        "binary": _binding(Path(sibling["binary"])),
        "setfile": _content_binding(base_setfile, neutral_setfile),
        "card": _binding(Path(sibling["card_path"])),
    }
    return sibling


def _compile_receipt(conn: sqlite3.Connection, sibling: Mapping[str, Any]) -> dict[str, Any]:
    row = conn.execute(
        """
        SELECT id,status,verdict,evidence_path,ex5_sha256,mq5_sha256,updated_at
        FROM work_items
        WHERE ea_id=? AND upper(phase)='COMPILE_EA'
          AND lower(status)='done' AND upper(coalesce(verdict,''))='COMPILE_OK'
        ORDER BY updated_at DESC,id DESC LIMIT 1
        """,
        (sibling["ea_id"],),
    ).fetchone()
    if row is None:
        raise MatrixServiceError(f"no COMPILE_OK receipt for {sibling['ea_id']}")
    if str(row["ex5_sha256"] or "").lower() != sibling["bindings"]["binary"]["sha256"]:
        raise MatrixServiceError(f"COMPILE_OK binary hash drift for {sibling['ea_id']}")
    if str(row["mq5_sha256"] or "").lower() != sibling["bindings"]["source"]["sha256"]:
        raise MatrixServiceError(f"COMPILE_OK source hash drift for {sibling['ea_id']}")
    evidence = _binding(Path(str(row["evidence_path"] or "")))
    return {
        "work_item_id": row["id"],
        "updated_at": row["updated_at"],
        "evidence": evidence,
        "ex5_sha256": row["ex5_sha256"],
        "mq5_sha256": row["mq5_sha256"],
    }


def _active_hold(conn: sqlite3.Connection, work_item_id: str) -> sqlite3.Row | None:
    return conn.execute(
        "SELECT * FROM work_item_holds WHERE work_item_id=? AND active=1",
        (work_item_id,),
    ).fetchone()


def _ensure_rollout_hold(
    conn: sqlite3.Connection, work_item_id: str, *, apply: bool
) -> dict[str, Any]:
    existing = conn.execute(
        "SELECT * FROM work_item_holds WHERE work_item_id=?", (work_item_id,)
    ).fetchone()
    if not apply:
        return {
            "work_item_id": work_item_id,
            "existing_hold": None if existing is None else existing["hold_code"],
            "would_install_or_convert_release_on_restart": True,
        }
    if existing is not None and int(existing["active"] or 0) == 0:
        # The governed worker restart already loaded the permanent claim guard
        # and released this transitional hold.  Never resurrect it on a later
        # pump cycle.
        return {
            "work_item_id": work_item_id,
            "hold_code": str(existing["hold_code"]),
            "active": False,
            "release_on_restart": bool(existing["release_on_restart"]),
            "restart_release_preserved": True,
        }
    now = _now()
    reason = (
        "DL-089 matrix service is installed on disk; keep old resident generic workers "
        "excluded until the governed worker restart loads the routing guard"
    )
    if existing is None:
        conn.execute(
            """
            INSERT INTO work_item_holds(
              work_item_id,hold_code,reason,active,release_on_restart,created_at,updated_at
            ) VALUES(?,?,?,1,1,?,?)
            """,
            (work_item_id, ROLLOUT_HOLD_CODE, reason, now, now),
        )
        code = ROLLOUT_HOLD_CODE
    else:
        # work_item_holds is keyed by work_item_id (one durable slot).  Preserve
        # the original mismatch code for audit, but convert it to the standard
        # safe release-on-restart lifecycle rather than deleting its history.
        conn.execute(
            """
            UPDATE work_item_holds
            SET reason=?,active=1,release_on_restart=1,updated_at=?,
                released_at=NULL,release_note=NULL
            WHERE work_item_id=?
            """,
            (reason, now, work_item_id),
        )
        code = str(existing["hold_code"])
    return {
        "work_item_id": work_item_id,
        "hold_code": code,
        "active": True,
        "release_on_restart": True,
    }


def _successor_payload(source_payload: Mapping[str, Any], source_row: sqlite3.Row) -> dict[str, Any]:
    payload = {
        key: json.loads(json.dumps(source_payload[key]))
        for key in _ROUTING_PAYLOAD_KEYS
        if key in source_payload
    }
    payload["execution_lane"] = "DL089_MATRIX_RUNNER"
    payload["matrix_runner"] = {
        "schema": RUNNER_SCHEMA,
        "revision": RUNNER_REVISION,
        "recovery_of_work_item_id": str(source_row["id"]),
        "source_receipt_preserved": True,
        "source_verdict_disposition_authority": "OWNER_ONLY",
        "pair_mode": "BOUNDED_PROGRAMS",
        "program_slots": program_slots(),
        "priority_window_cap": 8,
    }
    payload["queue_order_at"] = str(source_row["created_at"])
    payload["routing_identity_sha256"] = _sha256_bytes(_canonical_bytes(payload))
    return payload


def append_recovery_successor(
    conn: sqlite3.Connection,
    *,
    source_work_item_id: str,
    evidence_path: Path,
    apply: bool,
) -> dict[str, Any]:
    source = conn.execute("SELECT * FROM work_items WHERE id=?", (source_work_item_id,)).fetchone()
    if source is None:
        raise MatrixServiceError(f"recovery source row missing: {source_work_item_id}")
    payload = _payload(source)
    if not _is_dl089_pattern(source, payload):
        raise MatrixServiceError(f"recovery source is not a declared DL-089 Q12 row: {source_work_item_id}")
    if str(source["status"]).lower() != "done" or str(source["verdict"] or "").upper() != "PASS":
        raise MatrixServiceError(f"recovery source is not the invalid done/PASS shape: {source_work_item_id}")
    if payload.get("evidence_provenance") != "real_mt5":
        raise MatrixServiceError(f"recovery source lacks generic real_mt5 provenance: {source_work_item_id}")
    declaration = payload["pattern_filter_sweep"]
    cell_ids = [str(cell["work_item_id"]) for cell in declaration.get("annual_cells", [])]
    materialized = 0
    for offset in range(0, len(cell_ids), 400):
        batch = cell_ids[offset : offset + 400]
        if not batch:
            continue
        marks = ",".join("?" for _ in batch)
        materialized += int(
            conn.execute(
                f"SELECT COUNT(*) FROM work_items WHERE id IN ({marks})", batch
            ).fetchone()[0]
        )
    if materialized:
        raise MatrixServiceError(
            f"recovery source already has {materialized} materialized declared cells"
        )
    successor_id = str(
        uuid.uuid5(RECOVERY_NAMESPACE, f"{source_work_item_id}:{RUNNER_REVISION}")
    )
    successor_payload = _successor_payload(payload, source)
    existing = conn.execute("SELECT * FROM work_items WHERE id=?", (successor_id,)).fetchone()
    if existing is not None:
        if str(existing["payload_json"]) != json.dumps(successor_payload, sort_keys=True):
            raise MatrixServiceError(f"recovery successor UUID collision: {successor_id}")
        return {
            "created": False,
            "idempotent": True,
            "source_work_item_id": source_work_item_id,
            "successor_work_item_id": successor_id,
        }
    if apply:
        now = _now()
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at,
              gate_contract_version,ex5_sha256,setfile_sha256,mq5_sha256
            ) VALUES(?,?,?,?,?,?,'pending',NULL,0,NULL,NULL,NULL,?,?,?,?,?,?,?)
            """,
            (
                successor_id,
                "analytic",
                source["phase"],
                source["ea_id"],
                source["symbol"],
                source["setfile_path"],
                json.dumps(successor_payload, sort_keys=True),
                now,
                now,
                source["gate_contract_version"],
                source["ex5_sha256"],
                source["setfile_sha256"],
                source["mq5_sha256"],
            ),
        )
        _ensure_rollout_hold(conn, successor_id, apply=True)
    return {
        "created": bool(apply),
        "idempotent": False,
        "source_work_item_id": source_work_item_id,
        "successor_work_item_id": successor_id,
        "declaration_sha256": declaration.get("declaration_sha256"),
        "evidence_path": str(evidence_path.resolve()),
        "source_encoding": RECOVERY_SOURCE_ENCODING,
    }


def _latest_q02(
    conn: sqlite3.Connection, ea_id: str, symbol: str
) -> sqlite3.Row | None:
    return conn.execute(
        """
        SELECT * FROM work_items
        WHERE ea_id=? AND upper(symbol)=upper(?) AND upper(phase) IN ('Q02','P2')
        ORDER BY created_at DESC,id DESC LIMIT 1
        """,
        (ea_id, symbol),
    ).fetchone()


def _q02_matches_measurement_bindings(
    row: sqlite3.Row, sibling: Mapping[str, Any]
) -> bool:
    bindings = sibling["bindings"]
    if Path(str(row["setfile_path"] or "")).resolve() != Path(
        sibling["base_setfile"]
    ).resolve():
        return False
    for column, binding in (
        ("ex5_sha256", bindings["binary"]),
        ("mq5_sha256", bindings["source"]),
        ("setfile_sha256", bindings["setfile"]),
    ):
        value = str(row[column] or "").lower()
        if value and value != str(binding["sha256"]).lower():
            return False
    return True


def _hold_superseded_pending_q02(
    conn: sqlite3.Connection, row: sqlite3.Row, *, apply: bool
) -> None:
    if (
        str(row["status"]).lower() != "pending"
        or row["verdict"] is not None
        or row["claimed_by"] is not None
    ):
        raise MatrixServiceError(
            f"stale-binding Q02 is not safely holdable: {row['id']} "
            f"{row['status']}/{row['verdict']} claimed_by={row['claimed_by']}"
        )
    existing = conn.execute(
        "SELECT hold_code,active FROM work_item_holds WHERE work_item_id=?",
        (row["id"],),
    ).fetchone()
    if existing is not None:
        if str(existing["hold_code"]) != SUPERSEDED_Q02_HOLD_CODE or not int(
            existing["active"] or 0
        ):
            raise MatrixServiceError(
                f"stale-binding Q02 has incompatible hold: {row['id']}"
            )
        return
    if apply:
        now = _now()
        conn.execute(
            """
            INSERT INTO work_item_holds(
              work_item_id,hold_code,reason,active,release_on_restart,created_at,updated_at
            ) VALUES(?,?,?,1,0,?,?)
            """,
            (
                row["id"],
                SUPERSEDED_Q02_HOLD_CODE,
                "DL-089 measurement setfile lineage changed; preserve this unclaimed row and use a fresh identity-bound successor",
                now,
                now,
            ),
        )


def _seed_q02(
    conn: sqlite3.Connection,
    *,
    q12_row: sqlite3.Row,
    sibling: Mapping[str, Any],
    compile_receipt: Mapping[str, Any],
    apply: bool,
) -> dict[str, Any]:
    existing = _latest_q02(conn, str(sibling["ea_id"]), str(q12_row["symbol"]))
    superseded_work_item_id = None
    if existing is not None and _q02_matches_measurement_bindings(existing, sibling):
        return {
            "created": False,
            "work_item_id": existing["id"],
            "status": existing["status"],
            "verdict": existing["verdict"],
        }
    if existing is not None and str(existing["status"]).lower() == "pending":
        _hold_superseded_pending_q02(conn, existing, apply=apply)
        superseded_work_item_id = str(existing["id"])
    bindings = sibling["bindings"]
    seed = (
        f"{RUNNER_REVISION}:{sibling['ea_id']}:{q12_row['symbol']}:"
        f"{bindings['binary']['sha256']}:{bindings['setfile']['sha256']}"
    )
    work_item_id = str(uuid.uuid5(Q02_NAMESPACE, seed))
    payload = {
        "schema": "qm.dl089-measurement-q02-prerequisite/v1",
        "matrix_runner_revision": RUNNER_REVISION,
        "q12_work_item_id": q12_row["id"],
        "subject_ea_id": q12_row["ea_id"],
        "compile_work_item_id": compile_receipt["work_item_id"],
        "compile_evidence_sha256": compile_receipt["evidence"]["sha256"],
        "from_year": Q02_FROM_YEAR,
        "to_year": Q02_TO_YEAR,
        "requested_from_year": Q02_FROM_YEAR,
        "requested_to_year": Q02_TO_YEAR,
        "expected_current_ex5_sha256": bindings["binary"]["sha256"],
        "expected_ex5_sha256": bindings["binary"]["sha256"],
        "expected_mq5_sha256": bindings["source"]["sha256"],
        "expected_setfile_sha256": bindings["setfile"]["sha256"],
        "expected_symbol": q12_row["symbol"],
        "expected_period": sibling["timeframe"],
        "expected_expert": f"QM\\{sibling['ea_label']}",
        "ea_dir_name": sibling["ea_label"],
        "priority_track": True,
        "priority_reason": "OWNER_P0_DL089_MATRIX_PREREQUISITE",
        "target_symbols": [q12_row["symbol"]],
        "target_timeframe": sibling["timeframe"],
    }
    if apply:
        now = _now()
        conn.execute(
            """
            INSERT INTO work_items(
              id,kind,phase,ea_id,symbol,setfile_path,status,verdict,attempt_count,
              parent_task_id,evidence_path,claimed_by,payload_json,created_at,updated_at,
              gate_contract_version,ex5_sha256,setfile_sha256,mq5_sha256
            ) VALUES(?,'backtest','Q02',?,?,?,'pending',NULL,0,NULL,NULL,NULL,?,?,?,?,?,?,?)
            """,
            (
                work_item_id,
                sibling["ea_id"],
                q12_row["symbol"],
                str(sibling["base_setfile"]),
                json.dumps(payload, sort_keys=True),
                now,
                now,
                q12_row["gate_contract_version"],
                bindings["binary"]["sha256"],
                bindings["setfile"]["sha256"],
                bindings["source"]["sha256"],
            ),
        )
    return {
        "created": bool(apply),
        "work_item_id": work_item_id,
        "status": "pending",
        "verdict": None,
        "superseded_work_item_id": superseded_work_item_id,
    }


def _queue_order(row: sqlite3.Row, payload: Mapping[str, Any]) -> tuple[str, str]:
    return (str(payload.get("queue_order_at") or row["created_at"]), str(row["id"]))


def _matrix_rows(conn: sqlite3.Connection, q12_id: str) -> list[sqlite3.Row]:
    rows = conn.execute(
        "SELECT * FROM work_items WHERE upper(phase)=? ORDER BY created_at,id",
        (census.PHASE,),
    ).fetchall()
    result: list[sqlite3.Row] = []
    for row in rows:
        try:
            if str(_payload(row).get("q12_work_item_id") or "") == q12_id:
                result.append(row)
        except MatrixServiceError:
            continue
    return result


def _collect_cell_receipts(
    conn: sqlite3.Connection,
    *,
    q12_row: sqlite3.Row,
    program_dir: Path,
    limit: int,
) -> list[dict[str, Any]]:
    receipts: list[dict[str, Any]] = []
    receipt_dir = program_dir / "cell_receipts"
    for row in _matrix_rows(conn, str(q12_row["id"])):
        if len(receipts) >= limit:
            break
        if str(row["status"]).lower() != "done" or str(row["verdict"] or "").upper() != "MEASURED":
            continue
        target = receipt_dir / f"{row['id']}.json"
        if target.is_file():
            continue
        evidence = Path(str(row["evidence_path"] or ""))
        try:
            metric = census.cell_report(evidence)
        except (OSError, ValueError, json.JSONDecodeError, census.CensusError):
            continue
        payload = _payload(row)
        receipt = {
            "schema": "qm.dl089-cell-receipt/v1",
            "matrix_runner_revision": RUNNER_REVISION,
            "q12_work_item_id": q12_row["id"],
            "work_item_id": row["id"],
            "cell_key": payload.get("cell_key"),
            "stage": payload.get("stage", "ANNUAL_CENSUS"),
            "created_at_utc": _now(),
            "measurement": metric,
        }
        census._atomic_write(target, json.dumps(receipt, indent=2, sort_keys=True) + "\n")
        receipts.append(
            {
                "work_item_id": row["id"],
                "cell_key": payload.get("cell_key"),
                "receipt_path": str(target.resolve()),
                "receipt_sha256": _sha256_file(target),
            }
        )
    return receipts


def _finalize_from_terminal_ledger(
    conn: sqlite3.Connection,
    *,
    q12_row: sqlite3.Row,
    ledger_path: Path,
    program_dir: Path,
    apply: bool,
) -> dict[str, Any] | None:
    ledger = json.loads(ledger_path.read_text(encoding="utf-8-sig"))
    driver = ledger.get("driver") or {}
    state = str(driver.get("state") or "")
    # Terminal pattern-selection states.  READY_FOR_Q15 joined 2026-09-02: the
    # EUR pilot (QM5_11421/EURUSD) ran the driver past PATTERN_SELECTION_READY
    # through numeric + full-window measuring into READY_FOR_Q15, and the Q12
    # owner row stayed pending forever because only the two earlier terminal
    # states were recognised here.  The pattern verdict is fully determined by
    # ``wf.final_selection`` in every one of these states; the later stages
    # never reopen the pattern selection.
    if state not in {
        selector.STATE_PATTERN_READY,
        selector.STATE_UNSTABLE,
        selector.STATE_READY,
    }:
        return None
    final = (driver.get("wf") or {}).get("final_selection") or {"BUY": [], "SELL": []}
    selected_count = len(final.get("BUY", [])) + len(final.get("SELL", []))
    verdict = "OPT_ELIGIBLE" if state == selector.STATE_PATTERN_READY and selected_count else "NO_FILTER_CHANGE"
    evidence_rows: list[dict[str, Any]] = []
    for row in _matrix_rows(conn, str(q12_row["id"])):
        path = Path(str(row["evidence_path"] or ""))
        evidence_rows.append(
            {
                "work_item_id": row["id"],
                "status": row["status"],
                "verdict": row["verdict"],
                "evidence_path": str(path),
                "evidence_sha256": _sha256_file(path) if path.is_file() else None,
                "cell_key": _payload(row).get("cell_key"),
            }
        )
    resolved_verdicts = {selector.census_measured_verdict(), pruning.SKIPPED_VERDICT}
    if not evidence_rows or any(
        str(item["status"]).lower() != "done"
        or str(item["verdict"]).upper() not in resolved_verdicts
        for item in evidence_rows
    ):
        return None
    receipt_path = program_dir / "q12_selection_receipt.json"
    receipt = {
        "schema": "qm.dl089-q12-selection-receipt/v1",
        "matrix_runner_revision": RUNNER_REVISION,
        "q12_work_item_id": q12_row["id"],
        "completed_at_utc": _now(),
        "verdict": verdict,
        "driver_state": state,
        "final_selection": final,
        "stability": (driver.get("wf") or {}).get("stability"),
        "ledger_path": str(ledger_path.resolve()),
        "ledger_sha256": _sha256_file(ledger_path),
        "cell_evidence": evidence_rows,
    }
    if apply:
        census._atomic_write(receipt_path, json.dumps(receipt, indent=2, sort_keys=True) + "\n")
        now = _now()
        cursor = conn.execute(
            """
            UPDATE work_items
            SET status='done',verdict=?,evidence_path=?,claimed_by=NULL,updated_at=?
            WHERE id=? AND lower(status)='pending' AND verdict IS NULL AND claimed_by IS NULL
            """,
            (verdict, str(receipt_path.resolve()), now, q12_row["id"]),
        )
        if cursor.rowcount != 1:
            raise MatrixServiceError(f"Q12 completion compare-and-set lost: {q12_row['id']}")
        conn.execute(
            """
            UPDATE work_item_holds
            SET active=0,released_at=?,updated_at=?,release_note=?
            WHERE work_item_id=? AND active=1
            """,
            (now, now, "DL-089 matrix completed from sealed cell evidence", q12_row["id"]),
        )
    return {
        "work_item_id": q12_row["id"],
        "verdict": verdict,
        "evidence_path": str(receipt_path.resolve()),
        "applied": apply,
    }


def _service_existing_matrix(
    conn: sqlite3.Connection,
    *,
    db_path: Path,
    q12_row: sqlite3.Row,
    artifact_root: Path,
    window: int,
    receipt_limit: int,
    apply: bool,
    lane_limit: int,
    cell_limit: int,
) -> dict[str, Any]:
    declaration = _payload(q12_row)["pattern_filter_sweep"]
    program_dir = artifact_root / str(declaration["program_id"])
    ledger_path = program_dir / "ledger.json"
    if not ledger_path.is_file():
        raise MatrixServiceError(f"matrix rows exist without ledger: {q12_row['id']}")
    boost = (
        census.boost(
            ledger_path=ledger_path,
            db_path=db_path,
            window=window,
            lane_limit=lane_limit,
            cell_limit=cell_limit,
        )
        if apply
        else None
    )
    receipts = _collect_cell_receipts(
        conn,
        q12_row=q12_row,
        program_dir=program_dir,
        limit=receipt_limit if apply else 0,
    )
    advance = selector.advance(
        ledger_path=ledger_path,
        db_path=db_path,
        dry_run=not apply,
        pattern_only=True,
    )
    # selector owns a separate connection; refresh this connection's read view.
    finalized = _finalize_from_terminal_ledger(
        conn,
        q12_row=q12_row,
        ledger_path=ledger_path,
        program_dir=program_dir,
        apply=apply,
    )
    return {
        "work_item_id": q12_row["id"],
        "program_id": declaration["program_id"],
        "ledger_path": str(ledger_path.resolve()),
        "boost": boost,
        "cell_receipts_created": receipts,
        "advance": advance,
        "finalized": finalized,
    }


def refill_existing_frontiers(
    conn: sqlite3.Connection,
    *,
    db_path: Path,
    worker_count: int,
    apply: bool = False,
    window: int = 8,
) -> dict[str, Any]:
    """Refresh existing DL-089 queue heads without running the full service.

    The full matrix service authenticates siblings, creates Q02 prerequisites,
    writes receipts, advances selectors, and materializes new owners.  That is
    intentionally comprehensive, but it can take longer than the pump's late
    stage budget.  Existing owners only need ``opt_census.boost`` to keep their
    already-authenticated ledgers supplied.  This early, bounded path discovers
    only matrices that already have cell rows and never creates a program,
    verdict, receipt, or terminal job.
    """

    if window != 8:
        raise ValueError("DL-089 scheduling contract requires an eight-cell window")
    conn.row_factory = sqlite3.Row
    q12_rows = conn.execute(
        """
        SELECT id,phase,created_at,payload_json
        FROM work_items
        WHERE upper(phase)='Q12' AND lower(status)='pending'
          AND verdict IS NULL AND claimed_by IS NULL
        ORDER BY created_at,id
        """
    ).fetchall()
    cell_rows = conn.execute(
        """
        SELECT id,status,ea_id,symbol,payload_json
        FROM work_items
        WHERE upper(phase)=? AND lower(status) IN ('pending','active')
        ORDER BY created_at,id
        """,
        (census.PHASE,),
    ).fetchall()

    cells_by_q12: dict[str, list[tuple[sqlite3.Row, dict[str, Any]]]] = {}
    for row in cell_rows:
        try:
            payload = json.loads(row["payload_json"] or "{}")
        except json.JSONDecodeError:
            continue
        if payload.get("schema") != census.SCHEMA:
            continue
        q12_id = str(payload.get("q12_work_item_id") or "")
        if not q12_id:
            continue
        cells_by_q12.setdefault(q12_id, []).append((row, payload))

    existing: list[tuple[sqlite3.Row, dict[str, Any], list[tuple[sqlite3.Row, dict[str, Any]]]]] = []
    for row in q12_rows:
        try:
            payload = _payload(row)
        except MatrixServiceError:
            continue
        if not _is_dl089_pattern(row, payload):
            continue
        cells = cells_by_q12.get(str(row["id"])) or []
        if cells:
            existing.append((row, payload, cells))
    existing.sort(key=lambda item: _queue_order(item[0], item[1]))

    configured_k = program_slots()
    configured_l = scheduling.lanes_per_program()
    configured_g = scheduling.cell_slots()
    k_eff, l_eff, g_eff = scheduling.effective_limits(worker_count)
    allowlist = scheduling.same_program_parallel_allowlist()
    refilled: list[dict[str, Any]] = []
    deferred: list[dict[str, Any]] = []

    for q12_row, q12_payload, cells in existing[:k_eff]:
        declaration = q12_payload["pattern_filter_sweep"]
        program = str(declaration["program_id"])
        ledger_paths = {
            str(payload.get("ledger_path") or "").strip()
            for _row, payload in cells
            if str(payload.get("ledger_path") or "").strip()
        }
        if len(ledger_paths) != 1:
            deferred.append({
                "q12_work_item_id": str(q12_row["id"]),
                "program_id": program,
                "machine_reason": (
                    "FRONTIER_REFILL_LEDGER_PATH_MISSING"
                    if not ledger_paths
                    else "FRONTIER_REFILL_LEDGER_PATH_CONFLICT"
                ),
                "ledger_paths": sorted(ledger_paths),
            })
            continue
        ledger_path = Path(next(iter(ledger_paths)))
        lane_limit = l_eff if program in allowlist else min(1, l_eff)
        try:
            boost = (
                census.boost(
                    ledger_path=ledger_path,
                    db_path=db_path,
                    window=window,
                    lane_limit=lane_limit,
                    cell_limit=g_eff,
                )
                if apply
                else None
            )
        except (census.CensusError, OSError, ValueError, json.JSONDecodeError) as exc:
            deferred.append({
                "q12_work_item_id": str(q12_row["id"]),
                "program_id": program,
                "machine_reason": f"FRONTIER_REFILL_FAILED:{exc}",
                "ledger_path": str(ledger_path),
            })
            continue
        refilled.append({
            "q12_work_item_id": str(q12_row["id"]),
            "program_id": program,
            "ledger_path": str(ledger_path),
            "active_cells": sum(
                1 for row, _payload_row in cells
                if str(row["status"]).lower() == "active"
            ),
            "pending_cells": sum(
                1 for row, _payload_row in cells
                if str(row["status"]).lower() == "pending"
            ),
            "boost": boost,
        })

    return {
        "schema": "qm.dl089-frontier-refill/v1",
        "applied": bool(apply),
        "worker_count": int(worker_count),
        "program_slots_configured": configured_k,
        "program_slots_effective": k_eff,
        "lanes_per_program_configured": configured_l,
        "lanes_per_program_effective": l_eff,
        "cell_slots_configured": configured_g,
        "cell_slots_effective": g_eff,
        "existing_programs": len(existing),
        "refilled": refilled,
        "deferred": deferred,
    }


def _materialize(
    *,
    db_path: Path,
    repo_root: Path,
    artifact_root: Path,
    q12_row: sqlite3.Row,
    sibling: Mapping[str, Any],
    window: int,
    lane_limit: int,
    cell_limit: int,
) -> dict[str, Any]:
    payload = _payload(q12_row)
    declaration = dict(payload["pattern_filter_sweep"])
    program_dir = artifact_root / str(declaration["program_id"])
    plan = census.build_plan_from_declaration(
        ea_id=str(sibling["ea_id"]),
        ea_label=str(sibling["ea_label"]),
        symbol=str(q12_row["symbol"]),
        timeframe=str(sibling["timeframe"]),
        base_setfile=Path(sibling["base_setfile"]),
        output_dir=program_dir / "setfiles",
        declaration=declaration,
        subject_ea_id=str(q12_row["ea_id"]),
    )
    ledger_path = program_dir / "ledger.json"
    enqueue = census.enqueue(
        plan,
        db_path=db_path,
        ledger_path=ledger_path,
        q02_ea_id=str(sibling["ea_id"]),
        parent_work_item_id=str(q12_row["id"]),
        declaration_sha256=str(declaration["declaration_sha256"]),
        runner_revision=RUNNER_REVISION,
    )
    boost = census.boost(
        ledger_path=ledger_path,
        db_path=db_path,
        window=window,
        lane_limit=lane_limit,
        cell_limit=cell_limit,
    )
    registration = {
        "schema": "qm.dl089-matrix-registration-receipt/v1",
        "registered_at_utc": _now(),
        "matrix_runner_revision": RUNNER_REVISION,
        "q12_work_item_id": q12_row["id"],
        "subject_ea_id": q12_row["ea_id"],
        "measurement_ea_id": sibling["ea_id"],
        "program_id": declaration["program_id"],
        "declaration_sha256": declaration["declaration_sha256"],
        "annual_cells_sha256": declaration["annual_cells_sha256"],
        "wf_cells_sha256": declaration["wf_cells_sha256"],
        "measurement_bindings": sibling["bindings"],
        "enqueue": enqueue,
        "priority_window": boost,
    }
    registration_path = program_dir / "runner_registration.json"
    census._atomic_write(
        registration_path, json.dumps(registration, indent=2, sort_keys=True) + "\n"
    )
    return {
        "work_item_id": q12_row["id"],
        "program_id": declaration["program_id"],
        "measurement_ea_id": sibling["ea_id"],
        "ledger_path": str(ledger_path.resolve()),
        "registration_path": str(registration_path.resolve()),
        "registration_sha256": _sha256_file(registration_path),
        "enqueue": enqueue,
        "boost": boost,
    }


def service_pending(
    conn: sqlite3.Connection,
    *,
    db_path: Path,
    repo_root: Path,
    artifact_root: Path = DEFAULT_ARTIFACT_ROOT,
    apply: bool = False,
    q12_work_item_ids: Iterable[str] | None = None,
    recover_work_item_ids: Iterable[str] | None = None,
    evidence_path: Path | None = None,
    window: int = 8,
    receipt_limit: int = 16,
) -> dict[str, Any]:
    """Append recoveries, seed prerequisites, and advance bounded matrices."""

    if window != 8:
        raise ValueError("DL-089 scheduling contract requires an eight-cell window")
    conn.row_factory = sqlite3.Row
    recoveries: list[dict[str, Any]] = []
    for work_item_id in recover_work_item_ids or ():
        if evidence_path is None:
            raise ValueError("evidence_path is required for recovery successors")
        recoveries.append(
            append_recovery_successor(
                conn,
                source_work_item_id=str(work_item_id),
                evidence_path=evidence_path,
                apply=apply,
            )
        )
    if apply and recoveries:
        conn.commit()

    targets = None if q12_work_item_ids is None else {str(value) for value in q12_work_item_ids}
    rows = conn.execute(
        """
        SELECT * FROM work_items
        WHERE upper(phase)='Q12' AND lower(status)='pending'
          AND verdict IS NULL AND claimed_by IS NULL
        ORDER BY created_at,id
        """
    ).fetchall()
    candidates: list[tuple[sqlite3.Row, dict[str, Any]]] = []
    deferred: list[dict[str, Any]] = []
    q02: list[dict[str, Any]] = []
    for row in rows:
        if targets is not None and str(row["id"]) not in targets:
            continue
        try:
            payload = _payload(row)
            if not _is_dl089_pattern(row, payload):
                continue
            hold = _active_hold(conn, str(row["id"]))
            if hold is not None and str(hold["hold_code"]) not in ALLOWED_SERVICE_HOLDS:
                raise MatrixServiceError(f"blocking hold: {hold['hold_code']}")
            if apply:
                # Convert the original emergency mismatch hold immediately,
                # even when the measurement sibling is still waiting on build
                # or compile evidence.  A restarted worker has the hard claim
                # guard; until then release_on_restart keeps old residents out.
                _ensure_rollout_hold(conn, str(row["id"]), apply=True)
            declaration = payload["pattern_filter_sweep"]
            sibling = _measurement_sibling(
                repo_root.resolve(),
                str(row["ea_id"]),
                str(row["symbol"]),
                artifact_root=artifact_root,
                program_id=str(declaration["program_id"]),
                apply=apply,
            )
            compile_receipt = _compile_receipt(conn, sibling)
            q02_state = _seed_q02(
                conn,
                q12_row=row,
                sibling=sibling,
                compile_receipt=compile_receipt,
                apply=apply,
            )
            q02.append(
                {
                    "q12_work_item_id": row["id"],
                    "measurement_ea_id": sibling["ea_id"],
                    **q02_state,
                }
            )
            if str(q02_state["status"]).lower() == "done" and str(q02_state["verdict"] or "").upper() == "PASS":
                candidates.append((row, sibling))
            elif str(q02_state["status"]).lower() in {"failed", "done"}:
                raise MatrixServiceError(
                    f"measurement Q02 is terminal non-PASS: {q02_state['work_item_id']} "
                    f"{q02_state['status']}/{q02_state['verdict']}"
                )
        except (
            MatrixServiceError,
            census.CensusError,
            OSError,
            ValueError,
            json.JSONDecodeError,
        ) as exc:
            deferred.append(
                {
                    "work_item_id": row["id"],
                    "ea_id": row["ea_id"],
                    "symbol": row["symbol"],
                    "machine_reason": str(exc),
                }
            )
    if apply and q02:
        conn.commit()

    candidates.sort(key=lambda item: _queue_order(item[0], _payload(item[0])))
    maintained: list[dict[str, Any]] = []
    materialized: list[dict[str, Any]] = []

    # Import lazily: farmctl imports this service from its pump path.
    try:
        import farmctl
    except ModuleNotFoundError:
        from tools.strategy_farm import farmctl

    worker_count = len(farmctl.worker_policy_terminals())
    configured_k = program_slots()
    configured_l = scheduling.lanes_per_program()
    configured_g = scheduling.cell_slots()
    k_eff, l_eff, g_eff = scheduling.effective_limits(worker_count)
    slots = k_eff
    governed = candidates[:slots]
    active_rows = [
        dict(row)
        for row in conn.execute(
            "SELECT id,phase,ea_id,symbol,payload_json FROM work_items "
            "WHERE lower(status)='active' AND upper(phase)='OPT_CENSUS'"
        )
    ]
    active_snapshot = scheduling.active_census_snapshot(active_rows)
    allowlist = scheduling.same_program_parallel_allowlist()
    slot_owners: list[dict[str, Any]] = []
    for slot, (row, sibling) in enumerate(governed, start=1):
        declaration = _payload(row)["pattern_filter_sweep"]
        program = str(declaration["program_id"])
        program_lane_limit = l_eff if program in allowlist else min(1, l_eff)
        # G is the bounded refill-window ceiling for every owner. The atomic
        # claimant applies the live fleet total; shrinking this value by other
        # active programmes drained all pending frontier priority at saturation
        # and made throughput depend on the next pump cadence.
        program_cell_limit = g_eff
        owner = {
            "slot": slot,
            "work_item_id": str(row["id"]),
            "program_id": str(declaration["program_id"]),
            "measurement_ea_id": str(sibling["ea_id"]),
            "symbol": str(row["symbol"]),
        }
        if _matrix_rows(conn, str(row["id"])):
            maintained_row = _service_existing_matrix(
                conn,
                db_path=db_path,
                q12_row=row,
                artifact_root=artifact_root,
                window=window,
                receipt_limit=receipt_limit,
                apply=apply,
                lane_limit=program_lane_limit,
                cell_limit=program_cell_limit,
            )
            maintained.append(maintained_row)
            owner["action"] = "maintained"
        elif apply:
            materialized_row = _materialize(
                db_path=db_path,
                repo_root=repo_root,
                artifact_root=artifact_root,
                q12_row=row,
                sibling=sibling,
                window=window,
                lane_limit=program_lane_limit,
                cell_limit=program_cell_limit,
            )
            materialized.append(materialized_row)
            owner["action"] = "materialized"
        else:
            materialized.append(
                {
                    "would_materialize": True,
                    "work_item_id": row["id"],
                    "measurement_ea_id": sibling["ea_id"],
                    "program_id": declaration["program_id"],
                }
            )
            owner["action"] = "would_materialize"
        slot_owners.append(owner)

    boosts_by_program = {
        str(row["program_id"]): row.get("boost") or {}
        for row in [*maintained, *materialized]
        if row.get("program_id")
    }
    capacity_waits: list[dict[str, Any]] = []
    for owner in slot_owners:
        program = str(owner["program_id"])
        owner["active_lane_ids"] = [
            list(lane) for lane in sorted(active_snapshot["lanes"])
            if lane[0] == program
        ]
        owner["boosted_lane_ids"] = boosts_by_program.get(program, {}).get(
            "boosted_lane_ids", []
        )
        if active_snapshot["total"] >= g_eff:
            owner["capacity_reason"] = f"CELL_SLOT_WAIT:G={g_eff}"
        elif active_snapshot["program_lane_counts"].get(program, 0) >= (
            l_eff if program in allowlist else min(1, l_eff)
        ):
            owner["capacity_reason"] = (
                "PROGRAM_LANE_WAIT:L="
                f"{l_eff if program in allowlist else min(1, l_eff)}"
            )
        if owner.get("capacity_reason"):
            capacity_waits.append({
                "program_id": program,
                "machine_reason": owner["capacity_reason"],
            })

    for row, _sibling in candidates[slots:]:
        program_id = _payload(row)["pattern_filter_sweep"]["program_id"]
        deferred.append(
            {
                "work_item_id": row["id"],
                "ea_id": row["ea_id"],
                "symbol": row["symbol"],
                "program_id": program_id,
                "machine_reason": f"PROGRAM_SLOT_WAIT:K={slots}",
            }
        )
    if apply:
        conn.commit()
    return {
        "schema": SERVICE_SCHEMA,
        "applied": apply,
        "matrix_runner_revision": RUNNER_REVISION,
        "pair_mode": "BOUNDED_PROGRAMS",
        "program_slots": slots,
        "program_slots_configured": configured_k,
        "program_slots_effective": k_eff,
        "lanes_per_program_configured": configured_l,
        "lanes_per_program_effective": l_eff,
        "cell_slots_configured": configured_g,
        "cell_slots_effective": g_eff,
        "worker_count": worker_count,
        "active_opt_census_cells": active_snapshot["total"],
        "capacity_waits": capacity_waits,
        "slot_owners": slot_owners,
        "priority_window_cap": window,
        "recoveries": recoveries,
        "q02_prerequisites": q02,
        "materialized": materialized,
        "maintained": maintained,
        "deferred": deferred,
    }
