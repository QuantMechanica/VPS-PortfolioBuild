"""Build and verify an immutable FTMO Demo generation manifest.

This module is deliberately read-only towards MT5.  It inventories repository
sources and the already-installed Demo artifacts; it never installs, attaches,
starts a terminal, or changes AutoTrading.  A manifest with a non-null
``launch_timestamp_utc`` is sealed and may not be overwritten.
"""
from __future__ import annotations

import argparse
import configparser
import csv
import hashlib
import json
import os
import re
import sys
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


SCHEMA = "qm.ftmo-demo-genesis-manifest/v1"
DEFAULT_REPO = Path(r"C:\QM\repo")
DEFAULT_TERMINAL = Path(
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal"
    r"\81A933A9AFC5DE3C23B15CAB19C63850"
)
DEFAULT_RULES = DEFAULT_REPO / "docs/ftmo/FTMO_RULES_SNAPSHOT_2026-09-18.md"
DEFAULT_BOOK_STATE = Path(r"D:\QM\reports\state\ftmo_book_current.json")
DEFAULT_ATTRIBUTION = Path(r"D:\QM\reports\state\ftmo_sleeve_attribution.json")
DEFAULT_PACKAGE = (
    DEFAULT_REPO / "docs/ops/evidence/2026-09-18_ftmo_demo_book_v3_D2g6"
)
DEFAULT_GOVERNOR_SET = (
    DEFAULT_TERMINAL
    / "MQL5/Profiles/Presets/QM_FTMO_M13"
    / "QM5_13206_ftmo-account-governor_ACCOUNT_TIMER_M13_demo_active.set"
)
HASH_RE = re.compile(r"^[0-9a-f]{64}$")


class ManifestError(RuntimeError):
    """Fail-closed manifest input or immutability error."""


def sha256_file(path: Path | str) -> str:
    h = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _canonical_bytes(value: dict[str, Any]) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode(
        "utf-8"
    )


def manifest_digest(value: dict[str, Any]) -> str:
    material = deepcopy(value)
    material["manifest_sha256"] = None
    return hashlib.sha256(_canonical_bytes(material)).hexdigest()


def _load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ManifestError(f"json_unreadable:{path}:{exc}") from exc
    if not isinstance(value, dict):
        raise ManifestError(f"json_object_required:{path}")
    return value


def _read_set(path: Path) -> dict[str, str]:
    raw = path.read_bytes()
    if raw.startswith((b"\xff\xfe", b"\xfe\xff")):
        text = raw.decode("utf-16")
    else:
        text = raw.decode("utf-8-sig", errors="strict")
    values: dict[str, str] = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith(("#", ";")) or "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.split("||", 1)[0].strip()
    return values


def _read_terminal_identity(terminal: Path) -> dict[str, Any]:
    parser = configparser.ConfigParser()
    common = terminal / "config/common.ini"
    if not common.is_file():
        raise ManifestError(f"terminal_common_ini_missing:{common}")
    parser.read(common, encoding="utf-16")
    login = parser.get("Common", "Login", fallback="").strip()
    server = parser.get("Common", "Server", fallback="").strip()
    enabled = parser.get("Experts", "Enabled", fallback="").strip()
    if not login or not server:
        raise ManifestError("terminal_identity_incomplete")
    masked = ("*" * max(0, len(login) - 3)) + login[-3:]
    return {
        "login_masked": masked,
        "_login_plaintext": login,
        "server": server,
        "terminal_id": terminal.name,
        "terminal_root": str(terminal.resolve()),
        "autotrading_enabled_at_inventory": enabled == "1",
    }


def _binding(path: Path, kind: str, *, repo: Path | None = None) -> dict[str, Any]:
    resolved = path.resolve()
    if not resolved.is_file():
        raise ManifestError(f"binding_missing:{kind}:{resolved}")
    display = str(resolved)
    if repo is not None:
        try:
            display = resolved.relative_to(repo.resolve()).as_posix()
        except ValueError:
            pass
    return {
        "kind": kind,
        "path": display,
        "resolved_path": str(resolved),
        "sha256": sha256_file(resolved),
        "bytes": resolved.stat().st_size,
        "hash_mode": "raw_bytes_sha256",
    }


