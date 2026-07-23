"""Recover cards rejected solely under the superseded R1/source policy.

OWNER 2026-07-23: source reputation is informational. Existing book/web/forum
lineage is preserved; Fabian Grabner (OWNER) is used only when no more concrete
source can be recovered. Rejected originals remain immutable audit evidence.

Recovery is deliberately split:

* audited cards whose bodies document R2-R4 PASS may return to approved;
* all other source-only cards return to draft for semantic G0 and, where
  required, current-contract repair;
* identity/slug collisions are recorded for re-ID instead of being copied under
  an unsafe EA identity.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import sys
import uuid
from collections import Counter
from pathlib import Path
from typing import Any

try:
    import farmctl
except ModuleNotFoundError:
    from tools.strategy_farm import farmctl


DEFAULT_ROOT = Path(r"D:\QM\strategy_farm")

# Independent read-only audit 2026-07-23: formally complete cards whose only
# recorded G0 rejection was R1/source/citation policy.
AUDITED_SOURCE_ONLY_EA_IDS = frozenset({
    "QM5_2076",
    "QM5_9501",
    "QM5_10973",
    "QM5_11212",
    "QM5_11213",
    "QM5_11214",
    "QM5_11619",
    "QM5_11897",
    "QM5_11898",
    "QM5_11904",
    "QM5_12351",
    "QM5_12352",
    "QM5_12354",
    "QM5_12355",
    "QM5_12384",
    "QM5_12400",
    "QM5_12401",
    "QM5_12512",
})

# These seven cards contain explicit R2/R3/R4 PASS evidence in their bodies.
# The others need fresh semantic G0 even if formally complete.
AUDITED_R234_PASS_EA_IDS = frozenset({
    "QM5_11212",
    "QM5_11213",
    "QM5_11214",
    "QM5_11619",
    "QM5_12351",
    "QM5_12512",
})

KNOWN_SEMANTIC_DUPLICATES = {
    "QM5_12384": "QM5_1111",
    "QM5_12400": "QM5_12409",
}

# Audit group B: old R1/source rejections that now need contract repair and/or
# re-ID before semantic G0. Multiple rejected artefacts under one listed ID are
# intentionally retained as identity-repair evidence, except the explicitly
# unrelated 11689 sibling filtered below.
AUDITED_REPAIR_EA_IDS = frozenset({
    "QM5_1201",
    "QM5_1224", "QM5_1225", "QM5_1226", "QM5_1227", "QM5_1231",
    "QM5_1261", "QM5_1262", "QM5_1286", "QM5_1287",
    "QM5_1312", "QM5_1316", "QM5_1321", "QM5_1322", "QM5_1323",
    "QM5_1326", "QM5_1338", "QM5_1354", "QM5_1355", "QM5_1366",
    "QM5_1381", "QM5_1450", "QM5_1528", "QM5_1541", "QM5_1545",
    "QM5_1555", "QM5_1561", "QM5_1564", "QM5_1566", "QM5_1584",
    "QM5_1602", "QM5_1603", "QM5_1621", "QM5_1626", "QM5_1627",
    "QM5_1628", "QM5_1630", "QM5_1638", "QM5_1646", "QM5_1650",
    "QM5_1670", "QM5_1750", "QM5_1753", "QM5_2245", "QM5_3005",
    "QM5_9354", "QM5_9576", "QM5_9577", "QM5_9578",
    "QM5_9641", "QM5_9642", "QM5_9643", "QM5_9644", "QM5_9645",
    "QM5_10282", "QM5_10645", "QM5_10648", "QM5_10649",
    "QM5_11291", "QM5_11292", "QM5_11294", "QM5_11299",
    "QM5_11300", "QM5_11301", "QM5_11302", "QM5_11325",
    "QM5_11362", "QM5_11363", "QM5_11364", "QM5_11375",
    "QM5_11376", "QM5_11380", "QM5_11388",
    "QM5_11401", "QM5_11402", "QM5_11434", "QM5_11435",
    "QM5_11455", "QM5_11456", "QM5_11457", "QM5_11461",
    "QM5_11465", "QM5_11496",
    "QM5_11516", "QM5_11517", "QM5_11518",
    "QM5_11531", "QM5_11532", "QM5_11533", "QM5_11537",
    "QM5_11538", "QM5_11539", "QM5_11563",
    "QM5_11689",
    "QM5_12430", "QM5_12433", "QM5_12435", "QM5_12436",
    "QM5_12941", "QM5_12942",
})

RETIREMENT_R1_FAIL_CARD_NAMES = frozenset({
    "QM5_12941_hopwood-bermaui-macd-h4-card.md",
    "QM5_12942_ehlers-ebsw-cycle-composite-h4.md",
    "QM5_1650_sperandeo-trader-vic-ii-pattern-h4.md",
    "QM5_3005_alpha-inst-magnet.md",
})

SOURCE_OMISSIONS = (
    {
        "uri": "https://www.forexfactory.com/thread/1331012",
        "title": "The PriceBob Strategy — R1 recovery",
    },
    {
        "uri": "https://www.forexfactory.com/thread/222356",
        "title": "Pure Trading System — R1 recovery",
    },
    {
        "uri": "https://www.forexfactory.com/thread/20469",
        "title": "100% Mechanical Trading Systems — recovery inventory",
    },
)


def _matching_cards(directory: Path, ea_id: str) -> list[Path]:
    return sorted(
        path
        for path in directory.glob(f"{ea_id}_*.md")
        if "_dup-" not in path.stem
    )


def _source_only_reason(reason: str) -> bool:
    if not re.search(
        r"(?i)\bR1\b|source.?citation|source attribution|source lineage|unattribut",
        reason,
    ):
        return False
    return not re.search(
        r"(?i)\bR[234]\b.{0,40}\b(?:FAIL|REJECT|BLOCK)",
        reason,
    )


def _frontmatter_reason(fm: dict[str, Any]) -> str:
    return str(
        fm.get("g0_rejection_reason")
        or fm.get("rejection_reason")
        or fm.get("retirement_reason")
        or ""
    )


def _ea_id_from_path(path: Path) -> str:
    match = re.match(r"^(QM5_\d+)_", path.name, flags=re.I)
    return match.group(1).upper() if match else ""


def _identity_conflicts(
    root: Path,
    source: Path,
    fm: dict[str, Any],
    *,
    approved_dir: Path,
    draft_dir: Path,
    source_only_id_counts: Counter[str],
) -> list[str]:
    conflicts: list[str] = []
    ea_id = str(fm.get("ea_id") or "").strip().upper()
    slug = str(fm.get("slug") or "").strip()
    path_ea_id = _ea_id_from_path(source)
    if not ea_id or ea_id != path_ea_id:
        conflicts.append(
            f"card_ea_id_mismatch:path={path_ea_id or 'missing'}:frontmatter={ea_id or 'missing'}"
        )
    if source_only_id_counts.get(path_ea_id, 0) > 1:
        conflicts.append(
            f"multiple_source_only_rejected_cards_for_ea:{path_ea_id}:"
            f"count={source_only_id_counts[path_ea_id]}"
        )
    if _matching_cards(approved_dir, path_ea_id):
        conflicts.append(f"approved_ea_id_already_exists:{path_ea_id}")
    if _matching_cards(draft_dir, path_ea_id):
        conflicts.append(f"draft_ea_id_already_exists:{path_ea_id}")

    registry = (
        farmctl.REPO_ROOT
        / "framework"
        / "registry"
        / "ea_id_registry.csv"
    )
    slug_index = farmctl._ea_registry_slug_index(registry)
    registry_id = path_ea_id[4:] if path_ea_id.startswith("QM5_") else path_ea_id
    registered_slugs = slug_index.get(registry_id, [])
    if registered_slugs and slug not in registered_slugs:
        conflicts.append(
            f"ea_id_registry_slug_mismatch:{path_ea_id}:"
            f"registry={','.join(registered_slugs)}:card={slug}"
        )
    other_slug_owners = sorted(
        owner
        for owner, slugs in slug_index.items()
        if owner != registry_id and slug and slug in slugs
    )
    if other_slug_owners:
        conflicts.append(
            f"ea_slug_registry_owned_by_other_id:{slug}:"
            f"owners={','.join(other_slug_owners)}"
        )
    ea_dirs = sorted(
        path.name
        for path in farmctl.FRAMEWORK_EAS_DIR.glob(f"{path_ea_id}_*")
        if path.is_dir()
    )
    expected_dir = f"{path_ea_id}_{slug}"
    unexpected_dirs = [name for name in ea_dirs if name != expected_dir]
    if unexpected_dirs:
        conflicts.append(
            f"ea_directory_identity_conflict:{','.join(unexpected_dirs)}"
        )
    if farmctl.db_path(root).exists():
        try:
            with farmctl.connect(root) as conn:
                task_rows = conn.execute(
                    "SELECT id, status FROM tasks WHERE card_id=?",
                    (path_ea_id,),
                ).fetchall()
            active_task_rows = [
                f"{row['id']}:{row['status']}"
                for row in task_rows
                if row["status"] in {"pending", "active", "done"}
            ]
            if active_task_rows:
                conflicts.append(
                    "existing_pipeline_tasks:" + ",".join(active_task_rows[:5])
                )
        except Exception:
            conflicts.append("pipeline_task_identity_check_failed")
    return conflicts


def _target_recovery_updates(
    source: Path,
    fm: dict[str, Any],
    *,
    source_lineage: dict[str, str],
    approve_directly: bool,
    contract_repair: bool,
) -> dict[str, str]:
    existing_r1 = str(fm.get("r1_track_record") or "").strip().upper()
    r1_value = (
        existing_r1
        if existing_r1 in farmctl.R1_BUILD_READY_VALUES
        else "TIER_C"
    )
    updates = {
        "status": "APPROVED" if approve_directly else "draft",
        "g0_status": "APPROVED" if approve_directly else "PENDING",
        "source_id": source_lineage["source_id"],
        "r1_track_record": r1_value,
        "r1_reasoning": json.dumps(
            "Existing attribution retained; R1 is informational and "
            "non-gating under OWNER policy 2026-07-23.",
            ensure_ascii=False,
        ),
        "r2_mechanical": "PASS" if approve_directly else "UNKNOWN",
        "r3_data_available": "PASS" if approve_directly else "UNKNOWN",
        "r4_ml_forbidden": "PASS" if approve_directly else "UNKNOWN",
        "card_body_incomplete": "true" if contract_repair else "false",
        "card_body_missing": (
            json.dumps("legacy_contract_repair", ensure_ascii=False)
            if contract_repair
            else '""'
        ),
        "legacy_contract_repair": "true" if contract_repair else "false",
        "g0_rejection_reason": json.dumps(
            "SUPERSEDED: source-only rejection recovered under OWNER R1 "
            "policy on 2026-07-23; original retained in cards_rejected.",
            ensure_ascii=False,
        ),
        "g0_recovery_reason": json.dumps(
            (
                "Source-only rejection recovered; audited card body documents "
                "R2-R4 PASS."
                if approve_directly
                else "Source-only rejection recovered; fresh semantic R2-R4 "
                "G0 review required."
            ),
            ensure_ascii=False,
        ),
        "g0_recovery_origin": json.dumps(source.as_posix(), ensure_ascii=False),
        "last_updated": "2026-07-23",
    }
    if approve_directly:
        updates["g0_approval_reasoning"] = json.dumps(
            "OWNER 2026-07-23 retroactive source-only recovery; body audit "
            "documents R2-R4 PASS and original rejection is retained.",
            ensure_ascii=False,
        )
    current_citation = str(fm.get("source_citation") or "").strip()
    current_is_owner_generic = (
        farmctl.OWNER_SOURCE_RECOVERY_ID in current_citation
        or "Fabian Grabner (OWNER), strategy hypothesis/source-lineage recovery"
        in current_citation
    )
    if not current_citation or current_is_owner_generic:
        updates["source_citation"] = json.dumps(
            source_lineage["citation"],
            ensure_ascii=False,
        )
    return updates


def _atomic_recovery_copy(
    source: Path,
    target: Path,
    updates: dict[str, str],
) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    staging = target.parent / f".{target.name}.{uuid.uuid4().hex}.tmp"
    try:
        shutil.copy2(source, staging)
        farmctl._update_flat_frontmatter_file(staging, updates)
        repaired = farmctl.parse_card_frontmatter(staging)
        if str(repaired.get("source_id") or "").strip() == "":
            raise ValueError("recovery staging card has no source_id")
        if str(repaired.get("g0_status") or "") != (
            "APPROVED" if target.parent.name == "cards_approved" else "PENDING"
        ):
            raise ValueError("recovery staging card has wrong g0_status")
        os.replace(staging, target)
    finally:
        try:
            staging.unlink()
        except OSError:
            pass


def _event_exists(root: Path, ea_id: str, source: Path) -> bool:
    with farmctl.connect(root) as conn:
        rows = conn.execute(
            "SELECT detail_json FROM events "
            "WHERE entity_type='card' AND entity_id=? "
            "AND event='r1_source_recovered'",
            (ea_id,),
        ).fetchall()
    for row in rows:
        try:
            detail = json.loads(row["detail_json"] or "{}")
        except (json.JSONDecodeError, TypeError):
            continue
        recorded = Path(str(detail.get("source_rejected_card") or ""))
        if recorded == source:
            return True
    return False


def _record_event(
    root: Path,
    *,
    ea_id: str,
    source: Path,
    target: Path,
    source_id: str,
    route: str,
) -> None:
    if _event_exists(root, ea_id, source):
        return
    with farmctl.connect(root) as conn:
        farmctl.event(
            conn,
            "card",
            ea_id,
            "r1_source_recovered",
            {
                "source_rejected_card": str(source),
                "recovered_card": str(target),
                "source_id": source_id,
                "route": route,
                "authority": "OWNER 2026-07-23",
            },
        )
        conn.commit()


def _existing_recovery_target(
    source: Path,
    *,
    approved_dir: Path,
    draft_dir: Path,
    identity_repair_dir: Path,
    recovery_origin_index: dict[str, Path],
) -> Path | None:
    origin_key = source.as_posix().casefold()
    indexed = recovery_origin_index.get(origin_key)
    if indexed is not None and indexed.exists():
        return indexed
    for directory in (approved_dir, draft_dir, identity_repair_dir):
        target = directory / source.name
        if not target.exists():
            continue
        try:
            fm = farmctl.parse_card_frontmatter(target)
        except (OSError, ValueError):
            return target
        if str(fm.get("g0_recovery_origin") or "").replace("\\", "/") == source.as_posix():
            return target
        return target
    return None


def _index_recovery_origins(*directories: Path) -> dict[str, Path]:
    """Index recovered cards by immutable rejected origin, regardless of re-ID."""
    indexed: dict[str, Path] = {}
    for directory in directories:
        if not directory.is_dir():
            continue
        for card_path in directory.glob("QM5_*.md"):
            if not card_path.is_file():
                continue
            try:
                fm = farmctl.parse_card_frontmatter(card_path)
            except (OSError, ValueError):
                continue
            origin = str(fm.get("g0_recovery_origin") or "").strip()
            if origin:
                indexed[Path(origin).as_posix().casefold()] = card_path
    return indexed


def _write_cumulative_manifest(root: Path, run_result: dict[str, Any]) -> Path:
    manifest = root / "state" / "r1_source_recovery_20260723.json"
    manifest.parent.mkdir(parents=True, exist_ok=True)
    existing: dict[str, Any] = {}
    if manifest.exists():
        try:
            existing = json.loads(manifest.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            existing = {}
    runs = list(existing.get("runs") or [])
    runs.append({
        "run_at": farmctl.utc_now(),
        "summary": run_result["summary"],
        "actions": run_result["actions"],
        "source_omissions": run_result.get("source_omissions", []),
    })
    recovered = dict(existing.get("recovered_cards") or {})
    for action in run_result["actions"]:
        if action["action"] not in {
            "recovered_to_approved",
            "recovered_to_draft",
            "recovered_to_identity_repair",
            "already_recovered",
        }:
            continue
        recovered[action["source"]] = {
            "target": action.get("target"),
            "ea_id": action.get("ea_id"),
            "source_id": action.get("source_id"),
            "route": action.get("route"),
        }
    payload = {
        "authority": "OWNER 2026-07-23: R1/source reputation is non-gating",
        "owner_fallback_source_id": farmctl.OWNER_SOURCE_RECOVERY_ID,
        "recovered_cards": recovered,
        "runs": runs,
    }
    staging = manifest.with_suffix(f".{uuid.uuid4().hex}.tmp")
    staging.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    os.replace(staging, manifest)
    return manifest


def _queue_source_omissions(root: Path, *, apply: bool) -> list[dict[str, Any]]:
    queued: list[dict[str, Any]] = []
    for item in SOURCE_OMISSIONS:
        sid = farmctl.source_id({
            "source_type": "web_forum",
            "uri": item["uri"],
        })
        action: dict[str, Any] = {
            "source_id": sid,
            "uri": item["uri"],
            "title": item["title"],
            "action": "would_queue_source_recovery",
        }
        if apply:
            result = farmctl.add_source(
                root,
                item["uri"],
                item["title"],
                "web_forum",
                lane="recovery",
                priority=10,
            )
            if result.get("added"):
                action["action"] = "queued_source_recovery"
            else:
                with farmctl.connect(root) as conn:
                    row = conn.execute(
                        "SELECT status FROM sources WHERE id=?",
                        (sid,),
                    ).fetchone()
                    requeue_event = conn.execute(
                        "SELECT 1 FROM events WHERE entity_type='source' "
                        "AND entity_id=? AND event='r1_source_requeued' LIMIT 1",
                        (sid,),
                    ).fetchone()
                    if (
                        row
                        and row["status"] in {"blocked", "rejected"}
                        and requeue_event is None
                    ):
                        conn.execute(
                            "UPDATE sources SET status='pending', "
                            "assigned_worker=NULL, updated_at=? WHERE id=?",
                            (farmctl.utc_now(), sid),
                        )
                        farmctl.event(
                            conn,
                            "source",
                            sid,
                            "r1_source_requeued",
                            {"uri": item["uri"], "authority": "OWNER 2026-07-23"},
                        )
                        conn.commit()
                        action["action"] = "requeued_existing_source"
                    else:
                        status = str(row["status"]) if row else "missing"
                        action["action"] = (
                            "existing_source_already_requeued"
                            if requeue_event is not None
                            else f"existing_source_{status}"
                        )
                action["add_source_result"] = result
        queued.append(action)
    return queued


def _recover_unlocked(root: Path, *, apply: bool = False) -> dict[str, Any]:
    rejected_dir = root / "artifacts" / "cards_rejected"
    draft_dir = root / "artifacts" / "cards_draft"
    approved_dir = root / "artifacts" / "cards_approved"
    identity_repair_dir = root / "artifacts" / "cards_recovery"
    if apply:
        farmctl.init_db(root)
        draft_dir.mkdir(parents=True, exist_ok=True)
        approved_dir.mkdir(parents=True, exist_ok=True)
        identity_repair_dir.mkdir(parents=True, exist_ok=True)

    candidates: list[tuple[Path, dict[str, Any]]] = []
    audited_ids = AUDITED_SOURCE_ONLY_EA_IDS | AUDITED_REPAIR_EA_IDS
    for source in sorted(rejected_dir.glob("QM5_*.md")):
        path_ea_id = _ea_id_from_path(source)
        if path_ea_id not in audited_ids:
            continue
        if (
            path_ea_id == "QM5_11689"
            and source.name != "QM5_11689_strat-bb-mr.md"
        ):
            continue
        try:
            fm = farmctl.parse_card_frontmatter(source)
        except (OSError, ValueError):
            continue
        if (
            _source_only_reason(_frontmatter_reason(fm))
            or source.name in RETIREMENT_R1_FAIL_CARD_NAMES
        ):
            candidates.append((source, fm))

    source_only_id_counts = Counter(
        _ea_id_from_path(source) for source, _fm in candidates
    )
    recovery_origin_index = _index_recovery_origins(
        approved_dir,
        draft_dir,
        identity_repair_dir,
    )
    actions: list[dict[str, Any]] = []
    for source, fm in candidates:
        ea_id = _ea_id_from_path(source)
        source_lineage = farmctl._resolved_card_source_lineage(root, source, fm)
        if ea_id in KNOWN_SEMANTIC_DUPLICATES:
            actions.append({
                "ea_id": ea_id,
                "action": "skip_already_covered_duplicate",
                "source": str(source),
                "source_id": source_lineage["source_id"],
                "covered_by_ea_id": KNOWN_SEMANTIC_DUPLICATES[ea_id],
            })
            continue
        existing_target = _existing_recovery_target(
            source,
            approved_dir=approved_dir,
            draft_dir=draft_dir,
            identity_repair_dir=identity_repair_dir,
            recovery_origin_index=recovery_origin_index,
        )
        if existing_target is not None:
            try:
                existing_fm = farmctl.parse_card_frontmatter(existing_target)
            except (OSError, ValueError):
                existing_fm = {}
            if (
                str(existing_fm.get("g0_recovery_origin") or "").replace("\\", "/")
                == source.as_posix()
            ):
                if apply:
                    _record_event(
                        root,
                        ea_id=ea_id,
                        source=source,
                        target=existing_target,
                        source_id=str(existing_fm.get("source_id") or source_lineage["source_id"]),
                        route=existing_target.parent.name,
                    )
                actions.append({
                    "ea_id": ea_id,
                    "action": "already_recovered",
                    "source": str(source),
                    "target": str(existing_target),
                    "source_id": str(existing_fm.get("source_id") or source_lineage["source_id"]),
                    "route": existing_target.parent.name,
                })
            else:
                same_identity = (
                    str(existing_fm.get("ea_id") or "").strip().upper() == ea_id
                    and str(existing_fm.get("slug") or "").strip()
                    == str(fm.get("slug") or "").strip()
                )
                actions.append({
                    "ea_id": ea_id,
                    "action": (
                        "skip_already_approved_equivalent"
                        if same_identity
                        and existing_target.parent.name == "cards_approved"
                        else "skip_existing_identity"
                    ),
                    "source": str(source),
                    "target": str(existing_target),
                    "reason": (
                        "same EA/slug already approved"
                        if same_identity
                        else "same filename/EA exists without this recovery origin"
                    ),
                })
            continue

        explicit_hard_fail = [
            key
            for key in farmctl.R_STRICT_PASS_FIELDS
            if str(fm.get(key) or "").strip().upper() == "FAIL"
        ]
        if explicit_hard_fail:
            actions.append({
                "ea_id": ea_id,
                "action": "keep_rejected_independent_hard_fail",
                "source": str(source),
                "hard_fail_fields": explicit_hard_fail,
            })
            continue

        conflicts = _identity_conflicts(
            root,
            source,
            fm,
            approved_dir=approved_dir,
            draft_dir=draft_dir,
            source_only_id_counts=source_only_id_counts,
        )
        if conflicts:
            target = identity_repair_dir / source.name
            updates = _target_recovery_updates(
                source,
                fm,
                source_lineage=source_lineage,
                approve_directly=False,
                contract_repair=True,
            )
            updates.update({
                "identity_repair_required": "true",
                "identity_repair_conflicts": json.dumps(
                    " | ".join(conflicts),
                    ensure_ascii=False,
                ),
                "recovered_from_ea_id": json.dumps(ea_id, ensure_ascii=False),
            })
            action_name = (
                "recovered_to_identity_repair"
                if apply
                else "would_recover_to_identity_repair"
            )
            if apply:
                _atomic_recovery_copy(source, target, updates)
                recovery_origin_index[source.as_posix().casefold()] = target
                _record_event(
                    root,
                    ea_id=ea_id,
                    source=source,
                    target=target,
                    source_id=source_lineage["source_id"],
                    route=identity_repair_dir.name,
                )
            actions.append({
                "ea_id": ea_id,
                "action": action_name,
                "source": str(source),
                "target": str(target),
                "source_id": source_lineage["source_id"],
                "conflicts": conflicts,
                "route": identity_repair_dir.name,
            })
            continue

        coverage = farmctl._verify_card_body_coverage(source)
        contract_issues = farmctl._approval_card_contract_issues(source, fm)
        expected_trades = farmctl._infer_expected_trades_per_year_per_symbol(
            source.read_text(encoding="utf-8-sig", errors="ignore")
        )
        current_gaps = (
            set(coverage.get("missing") or []) - {"source_citation"}
        )
        contract_repair = bool(
            current_gaps
            or contract_issues
            or expected_trades is None
            or expected_trades < 2
        )
        approve_directly = (
            ea_id in AUDITED_R234_PASS_EA_IDS
            and not contract_repair
        )
        target_dir = approved_dir if approve_directly else draft_dir
        target = target_dir / source.name
        updates = _target_recovery_updates(
            source,
            fm,
            source_lineage=source_lineage,
            approve_directly=approve_directly,
            contract_repair=contract_repair,
        )
        action_name = (
            "recovered_to_approved"
            if approve_directly
            else "recovered_to_draft"
        )
        action: dict[str, Any] = {
            "ea_id": ea_id,
            "action": (
                action_name
                if apply
                else action_name.replace("recovered_", "would_recover_", 1)
            ),
            "source": str(source),
            "target": str(target),
            "source_id": source_lineage["source_id"],
            "source_resolution": source_lineage["kind"],
            "route": target_dir.name,
            "contract_repair": contract_repair,
            "contract_issues": contract_issues,
            "body_missing": sorted(current_gaps),
            "expected_trades_per_year_per_symbol": expected_trades,
        }
        if apply:
            _atomic_recovery_copy(source, target, updates)
            recovery_origin_index[source.as_posix().casefold()] = target
            _record_event(
                root,
                ea_id=ea_id,
                source=source,
                target=target,
                source_id=source_lineage["source_id"],
                route=target_dir.name,
            )
        actions.append(action)

    summary = {
        "source_only_candidates": len(candidates),
        "recovered_to_approved": sum(
            action["action"] == "recovered_to_approved" for action in actions
        ),
        "recovered_to_draft": sum(
            action["action"] == "recovered_to_draft" for action in actions
        ),
        "already_recovered": sum(
            action["action"] == "already_recovered" for action in actions
        ),
        "already_approved_equivalent": sum(
            action["action"] == "skip_already_approved_equivalent"
            for action in actions
        ),
        "recovered_to_identity_repair": sum(
            action["action"] == "recovered_to_identity_repair"
            for action in actions
        ),
        "independent_hard_fail": sum(
            action["action"] == "keep_rejected_independent_hard_fail"
            for action in actions
        ),
    }
    source_omissions = _queue_source_omissions(root, apply=apply)
    summary["source_omissions_queued"] = sum(
        item["action"] in {"queued_source_recovery", "requeued_existing_source"}
        for item in source_omissions
    )
    result: dict[str, Any] = {
        "applied": apply,
        "authority": "OWNER 2026-07-23: R1/source reputation is non-gating",
        "owner_fallback_source_id": farmctl.OWNER_SOURCE_RECOVERY_ID,
        "audited_source_only_ids": sorted(AUDITED_SOURCE_ONLY_EA_IDS),
        "audited_r234_pass_ids": sorted(AUDITED_R234_PASS_EA_IDS),
        "summary": summary,
        "actions": actions,
        "source_omissions": source_omissions,
    }
    if apply:
        result["manifest"] = str(_write_cumulative_manifest(root, result))
    return result


def recover(root: Path, *, apply: bool = False) -> dict[str, Any]:
    if not apply:
        return _recover_unlocked(root, apply=False)
    claim = farmctl._acquire_build_dispatch_claim(
        root,
        ea_id="R1_SOURCE_RECOVERY_APPLY",
        task_id="r1-source-recovery-20260723",
        agent="controller",
        stale_sec=3600,
    )
    if claim is None:
        raise RuntimeError("another R1 source-recovery apply is already running")
    try:
        return _recover_unlocked(root, apply=True)
    finally:
        farmctl._release_build_dispatch_claim(claim)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=str(DEFAULT_ROOT))
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Restore source-only cards into approved/draft recovery routes.",
    )
    args = parser.parse_args()
    print(
        json.dumps(
            recover(Path(args.root), apply=args.apply),
            indent=2,
            ensure_ascii=False,
        )
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
