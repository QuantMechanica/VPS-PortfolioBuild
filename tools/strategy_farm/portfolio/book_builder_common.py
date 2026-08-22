"""Pure helpers shared by the DL-084 dual-venue book builders.

The helpers read manifests, sealed trade streams, and repository registries only.
They never touch a terminal, the farm database, or a deployment surface.
"""
from __future__ import annotations

import csv
import hashlib
import json
import math
import re
from pathlib import Path
from typing import Any, Iterable, Mapping

from tools.strategy_farm.portfolio.marginal_contribution_eval import capnorm
from tools.strategy_farm.portfolio.portfolio_common import align, load_streams, to_daily_pnl
from tools.strategy_farm.portfolio.portfolio_kpi import metrics_from_daily_pnl


SCHEMA = "qm.dual-book-roster/v1"
Key = tuple[int, str]


class BookBuildError(ValueError):
    """Fail-closed input, provenance, or arithmetic error."""


def canonical_json(value: Any) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=True)


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def file_binding(path: Path) -> dict[str, Any]:
    target = path.expanduser().resolve()
    if not target.is_file():
        raise BookBuildError(f"required file is missing: {target}")
    return {
        "path": str(target),
        "sha256": sha256_file(target),
        "size_bytes": target.stat().st_size,
    }


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise BookBuildError(f"cannot read JSON {path}: {exc}") from exc


def key_from_row(row: Mapping[str, Any], label: str) -> Key:
    try:
        ea_id = int(str(row["ea_id"]).upper().replace("QM5_", ""))
        symbol = str(row["symbol"]).strip().upper()
    except (KeyError, TypeError, ValueError) as exc:
        raise BookBuildError(f"{label} has no valid ea_id/symbol") from exc
    if not symbol:
        raise BookBuildError(f"{label} has an empty symbol")
    if "." not in symbol:
        symbol += ".DWX"
    return ea_id, symbol


def key_object(key: Key) -> dict[str, Any]:
    return {"ea_id": key[0], "symbol": key[1]}


def _unique(keys: Iterable[Key], label: str) -> list[Key]:
    result: list[Key] = []
    seen: set[Key] = set()
    for key in keys:
        if key in seen:
            raise BookBuildError(f"duplicate {label} sleeve: {key[0]}:{key[1]}")
        seen.add(key)
        result.append(key)
    return result