def _registry_rows(path: Path, ea_ids: set[int], *, magic: bool) -> list[dict[str, str]]:
    def numeric_id(value: str) -> int | None:
        match = re.fullmatch(r"(?:QM5_)?(\d+)", (value or "").strip())
        return int(match.group(1)) if match else None

    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        rows = [row for row in csv.DictReader(handle) if numeric_id(row.get("ea_id", "")) in ea_ids]
    if not rows:
        raise ManifestError(f"registry_rows_missing:{path}")
    if magic:
        return rows
    by_id = {numeric_id(row["ea_id"]): row for row in rows}
    missing = sorted(ea_ids - set(by_id))
    if missing:
        raise ManifestError(f"ea_registry_rows_missing:{missing}")
    return [by_id[key] for key in sorted(by_id)]


def _book_roles(path: Path | None) -> dict[int, dict[str, Any]]:
    if path is None or not path.is_file():
        return {}
    state = _load_json(path)
    incumbent = state.get("incumbent") or {}
    return {
        int(row["ea_id"]): row
        for row in incumbent.get("sleeves", [])
        if isinstance(row, dict) and row.get("ea_id") is not None
    }


def _resolve_setfile(candidate: dict[str, Any], package: Path, terminal: Path) -> Path:
    explicit = candidate.get("setfile_path")
    if explicit:
        return Path(explicit)
    stem = f"QM5_{int(candidate['ea_id'])}_{candidate['ftmo_symbol']}_{candidate['timeframe']}_live_trial.set"
    installed_path = terminal / "MQL5/Profiles/Presets/QM_FTMO_M13" / stem
    if installed_path.is_file():
        return installed_path
    package_path = package / "sets" / stem
    if package_path.is_file():
        return package_path
    return installed_path


def _resolve_source(candidate: dict[str, Any], repo: Path) -> Path:
    if candidate.get("source_path"):
        return Path(candidate["source_path"])
    label = str(candidate["ea_label"])
    return repo / "framework/EAs" / label / f"{label}.mq5"


def _resolve_ex5(candidate: dict[str, Any], terminal: Path) -> Path:
    if candidate.get("ex5_path"):
        return Path(candidate["ex5_path"])
    return terminal / "MQL5/Experts/QM_FTMO" / f"{candidate['ea_label']}.ex5"


def _validate_roster(roster: dict[str, Any]) -> list[dict[str, Any]]:
    if roster.get("schema") not in {
        "qm.ftmo-demo-roster/v1",
        "qm.ftmo-book-roster/v1",
    }:
        raise ManifestError(f"roster_schema_invalid:{roster.get('schema')}")
    rows = roster.get("candidates") or roster.get("sleeves")
    if not isinstance(rows, list) or not rows:
        raise ManifestError("roster_candidates_missing")
    seen: set[int] = set()
    for row in rows:
        required = {"ea_id", "ea_label", "ftmo_symbol", "timeframe", "slot", "magic"}
        missing = sorted(required - set(row))
        if missing:
            raise ManifestError(f"roster_candidate_fields_missing:{missing}")
        ea_id, slot, magic = int(row["ea_id"]), int(row["slot"]), int(row["magic"])
        if magic != ea_id * 10000 + slot:
            raise ManifestError(f"magic_formula_mismatch:{magic}")
        if magic in seen:
            raise ManifestError(f"duplicate_magic:{magic}")
        seen.add(magic)
    return rows


