#!/usr/bin/env python3
"""Continuous book recomposition CLI (Phase E, OWNER-DEC-CBE-20260915).

Two deterministic subcommands (directive section 7/58/70):

    python tools/strategy_farm/portfolio/recompose/recompose.py freeze \
        --venue dxz|ftmo --out <snapshot_dir>
    python tools/strategy_farm/portfolio/recompose/recompose.py evaluate \
        --venue dxz|ftmo --snapshot <snapshot_dir> --out <read_model.json>

``freeze`` collects the frozen inputs (``frozen_snapshot.freeze``).  ``evaluate``
reads ONLY the snapshot, computes the section 7 metric vector, the section 57 venue
fitness, portfolio alternatives, the section 59 materiality predicate and the section 6
outcome, and writes:

* ``D:/QM/reports/book_evolution/<ISO-week>/<venue>/evaluation.json`` + ``evidence.md``
* the shared read-model ``D:/QM/reports/state/book_evolution_<venue>.json``
  (schema ``qm.book-evolution-venue/v1``; FTMO also mirrors ``demo_cycle`` from the
  readiness read-model when present).

The engine never deploys, never toggles AutoTrading, never writes the farm DB.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
from pathlib import Path
from typing import Any, Mapping, Sequence

_HERE = Path(__file__).resolve()
_FARM_ROOT = _HERE.parents[2]
_REPO_ROOT = _HERE.parents[4]
# book_builder_common imports via the absolute ``tools.strategy_farm.portfolio`` package
# path, so the repo root must be importable; the ``portfolio.*`` imports below need the
# farm root.  Both are added so the module works as a script and under pytest.
for _p in (str(_REPO_ROOT), str(_FARM_ROOT)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from portfolio import concentration_tail  # noqa: E402
from portfolio import risk_diagnostics  # noqa: E402
from portfolio.book_builder_common import matrix_on_grid, shared_day_grid  # noqa: E402
from portfolio.portfolio_common import load_streams, to_daily_pnl  # noqa: E402
from portfolio.recompose import alternatives as alt_mod  # noqa: E402
from portfolio.recompose import decide as decide_mod  # noqa: E402
from portfolio.recompose import frozen_snapshot  # noqa: E402
from portfolio.recompose import materiality as mat_mod  # noqa: E402
from portfolio.recompose import metrics as metrics_mod  # noqa: E402
from portfolio.recompose import venue_fitness  # noqa: E402

Key = tuple[int, str]

STATE_DIR = Path(r"D:\QM\reports\state")
BOOK_EVOLUTION_ROOT = Path(r"D:\QM\reports\book_evolution")
READ_MODEL_SCHEMA = "qm.book-evolution-venue/v1"
DEFAULT_DXZ_RISK_BUDGET = 11.0
DEFAULT_DXZ_SLEEVE_CAP = 1.5
DEFAULT_FTMO_RISK_BUDGET = 2.5  # 8 x 0.3125 %


def _parse_key(token: str) -> Key:
    ea, _sep, sym = token.partition(":")
    return int(ea), sym


def _next_recomposition_utc(as_of: dt.datetime) -> str:
    # Upcoming Sunday (weekday 6); if today is Sunday, use today.
    days_ahead = (6 - as_of.weekday()) % 7
    target = (as_of + dt.timedelta(days=days_ahead)).date()
    return dt.datetime(target.year, target.month, target.day, 10, 0, tzinfo=dt.UTC).isoformat()


def _load_daily(snapshot_dir: Path, all_keys: Sequence[Key]) -> tuple[dict[Key, dict], dict[Key, list]]:
    stream_root = snapshot_dir / "streams"
    trades = load_streams(stream_root, candidates=list(all_keys))
    daily = {k: to_daily_pnl(v) for k, v in trades.items() if v}
    return daily, trades


def _incumbent_by_label(manifest: Mapping[str, Any], label: str) -> dict[str, Any] | None:
    for inc in manifest.get("incumbents", []):
        if inc.get("label") == label:
            return inc
    return None


def _incumbent_keys(inc: Mapping[str, Any]) -> list[Key]:
    return sorted((int(s["ea_id"]), str(s["symbol"])) for s in inc.get("sleeves", []))


def _incumbent_weights(inc: Mapping[str, Any], daily: Mapping[Key, dict], budget: float, cap: float) -> dict[Key, float]:
    """Use declared risk_pct where present + streamed; else derive capped inverse-vol."""
    declared = {}
    for s in inc.get("sleeves", []):
        k = (int(s["ea_id"]), str(s["symbol"]))
        if s.get("risk_pct") is not None and daily.get(k):
            declared[k] = float(s["risk_pct"])
    keys_with_streams = [k for k in _incumbent_keys(inc) if daily.get(k)]
    if declared and len(declared) == len(keys_with_streams):
        return declared
    return alt_mod.weights_for(keys_with_streams, daily, total_risk_budget=budget, sleeve_cap=cap)


def _risk_diagnostics(
    keys: Sequence[Key],
    weights: Mapping[Key, float],
    daily: Mapping[Key, dict],
    trades: Mapping[Key, list],
    metrics: Mapping[str, Any],
    *,
    starting_capital: float = 100_000.0,
    asset_by_key: Mapping[Key, str] | None = None,
    family_by_key: Mapping[Key, str] | None = None,
    session_by_key: Mapping[Key, str] | None = None,
) -> dict[str, Any]:
    """Advisory concentration cap-warnings + hard-guard summary for a roster.

    Reuses ``concentration_tail.evaluate`` (advisory since slice b2) + ``risk_diagnostics``
    and enriches the dependence panel with the downside-correlation and entry-day
    trade-overlap already computed by ``metrics`` (b2 review deferred these to E1).  Any
    classification/policy failure degrades to EVIDENCE_MISSING, never invented.
    """
    ordered = [k for k in sorted((int(e), str(s)) for e, s in keys) if daily.get(k)]
    if not ordered:
        return {"status": "EVIDENCE_MISSING", "reason": "no_streamed_sleeves"}
    try:
        start = max(min(daily[k]) for k in ordered)
        end = min(max(daily[k]) for k in ordered)
        grid = shared_day_grid(daily, ordered, start, end)
        grid_keys, matrix = matrix_on_grid(daily, ordered, grid)
        concentration = concentration_tail.evaluate(
            keys=grid_keys,
            weights={k: float(weights[k]) for k in grid_keys},
            dates=grid,
            matrix=matrix,
            streams={k: trades.get(k, []) for k in grid_keys},
            starting_capital=starting_capital,
            asset_by_key={k: asset_by_key[k] for k in grid_keys} if asset_by_key else None,
            family_by_key={k: family_by_key[k] for k in grid_keys} if family_by_key else None,
            session_by_key={k: session_by_key[k] for k in grid_keys} if session_by_key else None,
        )
    except Exception as exc:  # noqa: BLE001 - policy/classification gaps are non-fatal here
        return {"status": "EVIDENCE_MISSING", "reason": f"{type(exc).__name__}: {exc}"}

    # Enrich dependence panel with downside correlation + entry-day trade overlap.
    down = {(e["a"], e["b"]): e.get("downside_correlation") for e in metrics.get("downside_correlation_panel", [])}
    overlap = {(e["a"], e["b"]): e.get("entry_day_jaccard") for e in metrics.get("trade_overlap_panel", [])}
    panel: list[dict[str, Any]] = []
    for entry in metrics.get("pairwise_correlation_panel", []):
        key = (entry["a"], entry["b"])
        panel.append({
            "a": entry["a"],
            "b": entry["b"],
            "correlation": entry.get("correlation"),
            "downside_correlation": down.get(key),
            "trade_overlap_jaccard": overlap.get(key),
        })
    diagnostics = risk_diagnostics.build(concentration, dependence_panel=panel)
    diagnostics["status"] = "PRESENT"
    return diagnostics


def _change_concentration(
    baseline_metrics: Mapping[str, Any],
    alt_metrics: Mapping[str, Any],
    change: Mapping[str, Any],
) -> list[dict[str, Any]]:
    """Advisory warnings when a proposed change RAISES a symbol's concentration (E1 M2).

    OWNER-DEC-CBE-20260915 sec 8 makes the static per-symbol cap advisory, so a change
    that does not breach the 46 %-of-budget cap can still concentrate the book further
    into its most-exposed symbol.  This surfaces that explicitly (naming the symbol and
    its share of the risk budget) as an advisory, non-blocking warning -- it is NOT a new
    permanent cap, it is a measured observation about what the change does.  The
    2026-W38 ADD_SLEEVE 10700 XAUUSD proposal therefore shows its XAUUSD concentration
    increase even though the advisory 46 % cap is not breached.
    """
    base_exp = baseline_metrics.get("symbol_exposure_risk_pct") or {}
    alt_exp = alt_metrics.get("symbol_exposure_risk_pct") or {}
    if not isinstance(alt_exp, Mapping) or not alt_exp:
        return []
    total = _num(alt_metrics.get("total_risk_pct")) or sum(
        v for v in alt_exp.values() if isinstance(v, (int, float))
    )
    top_symbol = max(alt_exp, key=lambda s: alt_exp.get(s) or 0.0)
    added_bare = {str(sym).upper().split(".", 1)[0] for _ea, sym in (change.get("add") or [])}
    warnings: list[dict[str, Any]] = []
    for sym in sorted(added_bare):
        a_val = _num(alt_exp.get(sym))
        if a_val is None:
            continue
        b_val = _num(base_exp.get(sym)) or 0.0
        if a_val <= b_val + 1e-12:
            continue
        share = round(a_val / total * 100.0, 2) if total else None
        warnings.append({
            "cap": "symbol_concentration_increase",
            "key": sym,
            "value": round(a_val, 6),
            "baseline_value": round(b_val, 6),
            "share_of_budget_pct": share,
            "is_largest_symbol": sym == str(top_symbol).upper().split(".", 1)[0],
            "unit": "planned_stop_risk_pct",
            "severity": "WARN",
            "note": (
                f"change raises book exposure to {sym} from {round(b_val, 4)}% to "
                f"{round(a_val, 4)}%"
                + (" (already the largest symbol)" if sym == top_symbol else "")
            ),
        })
    return warnings


def _num(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return float(value)
    return None


def _change_outcome(added: list[Key], removed: list[Key]) -> str:
    if added and removed:
        return "REPLACE_SLEEVE"
    if added:
        return "ADD_SLEEVE"
    if removed:
        return "REMOVE_SLEEVE"
    return "KEEP"


def evaluate(
    venue: str,
    snapshot_dir: Path,
    out: Path,
    *,
    risk_budget: float | None = None,
    sleeve_cap: float = DEFAULT_DXZ_SLEEVE_CAP,
    book_evolution_root: Path | None = None,
) -> dict[str, Any]:
    venue = str(venue).lower()
    manifest = frozen_snapshot.load_snapshot(snapshot_dir)
    if manifest.get("venue") != venue:
        raise ValueError(f"snapshot venue {manifest.get('venue')!r} != requested {venue!r}")
    as_of = dt.datetime.fromisoformat(manifest["frozen_at_utc"])
    iso_week = manifest["iso_week"]
    seed = int(manifest.get("seed", 0))
    budget = risk_budget if risk_budget is not None else (
        DEFAULT_DXZ_RISK_BUDGET if venue == "dxz" else DEFAULT_FTMO_RISK_BUDGET
    )

    pool = [_parse_key(p) for p in manifest["qualified_pool"]["pairs"]]
    all_keys = [_parse_key(k) for k in manifest["all_keys"]]
    daily, trades = _load_daily(Path(snapshot_dir), all_keys)

    incumbents = manifest.get("incumbents", [])
    primary = incumbents[0] if incumbents else {"label": "empty", "sleeves": []}
    primary_keys = [k for k in _incumbent_keys(primary) if daily.get(k)]

    def _consistent_weights(keys: Sequence[Key]) -> dict[Key, float]:
        """Weight ANY roster with the SAME allocator + budget so the recomposition
        decision compares roster COMPOSITION, not weighting scheme (avoids a reweight
        artifact). The live book's own declared weights are kept for provenance only."""
        streamed = [k for k in keys if daily.get(k)]
        if not streamed:
            return {}
        return alt_mod.weights_for(streamed, daily, total_risk_budget=budget, sleeve_cap=sleeve_cap)

    # Metrics + fitness for every labelled incumbent.  ``comparison`` uses the consistent
    # allocator (decision basis); ``as_deployed`` uses the declared live/staged weights
    # (provenance) when available.
    incumbent_reports: list[dict[str, Any]] = []
    for inc in incumbents:
        keys = [k for k in _incumbent_keys(inc) if daily.get(k)]
        if not keys:
            incumbent_reports.append({"label": inc.get("label"), "status": "NO_STREAMS"})
            continue
        cmp_w = _consistent_weights(keys)
        m_cmp = metrics_mod.compute_roster_metrics(keys, cmp_w, daily, trades_by_key=trades)
        f_cmp = venue_fitness.compute_venue_fitness(venue, m_cmp, snapshot=manifest)
        declared_w = _incumbent_weights(inc, daily, budget, sleeve_cap)
        m_dep = metrics_mod.compute_roster_metrics(keys, declared_w, daily, trades_by_key=trades)
        incumbent_reports.append({
            "label": inc.get("label"),
            "status": inc.get("status"),
            "sleeve_count": len(keys),
            "metrics": m_cmp,
            "fitness": f_cmp,
            "metrics_as_deployed": m_dep,
        })

    baseline_report = next((r for r in incumbent_reports if r.get("metrics")), None)
    fitness_evaluated = bool(
        baseline_report and isinstance(baseline_report["fitness"].get("objective"), (int, float))
    )

    baseline_metrics = baseline_report["metrics"] if baseline_report else {}
    baseline_fitness = baseline_report["fitness"] if baseline_report else {"objective": "NOT_EVALUATED"}
    baseline_weights = _consistent_weights(primary_keys) if primary_keys else {}
    # Declared live weights are recorded in the read-model incumbent for provenance.
    display_weights = _incumbent_weights(primary, daily, budget, sleeve_cap) if primary_keys else {}
    baseline_book = metrics_mod.book_by_date(primary_keys, baseline_weights, daily) if primary_keys else {}
    incumbent_symbols = [s for _e, s in primary_keys]

    # Advisory concentration / dependence diagnostics for the incumbent baseline roster
    # (b2 caps -> advisory; carried into the output, never a silent no-op).  Computed
    # BEFORE the alternatives loop so materiality can weigh each alternative's dependence
    # against the baseline (E1 review M2).
    baseline_risk_diag = (
        _risk_diagnostics(primary_keys, baseline_weights, daily, trades, baseline_metrics)
        if primary_keys else {"status": "EVIDENCE_MISSING", "reason": "no_incumbent_streams"}
    )

    # Alternatives: standard add/remove/replace + each secondary incumbent as an explicit book.
    alternatives = alt_mod.enumerate_alternatives(
        primary_keys, pool, daily, total_risk_budget=budget, sleeve_cap=sleeve_cap
    ) if primary_keys else []

    for inc in incumbents[1:]:
        keys = [k for k in _incumbent_keys(inc) if daily.get(k)]
        if not keys:
            continue
        added = sorted(set(keys) - set(primary_keys))
        removed = sorted(set(primary_keys) - set(keys))
        weights = _consistent_weights(keys)
        alternatives.append({
            "label": inc.get("label"),
            "keys": [list(k) for k in sorted(keys)],
            "weights": {f"{k[0]}:{k[1]}": round(v, 8) for k, v in sorted(weights.items())},
            "change": {
                "outcome": _change_outcome(added, removed),
                "add": [list(k) for k in added],
                "remove": [list(k) for k in removed],
                "replace": [],
                "note": f"labelled incumbent {inc.get('label')}",
            },
        })

    assessed: list[dict[str, Any]] = []
    live_evidence = manifest.get("live_evidence", {})
    for a in alternatives:
        keys = [tuple(k) for k in a["keys"]]
        weights = {_parse_key(k): float(v) for k, v in a["weights"].items()}
        m = metrics_mod.compute_roster_metrics(keys, weights, daily, trades_by_key=trades)
        f = venue_fitness.compute_venue_fitness(venue, m, snapshot=manifest)
        alt_book = metrics_mod.book_by_date(keys, weights, daily)
        # Risk diagnostics for THIS alternative roster (E1 review M2): the same advisory
        # cap warnings + hard guards + dependence panel the incumbent gets, plus the
        # change-level symbol-concentration diagnostic.  These weigh into materiality.
        alt_risk_diag = _risk_diagnostics(keys, weights, daily, trades, m)
        change_conc = _change_concentration(baseline_metrics, m, a["change"])
        if isinstance(alt_risk_diag, dict):
            alt_risk_diag["change_concentration_warnings"] = change_conc
        assessment = mat_mod.assess(
            venue=venue,
            change=a["change"],
            baseline_fitness=baseline_fitness,
            alt_fitness=f,
            baseline_metrics=baseline_metrics,
            alt_metrics=m,
            baseline_book_by_date=baseline_book,
            alt_book_by_date=alt_book,
            incumbent_symbols=incumbent_symbols,
            incumbent_live_evidence=live_evidence,
            alt_risk_diagnostics=alt_risk_diag,
            baseline_risk_diagnostics=baseline_risk_diag,
            seed=seed,
        )
        assessed.append({
            "label": a["label"],
            "change": a["change"],
            "metrics": m,
            "fitness": f,
            "materiality": assessment,
            "risk_diagnostics": alt_risk_diag,
        })

    challengers_available = any(
        a["change"].get("outcome") in {"ADD_SLEEVE", "REPLACE_SLEEVE"} for a in alternatives
    )
    proposal = decide_mod.decide(
        venue=venue,
        baseline_metrics=baseline_metrics,
        baseline_fitness=baseline_fitness,
        assessed_alternatives=[a for a in assessed if a["label"] != "incumbent"],
        fitness_evaluated=fitness_evaluated,
        challengers_available=challengers_available,
    )

    # Challengers list (qualified not in incumbent) with marginal value.
    incumbent_set = set(primary_keys)
    challenger_rows: list[dict[str, Any]] = []
    for k in sorted(set(pool) - incumbent_set):
        add_label = f"add:{k[0]}:{k[1]}"
        match = next((a for a in assessed if a["label"] == add_label), None)
        if match is not None:
            mv = {
                "delta_objective": match["materiality"]["factors"].get("delta_objective"),
                "material": match["materiality"].get("material"),
            }
        else:
            mv = "NOT_EVALUATED"
        challenger_rows.append({
            "ea_id": k[0],
            "symbol": k[1],
            "highest_gate": "Q14",
            "has_stream": bool(daily.get(k)),
            "marginal_value": mv,
        })

    # Risk diagnostics for the SELECTED alternative (E1 review M2): carried into the
    # read-model proposal so the proposal's own concentration / dependence risk is
    # visible, not only the incumbent's.
    selected_label = proposal.get("selected_alternative")
    selected_risk_diag = None
    if selected_label:
        match = next((a for a in assessed if a["label"] == selected_label), None)
        if match is not None:
            selected_risk_diag = match.get("risk_diagnostics")

    # Engine outputs are a PURE function of the frozen snapshot (directive section 70):
    # the generation timestamp is the snapshot's freeze instant, so two evaluations of the
    # same snapshot are byte-identical.
    generated_at_utc = manifest["frozen_at_utc"]
    read_model = _build_read_model(
        venue=venue,
        as_of=as_of,
        generated_at_utc=generated_at_utc,
        iso_week=iso_week,
        manifest=manifest,
        primary=primary,
        primary_keys=primary_keys,
        baseline_weights=display_weights,
        challengers=challenger_rows,
        proposal=proposal,
        risk_diagnostics=baseline_risk_diag,
        selected_risk_diagnostics=selected_risk_diag,
        snapshot_dir=Path(snapshot_dir),
    )

    evaluation = {
        "schema": "qm.recompose-evaluation/v1",
        "venue": venue,
        "iso_week": iso_week,
        "generated_at_utc": generated_at_utc,
        "frozen_at_utc": manifest["frozen_at_utc"],
        "git_commit": manifest.get("git_commit"),
        "seed": seed,
        "risk_budget_pct": budget,
        "sleeve_cap_pct": sleeve_cap,
        "qualified_pool": manifest["qualified_pool"],
        "incumbent_reports": incumbent_reports,
        "baseline_label": baseline_report["label"] if baseline_report else None,
        "alternatives_assessed": assessed,
        "risk_diagnostics": baseline_risk_diag,
        "proposal": proposal,
        "read_model": read_model,
        "snapshot_dir": str(Path(snapshot_dir)),
    }

    week_dir = (book_evolution_root or BOOK_EVOLUTION_ROOT) / iso_week / venue
    week_dir.mkdir(parents=True, exist_ok=True)
    (week_dir / "evaluation.json").write_text(
        json.dumps(evaluation, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    (week_dir / "evidence.md").write_text(
        _render_evidence(evaluation, manifest), encoding="utf-8"
    )
    out = Path(out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(read_model, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return read_model


def _build_read_model(
    *,
    venue: str,
    as_of: dt.datetime,
    generated_at_utc: str,
    iso_week: str,
    manifest: Mapping[str, Any],
    primary: Mapping[str, Any],
    primary_keys: Sequence[Key],
    baseline_weights: Mapping[Key, float],
    challengers: Sequence[Mapping[str, Any]],
    proposal: Mapping[str, Any],
    risk_diagnostics: Mapping[str, Any],
    selected_risk_diagnostics: Mapping[str, Any] | None,
    snapshot_dir: Path,
) -> dict[str, Any]:
    sleeves = []
    total_risk = 0.0
    for s in primary.get("sleeves", []):
        k = (int(s["ea_id"]), str(s["symbol"]))
        rp = s.get("risk_pct")
        if rp is None:
            rp = baseline_weights.get(k)
        if isinstance(rp, (int, float)):
            total_risk += float(rp)
        sleeves.append({
            "ea_id": k[0],
            "symbol": k[1],
            "magic": s.get("magic", "UNKNOWN"),
            "risk_pct": rp if rp is not None else "EVIDENCE_MISSING",
            "since": s.get("since", "UNKNOWN"),
            "status": ("HAS_STREAM" if k in set(primary_keys) else "NO_STREAM_EVIDENCE"),
        })

    live = manifest.get("live_evidence", {})
    if venue == "dxz":
        evidence = {
            "live_equity": live.get("live_equity", "EVIDENCE_MISSING"),
            "live_dd_pct": live.get("live_dd_pct", "EVIDENCE_MISSING"),
            "live_since": live.get("live_since", "EVIDENCE_MISSING"),
            "freshness_utc": _freshness(live),
            "sources": [s.get("path") for s in live.get("sources", []) if isinstance(s, Mapping)],
        }
    else:
        evidence = {
            "live_equity": live.get("demo_equity", "EVIDENCE_MISSING"),
            "live_dd_pct": "EVIDENCE_MISSING",
            "live_since": "EVIDENCE_MISSING",
            "freshness_utc": _freshness(live),
            "sources": [s.get("path") for s in live.get("sources", []) if isinstance(s, Mapping)],
        }

    read_model: dict[str, Any] = {
        "schema": READ_MODEL_SCHEMA,
        "venue": venue,
        "generated_at_utc": generated_at_utc,
        "iso_week": iso_week,
        "incumbent": {
            "sleeves": sleeves,
            "sleeve_count": len(sleeves),
            "total_risk_pct": round(total_risk, 6) if total_risk else "EVIDENCE_MISSING",
            "source_path": primary.get("source_path", "UNKNOWN"),
            "label": primary.get("label"),
        },
        "evidence": evidence,
        "qualified_pool": {
            "count": manifest["qualified_pool"]["count"],
            "definition": manifest["qualified_pool"]["definition"],
            "csv_path": str(frozen_snapshot.CANDIDATE_UNIVERSE_CSV),
        },
        "challengers": [dict(c) for c in challengers],
        "proposal": {
            "outcome": proposal["outcome"],
            "changes": proposal.get("changes", []),
            "expected_metrics": proposal.get("expected_metrics", {}),
            "materiality": proposal.get("materiality", {}),
            "confidence": proposal.get("confidence"),
            "operational_risk": proposal.get("operational_risk"),
            "risk_diagnostics": _risk_diag_summary(risk_diagnostics),
            "selected_alternative_risk_diagnostics": (
                _risk_diag_summary(selected_risk_diagnostics)
                if selected_risk_diagnostics is not None else "NOT_APPLICABLE_KEEP"
            ),
        },
        "next_recomposition_utc": _next_recomposition_utc(as_of),
        "recommendation_text": _recommendation_text(venue, proposal, manifest),
        "owner_action": _owner_action(venue, proposal),
        "snapshot_dir": str(snapshot_dir),
    }

    if venue == "ftmo":
        read_model["demo_cycle"] = _ftmo_demo_cycle(manifest)

    return read_model


def _risk_diag_summary(diag: Mapping[str, Any] | None) -> dict[str, Any]:
    """Compact risk-diagnostics view for the read-model proposal (incumbent + selected)."""
    diag = diag or {}
    return {
        "status": diag.get("status", "EVIDENCE_MISSING"),
        "cap_warnings": diag.get("cap_warnings", []),
        "change_concentration_warnings": diag.get("change_concentration_warnings", []),
        "hard_guards_passed": (diag.get("hard_guards") or {}).get("passed"),
        "reason": diag.get("reason"),
    }


def _freshness(live: Mapping[str, Any]) -> str:
    for source in live.get("sources", []):
        if isinstance(source, Mapping) and source.get("mtime_utc"):
            return str(source["mtime_utc"])
    return "EVIDENCE_MISSING"


def _ftmo_demo_cycle(manifest: Mapping[str, Any]) -> Any:
    """Return the FTMO demo_cycle captured into the snapshot at freeze time (E1 M1).

    ``evaluate`` is a pure function of the frozen snapshot: the readiness read-model is
    captured (with sha256) in ``freeze`` and read ONLY from the manifest here, so a
    change to the live ``ftmo_challenge_readiness.json`` after freeze never alters an
    evaluation of the same snapshot.
    """
    readiness = manifest.get("ftmo_readiness") or {}
    return readiness.get("demo_cycle", "EVIDENCE_MISSING")


def _recommendation_text(venue: str, proposal: Mapping[str, Any], manifest: Mapping[str, Any]) -> str:
    outcome = proposal["outcome"]
    pool = manifest["qualified_pool"]["count"]
    if venue == "dxz":
        if outcome == "KEEP":
            return (
                f"DXZ weekly recomposition ({manifest['iso_week']}): default KEEP. "
                f"No alternative over the {pool}-pair qualified pool cleared the section 59 "
                "materiality threshold vs the live 24-sleeve book. Book quality/marginal "
                "contribution decision, not a count target."
            )
        return (
            f"DXZ weekly recomposition ({manifest['iso_week']}): proposed {outcome} "
            f"(selected {proposal.get('selected_alternative')}). Material improvement cleared "
            "section 59. OWNER review required before any live change."
        )
    return (
        f"FTMO weekly recomposition ({manifest['iso_week']}): {outcome}. FTMO_FITNESS "
        "(first-passage / breach probability) is not yet computed for the demo roster "
        "(slice F1 pending); continue the representative demo before any purchase decision."
    )


def _owner_action(venue: str, proposal: Mapping[str, Any]) -> str:
    if proposal["outcome"] in {"KEEP", "NO_VALID_CHANGE", "CONTINUE_OBSERVATION"}:
        return "NONE"
    return (
        "REVIEW_PROPOSED_CHANGE (prepared artifacts; live deployment / AutoTrading remain "
        "OWNER-only, never automated)"
    )


def _render_evidence(evaluation: Mapping[str, Any], manifest: Mapping[str, Any]) -> str:
    venue = evaluation["venue"]
    lines: list[str] = []
    lines.append(f"# Book evolution evidence — {venue.upper()} {evaluation['iso_week']}")
    lines.append("")
    lines.append(f"Frozen at: `{evaluation['frozen_at_utc']}` · git `{evaluation.get('git_commit')}` · seed `{evaluation['seed']}`.")
    lines.append(f"Snapshot: `{evaluation['snapshot_dir']}`.")
    lines.append(f"Deterministic + reproducible from the frozen snapshot alone (directive section 70).")
    lines.append("")
    lines.append("## Proposal")
    prop = evaluation["proposal"]
    lines.append(f"- Outcome: **{prop['outcome']}** (weekly default is KEEP; change only on material evidence, section 6/59).")
    lines.append(f"- Selected alternative: `{prop.get('selected_alternative')}`.")
    lines.append(f"- OWNER action: `{evaluation['read_model']['owner_action']}`.")
    lines.append("")
    lines.append("## Qualified pool")
    qp = evaluation["qualified_pool"]
    lines.append(f"- Count: **{qp['count']}** — definition: {qp['definition']}.")
    lines.append(f"- Source: `{qp.get('meta', {}).get('source')}`.")
    lines.append("")
    lines.append("## Incumbent-vs-qualified reconciliation (DL-089 requalification)")
    lines.extend(_reconciliation_lines(evaluation, manifest))
    lines.append("")
    lines.append("## Labelled incumbents")
    for rep in evaluation["incumbent_reports"]:
        if not rep.get("metrics"):
            lines.append(f"- `{rep.get('label')}`: {rep.get('status')} (no evaluable streams).")
            continue
        m = rep["metrics"]
        f = rep["fitness"]
        lines.append(
            f"- `{rep['label']}` ({rep['sleeve_count']} sleeves): "
            f"ann {m.get('expected_return_annual_pct')}% · maxDD {m.get('max_drawdown_pct')}% · "
            f"Sharpe {m.get('sharpe')} · ENB {m.get('effective_number_of_bets')} · "
            f"tailES5 {m.get('tail_loss_es5_pct')}% · fitness `{f.get('objective')}`."
        )
    lines.append("")
    lines.append("## Alternatives assessed (top by delta objective)")
    ranked = sorted(
        (a for a in evaluation["alternatives_assessed"] if a["label"] != "incumbent"),
        key=lambda a: -(a["materiality"]["factors"].get("delta_objective") or float("-inf")),
    )
    for a in ranked[:12]:
        mat = a["materiality"]
        lines.append(
            f"- `{a['label']}` → {a['change'].get('outcome')}: "
            f"Δobjective `{mat['factors'].get('delta_objective')}` · "
            f"material `{mat.get('material')}` · reasons {mat.get('reasons')}"
        )
    lines.append("")
    lines.append("## Advisory risk diagnostics (b2 caps -> advisory; carried into output)")
    rd = evaluation.get("risk_diagnostics", {})
    if rd.get("status") == "PRESENT":
        warns = rd.get("cap_warnings", [])
        hard = (rd.get("hard_guards") or {}).get("passed")
        lines.append(f"- Hard portfolio guards passed: `{hard}`; advisory cap warnings: `{len(warns)}`.")
        for w in warns:
            lines.append(
                f"  - `{w.get('cap')}` `{w.get('key')}`: `{w.get('value')}` vs threshold "
                f"`{w.get('threshold')}` ({w.get('unit')}); sleeves {w.get('affected_sleeves')}"
            )
        lines.append(f"- Dependence panel entries (pairwise + downside corr + trade overlap): `{len(rd.get('dependence_panel', []))}`.")
    else:
        lines.append(f"- Risk diagnostics EVIDENCE_MISSING: `{rd.get('reason')}`.")
    lines.append("")
    lines.append("## Selected / proposed alternative risk diagnostics (E1 review M2)")
    lines.extend(_selected_risk_lines(evaluation))
    lines.append("")
    lines.append("## Streams")
    st = manifest["streams"]
    lines.append(f"- Present: {st['count_present']} · missing: {st['count_missing']}.")
    if st["missing"]:
        lines.append(f"- Missing streams (no metric contribution, not zero-filled): {st['missing']}")
    lines.append("")
    lines.append("## Provenance / boundaries")
    lines.append("- Deterministic code for all numbers; the only RNG is the seeded materiality bootstrap.")
    lines.append("- No farm-DB write, no terminal start, no deployment, no AutoTrading toggle (OWNER-only).")
    return "\n".join(lines) + "\n"


def _selected_risk_lines(evaluation: Mapping[str, Any]) -> list[str]:
    """Render the proposed alternative's concentration/dependence diagnostics.

    When the outcome is KEEP there is no selected alternative; the top-by-delta
    alternative is shown instead so the reviewer still sees what a change would concentrate.
    """
    prop = evaluation.get("proposal", {})
    assessed = [a for a in evaluation.get("alternatives_assessed", []) if a.get("label") != "incumbent"]
    label = prop.get("selected_alternative")
    if not label:
        ranked = sorted(
            assessed,
            key=lambda a: -(a["materiality"]["factors"].get("delta_objective") or float("-inf")),
        )
        chosen = ranked[0] if ranked else None
        prefix = "Top-by-delta alternative (outcome is KEEP; shown for concentration visibility)"
    else:
        chosen = next((a for a in assessed if a.get("label") == label), None)
        prefix = f"Selected alternative `{label}`"
    if chosen is None:
        return ["- No alternative evaluated."]
    rd = chosen.get("risk_diagnostics") or {}
    lines = [f"- {prefix}."]
    if rd.get("status") == "PRESENT":
        hard = (rd.get("hard_guards") or {}).get("passed")
        warns = rd.get("cap_warnings", [])
        lines.append(f"  - Hard portfolio guards passed: `{hard}`; advisory cap warnings: `{len(warns)}`.")
        for w in warns:
            lines.append(
                f"    - `{w.get('cap')}` `{w.get('key')}`: `{w.get('value')}` vs `{w.get('threshold')}`."
            )
    else:
        lines.append(f"  - Risk diagnostics: `{rd.get('status')}` ({rd.get('reason')}).")
    conc = rd.get("change_concentration_warnings") or []
    if conc:
        lines.append(f"  - Change-concentration warnings (advisory, non-blocking): `{len(conc)}`.")
        for w in conc:
            lines.append(
                f"    - `{w.get('key')}`: {w.get('note')} "
                f"(share of budget `{w.get('share_of_budget_pct')}%`)."
            )
    else:
        lines.append("  - Change-concentration warnings: none.")
    dep = chosen["materiality"]["factors"].get("dependence_risk") or {}
    lines.append(
        f"  - Dependence risk: hard_guards_passed=`{dep.get('hard_guards_passed')}` · "
        f"Δmean|downside-corr|=`{dep.get('delta_mean_abs_downside_correlation')}` "
        f"(band `{dep.get('max_downside_corr_worsening')}`) · pass=`{dep.get('pass')}`."
    )
    return lines


def _reconciliation_lines(evaluation: Mapping[str, Any], manifest: Mapping[str, Any]) -> list[str]:
    pool = {(_parse_key(p)) for p in manifest["qualified_pool"]["pairs"]}
    lines: list[str] = []
    for inc in manifest.get("incumbents", []):
        keys = {(int(s["ea_id"]), str(s["symbol"])) for s in inc.get("sleeves", [])}
        overlap = keys & pool
        non_qual = sorted(keys - pool)
        lines.append(
            f"- `{inc.get('label')}`: {len(keys)} sleeves; {len(overlap)} in the qualified pool; "
            f"{len(non_qual)} NOT currently qualified (retained, not dropped; DL-089 requalification status)."
        )
        if non_qual:
            labels = ", ".join(f"{e}:{s}" for e, s in non_qual[:40])
            lines.append(f"  - Non-qualified incumbents (need DL-089 requalification): {labels}")
    return lines


def freeze(venue: str, out: Path, **kwargs: Any) -> dict[str, Any]:
    return frozen_snapshot.freeze(venue, out, **kwargs)


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Continuous book recomposition engine (E1).")
    sub = parser.add_subparsers(dest="command", required=True)

    p_freeze = sub.add_parser("freeze", help="freeze the recomposition inputs into a snapshot dir")
    p_freeze.add_argument("--venue", required=True, choices=["dxz", "ftmo"])
    p_freeze.add_argument("--out", required=True, type=Path)
    p_freeze.add_argument("--seed", type=int, default=0)
    p_freeze.add_argument("--pairs", type=str, default=None, help="optional explicit ea:symbol,... pool override")

    p_eval = sub.add_parser("evaluate", help="evaluate a frozen snapshot into the read-model")
    p_eval.add_argument("--venue", required=True, choices=["dxz", "ftmo"])
    p_eval.add_argument("--snapshot", required=True, type=Path)
    p_eval.add_argument("--out", required=True, type=Path)
    p_eval.add_argument("--risk-budget", type=float, default=None)
    p_eval.add_argument("--sleeve-cap", type=float, default=DEFAULT_DXZ_SLEEVE_CAP)

    args = parser.parse_args(argv)
    if args.command == "freeze":
        pairs = None
        if args.pairs:
            pairs = [_parse_key(t.strip()) for t in args.pairs.split(",") if t.strip()]
        manifest = freeze(args.venue, args.out, seed=args.seed, qualified_pairs=pairs)
        print(json.dumps({
            "freeze": args.venue,
            "out": str(args.out),
            "qualified_pool": manifest["qualified_pool"]["count"],
            "streams_present": manifest["streams"]["count_present"],
            "streams_missing": manifest["streams"]["count_missing"],
        }, indent=2))
        return 0

    read_model = evaluate(
        args.venue,
        args.snapshot,
        args.out,
        risk_budget=args.risk_budget,
        sleeve_cap=args.sleeve_cap,
    )
    print(json.dumps({
        "evaluate": args.venue,
        "outcome": read_model["proposal"]["outcome"],
        "owner_action": read_model["owner_action"],
        "out": str(args.out),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