def resolve_roster(path: Path) -> tuple[list[Key], dict[str, Any]]:
    """Resolve Q10-PASS parents plus Q16 decisions from an explicit input.

    A conventional book manifest is accepted as an explicit frozen Q10 roster for
    reproducible incumbent dry-runs. New optimization runs should use
    ``qm.dual-book-roster/v1`` so every Q16 replacement/addition is declared.
    """
    payload = load_json(path)
    if not isinstance(payload, Mapping):
        raise BookBuildError("roster input must be a JSON object")
    source_binding = file_binding(path)
    if payload.get("schema") != SCHEMA:
        rows = payload.get("sleeves")
        if not isinstance(rows, list):
            raise BookBuildError(f"roster must be {SCHEMA} or contain a sleeves list")
        keys = _unique((key_from_row(row, "manifest sleeve") for row in rows), "manifest")
        return sorted(keys), {
            "mode": "EXPLICIT_FROZEN_Q10_ROSTER_MANIFEST",
            "input": source_binding,
            "q16_outcomes_applied": [],
        }

    rows = payload.get("q10_pass")
    if not isinstance(rows, list):
        raise BookBuildError("dual-book roster q10_pass must be a list")
    parents: list[Key] = []
    for index, row in enumerate(rows):
        if not isinstance(row, Mapping):
            raise BookBuildError(f"q10_pass[{index}] must be an object")
        verdict = str(row.get("q10_verdict", "PASS")).upper()
        if verdict != "PASS":
            raise BookBuildError(f"q10_pass[{index}] verdict is {verdict}, not PASS")
        parents.append(key_from_row(row, f"q10_pass[{index}]"))
    roster = set(_unique(parents, "Q10"))
    applied: list[dict[str, Any]] = []
    outcomes = payload.get("q16_outcomes", [])
    if not isinstance(outcomes, list):
        raise BookBuildError("q16_outcomes must be a list")
    for index, outcome in enumerate(outcomes):
        if not isinstance(outcome, Mapping):
            raise BookBuildError(f"q16_outcomes[{index}] must be an object")
        verdict = str(outcome.get("verdict", "")).upper()
        if verdict not in {"PROMOTE_CHALLENGER", "KEEP_INCUMBENT", "ADMIT_BOTH", "FAIL"}:
            raise BookBuildError(f"q16_outcomes[{index}] has unsupported verdict {verdict!r}")
        parent_raw = outcome.get("parent")
        challenger_raw = outcome.get("challenger")
        if not isinstance(parent_raw, Mapping) or not isinstance(challenger_raw, Mapping):
            raise BookBuildError(f"q16_outcomes[{index}] needs parent and challenger objects")
        parent = key_from_row(parent_raw, f"q16_outcomes[{index}].parent")
        challenger = key_from_row(challenger_raw, f"q16_outcomes[{index}].challenger")
        if parent not in roster:
            raise BookBuildError(f"Q16 parent is absent from Q10 roster: {parent}")
        challenger_q10 = str(outcome.get("challenger_q10_verdict", "")).upper()
        if verdict in {"PROMOTE_CHALLENGER", "ADMIT_BOTH"} and challenger_q10 != "PASS":
            raise BookBuildError(f"Q16 {verdict} challenger lacks declared Q10 PASS: {challenger}")
        if verdict == "PROMOTE_CHALLENGER":
            roster.remove(parent)
            roster.add(challenger)
        elif verdict == "ADMIT_BOTH":
            roster.add(challenger)
        applied.append({
            "verdict": verdict,
            "parent": key_object(parent),
            "challenger": key_object(challenger),
        })
    return sorted(roster), {
        "mode": SCHEMA,
        "input": source_binding,
        "q16_outcomes_applied": applied,
    }


def load_magic_registry(path: Path) -> dict[Key, int]:
    binding = file_binding(path)
    del binding
    result: dict[Key, int] = {}
    with path.open(newline="", encoding="utf-8-sig") as handle:
        for row in csv.DictReader(handle):
            try:
                key = (int(row["ea_id"]), str(row["symbol"]).upper())
                magic = int(row["magic"])
            except (KeyError, TypeError, ValueError):
                continue
            if str(row.get("status", "active")).lower() == "active":
                result[key] = magic
    return result


def _set_value(text: str, name: str) -> float | None:
    match = re.search(rf"(?m)^\s*{re.escape(name)}\s*=\s*([-+0-9.eE]+)\s*$", text)
    return float(match.group(1)) if match else None


def resolve_setfile(repo_root: Path, key: Key) -> tuple[Path, float, float]:
    ea_id, symbol = key
    ea_dirs = sorted((repo_root / "framework" / "EAs").glob(f"QM5_{ea_id}_*"))
    if not ea_dirs:
        raise BookBuildError(f"repository EA directory missing for QM5_{ea_id}")
    candidates = sorted(
        candidate
        for ea_dir in ea_dirs
        for candidate in (ea_dir / "sets").glob(f"*_{symbol}_*_backtest.set")
    )
    canonical_name = re.compile(
        rf"^QM5_{ea_id}_.+_{re.escape(symbol)}_[A-Z0-9]+_backtest\.set$",
        re.IGNORECASE,
    )
    exact = [candidate for candidate in candidates if canonical_name.match(candidate.name)]
    if len(exact) != 1:
        exact = []
        for candidate in sorted(
            candidate
            for ea_dir in ea_dirs
            for candidate in (ea_dir / "sets").glob("*_backtest.set")
        ):
            try:
                body = candidate.read_text(encoding="utf-8-sig")
            except (OSError, UnicodeError):
                continue
            header = re.search(r"(?mi)^;\s*symbol\s*:\s*(\S+)\s*$", body)
            host = re.search(r"(?mi)^;\s*host_symbol\s*:\s*(\S+)\s*$", body)
            declared = {m.group(1).upper() for m in (header, host) if m}
            if symbol in declared:
                exact.append(candidate)
    if len(exact) != 1:
        raise BookBuildError(f"expected one backtest set for {ea_id}:{symbol}, found {len(exact)}")
    text = exact[0].read_text(encoding="utf-8-sig")
    risk_fixed = _set_value(text, "RISK_FIXED")
    risk_percent = _set_value(text, "RISK_PERCENT")
    if risk_fixed is None or risk_fixed <= 0 or risk_percent != 0:
        raise BookBuildError(
            f"unsafe backtest risk controls in {exact[0]}: "
            f"RISK_FIXED={risk_fixed}, RISK_PERCENT={risk_percent}"
        )
    return exact[0].resolve(), float(risk_fixed), float(risk_percent)