def build_manifest(
    *,
    roster_path: Path,
    output_json: Path,
    repo: Path = DEFAULT_REPO,
    terminal: Path = DEFAULT_TERMINAL,
    package: Path = DEFAULT_PACKAGE,
    rules_snapshot: Path = DEFAULT_RULES,
    book_state: Path | None = DEFAULT_BOOK_STATE,
    governor_set: Path = DEFAULT_GOVERNOR_SET,
    generation_id: str | None = None,
    launch_timestamp_utc: str | None = None,
    build_receipt: Path | None = None,
) -> dict[str, Any]:
    """Build, write, and return a manifest; refuse launched-target overwrite."""
    output_json = output_json.resolve()
    if output_json.exists():
        old = _load_json(output_json)
        if old.get("launch_timestamp_utc"):
            raise ManifestError(f"launched_manifest_immutable:{output_json}")
    repo, terminal, package = repo.resolve(), terminal.resolve(), package.resolve()
    roster_path, rules_snapshot, governor_set = (
        roster_path.resolve(),
        rules_snapshot.resolve(),
        governor_set.resolve(),
    )
    roster = _load_json(roster_path)
    candidates = _validate_roster(roster)
    terminal_identity = _read_terminal_identity(terminal)
    login_plaintext = terminal_identity.pop("_login_plaintext")
    roles = _book_roles(book_state)
    total_risk = float(
        roster.get("book_risk_percent")
        or roster.get("total_risk_pct")
        or sum(float(row.get("risk_percent", 0.0)) for row in candidates)
    )
    if total_risk <= 0:
        raise ManifestError("book_risk_non_positive")

    ea_registry = repo / "framework/registry/ea_id_registry.csv"
    magic_registry = repo / "framework/registry/magic_numbers.csv"
    ea_ids = {int(row["ea_id"]) for row in candidates}
    ea_rows = _registry_rows(ea_registry, ea_ids, magic=False)
    magic_rows = _registry_rows(magic_registry, ea_ids, magic=True)
    active_magic = {
        int(row["magic"]): row for row in magic_rows if row.get("status") == "active"
    }

    sleeves: list[dict[str, Any]] = []
    for row in candidates:
        ea_id, magic = int(row["ea_id"]), int(row["magic"])
        registry = active_magic.get(magic)
        expected_symbol = f"{row.get('dxz_symbol') or row['ftmo_symbol']}.DWX"
        if registry is None:
            raise ManifestError(f"active_magic_registry_row_missing:{magic}")
        if registry.get("symbol") != expected_symbol:
            raise ManifestError(
                f"magic_registry_symbol_mismatch:{magic}:{registry.get('symbol')}!={expected_symbol}"
            )
        source = _resolve_source(row, repo)
        ex5 = _resolve_ex5(row, terminal)
        setfile = _resolve_setfile(row, package, terminal)
        role_row = roles.get(ea_id, {})
        risk = float(row.get("risk_percent", role_row.get("risk_percent", 0.0)))
        if risk <= 0:
            raise ManifestError(f"risk_percent_missing:{ea_id}")
        set_values = _read_set(setfile)
        sleeves.append(
            {
                "ea_id": ea_id,
                "ea_label": row["ea_label"],
                "symbol": row["ftmo_symbol"],
                "timeframe": row["timeframe"],
                "magic": magic,
                "slot": int(row["slot"]),
                "role": row.get("role") or role_row.get("role") or "UNCLASSIFIED",
                "risk_percent": risk,
                "weight": round(risk / total_risk, 10),
                "source": _binding(source, "ea_source", repo=repo),
                "installed_ex5": _binding(ex5, "installed_ex5"),
                "setfile": _binding(setfile, "installed_setfile"),
                "runtime_policy": {
                    "environment": set_values.get("ENV"),
                    "risk_fixed": set_values.get("RISK_FIXED"),
                    "risk_percent": set_values.get("RISK_PERCENT"),
                    "news_temporal": set_values.get("qm_news_temporal"),
                    "news_compliance": set_values.get("qm_news_compliance"),
                    "news_stale_max_hours": set_values.get("qm_news_stale_max_hours"),
                    "friday_close_enabled": set_values.get("qm_friday_close_enabled"),
                    "friday_close_hour_broker": set_values.get("qm_friday_close_hour_broker"),
                    "kill_switch_anchor_mode": set_values.get("qm_ks_day_anchor_mode"),
                    "kill_switch_book_tag": set_values.get("qm_ks_book_tag"),
                },
            }
        )

    governor_source = repo / (
        "framework/EAs/QM5_13206_ftmo-account-governor/"
        "QM5_13206_ftmo-account-governor.mq5"
    )
    governor_ex5 = terminal / "MQL5/Experts/QM_FTMO/QM5_13206_ftmo-account-governor.ex5"
    governor_values = _read_set(governor_set)
    anchor_modes = {s["runtime_policy"]["kill_switch_anchor_mode"] for s in sleeves}
    book_tags = {s["runtime_policy"]["kill_switch_book_tag"] for s in sleeves}
    configured_anchor = len(anchor_modes) == 1 and next(iter(anchor_modes)) not in {None, ""}
    configured_tag = len(book_tags) == 1 and next(iter(book_tags)) not in {None, ""}
    receipt = build_receipt or (package / "RECEIPT_alias_builds.md")

    bindings = {
        "roster": _binding(roster_path, "roster", repo=repo),
        "rules_snapshot": _binding(rules_snapshot, "rules_snapshot", repo=repo),
        "ea_id_registry": _binding(ea_registry, "ea_id_registry", repo=repo),
        "magic_registry": _binding(magic_registry, "magic_registry", repo=repo),
        "governor_source": _binding(governor_source, "governor_source", repo=repo),
        "governor_ex5": _binding(governor_ex5, "governor_ex5"),
        "governor_setfile": _binding(governor_set, "governor_setfile"),
        "build_receipt": _binding(receipt, "build_receipt", repo=repo),
    }
    gid = generation_id or str(roster.get("cycle_id") or roster.get("book_id") or roster.get("label"))
    if not gid or gid == "None":
        raise ManifestError("generation_id_missing")
    challenge_id = governor_values.get("challenge_id")
    if challenge_id:
        challenge_id = challenge_id.replace(login_plaintext, terminal_identity["login_masked"])
    manifest: dict[str, Any] = {
        "schema": SCHEMA,
        "generation_id": gid,
        "book_id": roster.get("cycle_id") or roster.get("book_id") or gid,
        "status": "LAUNCHED_IMMUTABLE" if launch_timestamp_utc else "PRELAUNCH_MUTABLE",
        "launch_timestamp_utc": launch_timestamp_utc,
        "inventory_scope": "READ_ONLY_PRE_SUNDAY_REHEARSAL" if not launch_timestamp_utc else "LAUNCH",
        "demo_account": terminal_identity,
        "rules": {
            "snapshot": bindings["rules_snapshot"],
            "product": "FTMO Challenge 2-Step / USD 100000 / Standard",
            "initial_balance_usd": 100000.0,
            "phase1_profit_target_percent": 10.0,
            "verification_profit_target_percent": 5.0,
        },
        "roster": {
            "binding": bindings["roster"],
            "sleeve_count": len(sleeves),
            "sleeves": sleeves,
            "total_book_risk_percent": total_risk,
        },
        "account_risk_limits": {
            "daily_loss_percent": 5.0,
            "daily_loss_usd": 5000.0,
            "maximum_loss_percent": 10.0,
            "maximum_loss_floor_usd": 90000.0,
            "combined_open_risk_contract": "QM_AccountRiskReservation.mqh",
        },
        "daily_loss_controls": {
            "anchor_mode": next(iter(anchor_modes)) if configured_anchor else None,
            "offset_policy": "EUROPE_PRAGUE_DYNAMIC_DST" if configured_anchor else None,
            "basis": "Prague-midnight balance; equity includes open P/L, swap and commission",
            "configuration_status": "CONFIGURED" if configured_anchor else "MISSING_GOVERNED_INITIALIZER",
        },
        "maximum_loss_controls": {
            "mode": "STATIC_INITIAL_BALANCE_FLOOR",
            "floor_usd": 90000.0,
            "governor_source": bindings["governor_source"]["path"],
        },
        "kill_switch": {
            "anchor_mode": next(iter(anchor_modes)) if configured_anchor else None,
            "offset_policy": "EUROPE_PRAGUE_DYNAMIC_DST" if configured_anchor else None,
            "book_tag": next(iter(book_tags)) if configured_tag else None,
            "configuration_status": "CONFIGURED" if configured_anchor and configured_tag else "MISSING_CONFIGURATION_PROOF",
            "expected_proof_events": ["KS_DAY_ANCHOR_SET", "KS_BOOK_TAG_SET", "KS_DAY_ROLLOVER"],
        },
        "rollover_semantics": {
            "timezone": "Europe/Prague",
            "day_boundary": "00:00 Europe/Prague",
            "dst_policy": "IANA Europe/Prague; dynamic CET/CEST",
            "helper_source": "framework/include/QM/QM_FTMOGovernorPolicy.mqh",
        },
        "news_policy": {
            "source": "NATIVE_MT5_CALENDAR_LIVE",
            "blackout": "PRE30_POST30_PLUS_FTMO_COMPLIANCE",
            "fail_closed": True,
            "stale_max_hours_upper_bound": 336,
        },
        "weekend_policy": {
            "evaluation": "FTMO evaluation permits weekend holding",
            "book": "Friday flat policy from per-sleeve setfiles",
        },
        "session_policy": {
            "mode": "EA_DEFINED_HASH_BOUND",
            "evidence": "Each sleeve source and setfile are hash-bound above",
        },
        "account_governor": {
            "source": bindings["governor_source"],
            "installed_ex5": bindings["governor_ex5"],
            "setfile": bindings["governor_setfile"],
            "allowed_magics": sorted(int(x) for x in governor_values.get("allowed_magics_csv", "").split(",") if x),
            "challenge_id_masked": challenge_id,
        },
        "server_request_safety": {
            "governor_timer_ms": int(governor_values.get("governor_timer_ms") or 0),
            "close_deviation_points": int(governor_values.get("close_deviation_points") or 0),
            "provider_simultaneous_order_limit": 200,
            "provider_hyperactive_positions_per_day": 2000,
        },
        "logging": {
            "trial_directory": f"MQL5/Files/QM/ftmo_trial/{gid}",
            "kill_switch_state_glob": "MQL5/Files/QM/kill_switch/*.state",
            "governor_log": "MQL5/Files/QM/ftmo_governor_events.jsonl",
        },
        "sleeve_pnl_attribution_sidecar": str(DEFAULT_ATTRIBUTION),
        "registries": {
            "ea_id": bindings["ea_id_registry"],
            "magic": bindings["magic_registry"],
            "ea_rows": ea_rows,
            "selected_magic_rows": [active_magic[int(row["magic"])] for row in candidates],
        },
        "build_evidence": bindings["build_receipt"],
        "manifest_sha256": None,
    }
    manifest["manifest_sha256"] = manifest_digest(manifest)
    output_json.parent.mkdir(parents=True, exist_ok=True)
    output_json.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    _write_markdown(manifest, output_json.with_suffix(".md"))
    return manifest


