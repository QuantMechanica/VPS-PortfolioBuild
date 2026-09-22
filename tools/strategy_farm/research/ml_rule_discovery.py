#!/usr/bin/env python3
"""Offline interpretable rule discovery over closed session features.

Permitted ML/statistics are research instruments only.  This tool implements
deterministic shallow CART (depth <= 3), sparse association/rule lists, and a
small gradient-boosted-stump importance ranking.  It emits no model file and
no runtime inference contract: surviving outputs are boolean conjunctions
that can be executed mechanically in the shared F2 engine.

Discovery is 2018-07..2021-12, rule-selection validation is calendar 2022,
and no 2023-2025 HCC file is opened.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import sys
from collections import defaultdict
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
from typing import Any

import numpy as np

REPO = Path("C:/QM/repo")
RESEARCH = Path(__file__).resolve().parent
if str(RESEARCH) not in sys.path:
    sys.path.insert(0, str(RESEARCH))

import cross_symbol_scanner as CSCAN  # noqa: E402
import session_features as SF  # noqa: E402


SCHEMA = "qm.offline-mechanical-rule-discovery/v2"
SEED = 20260922
MIN_SUPPORT = 0.02
MIN_N = 30
FDR_Q = 0.10
TREE_MAX_DEPTH = 3
BOOST_ROUNDS = 10
BOOST_LEARNING_RATE = 0.20


def _sha(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for block in iter(lambda: fh.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def atomic_specs(feature_names: list[str]) -> list[dict[str, Any]]:
    specs = []
    for name in sorted(feature_names):
        if name.endswith("_return_atr"):
            vals, ops = (-1.0, -0.5, 0.0, 0.5, 1.0), ("<=", ">=")
        elif name.endswith("_range_atr"):
            vals, ops = (0.5, 1.0, 1.5, 2.0), ("<=", ">=")
        elif name.endswith("_vol_ratio"):
            vals, ops = (0.8, 1.0, 1.2), ("<=", ">=")
        elif name.endswith("_prior_day_position"):
            vals, ops = (0.2, 0.5, 0.8), ("<=", ">=")
        elif name.endswith("_overnight_gap_atr"):
            vals, ops = (-0.5, -0.25, 0.0, 0.25, 0.5), ("<=", ">=")
        elif name.endswith("_compression"):
            vals, ops = (1,), ("==",)
        elif name.endswith("_ma_regime") or name.endswith("_asia_fvg_sign"):
            vals, ops = (-1, 0, 1), ("==",)
        elif name.endswith("_asia_fvg_count"):
            vals, ops = (1, 2), (">=",)
        elif name == "target_day_of_week":
            vals, ops = tuple(range(5)), ("==",)
        elif name == "feature_time_of_day":
            vals, ops = tuple(range(len(CSCAN.SESSION_ORDER))), ("==",)
        else:
            continue
        for op in ops:
            for value in vals:
                specs.append({"feature": name, "op": op, "value": value, "negated": False})
    return specs


def atom_key(atom: dict[str, Any]) -> str:
    return f"{'NOT:' if atom.get('negated') else ''}{atom['feature']}:{atom['op']}:{atom['value']}"


def atom_mask(values: np.ndarray, atom: dict[str, Any]) -> np.ndarray:
    finite = np.isfinite(values)
    op, value = atom["op"], float(atom["value"])
    if op == ">=":
        mask = finite & (values >= value)
    elif op == "<=":
        mask = finite & (values <= value)
    elif op == "==":
        mask = finite & (values == value)
    else:
        raise ValueError(op)
    # A missing value is never evidence that a negated condition is true.
    # Both positive and negated atoms therefore fail closed on NaN.
    return (finite & ~mask) if atom.get("negated") else mask


def rule_key(atoms: list[dict[str, Any]]) -> str:
    return "&".join(sorted(atom_key(a) for a in atoms))


def rule_mask(columns: dict[str, np.ndarray], atoms: list[dict[str, Any]]) -> np.ndarray:
    n = len(next(iter(columns.values())))
    mask = np.ones(n, dtype=bool)
    for atom in atoms:
        mask &= atom_mask(columns[atom["feature"]], atom)
    return mask


def mechanical_rule_matches(rule: dict[str, Any], features: dict[str, float | int | None]) -> bool:
    """Execute the model-free boolean condition emitted for the F2 family."""
    if rule.get("schema") != "qm.f2-mechanical-session-rule/v1":
        raise ValueError("unsupported mechanical rule schema")
    for atom in rule["all"]:
        raw = features.get(atom["feature"])
        value = np.array([np.nan if raw is None else float(raw)], dtype=float)
        if not bool(atom_mask(value, atom)[0]):
            return False
    return True


def _stats(values: np.ndarray) -> dict[str, Any]:
    n = int(values.size)
    if not n:
        return {"n": 0, "mean_net_r": None, "median_net_r": None, "t_stat": None, "p_one_sided": 1.0, "hit_rate": None}
    mean = float(values.mean())
    if n > 1:
        sd = float(values.std(ddof=1))
        t = mean / (sd / math.sqrt(n)) if sd > 0 else (math.inf if mean > 0 else -math.inf)
        p = 0.5 * math.erfc(t / math.sqrt(2)) if math.isfinite(t) else (0.0 if t > 0 else 1.0)
    else:
        t, p = None, 1.0
    return {
        "n": n, "mean_net_r": round(mean, 8), "median_net_r": round(float(np.median(values)), 8),
        "t_stat": None if t is None else ("INF" if t == math.inf else ("-INF" if t == -math.inf else round(t, 8))),
        "p_one_sided": float(max(0.0, min(1.0, p))), "hit_rate": round(float((values > 0).mean()), 8),
    }


def _columns(rows: list[dict[str, Any]], names: list[str]) -> dict[str, np.ndarray]:
    return {name: np.array([float(r["features"].get(name)) if r["features"].get(name) is not None else np.nan for r in rows], dtype=float) for name in names}


def _split_rows(rows: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    discovery = [r for r in rows if dt.date.fromisoformat(r["target_day"]) <= SF.DISCOVERY_END]
    validation = [r for r in rows if SF.VALIDATION_START <= dt.date.fromisoformat(r["target_day"]) <= SF.END]
    if any(dt.date.fromisoformat(r["target_day"]).year >= 2023 for r in rows):
        raise AssertionError("HELDOUT_2023_2025_TOUCHED")
    return discovery, validation


def _rank_atoms(atoms: list[dict[str, Any]], masks: dict[str, np.ndarray], y: np.ndarray) -> list[tuple[float, dict[str, Any]]]:
    baseline = float(y.mean()) if y.size else 0.0
    ranked = []
    for atom in atoms:
        mask = masks[atom_key(atom)]
        if not mask.any() or mask.all():
            continue
        score = abs(float(y[mask].mean()) - baseline) * math.sqrt(int(mask.sum()))
        ranked.append((score, atom))
    return sorted(ranked, key=lambda x: (-x[0], atom_key(x[1])))


def boosted_stump_importance(atoms: list[dict[str, Any]], masks: dict[str, np.ndarray], y: np.ndarray) -> list[dict[str, Any]]:
    if y.size == 0:
        return []
    ranked = _rank_atoms(atoms, masks, y)[:32]
    candidates = [a for _, a in ranked]
    pred = np.full(y.size, float(y.mean()))
    importance: dict[str, dict[str, float]] = defaultdict(lambda: {"gain": 0.0, "mean_abs_additive_contribution": 0.0, "rounds": 0})
    for _ in range(BOOST_ROUNDS):
        residual = y - pred
        base_sse = float(np.square(residual).sum())
        best = None
        for atom in candidates:
            m = masks[atom_key(atom)]
            if m.sum() < MIN_N or (~m).sum() < MIN_N:
                continue
            a, b = float(residual[m].mean()), float(residual[~m].mean())
            sse = float(np.square(residual[m] - a).sum() + np.square(residual[~m] - b).sum())
            gain = base_sse - sse
            candidate = (gain, atom_key(atom), atom, a, b, m)
            if best is None or candidate[:2] > best[:2]:
                best = candidate
        if best is None or best[0] <= 0:
            break
        gain, _key, atom, a, b, mask = best
        update = np.where(mask, a, b) * BOOST_LEARNING_RATE
        pred += update
        item = importance[atom["feature"]]
        item["gain"] += gain
        item["mean_abs_additive_contribution"] += float(np.abs(update).mean())
        item["rounds"] += 1
    return [
        {"feature": name, "gain": round(v["gain"], 8), "shap_style_mean_abs_contribution": round(v["mean_abs_additive_contribution"], 8), "rounds": int(v["rounds"])}
        for name, v in sorted(importance.items(), key=lambda kv: (-kv[1]["gain"], kv[0]))
    ]


def cart_leaf_rules(
    ranked_atoms: list[dict[str, Any]], masks: dict[str, np.ndarray],
    available: dict[str, np.ndarray], y: np.ndarray,
) -> list[list[dict[str, Any]]]:
    leaves: list[list[dict[str, Any]]] = []

    def walk(indices: np.ndarray, path: list[dict[str, Any]], depth: int, used: set[str]) -> None:
        if depth >= TREE_MAX_DEPTH or indices.sum() < 2 * MIN_N:
            if indices.sum() >= MIN_N:
                leaves.append(path)
            return
        current = y[indices]
        base = float(np.square(current - current.mean()).sum())
        best = None
        for atom in ranked_atoms[:20]:
            key = atom_key(atom)
            if key in used:
                continue
            present = indices & available[atom["feature"]]
            left, right = present & masks[key], present & ~masks[key]
            if left.sum() < MIN_N or right.sum() < MIN_N:
                continue
            missing = indices & ~available[atom["feature"]]
            # Missing rows stay at the parent prediction and cannot create an
            # artificial split gain by disappearing from the comparison.
            sse = float(
                np.square(y[left] - y[left].mean()).sum()
                + np.square(y[right] - y[right].mean()).sum()
                + np.square(y[missing] - current.mean()).sum()
            )
            gain = base - sse
            cand = (gain, key, atom, left, right)
            if best is None or cand[:2] > best[:2]:
                best = cand
        if best is None or best[0] <= 0:
            leaves.append(path); return
        _gain, key, atom, left, right = best
        walk(left, path + [dict(atom)], depth + 1, used | {key})
        neg = dict(atom); neg["negated"] = not bool(neg.get("negated"))
        walk(right, path + [neg], depth + 1, used | {key})

    walk(np.ones(y.size, dtype=bool), [], 0, set())
    return [rule for rule in leaves if rule]


def discover_group(rows: list[dict[str, Any]], group_id: str) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    discovery, validation = _split_rows(rows)
    if len(discovery) < MIN_N or len(validation) < MIN_N:
        return [], {
            "group_id": group_id,
            "discovery_rows": len(discovery),
            "validation_rows": len(validation),
            "features_available": 0,
            "threshold_feature_atoms_generated": 0,
            "threshold_feature_atoms_eligible": 0,
            "rule_structures_evaluated": 0,
            "directional_rules_evaluated": 0,
            "importance": [],
        }
    names = sorted(set().union(*(r["features"].keys() for r in discovery)))
    cols_d, cols_v = _columns(discovery, names), _columns(validation, names)
    y_gross = np.array([(r["target_long_net_r"] - r["target_short_net_r"]) / 2.0 for r in discovery])
    generated_atoms = atomic_specs(names)
    masks_d = {atom_key(a): atom_mask(cols_d[a["feature"]], a) for a in generated_atoms}
    support_floor = max(MIN_N, math.ceil(MIN_SUPPORT * len(discovery)))
    atoms = [a for a in generated_atoms if support_floor <= int(masks_d[atom_key(a)].sum()) <= len(discovery) - MIN_N]
    ranked = _rank_atoms(atoms, masks_d, y_gross)
    importance = boosted_stump_importance(atoms, masks_d, y_gross)

    rules: dict[str, dict[str, Any]] = {}
    for atom in atoms:
        rules[rule_key([atom])] = {"atoms": [atom], "methods": ["SPARSE_RULE_LIST"]}
    top = [a for _, a in ranked[:12]]
    for i, a in enumerate(top):
        for b in top[i + 1:]:
            rr = [a, b]
            mask = rule_mask(cols_d, rr)
            if int(mask.sum()) >= support_floor:
                rules.setdefault(rule_key(rr), {"atoms": rr, "methods": []})["methods"].append("ASSOCIATION_RULE")
    available = {name: np.isfinite(cols_d[name]) for name in names}
    for rr in cart_leaf_rules([a for _, a in ranked], masks_d, available, y_gross):
        key = rule_key(rr)
        rules.setdefault(key, {"atoms": rr, "methods": []})["methods"].append("CART_DEPTH_LE_3")

    tests = []
    for key, rule in sorted(rules.items()):
        md, mv = rule_mask(cols_d, rule["atoms"]), rule_mask(cols_v, rule["atoms"])
        if int(md.sum()) < support_floor:
            continue
        for direction, target in (("LONG", "target_long_net_r"), ("SHORT", "target_short_net_r")):
            yd = np.array([r[target] for r, keep in zip(discovery, md) if keep], dtype=float)
            yv = np.array([r[target] for r, keep in zip(validation, mv) if keep], dtype=float)
            s, v = _stats(yd), _stats(yv)
            tests.append({
                "test_id": hashlib.sha256(f"{group_id}|{key}|{direction}".encode()).hexdigest()[:20],
                "group_id": group_id, "direction": direction, "atoms": rule["atoms"], "methods": sorted(set(rule["methods"])),
                "discovery_support": round(int(md.sum()) / len(discovery), 8),
                "validation_support": round(int(mv.sum()) / len(validation), 8),
                "discovery": s, "validation": v,
            })
    return tests, {
        "group_id": group_id,
        "discovery_rows": len(discovery),
        "validation_rows": len(validation),
        "features_available": len(names),
        "threshold_feature_atoms_generated": len(generated_atoms),
        "threshold_feature_atoms_eligible": len(atoms),
        "rule_structures_evaluated": len(tests) // 2,
        "directional_rules_evaluated": len(tests),
        "importance": importance[:20],
    }


def apply_fdr(tests: list[dict[str, Any]], q: float = FDR_Q) -> dict[str, Any]:
    ranked = []
    for test in tests:
        s = test["discovery"]
        p = s["p_one_sided"] if s["n"] >= MIN_N and (s["mean_net_r"] or 0) > 0 else 1.0
        ranked.append((float(p), test["test_id"], test))
    ranked.sort(key=lambda x: (x[0], x[1]))
    m, cutoff_rank, cutoff = len(ranked), 0, None
    for rank, (p, _tid, _test) in enumerate(ranked, 1):
        if p <= q * rank / m:
            cutoff_rank, cutoff = rank, p
    running, qvals = 1.0, {}
    for rank in range(m, 0, -1):
        p, tid, _ = ranked[rank - 1]
        running = min(running, p * m / rank)
        qvals[tid] = min(1.0, running)
    penalty = math.sqrt(2 * math.log(max(2, m)))
    for p, _tid, test in ranked:
        s, v = test["discovery"], test["validation"]
        test["fdr_q_value"] = float(qvals[test["test_id"]])
        test["fdr_reject_10pct"] = bool(cutoff is not None and p <= cutoff)
        test["validation_same_sign_half_effect"] = bool(
            test["fdr_reject_10pct"] and v["n"] >= MIN_N and (v["mean_net_r"] or 0) > 0
            and (v["mean_net_r"] or 0) >= 0.5 * (s["mean_net_r"] or math.inf)
        )
        t = s["t_stat"]
        tval = float(t) if isinstance(t, (int, float)) else (math.inf if t == "INF" else -math.inf)
        test["search_deflated_t"] = round(tval - penalty, 8) if math.isfinite(tval) else ("INF" if tval > 0 else "-INF")
        test["state"] = "WORTH_MT5_TEST" if test["validation_same_sign_half_effect"] else ("UNKNOWN" if s["n"] < MIN_N or v["n"] < MIN_N else "CLEAR_REJECT")
    return {
        "q": q,
        "tests": m,
        "cutoff_rank": cutoff_rank,
        "cutoff_p": cutoff,
        "deflated_t_penalty_sqrt_2logM": round(penalty, 8),
        "deflated_statistic": "discovery t-stat minus sqrt(2*ln(direction-specific rules evaluated))",
    }


def _neighbor_rule_variants(atoms: list[dict[str, Any]], feature_names: list[str]) -> list[dict[str, Any]]:
    catalogue: dict[tuple[str, str], list[float]] = defaultdict(list)
    for atom in atomic_specs(feature_names):
        if atom["op"] != "==":
            catalogue[(atom["feature"], atom["op"])].append(float(atom["value"]))
    for key in catalogue:
        catalogue[key] = sorted(set(catalogue[key]))

    variants: dict[str, dict[str, Any]] = {}
    for index, atom in enumerate(atoms):
        values = catalogue.get((atom["feature"], atom["op"]), [])
        if not values:
            continue
        try:
            position = values.index(float(atom["value"]))
        except ValueError:
            continue
        for adjacent in (position - 1, position + 1):
            if not 0 <= adjacent < len(values):
                continue
            changed = [dict(item) for item in atoms]
            changed[index]["value"] = values[adjacent]
            key = rule_key(changed)
            variants[key] = {
                "atoms": changed,
                "changed_feature": atom["feature"],
                "changed_op": atom["op"],
                "from": atom["value"],
                "to": values[adjacent],
            }
    return [variants[key] for key in sorted(variants)]


def assess_neighboring_thresholds(test: dict[str, Any], rows: list[dict[str, Any]]) -> dict[str, Any]:
    """Check immediate predeclared threshold neighbours without selecting on them."""
    discovery, validation = _split_rows(rows)
    names = sorted(set().union(*(r["features"].keys() for r in discovery)))
    cols_d, cols_v = _columns(discovery, names), _columns(validation, names)
    variants = _neighbor_rule_variants(test["atoms"], names)
    target = "target_long_net_r" if test["direction"] == "LONG" else "target_short_net_r"
    base_d = float(test["discovery"]["mean_net_r"])
    base_v = float(test["validation"]["mean_net_r"])
    support_floor = max(MIN_N, math.ceil(MIN_SUPPORT * len(discovery)))
    checks = []
    for variant in variants:
        md = rule_mask(cols_d, variant["atoms"])
        mv = rule_mask(cols_v, variant["atoms"])
        sd = _stats(np.array([r[target] for r, keep in zip(discovery, md) if keep], dtype=float))
        sv = _stats(np.array([r[target] for r, keep in zip(validation, mv) if keep], dtype=float))
        stable = bool(
            sd["n"] >= support_floor
            and sv["n"] >= MIN_N
            and (sd["mean_net_r"] or 0) > 0
            and (sv["mean_net_r"] or 0) > 0
            and (sd["mean_net_r"] or 0) >= 0.5 * base_d
            and (sv["mean_net_r"] or 0) >= 0.5 * base_v
        )
        checks.append({
            **{k: variant[k] for k in ("changed_feature", "changed_op", "from", "to")},
            "discovery": sd,
            "validation": sv,
            "stable_positive_half_effect": stable,
        })
    return {
        "definition": "vary one ordered atom to each immediately adjacent predeclared threshold; require >=2%/30 discovery support, >=30 validation rows, positive means, and >=50% of the selected rule's effect in both samples",
        "status": "NOT_APPLICABLE" if not checks else ("ROBUST" if all(c["stable_positive_half_effect"] for c in checks) else "FRAGILE"),
        "variants_evaluated": len(checks),
        "checks": checks,
    }


def _atom_text(atom: dict[str, Any]) -> str:
    condition = f"{atom['feature']} {atom['op']} {atom['value']}"
    return f"NOT ({condition})" if atom.get("negated") else condition


def _mechanical_candidate(test: dict[str, Any], group_meta: dict[str, Any]) -> dict[str, Any]:
    symbol = group_meta["execution_symbol"]
    refs = sorted({a["feature"].split("_")[1].upper() + ".DWX" for a in test["atoms"] if a["feature"].startswith("ref_")})
    rule_text = " AND ".join(_atom_text(a) for a in test["atoms"])
    feature_session = group_meta["feature_session"]
    target_session = group_meta["target_session"]
    return {
        "HYPOTHESIS_ID": "MLDISC-" + test["test_id"].upper(),
        "STATUS": "RESEARCH_CANDIDATE_NOT_PREREGISTERED_OR_PIPELINE_VALIDATED",
        "DISCOVERY_METHODS": test["methods"],
        "FDR_Q_VALUE": test["fdr_q_value"],
        "DISCOVERY_SUPPORT": test["discovery_support"],
        "VALIDATION_SUPPORT": test["validation_support"],
        "ECONOMIC_RATIONALE": "NONE unless separately supplied by independent critique; statistical condition only",
        "SYMBOLS": sorted(set([symbol, *refs])), "EXECUTION_SYMBOL": symbol, "REFERENCE_SYMBOLS": refs,
        "TIMEFRAME": "M1 source aggregated into completed DST-correct session windows",
        "SESSION": target_session,
        "ENTRY_RULE": f"After {feature_session} is closed, enter {test['direction']} at the next target-window bar open when {rule_text}; skip the entry during the mandatory PRE30/POST30 high-impact news blackout",
        "STOP_RULE": "max(0.3 x prior-14 NY_CASH ATR, 1.0 x prior-14 target-window ATR, 5 x round-trip spread); conservative F2 gap-through fill",
        "EXIT_RULE": f"no profit target; fixed time exit at the end of {target_session}, with framework Friday-close cap",
        "RISK_RULE": "RISK_FIXED=1000; RISK_PERCENT=0; one trade per symbol/target-session/day; no overnight hold; <=5% daily and <=10% total book DD guards remain external portfolio controls",
        "EXPECTED_BOOK_ROLE": "session-flat discovery candidate; role unproven until F2/MT5 evidence",
        "EXPECTED_OVERLAP": f"concentrated in {target_session} and named symbols",
        "COST_SENSITIVITY": "base F2 round-trip prior in discovery; mandatory doubled-cost F2 falsification next",
        "FALSIFICATION_TEST": "pre-register unchanged rule for 2023-2025 F2 prescreen; reject on sign/effect failure, double-cost failure, or MT5 mismatch",
        "DISCOVERY_SAMPLE": {"period": [SF.START.isoformat(), SF.DISCOVERY_END.isoformat()], "metrics": test["discovery"]},
        "VALIDATION_SAMPLE": {"period": [SF.VALIDATION_START.isoformat(), SF.END.isoformat()], "metrics": test["validation"]},
        "MECHANICAL_RULE": {
            "schema": "qm.f2-mechanical-session-rule/v1",
            "feature_schema": SF.SCHEMA,
            "condition_evaluator": "tools.strategy_farm.research.ml_rule_discovery:mechanical_rule_matches",
            "execution_engine": "tools/strategy_farm/session_tools/velocity_family_f2_cash_session_0921.py:simulate",
            "statistics_engine": "velocity_family_f1_sweep_0921.py:period_stats + velocity_family_f2_cash_session_0921.py:bootstrap_pass_prob",
            "feature_session": feature_session,
            "target_session": target_session,
            "all": test["atoms"],
            "missing_feature_policy": "NO_TRADE",
            "direction": test["direction"],
            "entry": "NEXT_BAR_OPEN_AFTER_FEATURE_WINDOW",
            "news_blackout": {"impact": "HIGH", "pre_minutes": 30, "post_minutes": 30, "currencies": "strict execution-symbol currencies"},
            "stop": {"cash_atr_min": 0.3, "target_window_atr": 1.0, "round_trip_spread_multiple_min": 5.0, "gap_through": "WORSE_OF_LEVEL_OR_BREACH_BAR_OPEN"},
            "target": None,
            "flat": {"at": "TARGET_SESSION_END", "friday_server_cap": "21:00"},
            "risk": {"RISK_FIXED": 1000, "RISK_PERCENT": 0},
        },
        "NEIGHBORING_THRESHOLD_ROBUSTNESS": test.get("neighboring_threshold_robustness", {"status": "NOT_RUN"}),
        "SEARCH_DEFLATED_T": test["search_deflated_t"],
        "NEXT_PHASE": "independent critique, QM-RESEARCH mechanization/preregistration, then untouched 2023-2025 F2 prescreen",
    }


def _prepare_job(args):
    symbol, cache, reuse = args
    return symbol, SF.prepare_symbol(symbol, Path(cache), reuse)


def _trial_ledger_sha256(tests: list[dict[str, Any]]) -> str:
    digest = hashlib.sha256()
    for test in sorted(tests, key=lambda row: row["test_id"]):
        digest.update(json.dumps(test, sort_keys=True, separators=(",", ":"), allow_nan=False).encode())
        digest.update(b"\n")
    return digest.hexdigest()


def run(symbols: tuple[str, ...], cache_dir: Path, workers: int, reuse: bool = True) -> dict[str, Any]:
    bases = {}
    jobs = [(s, str(cache_dir), reuse) for s in symbols]
    if workers > 1:
        with ProcessPoolExecutor(max_workers=workers) as pool:
            for symbol, base in pool.map(_prepare_job, jobs):
                bases[symbol] = base; print(f"features {symbol}", file=sys.stderr, flush=True)
    else:
        for job in jobs:
            symbol, base = _prepare_job(job); bases[symbol] = base; print(f"features {symbol}", file=sys.stderr, flush=True)
    tests, groups, group_meta = [], [], {}
    feature_names: set[str] = set()
    for symbol in symbols:
        if not bases[symbol]["structural"]["bars"]:
            continue
        needed = {symbol, *SF.REFERENCE_SYMBOLS}
        rows = SF.build_rows(symbol, {k: bases[k] for k in needed if k in bases})
        by_group = defaultdict(list)
        for row in rows:
            feature_names.update(row["features"])
            gid = f"{symbol}|{row['feature_session']}->{row['target_session']}"
            by_group[gid].append(row)
            group_meta[gid] = {"execution_symbol": symbol, "feature_session": row["feature_session"], "target_session": row["target_session"]}
        for gid in sorted(by_group):
            found, summary = discover_group(by_group[gid], gid)
            tests.extend(found); groups.append(summary)
            print(f"discovered {gid}: {len(found)} tests", file=sys.stderr, flush=True)
    fdr = apply_fdr(tests)
    worth = [test for test in tests if test["state"] == "WORTH_MT5_TEST"]
    worth_by_symbol: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for test in worth:
        worth_by_symbol[group_meta[test["group_id"]]["execution_symbol"]].append(test)
    for symbol in sorted(worth_by_symbol):
        needed = {symbol, *SF.REFERENCE_SYMBOLS}
        rows = SF.build_rows(symbol, {key: bases[key] for key in needed if key in bases})
        by_group = defaultdict(list)
        for row in rows:
            by_group[f"{symbol}|{row['feature_session']}->{row['target_session']}"].append(row)
        for test in worth_by_symbol[symbol]:
            test["neighboring_threshold_robustness"] = assess_neighboring_thresholds(test, by_group[test["group_id"]])
    survivors = [_mechanical_candidate(test, group_meta[test["group_id"]]) for test in worth]
    fdr_discoveries = sorted((test for test in tests if test["fdr_reject_10pct"]), key=lambda row: row["test_id"])
    method_counts = {
        method: sum(method in test["methods"] for test in tests)
        for method in ("SPARSE_RULE_LIST", "ASSOCIATION_RULE", "CART_DEPTH_LE_3")
    }
    neighbour_counts = {
        state: sum(test.get("neighboring_threshold_robustness", {}).get("status") == state for test in worth)
        for state in ("ROBUST", "FRAGILE", "NOT_APPLICABLE")
    }
    neighbour_variants = sum(test.get("neighboring_threshold_robustness", {}).get("variants_evaluated", 0) for test in worth)
    script = Path(__file__).resolve(); features_script = Path(SF.__file__).resolve()
    return {
        "schema": SCHEMA, "seed": SEED,
        "scripts": {str(script).replace("\\", "/"): _sha(script), str(features_script).replace("\\", "/"): _sha(features_script)},
        "years_opened": list(SF.YEARS), "heldout_2023_2025_opened": False,
        "discovery_period": [SF.START.isoformat(), SF.DISCOVERY_END.isoformat()],
        "validation_period": [SF.VALIDATION_START.isoformat(), SF.END.isoformat()],
        "heldout_period": ["2023-01-01", "2025-12-31"],
        "methods": {
            "cart_max_depth": TREE_MAX_DEPTH,
            "association_min_support": MIN_SUPPORT,
            "gradient_boosted_stump_rounds": BOOST_ROUNDS,
            "boost_learning_rate": BOOST_LEARNING_RATE,
            "directional_rule_counts": method_counts,
            "runtime_model": None,
        },
        "feature_contract": {
            "feature_count": len(feature_names),
            "feature_names": sorted(feature_names),
            "families": [
                "own/reference prior-window return and range in prior-14 same-window ATR units",
                "overnight gap versus prior NY cash close",
                "prior-day range position and day of week",
                "lagged D1 MA50/MA200 regime for execution/reference symbols",
                "prior-window realised-volatility ATR ratio and NR-style compression",
                "Asia three-M15-bar fair-value-gap sign/count",
                "DST-correct feature-session time of day",
            ],
            "lookahead_assertion": "last consumed HCC source-bar timestamp < execution target-window open",
            "missing_feature_policy": "condition false / NO_TRADE, including negated atoms",
        },
        "target_contract": {
            "definition": "target-window open-to-close return in prior-14 target-window ATR units minus one F2-format spread_rt+slip_rt price prior",
            "fixed_time_exit": "target session end",
            "commission": "not included: the shared full-universe prior is price friction; venue-specific commission is mandatory in the pre-registered F2 prescreen",
        },
        "fdr": fdr,
        "counts": {
            "symbols_declared": len(symbols),
            "symbols_with_2018_2022_history": sum(bool(bases[s]["structural"]["bars"]) for s in symbols),
            "features": len(feature_names),
            "feature_groups": len(groups),
            "threshold_feature_atoms_generated": sum(group["threshold_feature_atoms_generated"] for group in groups),
            "threshold_feature_atoms_eligible": sum(group["threshold_feature_atoms_eligible"] for group in groups),
            "rule_structures_evaluated": sum(group["rule_structures_evaluated"] for group in groups),
            "rules_evaluated": len(tests),
            "fdr_rejections": len(fdr_discoveries),
            "mechanical_candidates": len(survivors),
            "neighbor_variants_evaluated": neighbour_variants,
            "neighbor_status": neighbour_counts,
            "states": {state: sum(test["state"] == state for test in tests) for state in ("CLEAR_REJECT", "UNKNOWN", "WORTH_MT5_TEST")},
        },
        "trial_ledger": {
            "rows": len(tests),
            "sha256_canonical_jsonl": _trial_ledger_sha256(tests),
            "materialized_subset": "all BH discoveries plus every 2022-confirmed mechanical candidate",
        },
        "groups": groups,
        "fdr_discoveries": fdr_discoveries,
        "survivors": survivors,
        "data": {
            symbol: {
                "bars": bases[symbol]["structural"]["bars"],
                "ohlc_violations": bases[symbol]["structural"]["ohlc_violations"],
                "source_files": bases[symbol]["source_files"],
                "cost_prior": bases[symbol]["cost_prior"],
            }
            for symbol in symbols
        },
    }


def markdown(out: dict[str, Any]) -> str:
    c = out["counts"]
    lines = [
        "# Offline mechanical-rule discovery — 2026-09-22",
        "",
        "Research-only offline discovery; no runtime ML model is emitted.",
        "",
        "## Result",
        "",
        f"Evaluated **{c['rules_evaluated']:,}** direction-specific rules across {c['feature_groups']} symbol/session groups and {c['features']} closed-data features. BH FDR 10% rejected {c['fdr_rejections']}; **{c['mechanical_candidates']}** rules also survived the locked 2022 rule-selection validation.",
        "",
        f"States: `{json.dumps(c['states'], sort_keys=True)}`. Neighbouring-threshold checks: `{json.dumps(c['neighbor_status'], sort_keys=True)}` across {c['neighbor_variants_evaluated']} variants.",
        "",
        f"The canonical all-trial ledger has {out['trial_ledger']['rows']:,} rows and SHA-256 `{out['trial_ledger']['sha256_canonical_jsonl']}`; the compact machine JSON materializes all FDR discoveries and all final candidates.",
        "",
        "Discovery used 2018-07..2021-12, validation used only 2022, and 2023-2025 was not opened. Shallow CART, association rules, and boosted-stump importance were used only to rank explicit boolean conjunctions.",
        "",
        "## Mechanical candidates",
        "",
    ]
    if not out["survivors"]:
        lines.append("No mechanical rule survived both global FDR and 2022 validation.")
    else:
        for row in out["survivors"]:
            lines.extend([f"### {row['HYPOTHESIS_ID']}", "", "```json", json.dumps(row, sort_keys=True, indent=1), "```", ""])
    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--symbols", default="ALL")
    ap.add_argument("--workers", type=int, default=2)
    ap.add_argument("--cache-dir", default="D:/QM/reports/research/ml_rule_discovery/features_2018_2022")
    ap.add_argument("--no-reuse", action="store_true")
    ap.add_argument("--out", default=str(REPO / "docs/research/ftmo_shadow/ml_rule_discovery_2026-09-22.json"))
    ap.add_argument("--report", default=str(REPO / "docs/research/ftmo_shadow/ml_rule_discovery_2026-09-22.md"))
    ap.add_argument("--originating-task-id", default=None)
    ap.add_argument("--owner-decision", default=None)
    args = ap.parse_args()
    symbols = CSCAN.UNIVERSE if args.symbols == "ALL" else tuple(sorted(s.strip() for s in args.symbols.split(",") if s.strip()))
    out = run(symbols, Path(args.cache_dir), max(1, min(2, args.workers)), not args.no_reuse)
    out["provenance"] = {
        "originating_task_id": args.originating_task_id,
        "owner_decision": args.owner_decision,
        "source_contract": "docs/ops/INTERNAL_RESEARCH_SOURCE_CONTRACT.md",
        "owner_directive": "docs/ops/evidence/2026-09-21_ftmo_full_throttle_override/owner_directive_verbatim.md",
    }
    out_path, report_path = Path(args.out), Path(args.report)
    out_path.parent.mkdir(parents=True, exist_ok=True); report_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(out, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n", encoding="utf-8", newline="\n")
    report_path.write_text(markdown(out), encoding="utf-8", newline="\n")
    print(json.dumps({"out": str(out_path), "report": str(report_path), "counts": out["counts"], "fdr": out["fdr"]}, sort_keys=True, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