def sleeve_bindings(repo_root: Path, keys: Iterable[Key]) -> list[dict[str, Any]]:
    magic_path = repo_root / "framework" / "registry" / "magic_numbers.csv"
    magics = load_magic_registry(magic_path)
    result: list[dict[str, Any]] = []
    for key in sorted(keys):
        if key not in magics:
            raise BookBuildError(f"active magic registry row missing for {key[0]}:{key[1]}")
        setfile, risk_fixed, risk_percent = resolve_setfile(repo_root, key)
        result.append({
            **key_object(key),
            "magic": magics[key],
            "setfile": str(setfile.relative_to(repo_root)).replace("\\", "/"),
            "setfile_sha256": sha256_file(setfile),
            "backtest_risk_fixed": risk_fixed,
            "backtest_risk_percent": risk_percent,
        })
    return result


def roster_sha256(rows: Iterable[Mapping[str, Any]]) -> str:
    identity = [
        {"ea_id": int(row["ea_id"]), "symbol": str(row["symbol"]).upper()}
        for row in rows
    ]
    return sha256_bytes(canonical_json(sorted(identity, key=lambda x: (x["ea_id"], x["symbol"]))).encode())


def load_daily(stream_root: Path, keys: list[Key]) -> tuple[dict[Key, dict], dict[str, Any]]:
    streams = load_streams(stream_root, candidates=keys)
    missing = sorted(set(keys) - set(streams))
    if missing:
        labels = ", ".join(f"{ea}:{symbol}" for ea, symbol in missing)
        raise BookBuildError(f"sealed stream basis is missing roster sleeves: {labels}")
    daily = {key: to_daily_pnl(streams[key]) for key in keys}
    empty = [key for key, values in daily.items() if not values]
    if empty:
        raise BookBuildError(f"sealed stream basis contains empty sleeves: {empty}")
    q08_dir = stream_root / "QM" / "q08_trades"
    hashes = {}
    for key in keys:
        filename = f"{key[0]}_{key[1].replace('.', '_')}.jsonl"
        candidate = q08_dir / filename
        if candidate.is_file():
            hashes[f"{key[0]}:{key[1]}"] = sha256_file(candidate)
    return daily, {
        "root": str(stream_root.resolve()),
        "stream_count": len(streams),
        "stream_sha256": hashes,
    }


def common_window(daily: Mapping[Key, Mapping[Any, float]], keys: Iterable[Key]) -> tuple[Any, Any]:
    selected = list(keys)
    start = max(min(daily[key]) for key in selected)
    end = min(max(daily[key]) for key in selected)
    if start > end:
        raise BookBuildError("roster streams have no common history")
    return start, end


def aligned_matrix(
    daily: Mapping[Key, Mapping[Any, float]], keys: list[Key], start: Any, end: Any
) -> tuple[list[Key], list[Any], list[list[float]]]:
    clipped = {
        key: {day: pnl for day, pnl in daily[key].items() if start <= day <= end}
        for key in keys
    }
    aligned_keys, dates, matrix = align(clipped)
    rows = [[float(matrix[r][c]) for c in range(len(aligned_keys))] for r in range(len(dates))]
    if not dates:
        raise BookBuildError("common history produced no aligned days")
    return list(aligned_keys), list(dates), rows