def _all_bindings(manifest: dict[str, Any]) -> Iterable[tuple[str, dict[str, Any]]]:
    yield "rules.snapshot", manifest["rules"]["snapshot"]
    yield "roster.binding", manifest["roster"]["binding"]
    for index, sleeve in enumerate(manifest["roster"]["sleeves"]):
        prefix = f"sleeve[{index}]:{sleeve['ea_id']}"
        yield f"{prefix}.source", sleeve["source"]
        yield f"{prefix}.installed_ex5", sleeve["installed_ex5"]
        yield f"{prefix}.setfile", sleeve["setfile"]
    yield "governor.source", manifest["account_governor"]["source"]
    yield "governor.installed_ex5", manifest["account_governor"]["installed_ex5"]
    yield "governor.setfile", manifest["account_governor"]["setfile"]
    yield "registries.ea_id", manifest["registries"]["ea_id"]
    yield "registries.magic", manifest["registries"]["magic"]
    yield "build_evidence", manifest["build_evidence"]


def verify_manifest(manifest_or_path: dict[str, Any] | Path | str) -> dict[str, Any]:
    manifest_path: Path | None = None
    if isinstance(manifest_or_path, dict):
        manifest = manifest_or_path
    else:
        manifest_path = Path(manifest_or_path).resolve()
        manifest = _load_json(manifest_path)
    rows: list[dict[str, Any]] = []
    expected_self = manifest.get("manifest_sha256")
    actual_self = manifest_digest(manifest)
    rows.append(
        {
            "item": "manifest",
            "path": str(manifest_path) if manifest_path else None,
            "expected_sha256": expected_self,
            "actual_sha256": actual_self,
            "state": "MATCH" if expected_self == actual_self else "DRIFT",
        }
    )
    for item, binding in _all_bindings(manifest):
        path = Path(binding["resolved_path"])
        actual = sha256_file(path) if path.is_file() else None
        expected = binding.get("sha256")
        rows.append(
            {
                "item": item,
                "path": str(path),
                "expected_sha256": expected,
                "actual_sha256": actual,
                "state": "MATCH" if actual == expected else "DRIFT",
            }
        )
    # Re-evaluate deterministic registry semantics, not only their bytes.
    registry_ok, registry_reason = _verify_registry_semantics(manifest)
    rows.append(
        {
            "item": "registry_semantics",
            "path": manifest["registries"]["magic"]["resolved_path"],
            "expected_sha256": None,
            "actual_sha256": None,
            "state": "MATCH" if registry_ok else "DRIFT",
            "reason": registry_reason,
        }
    )
    drift = [row for row in rows if row["state"] == "DRIFT"]
    return {
        "schema": "qm.ftmo-demo-genesis-verify/v1",
        "manifest": str(manifest_path) if manifest_path else None,
        "generation_id": manifest.get("generation_id"),
        "status": "PASS" if not drift else "DRIFT",
        "drift_count": len(drift),
        "items": rows,
    }