def _column_std(matrix: list[list[float]], column: int) -> float:
    values = [row[column] for row in matrix]
    mean = sum(values) / len(values)
    return math.sqrt(sum((value - mean) ** 2 for value in values) / len(values))


def capped_inverse_vol(
    keys: list[Key], matrix: list[list[float]], *, total: float, cap: float,
    overlay: Mapping[Key, float] | None = None,
) -> dict[Key, float]:
    scores = []
    for column, key in enumerate(keys):
        volatility = _column_std(matrix, column)
        score = 1.0 / volatility if volatility > 0 else 0.0
        score *= float((overlay or {}).get(key, 1.0))
        scores.append(score)
    weights = capnorm(scores, total, cap)
    if abs(sum(weights) - total) > 1e-8:
        raise BookBuildError("capped inverse-vol solve did not exhaust the risk budget")
    if any(weight > cap + 1e-8 for weight in weights):
        raise BookBuildError("capped inverse-vol solve exceeded the sleeve cap")
    return {key: weights[index] for index, key in enumerate(keys)}


def portfolio_daily(
    keys: list[Key], matrix: list[list[float]], weights: Mapping[Key, float]
) -> list[float]:
    return [sum(row[column] * float(weights.get(key, 0.0)) for column, key in enumerate(keys)) for row in matrix]


def book_metrics(daily_pnl: list[float], n_sleeves: int, starting_capital: float) -> dict[str, Any]:
    result = metrics_from_daily_pnl(
        daily_pnl, n_sleeves=n_sleeves, starting_capital=starting_capital
    )
    n_days = len(daily_pnl)
    years = max(n_days / 252.0, 1.0 / 252.0)
    annual_return = sum(daily_pnl) / starting_capital * 100.0 / years
    maxdd = float(result["max_drawdown_pct"])
    return {
        "annual_return_pct": round(annual_return, 6),
        "return_to_maxdd": round(annual_return / maxdd, 6) if maxdd > 0 else None,
        "worst_day_pct": round(min(daily_pnl) / starting_capital * 100.0, 6),
        "max_drawdown_pct": round(maxdd, 6),
        "sharpe": result.get("sharpe"),
        "total_net_of_cost_profit": result.get("total_net_of_cost_profit"),
        "n_days": n_days,
        "n_sleeves": n_sleeves,
    }


def load_cluster_overlay(path: Path | None) -> tuple[dict[Key, float], dict[str, Any]]:
    if path is None:
        return {}, {"status": "NOT_PROVIDED", "applied": False}
    payload = load_json(path)
    if not isinstance(payload, Mapping) or not isinstance(payload.get("rows"), list):
        raise BookBuildError("cluster overlay must contain a rows list")
    overlay: dict[Key, float] = {}
    for index, row in enumerate(payload["rows"]):
        if not isinstance(row, Mapping):
            raise BookBuildError(f"cluster overlay row {index} is not an object")
        key = key_from_row(row, f"cluster overlay row {index}")
        try:
            multiplier = float(row["weight_multiplier"])
        except (KeyError, TypeError, ValueError) as exc:
            raise BookBuildError(f"cluster overlay row {index} lacks weight_multiplier") from exc
        if not math.isfinite(multiplier) or multiplier <= 0:
            raise BookBuildError(f"cluster overlay multiplier must be finite and positive: {key}")
        overlay[key] = multiplier
    return overlay, {"status": "APPLIED", "applied": True, "input": file_binding(path)}


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value.rstrip() + "\n", encoding="utf-8")