def _verify_registry_semantics(manifest: dict[str, Any]) -> tuple[bool, str]:
    try:
        ea_path = Path(manifest["registries"]["ea_id"]["resolved_path"])
        magic_path = Path(manifest["registries"]["magic"]["resolved_path"])
        sleeves = manifest["roster"]["sleeves"]
        ids = {int(row["ea_id"]) for row in sleeves}
        ea_rows = _registry_rows(ea_path, ids, magic=False)
        magic_rows = _registry_rows(magic_path, ids, magic=True)
        active_ids = {int(row["ea_id"]) for row in ea_rows if row.get("status") == "active"}
        active_magic = {
            int(row["magic"]): row for row in magic_rows if row.get("status") == "active"
        }
        for sleeve in sleeves:
            ea_id, magic, slot = int(sleeve["ea_id"]), int(sleeve["magic"]), int(sleeve["slot"])
            if ea_id not in active_ids or magic != ea_id * 10000 + slot:
                return False, f"inactive_or_formula_mismatch:{ea_id}:{magic}"
            row = active_magic.get(magic)
            if row is None or row.get("symbol") != f"{sleeve['symbol']}.DWX":
                return False, f"magic_row_mismatch:{magic}"
    except (KeyError, OSError, ValueError, ManifestError) as exc:
        return False, f"registry_check_error:{exc}"
    return True, "selected EA IDs and magic rows are active, unique, and formula-consistent"