def validate_dual_book_manifest(value: Mapping[str, Any]) -> None:
    """Dependency-free enforcement of the schema's safety-critical subset."""
    required = {
        "schema", "lane", "as_of", "execution_mode", "status",
        "application_authority", "deployment_action", "autotrading_action",
        "roster_sha256", "sleeve_list_sha256", "sleeves",
    }
    missing = sorted(required - set(value))
    if missing:
        raise BookBuildError(f"dual-book manifest required fields missing: {missing}")
    if value["schema"] != "qm.dual-book-manifest/v1":
        raise BookBuildError("dual-book manifest schema id is invalid")
    lane = value["lane"]
    if lane not in {"Q11_DXZ", "Q11_FTMO"}:
        raise BookBuildError(f"invalid dual-book lane: {lane}")
    if value["execution_mode"] != "DRY_RUN":
        raise BookBuildError("dual-book manifests must be DRY_RUN")
    if value["application_authority"] != "OWNER_ONLY":
        raise BookBuildError("dual-book application authority must remain OWNER_ONLY")
    if value["deployment_action"] != "NONE" or value["autotrading_action"] != "NONE":
        raise BookBuildError("dual-book builders cannot emit deployment or AutoTrading actions")
    concentration = value.get("concentration_tail")
    if not isinstance(concentration, Mapping):
        raise BookBuildError("dual-book manifest lacks SP-C3 concentration_tail evidence")
    if concentration.get("schema") != "qm.concentration-tail-report/v1":
        raise BookBuildError("dual-book concentration_tail schema is invalid")
    if concentration.get("application_authority") != "OWNER_ONLY":
        raise BookBuildError("concentration policy application authority must remain OWNER_ONLY")
    if concentration.get("deployment_action") != "NONE" or concentration.get("autotrading_action") != "NONE":
        raise BookBuildError("concentration evidence cannot emit deployment or AutoTrading actions")
    if concentration.get("builder_eligible") is True and concentration.get("policy_status") != "OWNER_RATIFIED":
        raise BookBuildError("unratified concentration policy cannot mint builder eligibility")
    if value["status"] in {"APPLY_RECOMMENDED", "BAR_MET_OWNER_REVIEW"} and concentration.get("builder_eligible") is not True:
        raise BookBuildError("positive book status requires SP-C3 builder eligibility")
    rows = value["sleeves"]
    if not isinstance(rows, list):
        raise BookBuildError("dual-book sleeves must be a list")
    for index, row in enumerate(rows):
        if not isinstance(row, Mapping):
            raise BookBuildError(f"dual-book sleeve {index} is not an object")
        needed = {"ea_id", "symbol", "magic", "setfile", "setfile_sha256", "weight"}
        if needed - set(row):
            raise BookBuildError(f"dual-book sleeve {index} is incomplete")
        if float(row["weight"]) <= 0:
            raise BookBuildError(f"dual-book sleeve {index} weight is not positive")
        for risk_name in ("risk_percent", "risk_percent_source", "backtest_risk_percent"):
            if risk_name in row and float(row[risk_name]) != 0:
                raise BookBuildError(f"dual-book sleeve {index} violates {risk_name}=0")
        for risk_name in ("risk_fixed", "risk_fixed_source", "backtest_risk_fixed"):
            if risk_name in row and float(row[risk_name]) <= 0:
                raise BookBuildError(f"dual-book sleeve {index} violates {risk_name}>0")
    actual_sleeve_hash = sha256_bytes(canonical_json(rows).encode("ascii"))
    if value["sleeve_list_sha256"] != actual_sleeve_hash:
        raise BookBuildError("dual-book sleeve-list hash does not match its body")
    if value["roster_sha256"] != roster_sha256(rows):
        raise BookBuildError("dual-book roster hash does not match its sleeve identities")
    if lane == "Q11_DXZ" and not {"weighting", "comparison", "stream_basis"} <= set(value):
        raise BookBuildError("Q11_DXZ manifest lacks weighting/comparison/stream evidence")
    if lane == "Q11_FTMO":
        ftmo_required = {"challenge_recommendation", "fund_score", "density", "ftmo_cost_swap", "phase1_bootstrap", "bar"}
        if not ftmo_required <= set(value):
            raise BookBuildError("Q11_FTMO manifest lacks fail-closed bar evidence")
        if value["challenge_recommendation"] != "NONE":
            raise BookBuildError("Q11_FTMO builder cannot recommend a challenge")