def seal_launch(path: Path, timestamp: str) -> dict[str, Any]:
    manifest = _load_json(path)
    if manifest.get("launch_timestamp_utc"):
        raise ManifestError(f"launched_manifest_immutable:{path}")
    try:
        parsed = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    except ValueError as exc:
        raise ManifestError(f"launch_timestamp_invalid:{timestamp}") from exc
    if parsed.tzinfo is None or parsed.utcoffset() != timezone.utc.utcoffset(parsed):
        raise ManifestError("launch_timestamp_must_be_utc")
    manifest["launch_timestamp_utc"] = parsed.astimezone(timezone.utc).isoformat().replace(
        "+00:00", "Z"
    )
    manifest["status"] = "LAUNCHED_IMMUTABLE"
    manifest["inventory_scope"] = "LAUNCH"
    manifest["manifest_sha256"] = manifest_digest(manifest)
    path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    _write_markdown(manifest, path.with_suffix(".md"))
    return manifest


def _write_markdown(manifest: dict[str, Any], path: Path) -> None:
    account = manifest["demo_account"]
    lines = [
        f"# FTMO Demo Genesis Manifest — {manifest['generation_id']}",
        "",
        f"Status: **{manifest['status']}**  ",
        f"Manifest SHA-256: `{manifest['manifest_sha256']}`  ",
        f"Launch timestamp UTC: `{manifest.get('launch_timestamp_utc')}`",
        "",
        "## Account and book",
        "",
        f"- Account: `{account['login_masked']}` on `{account['server']}`; terminal `{account['terminal_id']}`.",
        f"- AutoTrading at inventory: `{account['autotrading_enabled_at_inventory']}`.",
        f"- Sleeves: `{manifest['roster']['sleeve_count']}`; total book risk: `{manifest['roster']['total_book_risk_percent']}%`.",
        f"- Kill-switch configuration: `{manifest['kill_switch']['configuration_status']}`.",
        "",
        "## Hash-bound sleeves",
        "",
        "| EA | Symbol/TF | Magic | Role | Risk % | Source | EX5 | Set |",
        "|---|---|---:|---|---:|---|---|---|",
    ]
    for sleeve in manifest["roster"]["sleeves"]:
        lines.append(
            f"| {sleeve['ea_label']} | {sleeve['symbol']}/{sleeve['timeframe']} | "
            f"{sleeve['magic']} | {sleeve['role']} | {sleeve['risk_percent']} | "
            f"`{sleeve['source']['sha256'][:12]}` | "
            f"`{sleeve['installed_ex5']['sha256'][:12]}` | "
            f"`{sleeve['setfile']['sha256'][:12]}` |"
        )
    lines += [
        "",
        "This document is a rendering of the adjacent canonical JSON. Verification recomputes every bound hash and registry semantic. The tool performs no terminal mutation.",
        "",
    ]
    path.write_text("\n".join(lines), encoding="utf-8")


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("build", help="inventory artifacts and write JSON + Markdown")
    build.add_argument("--roster", type=Path, required=True)
    build.add_argument("--output-json", type=Path, required=True)
    build.add_argument("--repo", type=Path, default=DEFAULT_REPO)
    build.add_argument("--terminal", type=Path, default=DEFAULT_TERMINAL)
    build.add_argument("--package", type=Path, default=DEFAULT_PACKAGE)
    build.add_argument("--rules-snapshot", type=Path, default=DEFAULT_RULES)
    build.add_argument("--book-state", type=Path, default=DEFAULT_BOOK_STATE)
    build.add_argument("--governor-set", type=Path, default=DEFAULT_GOVERNOR_SET)
    build.add_argument("--generation-id")
    build.add_argument("--launch-timestamp-utc")
    build.add_argument("--build-receipt", type=Path)
    verify = sub.add_parser("verify", help="report MATCH/DRIFT for every binding")
    verify.add_argument("manifest", type=Path)
    verify.add_argument("--report", type=Path)
    seal = sub.add_parser("seal-launch", help="set launch timestamp once, then make immutable")
    seal.add_argument("manifest", type=Path)
    seal.add_argument("--timestamp-utc", required=True)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)
    try:
        if args.command == "build":
            manifest = build_manifest(
                roster_path=args.roster,
                output_json=args.output_json,
                repo=args.repo,
                terminal=args.terminal,
                package=args.package,
                rules_snapshot=args.rules_snapshot,
                book_state=args.book_state,
                governor_set=args.governor_set,
                generation_id=args.generation_id,
                launch_timestamp_utc=args.launch_timestamp_utc,
                build_receipt=args.build_receipt,
            )
            print(json.dumps({"status": "BUILT", "manifest_sha256": manifest["manifest_sha256"], "path": str(args.output_json)}))
            return 0
        if args.command == "seal-launch":
            manifest = seal_launch(args.manifest, args.timestamp_utc)
            print(json.dumps({"status": manifest["status"], "manifest_sha256": manifest["manifest_sha256"]}))
            return 0
        report = verify_manifest(args.manifest)
        rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
        if args.report:
            args.report.parent.mkdir(parents=True, exist_ok=True)
            args.report.write_text(rendered, encoding="utf-8")
        print(rendered, end="")
        return 0 if report["status"] == "PASS" else 2
    except ManifestError as exc:
        print(json.dumps({"status": "REFUSED", "reason": str(exc)}), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
